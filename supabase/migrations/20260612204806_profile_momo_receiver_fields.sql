-- Store the user's default MoMo receiver details on the profile.
-- MoMo numbers are saved in Rwanda local format (07XXXXXXXX), not +2507...

begin;

alter table public.profiles
  add column if not exists momo_number text,
  add column if not exists momo_pay_code text;

comment on column public.profiles.momo_number is
  'Default Rwanda MoMo receiver number in local 07XXXXXXXX format.';

comment on column public.profiles.momo_pay_code is
  'Optional MoMo Pay merchant code used for BioPay QR receive requests.';

create index if not exists idx_profiles_momo_number
  on public.profiles(momo_number)
  where momo_number is not null and momo_number <> '';

create index if not exists idx_profiles_momo_pay_code
  on public.profiles(momo_pay_code)
  where momo_pay_code is not null and momo_pay_code <> '';

create or replace function public.fn_momo_local_number(p_value text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g');
begin
  if v_digits = '' then
    return null;
  end if;

  if length(v_digits) = 12 and left(v_digits, 4) = '2507' then
    return '0' || substr(v_digits, 4);
  end if;

  if length(v_digits) = 9 and left(v_digits, 1) = '7' then
    return '0' || v_digits;
  end if;

  if length(v_digits) = 10 and left(v_digits, 2) = '07' then
    return v_digits;
  end if;

  return v_digits;
end;
$$;

create or replace function public.rpc_update_profile(p_payload json)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_vehicle_type text := v_payload->>'vehicle_type';
  v_profile public.profiles%rowtype;
begin
  update public.profiles
  set name                 = coalesce(v_payload->>'name', name),
      display_name         = coalesce(v_payload->>'display_name', display_name),
      phone                = coalesce(v_payload->>'phone', phone),
      whatsapp             = coalesce(v_payload->>'whatsapp', whatsapp),
      momo_number          = case
        when v_payload ? 'momo_number' then
          public.fn_momo_local_number(v_payload->>'momo_number')
        else momo_number
      end,
      momo_pay_code        = case
        when v_payload ? 'momo_pay_code' then
          nullif(regexp_replace(v_payload->>'momo_pay_code', '[^0-9]', '', 'g'), '')
        else momo_pay_code
      end,
      country_code         = coalesce(v_payload->>'country_code', country_code),
      vehicle_type         = coalesce((v_payload->>'vehicle_type')::public.vehicle_type_enum, vehicle_type),
      vehicle_number_plate = case
        when v_payload ? 'vehicle_number_plate' then
          nullif(upper(trim(v_payload->>'vehicle_number_plate')), '')
        else vehicle_number_plate
      end,
      bus_agency_name = case
        when v_payload ? 'bus_agency_name' then
          nullif(trim(v_payload->>'bus_agency_name'), '')
        when v_vehicle_type is not null and v_vehicle_type <> 'bus' then
          null
        else bus_agency_name
      end,
      bus_passenger_capacity = case
        when v_payload ? 'bus_passenger_capacity'
          and nullif(trim(v_payload->>'bus_passenger_capacity'), '') is not null then
            (v_payload->>'bus_passenger_capacity')::integer
        when v_payload ? 'bus_passenger_capacity' then
          null
        when v_vehicle_type is not null and v_vehicle_type <> 'bus' then
          null
        else bus_passenger_capacity
      end,
      avatar_url           = coalesce(v_payload->>'avatar_url', avatar_url),
      last_known_lat       = coalesce((v_payload->>'last_known_lat')::double precision, last_known_lat),
      last_known_lng       = coalesce((v_payload->>'last_known_lng')::double precision, last_known_lng),
      last_seen_at         = coalesce((v_payload->>'last_seen_at')::timestamptz, last_seen_at)
  where public.profiles.id = auth.uid()
  returning * into v_profile;

  if not found then
    raise exception using
      errcode = '28000',
      message = 'AUTHENTICATION_REQUIRED',
      detail = 'Profile updates require an authenticated user.';
  end if;

  if v_profile.is_driver = true then
    perform public.fn_upsert_active_vehicle(
      v_profile.id,
      v_profile.vehicle_type::text,
      v_profile.vehicle_number_plate
    );
  end if;

  if v_profile.is_driver = true
    and v_profile.vehicle_type = 'bus'
    and (
      nullif(trim(coalesce(v_profile.bus_agency_name, '')), '') is null
      or v_profile.bus_passenger_capacity is null
      or v_profile.bus_passenger_capacity not between 1 and 120
    )
  then
    raise exception using
      errcode = '22023',
      message = 'BUS_DRIVER_DETAILS_REQUIRED',
      detail = 'Bus drivers must provide agency name and passenger capacity.';
  end if;
end;
$$;

revoke all on function public.rpc_update_profile(json)
  from public, anon, authenticated;
grant execute on function public.rpc_update_profile(json) to authenticated;

create or replace function public.rpc_create_biopay_ussd_request(
  p_channel text,
  p_amount_minor integer,
  p_payee_label text,
  p_provider_code text default 'mtn_rw',
  p_payee_phone text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_reference text := 'BP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  v_phone text := public.fn_momo_local_number(p_payee_phone);
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_channel not in ('qr', 'nfc', 'face') then
    raise exception 'Invalid BioPay channel';
  end if;

  if p_amount_minor < 0 then
    raise exception 'Amount cannot be negative';
  end if;

  select coalesce(
      v_phone,
      public.fn_momo_local_number(momo_number),
      public.fn_momo_local_number(whatsapp),
      public.fn_momo_local_number(phone)
    )
    into v_phone
  from public.profiles
  where id = v_user_id;

  v_phone := coalesce(v_phone, public.fn_momo_local_number(p_payee_phone));

  insert into public.biopay_payment_requests (
    channel,
    payee_id,
    payee_label,
    provider_code,
    amount_minor,
    reference,
    ussd_code
  ) values (
    p_channel,
    v_user_id,
    coalesce(nullif(trim(p_payee_label), ''), 'BioPay merchant'),
    coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
    p_amount_minor,
    v_reference,
    public.fn_biopay_ussd_code(
      coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
      v_phone,
      p_amount_minor,
      v_reference
    )
  )
  returning * into v_row;

  insert into public.biopay_audit_events(actor_user_id, request_id, action)
  values (v_user_id, v_row.id, 'biopay.ussd_request.created');

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.rpc_create_biopay_ussd_request(text, integer, text, text, text)
  from public, anon, authenticated;
grant execute on function public.rpc_create_biopay_ussd_request(text, integer, text, text, text)
  to authenticated;

commit;
