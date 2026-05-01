begin;

-- Repair remote schema drift so the currently deployed RPCs compile cleanly.
-- This migration is intentionally idempotent because several columns/functions
-- already exist in local migrations but are missing or stale in the linked DB.

do $$
begin
  create type public.vehicle_type_enum as enum ('moto', 'cab', 'trike', 'truck', 'private');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.user_role_enum as enum ('passenger', 'driver', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.trip_status_enum as enum ('active', 'cancelled', 'completed', 'pending', 'approved', 'suspended', 'blocked');
exception
  when duplicate_object then null;
end $$;

alter table public.profiles
  add column if not exists last_known_lat double precision,
  add column if not exists last_known_lng double precision,
  add column if not exists last_seen_at timestamptz,
  add column if not exists display_name text,
  add column if not exists biopay_handle_type text not null default 'number',
  add column if not exists biopay_handle_value text not null default '',
  add column if not exists face_registered_at timestamptz,
  add column if not exists vehicle_number_plate text;

update public.profiles
set display_name = name
where display_name is null
  and coalesce(name, '') <> '';

alter table public.trips
  add column if not exists expires_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists starts_at timestamptz,
  add column if not exists origin_place_id text,
  add column if not exists destination_place_id text;

create index if not exists idx_trips_expires_at
  on public.trips(expires_at)
  where expires_at is not null;

create index if not exists idx_trips_starts_at
  on public.trips(starts_at)
  where starts_at is not null;

create index if not exists idx_profiles_last_seen
  on public.profiles(last_seen_at desc)
  where last_seen_at is not null;

create index if not exists idx_profiles_vehicle_number_plate
  on public.profiles(vehicle_number_plate)
  where vehicle_number_plate is not null
    and vehicle_number_plate <> '';

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'admin_whatsapp_numbers'
  )
  and not exists (
    select 1
    from pg_constraint c
    join pg_namespace n on n.oid = c.connamespace
    where n.nspname = 'public'
      and c.conname = 'admin_whatsapp_numbers_phone_e164_key'
  ) then
    alter table public.admin_whatsapp_numbers
      add constraint admin_whatsapp_numbers_phone_e164_key unique (phone_e164);
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'driver_locations'
  ) then
    alter table public.driver_locations
      add column if not exists vehicle_type_id text;

    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'driver_locations'
        and column_name = 'vehicle_type_id'
        and data_type = 'uuid'
    ) then
      alter table public.driver_locations
        alter column vehicle_type_id type text
        using vehicle_type_id::text;
    end if;
  end if;
end $$;

create or replace function public.rpc_get_discover_summary(
  p_user_lat double precision default null,
  p_user_lng double precision default null,
  p_vehicle_type text default null
)
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  result json;
  nearby_count integer;
  scheduled_count integer;
begin
  if p_user_lat is not null and p_user_lng is not null then
    select count(*)
    into nearby_count
    from public.driver_locations dl
    where dl.is_online = true
      and (p_vehicle_type is null or dl.vehicle_type_id = p_vehicle_type)
      and (6371 * acos(least(1, greatest(-1,
        cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
        cos(radians(dl.longitude) - radians(p_user_lng)) +
        sin(radians(p_user_lat)) * sin(radians(dl.latitude))
      )))) <= 10;
  else
    select count(*)
    into nearby_count
    from public.driver_locations dl
    where dl.is_online = true
      and (p_vehicle_type is null or dl.vehicle_type_id = p_vehicle_type);
  end if;

  select count(*)
  into scheduled_count
  from public.trips t
  where t.is_active = true
    and t.status = 'active'
    and (p_vehicle_type is null or t.vehicle_type = p_vehicle_type);

  select json_build_object(
    'nearby_driver_count', nearby_count,
    'scheduled_trip_count', scheduled_count
  )
  into result;

  return result;
end;
$$;

