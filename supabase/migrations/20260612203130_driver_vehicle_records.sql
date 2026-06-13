-- Persist driver onboarding vehicles as durable rows.
-- Profiles keep the display cache, while public.vehicles stores the active
-- vehicle selected during onboarding and later profile edits.

begin;

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_type_id text not null references public.vehicle_types(id) on delete restrict,
  plate_number text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_plate_number_not_blank
    check (nullif(trim(plate_number), '') is not null)
);

alter table public.vehicles
  add column if not exists owner_id uuid references public.profiles(id) on delete cascade,
  add column if not exists vehicle_type_id text references public.vehicle_types(id) on delete restrict,
  add column if not exists plate_number text,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.vehicles
  alter column owner_id set not null,
  alter column vehicle_type_id set not null,
  alter column plate_number set not null,
  alter column is_active set default true,
  alter column created_at set default now(),
  alter column updated_at set default now();

alter table public.vehicles
  drop constraint if exists vehicles_plate_number_not_blank;

alter table public.vehicles
  add constraint vehicles_plate_number_not_blank
  check (nullif(trim(plate_number), '') is not null);

create unique index if not exists idx_vehicles_one_active_per_owner
  on public.vehicles(owner_id)
  where is_active;

create index if not exists idx_vehicles_owner_active
  on public.vehicles(owner_id, is_active);

create index if not exists idx_vehicles_plate_search
  on public.vehicles(upper(plate_number));

drop trigger if exists set_vehicles_updated_at on public.vehicles;
create trigger set_vehicles_updated_at
before update on public.vehicles
for each row execute function public.handle_updated_at();

alter table public.vehicles enable row level security;

drop policy if exists vehicles_select_owner_or_admin on public.vehicles;
create policy vehicles_select_owner_or_admin
  on public.vehicles
  for select
  to authenticated
  using (owner_id = auth.uid() or public.is_platform_admin());

drop policy if exists vehicles_admin_insert on public.vehicles;
create policy vehicles_admin_insert
  on public.vehicles
  for insert
  to authenticated
  with check (public.is_platform_admin());

drop policy if exists vehicles_admin_update on public.vehicles;
create policy vehicles_admin_update
  on public.vehicles
  for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists vehicles_admin_delete on public.vehicles;
create policy vehicles_admin_delete
  on public.vehicles
  for delete
  to authenticated
  using (public.is_platform_admin());

grant select on public.vehicles to authenticated;

create or replace function public.fn_upsert_active_vehicle(
  p_owner_id uuid,
  p_vehicle_type_id text,
  p_plate_number text
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

  update public.vehicles
  set
    vehicle_type_id = v_vehicle_type_id,
    plate_number = v_plate_number,
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
      is_active
    )
    values (
      p_owner_id,
      v_vehicle_type_id,
      v_plate_number,
      true
    )
    returning id into v_vehicle_id;
  end if;

  return v_vehicle_id;
end;
$$;

revoke all on function public.fn_upsert_active_vehicle(uuid, text, text)
  from public, anon, authenticated;

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
  v_plate_number text := nullif(
    upper(regexp_replace(trim(coalesce(p_vehicle_number_plate, '')), '\s+', ' ', 'g')),
    ''
  );
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

  perform public.fn_upsert_active_vehicle(
    v_user_id,
    p_vehicle_type,
    v_plate_number
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
    role = 'driver'
  where id = v_user_id;
end;
$$;

revoke all on function public.rpc_enable_driver_mode(text, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text, text, integer)
  to authenticated;

create or replace function public.rpc_disable_driver_mode()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using
      errcode = '28000',
      message = 'authentication required';
  end if;

  update public.profiles
  set
    is_driver = false,
    role = 'passenger'
  where id = v_user_id;

  update public.vehicles
  set
    is_active = false,
    updated_at = now()
  where owner_id = v_user_id
    and is_active = true;
end;
$$;

revoke all on function public.rpc_disable_driver_mode()
  from public, anon, authenticated;
grant execute on function public.rpc_disable_driver_mode()
  to authenticated;

commit;
