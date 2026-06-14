-- Add rental vehicles as a first-class driver/owner vehicle type.
-- Rental owners choose a broad model class during onboarding/profile setup.

alter type public.vehicle_type_enum add value if not exists 'rentals';

insert into public.vehicle_types (id, label, icon_name, sort_order, is_active)
values ('rentals', 'Rentals', 'key-round', 7, true)
on conflict (id) do update
set
  label = excluded.label,
  icon_name = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

update public.vehicle_types
set sort_order = case id
  when 'moto' then 1
  when 'bus' then 2
  when 'cab' then 3
  when 'truck' then 4
  when 'trike' then 5
  when 'private' then 6
  when 'rentals' then 7
  else sort_order
end,
label = case id
  when 'moto' then 'Moto Taxi'
  when 'bus' then 'Bus'
  when 'cab' then 'Cab'
  when 'truck' then 'Truck'
  when 'trike' then 'Trike'
  when 'private' then 'Others'
  when 'rentals' then 'Rentals'
  else label
end,
updated_at = now()
where id in ('moto', 'bus', 'cab', 'truck', 'trike', 'private', 'rentals');

alter table public.profiles
  add column if not exists rental_vehicle_model text;

alter table public.profiles
  drop constraint if exists profiles_rental_vehicle_model_check;

alter table public.profiles
  add constraint profiles_rental_vehicle_model_check
  check (
    rental_vehicle_model is null
    or rental_vehicle_model in ('SUV', 'Sedan', 'Truck', 'Van', 'Bus')
  );

alter table public.vehicles
  add column if not exists rental_vehicle_model text;

alter table public.vehicles
  drop constraint if exists vehicles_rental_vehicle_model_check;

alter table public.vehicles
  add constraint vehicles_rental_vehicle_model_check
  check (
    rental_vehicle_model is null
    or rental_vehicle_model in ('SUV', 'Sedan', 'Truck', 'Van', 'Bus')
  );

insert into public.driver_plus_rules (
  vehicle_type_id,
  requires_plus,
  free_trial_days,
  free_daily_request_limit,
  free_total_request_limit,
  is_free_forever,
  is_active
)
values ('rentals', false, 0, 0, 0, true, true)
on conflict (vehicle_type_id) do update
set
  requires_plus = excluded.requires_plus,
  free_trial_days = excluded.free_trial_days,
  free_daily_request_limit = excluded.free_daily_request_limit,
  free_total_request_limit = excluded.free_total_request_limit,
  is_free_forever = excluded.is_free_forever,
  is_active = excluded.is_active,
  updated_at = now();

drop function if exists public.fn_upsert_active_vehicle(uuid, text, text);
drop function if exists public.fn_upsert_active_vehicle(uuid, text, text, text);