create or replace function public.rpc_search_nearby_drivers(
  p_user_lat double precision,
  p_user_lng double precision,
  p_search_text text default null,
  p_vehicle_type text default null,
  p_limit integer default 20
)
returns table (
  driver_id uuid,
  display_name text,
  vehicle_type_id text,
  plate_number text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  whatsapp text,
  member_id text
)
language plpgsql
security definer set search_path = ''
as $$
begin
  return query
  select
    dl.driver_id,
    coalesce(p.display_name, p.name) as display_name,
    coalesce(dl.vehicle_type_id, p.vehicle_type::text, 'cab') as vehicle_type_id,
    p.vehicle_number_plate as plate_number,
    dl.latitude,
    dl.longitude,
    (6371 * acos(least(1, greatest(-1,
      cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
      cos(radians(dl.longitude) - radians(p_user_lng)) +
      sin(radians(p_user_lat)) * sin(radians(dl.latitude))
    )))) as distance_km,
    p.whatsapp,
    p.member_id
  from public.driver_locations dl
  join public.profiles p on p.id = dl.driver_id
  where dl.is_online = true
    and (p_vehicle_type is null or coalesce(dl.vehicle_type_id, p.vehicle_type::text) = p_vehicle_type)
    and (
      p_search_text is null
      or p.name ilike '%' || p_search_text || '%'
      or coalesce(p.display_name, '') ilike '%' || p_search_text || '%'
      or coalesce(p.vehicle_number_plate, '') ilike '%' || p_search_text || '%'
    )
  order by distance_km asc
  limit greatest(coalesce(p_limit, 20), 1);
end;
$$;

create or replace function public.rpc_set_driver_online_status(p_is_online boolean)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set is_online = p_is_online,
      last_seen_at = timezone('utc', now())
  where public.profiles.id = auth.uid();

  update public.driver_locations
  set is_online = p_is_online,
      updated_at = timezone('utc', now())
  where driver_id = auth.uid();
end;
$$;

create or replace function public.rpc_update_profile(p_payload json)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set name                 = coalesce(p_payload->>'name', name),
      display_name         = coalesce(p_payload->>'display_name', display_name),
      phone                = coalesce(p_payload->>'phone', phone),
      whatsapp             = coalesce(p_payload->>'whatsapp', whatsapp),
      country_code         = coalesce(p_payload->>'country_code', country_code),
      vehicle_type         = coalesce((p_payload->>'vehicle_type')::public.vehicle_type_enum, vehicle_type),
      vehicle_number_plate = case
        when p_payload::jsonb ? 'vehicle_number_plate' then
          nullif(upper(trim(p_payload->>'vehicle_number_plate')), '')
        else vehicle_number_plate
      end,
      avatar_url           = coalesce(p_payload->>'avatar_url', avatar_url),
      biopay_handle_type   = coalesce(p_payload->>'biopay_handle_type', biopay_handle_type),
      biopay_handle_value  = coalesce(p_payload->>'biopay_handle_value', biopay_handle_value),
      last_known_lat       = coalesce((p_payload->>'last_known_lat')::double precision, last_known_lat),
      last_known_lng       = coalesce((p_payload->>'last_known_lng')::double precision, last_known_lng),
      last_seen_at         = coalesce((p_payload->>'last_seen_at')::timestamptz, last_seen_at)
  where public.profiles.id = auth.uid();
end;
$$;

drop function if exists public.rpc_enable_driver_mode(text);

