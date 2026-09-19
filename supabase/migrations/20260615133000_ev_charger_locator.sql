begin;

insert into public.platform_permissions (permission_key, description)
values
  ('ev_chargers.manage', 'Manage EV charger locations shown in the Mobio EV Charger locator.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key)
select p.id, 'ev_chargers.manage'
from public.profiles p
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

create table if not exists public.ev_chargers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  connector_types text[] not null default '{}'::text[],
  operator_name text,
  phone text,
  power_kw numeric(8, 2),
  price_note text,
  place_id text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint ev_chargers_name_check check (length(trim(name)) >= 2),
  constraint ev_chargers_address_check check (length(trim(address)) >= 3),
  constraint ev_chargers_latitude_check check (latitude between -90 and 90),
  constraint ev_chargers_longitude_check check (longitude between -180 and 180),
  constraint ev_chargers_power_check check (power_kw is null or power_kw >= 0)
);

create index if not exists idx_ev_chargers_org_active
  on public.ev_chargers(organization_id, is_active, name);
create index if not exists idx_ev_chargers_lat_lng
  on public.ev_chargers(latitude, longitude)
  where is_active = true;

drop trigger if exists set_ev_chargers_updated_at on public.ev_chargers;
create trigger set_ev_chargers_updated_at
  before update on public.ev_chargers
  for each row
  execute function public.handle_updated_at();

alter table public.ev_chargers enable row level security;

revoke all on public.ev_chargers from anon;
grant select on public.ev_chargers to authenticated;
grant all on public.ev_chargers to service_role;

drop policy if exists ev_chargers_read_active_or_admin on public.ev_chargers;
create policy ev_chargers_read_active_or_admin
  on public.ev_chargers
  for select
  to authenticated
  using (
    is_active = true
    or public.can_access_organization(organization_id, 'ev_chargers.manage')
  );

drop policy if exists ev_chargers_manage on public.ev_chargers;
create policy ev_chargers_manage
  on public.ev_chargers
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'ev_chargers.manage'))
  with check (public.can_access_organization(organization_id, 'ev_chargers.manage'));

create or replace function public._ev_charger_distance_km(
  p_from_latitude double precision,
  p_from_longitude double precision,
  p_to_latitude double precision,
  p_to_longitude double precision
)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select 6371.0 * 2.0 * atan2(
    sqrt(
      power(sin(radians((p_to_latitude - p_from_latitude) / 2.0)), 2)
      + cos(radians(p_from_latitude))
      * cos(radians(p_to_latitude))
      * power(sin(radians((p_to_longitude - p_from_longitude) / 2.0)), 2)
    ),
    sqrt(
      1.0 - (
        power(sin(radians((p_to_latitude - p_from_latitude) / 2.0)), 2)
        + cos(radians(p_from_latitude))
        * cos(radians(p_to_latitude))
        * power(sin(radians((p_to_longitude - p_from_longitude) / 2.0)), 2)
      )
    )
  );
$$;

create or replace function public.rpc_find_nearest_ev_chargers(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 30,
  p_limit integer default 5
)
returns table (
  id uuid,
  name text,
  address text,
  latitude double precision,
  longitude double precision,
  connector_types text[],
  operator_name text,
  phone text,
  power_kw numeric,
  price_note text,
  place_id text,
  is_active boolean,
  distance_km double precision
)
language sql
security definer
set search_path = ''
as $$
  with ranked as (
    select
      charger.id,
      charger.name,
      charger.address,
      charger.latitude,
      charger.longitude,
      charger.connector_types,
      charger.operator_name,
      charger.phone,
      charger.power_kw,
      charger.price_note,
      charger.place_id,
      charger.is_active,
      public._ev_charger_distance_km(
        p_latitude,
        p_longitude,
        charger.latitude,
        charger.longitude
      ) as distance_km
    from public.ev_chargers charger
    where charger.is_active = true
  )
  select *
  from ranked
  where distance_km <= least(greatest(coalesce(p_radius_km, 30), 1), 30)
  order by distance_km asc, name asc
  limit least(greatest(coalesce(p_limit, 5), 1), 5);
$$;

