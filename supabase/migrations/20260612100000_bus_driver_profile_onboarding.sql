-- Add bus-specific driver onboarding fields to profiles.
-- These fields support the approved public-transport expansion without
-- creating dispatch, fare, payment, or legacy trip lifecycle behavior.

begin;

alter table public.profiles
  add column if not exists bus_agency_name text,
  add column if not exists bus_passenger_capacity integer;

alter table public.profiles
  drop constraint if exists profiles_bus_passenger_capacity_check;

alter table public.profiles
  add constraint profiles_bus_passenger_capacity_check
  check (
    bus_passenger_capacity is null
    or (bus_passenger_capacity between 1 and 120)
  );

comment on column public.profiles.bus_agency_name is
  'Driver-provided agency name when the profile vehicle type is bus.';

comment on column public.profiles.bus_passenger_capacity is
  'Driver-provided bus passenger capacity for public transport onboarding.';

create index if not exists idx_profiles_bus_agency_name
  on public.profiles(bus_agency_name)
  where bus_agency_name is not null and bus_agency_name <> '';

create or replace function public.rpc_update_profile(p_payload json)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_vehicle_type text := v_payload->>'vehicle_type';
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
      avatar_url           = coalesce(v_payload->>'avatar_url', avatar_url),
      last_known_lat       = coalesce((v_payload->>'last_known_lat')::double precision, last_known_lat),
      last_known_lng       = coalesce((v_payload->>'last_known_lng')::double precision, last_known_lng),
      last_seen_at         = coalesce((v_payload->>'last_seen_at')::timestamptz, last_seen_at)
  where public.profiles.id = auth.uid();

  if exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_driver = true
      and p.vehicle_type = 'bus'
      and (
        nullif(trim(coalesce(p.bus_agency_name, '')), '') is null
        or p.bus_passenger_capacity is null
        or p.bus_passenger_capacity not between 1 and 120
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'BUS_DRIVER_DETAILS_REQUIRED',
      detail = 'Bus drivers must provide agency name and passenger capacity.';
  end if;
end;
$$;

grant execute on function public.rpc_update_profile(json) to authenticated;

drop function if exists public.rpc_enable_driver_mode(text, text);
drop function if exists public.rpc_enable_driver_mode(text, text, text, integer);

create or replace function public.rpc_enable_driver_mode(
  p_vehicle_type text default 'cab',
  p_vehicle_number_plate text default null,
  p_bus_agency_name text default null,
  p_bus_passenger_capacity integer default null
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
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires WhatsApp Cloud API login.';
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

  update public.profiles
  set
    is_driver = true,
    vehicle_type = p_vehicle_type::public.vehicle_type_enum,
    vehicle_number_plate = coalesce(
      nullif(upper(trim(p_vehicle_number_plate)), ''),
      vehicle_number_plate
    ),
    bus_agency_name = case
      when p_vehicle_type = 'bus' then nullif(trim(p_bus_agency_name), '')
      else null
    end,
    bus_passenger_capacity = case
      when p_vehicle_type = 'bus' then p_bus_passenger_capacity
      else null
    end,
    role = 'driver'
  where id = v_user_id;
end;
$$;

revoke all on function public.rpc_enable_driver_mode(text, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text, text, integer)
  to authenticated;

drop function if exists public.rpc_get_public_profile(uuid);

create or replace function public.rpc_get_public_profile(p_profile_id uuid)
returns table (
  id uuid,
  member_id text,
  name text,
  display_name text,
  role text,
  vehicle_type text,
  vehicle_number_plate text,
  bus_agency_name text,
  bus_passenger_capacity integer,
  is_driver boolean,
  avatar_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
begin
  if v_self_id is null then
    raise exception using
      errcode = '28000',
      message = 'authentication required';
  end if;

  if p_profile_id is null then
    return;
  end if;

  if p_profile_id <> v_self_id
    and not public.is_platform_admin()
    and not exists (
      select 1
      from public.chat_conversations c
      where v_self_id in (c.participant_low_id, c.participant_high_id)
        and p_profile_id in (c.participant_low_id, c.participant_high_id)
    )
    and not exists (
      select 1
      from public.trips t
      where t.author_id = p_profile_id
        and t.is_active = true
        and t.status in ('active', 'approved')
    )
  then
    return;
  end if;

  return query
  select
    p.id,
    p.member_id,
    p.name,
    p.display_name,
    p.role::text,
    p.vehicle_type::text,
    p.vehicle_number_plate,
    p.bus_agency_name,
    p.bus_passenger_capacity,
    p.is_driver,
    p.avatar_url,
    p.created_at
  from public.profiles p
  where p.id = p_profile_id;
end;
$$;

comment on function public.rpc_get_public_profile(uuid)
  is 'Returns minimal profile fields for authenticated chat/trip directory use, including non-sensitive bus onboarding metadata.';

revoke all on function public.rpc_get_public_profile(uuid) from public;
revoke all on function public.rpc_get_public_profile(uuid) from anon;
revoke all on function public.rpc_get_public_profile(uuid) from authenticated;
grant execute on function public.rpc_get_public_profile(uuid) to authenticated;

commit;