create or replace function public.rpc_enable_driver_mode(
  p_vehicle_type text default 'cab',
  p_vehicle_number_plate text default null
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set is_driver = true,
      vehicle_type = p_vehicle_type::public.vehicle_type_enum,
      vehicle_number_plate = coalesce(
        nullif(upper(trim(p_vehicle_number_plate)), ''),
        vehicle_number_plate
      ),
      role = 'driver'
  where public.profiles.id = auth.uid();
end;
$$;

create or replace function public.rpc_admin_list_trips(
  p_status text default null,
  p_role text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  role text,
  vehicle_type text,
  status text,
  is_active boolean,
  created_at timestamptz,
  member_id text
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  return query
  select
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    t.departure_date,
    t.role,
    t.vehicle_type,
    t.status,
    t.is_active,
    t.created_at,
    p.member_id
  from public.trips t
  join public.profiles p on p.id = t.author_id
  where (p_status is null or t.status = p_status)
    and (p_role is null or t.role = p_role)
  order by t.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.rpc_admin_update_user_role(
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  update public.profiles
  set role = p_role::public.user_role_enum,
      is_driver = (p_role = 'driver')
  where public.profiles.id = p_user_id;

  insert into public.admin_audit_log (admin_id, action, target_type, target_id, details)
  values (
    auth.uid(),
    'update_role',
    'profile',
    p_user_id,
    json_build_object('new_role', p_role)::jsonb
  );
end;
$$;

create or replace function public.rpc_admin_upsert_whatsapp_number(
  p_phone_e164 text,
  p_country_code text,
  p_display_name text default null,
  p_is_active boolean default true
)
returns table (
  id uuid,
  phone_e164 text,
  country_code text,
  display_name text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
declare
  v_phone text;
  v_country text;
  v_record public.admin_whatsapp_numbers%rowtype;
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  v_phone := regexp_replace(trim(coalesce(p_phone_e164, '')), '\s+', '', 'g');
  v_country := regexp_replace(trim(coalesce(p_country_code, '')), '\s+', '', 'g');

  if v_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Invalid WhatsApp number. Use E.164 format.';
  end if;

  if v_country !~ '^\+[1-9][0-9]{0,4}$' then
    raise exception 'Invalid country code.';
  end if;

  if v_phone not like v_country || '%' then
    raise exception 'WhatsApp number must match the selected country code.';
  end if;

  insert into public.admin_whatsapp_numbers (
    phone_e164,
    country_code,
    display_name,
    is_active
  )
  values (
    v_phone,
    v_country,
    nullif(trim(coalesce(p_display_name, '')), ''),
    coalesce(p_is_active, true)
  )
  on conflict on constraint admin_whatsapp_numbers_phone_e164_key do update
  set country_code = excluded.country_code,
      display_name = excluded.display_name,
      is_active = excluded.is_active
  returning * into v_record;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'upsert_admin_whatsapp_number',
    'admin_whatsapp_number',
    v_record.id,
    jsonb_build_object(
      'phone_e164', v_record.phone_e164,
      'country_code', v_record.country_code,
      'display_name', v_record.display_name,
      'is_active', v_record.is_active
    )
  );

  return query
  select
    v_record.id,
    v_record.phone_e164,
    v_record.country_code,
    v_record.display_name,
    v_record.is_active,
    v_record.created_at,
    v_record.updated_at;
end;
$$;

create or replace function public.rpc_admin_set_whatsapp_number_active(
  p_id uuid,
  p_is_active boolean
)
returns table (
  id uuid,
  phone_e164 text,
  country_code text,
  display_name text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
declare
  v_record public.admin_whatsapp_numbers%rowtype;
  v_active_count integer;
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  if p_is_active = false then
    select count(*)
    into v_active_count
    from public.admin_whatsapp_numbers n
    where n.is_active = true
      and n.id <> p_id;

    if v_active_count = 0 then
      raise exception 'At least one active admin WhatsApp number must remain.';
    end if;
  end if;

  update public.admin_whatsapp_numbers n
  set is_active = p_is_active
  where n.id = p_id
  returning n.* into v_record;

  if v_record.id is null then
    raise exception 'Admin WhatsApp number not found.';
  end if;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_admin_whatsapp_number_active',
    'admin_whatsapp_number',
    v_record.id,
    jsonb_build_object(
      'phone_e164', v_record.phone_e164,
      'is_active', v_record.is_active
    )
  );

  return query
  select
    v_record.id,
    v_record.phone_e164,
    v_record.country_code,
    v_record.display_name,
    v_record.is_active,
    v_record.created_at,
    v_record.updated_at;
end;
$$;

create or replace function public.biopay_reenroll_profile(
  p_profile_id uuid,
  p_expected_owner_token_version integer,
  p_embedding vector,
  p_model_version text,
  p_quality_score double precision default null
)
returns table (
  id uuid,
  biopay_id text,
  display_name text,
  ussd_string text,
  status text,
  owner_token_version integer,
  management_code_hash text,
  management_code_hint text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.biopay_profiles%rowtype;
begin
  update public.biopay_profiles bp
  set owner_token_version = bp.owner_token_version + 1,
      status = 'active',
      updated_at = timezone('utc', now())
  where bp.id = p_profile_id
    and bp.owner_token_version = p_expected_owner_token_version
    and bp.status <> 'deleted'
  returning bp.*
  into updated_profile;

  if not found then
    raise exception 'BioPay profile could not be re-enrolled.';
  end if;

  update public.biopay_face_embeddings bfe
  set is_active = false
  where bfe.profile_id = p_profile_id
    and bfe.is_active = true;

  insert into public.biopay_face_embeddings (
    profile_id,
    embedding,
    model_version,
    quality_score,
    source,
    is_active
  ) values (
    p_profile_id,
    p_embedding,
    p_model_version,
    p_quality_score,
    're_enrollment',
    true
  );

  return query
  select
    updated_profile.id,
    updated_profile.biopay_id,
    updated_profile.display_name,
    updated_profile.ussd_string,
    updated_profile.status,
    updated_profile.owner_token_version,
    updated_profile.management_code_hash,
    updated_profile.management_code_hint,
    updated_profile.created_at;
end;
$$;

create or replace function public.biopay_delete_profile(
  p_profile_id uuid,
  p_expected_owner_token_version integer
)
returns table (
  id uuid,
  biopay_id text,
  status text,
  owner_token_version integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.biopay_profiles%rowtype;
begin
  update public.biopay_face_embeddings bfe
  set is_active = false
  where bfe.profile_id = p_profile_id
    and bfe.is_active = true;

  update public.biopay_profiles bp
  set status = 'deleted',
      owner_token_version = bp.owner_token_version + 1,
      updated_at = timezone('utc', now())
  where bp.id = p_profile_id
    and bp.owner_token_version = p_expected_owner_token_version
    and bp.status <> 'deleted'
  returning bp.*
  into updated_profile;

  if not found then
    select *
    into updated_profile
    from public.biopay_profiles bp
    where bp.id = p_profile_id;

    if not found then
      raise exception 'BioPay profile could not be deleted.';
    end if;
  end if;

  return query
  select
    updated_profile.id,
    updated_profile.biopay_id,
    updated_profile.status,
    updated_profile.owner_token_version;
end;
$$;

grant execute on function public.rpc_get_discover_summary(double precision, double precision, text) to authenticated;
grant execute on function public.rpc_search_nearby_drivers(double precision, double precision, text, text, integer) to authenticated;
grant execute on function public.rpc_set_driver_online_status(boolean) to authenticated;
grant execute on function public.rpc_update_profile(json) to authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text) to authenticated;
grant execute on function public.rpc_admin_list_trips(text, text, integer, integer) to authenticated;
grant execute on function public.rpc_admin_update_user_role(uuid, text) to authenticated;
grant execute on function public.rpc_admin_upsert_whatsapp_number(text, text, text, boolean) to authenticated;
grant execute on function public.rpc_admin_set_whatsapp_number_active(uuid, boolean) to authenticated;

revoke all on function public.biopay_reenroll_profile(uuid, integer, vector, text, double precision) from public, anon, authenticated;
revoke all on function public.biopay_delete_profile(uuid, integer) from public, anon, authenticated;
grant execute on function public.biopay_reenroll_profile(uuid, integer, vector, text, double precision) to service_role;
grant execute on function public.biopay_delete_profile(uuid, integer) to service_role;

commit;