create or replace function public.fn_upsert_active_vehicle(
  p_owner_id uuid,
  p_vehicle_type_id text,
  p_plate_number text,
  p_rental_vehicle_model text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehicle_id uuid;
  v_vehicle_type_id text := nullif(trim(coalesce(p_vehicle_type_id, '')), '');
  v_plate_number text := nullif(
    upper(regexp_replace(trim(coalesce(p_plate_number, '')), '\s+', ' ', 'g')),
    ''
  );
  v_rental_vehicle_model text := nullif(
    trim(coalesce(p_rental_vehicle_model, '')),
    ''
  );
begin
  if p_owner_id is null then
    raise exception using
      errcode = '28000',
      message = 'AUTHENTICATION_REQUIRED',
      detail = 'A driver profile is required before a vehicle can be saved.';
  end if;

  if v_vehicle_type_id is null then
    raise exception using
      errcode = '22023',
      message = 'VEHICLE_TYPE_REQUIRED',
      detail = 'Drivers must choose a vehicle type.';
  end if;

  if v_plate_number is null then
    raise exception using
      errcode = '22023',
      message = 'VEHICLE_PLATE_REQUIRED',
      detail = 'Drivers must provide a vehicle plate number.';
  end if;

  if not exists (
    select 1
    from public.vehicle_types vt
    where vt.id = v_vehicle_type_id
      and vt.is_active = true
  ) then
    raise exception using
      errcode = '22023',
      message = 'VEHICLE_TYPE_UNAVAILABLE',
      detail = 'The selected vehicle type is not available.';
  end if;

  if v_vehicle_type_id = 'rentals'
    and coalesce(v_rental_vehicle_model, '') not in ('SUV', 'Sedan', 'Truck', 'Van', 'Bus')
  then
    raise exception using
      errcode = '22023',
      message = 'RENTAL_VEHICLE_MODEL_REQUIRED',
      detail = 'Rental owners must choose SUV, Sedan, Truck, Van, or Bus.';
  end if;

  if v_vehicle_type_id <> 'rentals' then
    v_rental_vehicle_model := null;
  end if;

  update public.vehicles
  set
    vehicle_type_id = v_vehicle_type_id,
    plate_number = v_plate_number,
    rental_vehicle_model = v_rental_vehicle_model,
    is_active = true,
    updated_at = now()
  where owner_id = p_owner_id
    and is_active = true
  returning id into v_vehicle_id;

  if v_vehicle_id is null then
    insert into public.vehicles (
      owner_id,
      vehicle_type_id,
      plate_number,
      rental_vehicle_model,
      is_active
    )
    values (
      p_owner_id,
      v_vehicle_type_id,
      v_plate_number,
      v_rental_vehicle_model,
      true
    )
    returning id into v_vehicle_id;
  end if;

  return v_vehicle_id;
end;
$$;

revoke all on function public.fn_upsert_active_vehicle(uuid, text, text, text)
  from public, anon, authenticated;

create or replace function public.rpc_update_profile(p_payload json)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_vehicle_type text := v_payload->>'vehicle_type';
  v_rental_vehicle_model text := nullif(trim(coalesce(v_payload->>'rental_vehicle_model', '')), '');
  v_profile public.profiles%rowtype;
begin
  update public.profiles
  set name                 = coalesce(v_payload->>'name', name),
      display_name         = coalesce(v_payload->>'display_name', display_name),
      phone                = coalesce(v_payload->>'phone', phone),
      whatsapp             = coalesce(v_payload->>'whatsapp', whatsapp),
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
      rental_vehicle_model = case
        when v_payload ? 'rental_vehicle_model' then v_rental_vehicle_model
        when v_vehicle_type is not null and v_vehicle_type <> 'rentals' then null
        else rental_vehicle_model
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
      v_profile.vehicle_number_plate,
      v_profile.rental_vehicle_model
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

  if v_profile.is_driver = true
    and v_profile.vehicle_type = 'rentals'
    and coalesce(v_profile.rental_vehicle_model, '') not in ('SUV', 'Sedan', 'Truck', 'Van', 'Bus')
  then
    raise exception using
      errcode = '22023',
      message = 'RENTAL_VEHICLE_MODEL_REQUIRED',
      detail = 'Rental owners must choose SUV, Sedan, Truck, Van, or Bus.';
  end if;
end;
$$;

revoke all on function public.rpc_update_profile(json)
  from public, anon, authenticated;
grant execute on function public.rpc_update_profile(json) to authenticated;

drop function if exists public.rpc_enable_driver_mode(text, text);
drop function if exists public.rpc_enable_driver_mode(text, text, text, integer);
drop function if exists public.rpc_enable_driver_mode(text, text, text, integer, text);

create or replace function public.rpc_enable_driver_mode(
  p_vehicle_type text default 'cab',
  p_vehicle_number_plate text default null,
  p_bus_agency_name text default null,
  p_bus_passenger_capacity integer default null,
  p_rental_vehicle_model text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_anonymous boolean :=
    coalesce((auth.jwt()->>'is_anonymous')::boolean, false);
  v_profile public.profiles%rowtype;
  v_plate_number text := nullif(
    upper(regexp_replace(trim(coalesce(p_vehicle_number_plate, '')), '\s+', ' ', 'g')),
    ''
  );
  v_rental_vehicle_model text := nullif(trim(coalesce(p_rental_vehicle_model, '')), '');
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires WhatsApp Cloud API login.';
  end if;

  if v_plate_number is null then
    raise exception using
      errcode = '22023',
      message = 'VEHICLE_PLATE_REQUIRED',
      detail = 'Drivers must provide a vehicle plate number.';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = v_user_id;

  if not found
    or v_profile.whatsapp_verified_at is null
    or coalesce(v_profile.auth_provider, '') <> 'whatsapp_cloud_otp'
  then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires a verified WhatsApp account.';
  end if;

  if p_vehicle_type = 'bus' and (
    nullif(trim(coalesce(p_bus_agency_name, '')), '') is null
    or p_bus_passenger_capacity is null
    or p_bus_passenger_capacity not between 1 and 120
  ) then
    raise exception using
      errcode = '22023',
      message = 'BUS_DRIVER_DETAILS_REQUIRED',
      detail = 'Bus drivers must provide agency name and passenger capacity.';
  end if;

  if p_vehicle_type = 'rentals'
    and coalesce(v_rental_vehicle_model, '') not in ('SUV', 'Sedan', 'Truck', 'Van', 'Bus')
  then
    raise exception using
      errcode = '22023',
      message = 'RENTAL_VEHICLE_MODEL_REQUIRED',
      detail = 'Rental owners must choose SUV, Sedan, Truck, Van, or Bus.';
  end if;

  perform public.fn_upsert_active_vehicle(
    v_user_id,
    p_vehicle_type,
    v_plate_number,
    v_rental_vehicle_model
  );

  update public.profiles
  set
    is_driver = true,
    vehicle_type = p_vehicle_type::public.vehicle_type_enum,
    vehicle_number_plate = v_plate_number,
    bus_agency_name = case
      when p_vehicle_type = 'bus' then nullif(trim(p_bus_agency_name), '')
      else null
    end,
    bus_passenger_capacity = case
      when p_vehicle_type = 'bus' then p_bus_passenger_capacity
      else null
    end,
    rental_vehicle_model = case
      when p_vehicle_type = 'rentals' then v_rental_vehicle_model
      else null
    end,
    role = 'driver'
  where id = v_user_id;
end;
$$;

revoke all on function public.rpc_enable_driver_mode(text, text, text, integer, text)
  from public, anon, authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text, text, integer, text)
  to authenticated;