create or replace function public.rpc_admin_upsert_ev_charger(
  p_charger_id uuid default null,
  p_name text default null,
  p_address text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_connector_types text[] default '{}'::text[],
  p_operator_name text default null,
  p_phone text default null,
  p_power_kw numeric default null,
  p_price_note text default null,
  p_place_id text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.ev_chargers%rowtype;
  v_next public.ev_chargers%rowtype;
  v_had_previous boolean := false;
  v_organization_id uuid := coalesce(
    public.profile_organization_id(auth.uid()),
    public.default_organization_id()
  );
  v_name text := nullif(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'), '');
  v_address text := nullif(regexp_replace(coalesce(p_address, ''), '\s+', ' ', 'g'), '');
  v_connector_types text[] := (
    select coalesce(array_agg(distinct trimmed order by trimmed), '{}'::text[])
    from (
      select nullif(trim(connector), '') as trimmed
      from unnest(coalesce(p_connector_types, '{}'::text[])) connector
    ) normalized
    where trimmed is not null
  );
begin
  if not public.has_platform_permission('ev_chargers.manage') then
    raise exception 'Unauthorized: ev_chargers.manage permission required';
  end if;

  if v_name is null or v_address is null then
    raise exception 'EV charger name and address are required.';
  end if;

  if p_latitude is null or p_longitude is null
    or p_latitude not between -90 and 90
    or p_longitude not between -180 and 180 then
    raise exception 'Valid EV charger coordinates are required.';
  end if;

  if p_charger_id is not null then
    select *
    into v_previous
    from public.ev_chargers
    where id = p_charger_id
    for update;

    if not found then
      raise exception 'EV charger not found.';
    end if;

    v_had_previous := true;
    v_organization_id := v_previous.organization_id;
  end if;

  if v_had_previous then
    update public.ev_chargers
    set
      name = v_name,
      address = v_address,
      latitude = p_latitude,
      longitude = p_longitude,
      connector_types = v_connector_types,
      operator_name = nullif(trim(coalesce(p_operator_name, '')), ''),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      power_kw = p_power_kw,
      price_note = nullif(trim(coalesce(p_price_note, '')), ''),
      place_id = nullif(trim(coalesce(p_place_id, '')), ''),
      is_active = coalesce(p_is_active, true),
      updated_at = timezone('utc', now())
    where id = p_charger_id
    returning * into v_next;
  else
    insert into public.ev_chargers (
      organization_id,
      name,
      address,
      latitude,
      longitude,
      connector_types,
      operator_name,
      phone,
      power_kw,
      price_note,
      place_id,
      is_active,
      created_by
    )
    values (
      v_organization_id,
      v_name,
      v_address,
      p_latitude,
      p_longitude,
      v_connector_types,
      nullif(trim(coalesce(p_operator_name, '')), ''),
      nullif(trim(coalesce(p_phone, '')), ''),
      p_power_kw,
      nullif(trim(coalesce(p_price_note, '')), ''),
      nullif(trim(coalesce(p_place_id, '')), ''),
      coalesce(p_is_active, true),
      auth.uid()
    )
    returning * into v_next;
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
    case when v_had_previous then 'update_ev_charger' else 'create_ev_charger' end,
    'ev_charger',
    v_next.id,
    jsonb_build_object(
      'had_previous', v_had_previous,
      'name', v_next.name,
      'address', v_next.address,
      'latitude', v_next.latitude,
      'longitude', v_next.longitude,
      'connector_types', v_next.connector_types,
      'is_active', v_next.is_active,
      'source', 'rpc_admin_upsert_ev_charger'
    )
  );

  return v_next.id;
end;
$$;

create or replace function public.rpc_admin_set_ev_charger_active(
  p_charger_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous public.ev_chargers%rowtype;
begin
  if not public.has_platform_permission('ev_chargers.manage') then
    raise exception 'Unauthorized: ev_chargers.manage permission required';
  end if;

  select *
  into v_previous
  from public.ev_chargers
  where id = p_charger_id
  for update;

  if not found then
    raise exception 'EV charger not found.';
  end if;

  update public.ev_chargers
  set
    is_active = coalesce(p_is_active, false),
    updated_at = timezone('utc', now())
  where id = p_charger_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'set_ev_charger_active',
    'ev_charger',
    p_charger_id,
    jsonb_build_object(
      'name', v_previous.name,
      'previous_is_active', v_previous.is_active,
      'next_is_active', coalesce(p_is_active, false),
      'source', 'rpc_admin_set_ev_charger_active'
    )
  );
end;
$$;

revoke all on function public._ev_charger_distance_km(
  double precision,
  double precision,
  double precision,
  double precision
) from public, anon, authenticated;
revoke all on function public.rpc_find_nearest_ev_chargers(
  double precision,
  double precision,
  double precision,
  integer
) from public, anon, authenticated;
revoke all on function public.rpc_admin_upsert_ev_charger(
  uuid,
  text,
  text,
  double precision,
  double precision,
  text[],
  text,
  text,
  numeric,
  text,
  text,
  boolean
) from public, anon, authenticated;
revoke all on function public.rpc_admin_set_ev_charger_active(uuid, boolean)
  from public, anon, authenticated;

grant execute on function public.rpc_find_nearest_ev_chargers(
  double precision,
  double precision,
  double precision,
  integer
) to authenticated;
grant execute on function public.rpc_admin_upsert_ev_charger(
  uuid,
  text,
  text,
  double precision,
  double precision,
  text[],
  text,
  text,
  numeric,
  text,
  text,
  boolean
) to authenticated;
grant execute on function public.rpc_admin_set_ev_charger_active(uuid, boolean)
  to authenticated;

commit;
