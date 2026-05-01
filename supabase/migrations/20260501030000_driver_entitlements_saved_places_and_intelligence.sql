begin;

-- WhatsApp-login metadata. Existing OTP functions remain admin-only; app-wide
-- WhatsApp login can populate these fields when that UI flow is added.
alter table public.profiles
  add column if not exists whatsapp_e164 text,
  add column if not exists whatsapp_verified_at timestamptz,
  add column if not exists auth_provider text,
  add column if not exists last_login_at timestamptz;

create index if not exists idx_profiles_whatsapp_e164
  on public.profiles(whatsapp_e164)
  where whatsapp_e164 is not null
    and whatsapp_e164 <> '';

-- Subscription plans now have a tier/name so entitlement rules can point to
-- a dynamic commercial product rather than hardcoded client behavior.
alter table public.subscription_plans
  add column if not exists tier text,
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists features jsonb;

update public.subscription_plans
set
  tier = coalesce(nullif(tier, ''), 'pro'),
  name = coalesce(nullif(name, ''), 'Pro'),
  features = coalesce(features, '{}'::jsonb);

alter table public.subscription_plans
  alter column tier set default 'pro',
  alter column tier set not null,
  alter column name set default 'Pro',
  alter column name set not null,
  alter column features set default '{}'::jsonb,
  alter column features set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'subscription_plans_tier_check'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_tier_check
      check (tier ~ '^[a-z][a-z0-9_-]{1,40}$');
  end if;
end;
$$;

create table if not exists public.driver_entitlement_rules (
  id uuid primary key default gen_random_uuid(),
  vehicle_type_id text not null references public.vehicle_types(id) on delete cascade,
  free_trip_limit_per_month integer not null check (free_trip_limit_per_month >= 0),
  required_tier text not null default 'pro',
  requires_subscription_after_limit boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_type_id)
);

create table if not exists public.driver_subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  vehicle_type_id text references public.vehicle_types(id) on delete set null,
  tier text not null default 'pro',
  status text not null default 'active'
    check (status in ('trialing', 'active', 'past_due', 'paused', 'cancelled', 'expired')),
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz not null,
  provider text,
  external_subscription_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint driver_subscriptions_period_check
    check (current_period_end > current_period_start)
);

create table if not exists public.driver_trip_entitlement_usage (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  vehicle_type_id text not null references public.vehicle_types(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  counted_at timestamptz not null default now(),
  source text not null default 'rpc_create_trip',
  metadata jsonb not null default '{}'::jsonb,
  unique (trip_id),
  constraint driver_trip_entitlement_usage_period_check
    check (period_end > period_start)
);

drop trigger if exists set_driver_entitlement_rules_updated_at on public.driver_entitlement_rules;
create trigger set_driver_entitlement_rules_updated_at
before update on public.driver_entitlement_rules
for each row execute function public.handle_updated_at();

drop trigger if exists set_driver_subscriptions_updated_at on public.driver_subscriptions;
create trigger set_driver_subscriptions_updated_at
before update on public.driver_subscriptions
for each row execute function public.handle_updated_at();

create index if not exists idx_driver_subscriptions_profile_status
  on public.driver_subscriptions(profile_id, status, current_period_end desc);

create index if not exists idx_driver_trip_entitlement_usage_profile_period
  on public.driver_trip_entitlement_usage(profile_id, vehicle_type_id, period_start);

alter table public.driver_entitlement_rules enable row level security;
alter table public.driver_subscriptions enable row level security;
alter table public.driver_trip_entitlement_usage enable row level security;

drop policy if exists driver_entitlement_rules_read on public.driver_entitlement_rules;
create policy driver_entitlement_rules_read
  on public.driver_entitlement_rules
  for select
  to authenticated
  using (is_active = true or public.is_platform_admin());

drop policy if exists driver_entitlement_rules_admin_write on public.driver_entitlement_rules;
create policy driver_entitlement_rules_admin_write
  on public.driver_entitlement_rules
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists driver_subscriptions_owner_read on public.driver_subscriptions;
create policy driver_subscriptions_owner_read
  on public.driver_subscriptions
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists driver_subscriptions_admin_write on public.driver_subscriptions;
create policy driver_subscriptions_admin_write
  on public.driver_subscriptions
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists driver_trip_entitlement_usage_owner_read on public.driver_trip_entitlement_usage;
create policy driver_trip_entitlement_usage_owner_read
  on public.driver_trip_entitlement_usage
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists driver_trip_entitlement_usage_admin_write on public.driver_trip_entitlement_usage;
create policy driver_trip_entitlement_usage_admin_write
  on public.driver_trip_entitlement_usage
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

insert into public.driver_entitlement_rules (
  vehicle_type_id,
  free_trip_limit_per_month,
  required_tier,
  requires_subscription_after_limit,
  is_active
)
values ('moto', 30, 'pro', true, true)
on conflict (vehicle_type_id) do update
set
  free_trip_limit_per_month = excluded.free_trip_limit_per_month,
  required_tier = excluded.required_tier,
  requires_subscription_after_limit = excluded.requires_subscription_after_limit,
  is_active = excluded.is_active,
  updated_at = now();

create table if not exists public.favorite_addresses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  address_type text not null default 'other'
    check (address_type in ('home', 'school', 'work', 'other')),
  formatted_address text not null,
  place_id text,
  latitude double precision,
  longitude double precision,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_favorite_addresses_updated_at on public.favorite_addresses;
create trigger set_favorite_addresses_updated_at
before update on public.favorite_addresses
for each row execute function public.handle_updated_at();

create index if not exists idx_favorite_addresses_profile
  on public.favorite_addresses(profile_id, is_active, sort_order);

create unique index if not exists uq_favorite_addresses_active_type
  on public.favorite_addresses(profile_id, address_type)
  where is_active = true
    and address_type in ('home', 'school', 'work');

alter table public.favorite_addresses enable row level security;

drop policy if exists favorite_addresses_owner_read on public.favorite_addresses;
create policy favorite_addresses_owner_read
  on public.favorite_addresses
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists favorite_addresses_owner_insert on public.favorite_addresses;
create policy favorite_addresses_owner_insert
  on public.favorite_addresses
  for insert
  to authenticated
  with check (profile_id = auth.uid());

drop policy if exists favorite_addresses_owner_update on public.favorite_addresses;
create policy favorite_addresses_owner_update
  on public.favorite_addresses
  for update
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin())
  with check (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists favorite_addresses_owner_delete on public.favorite_addresses;
create policy favorite_addresses_owner_delete
  on public.favorite_addresses
  for delete
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

create table if not exists public.mobility_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  venue_name text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  latitude double precision,
  longitude double precision,
  expected_attendance integer check (expected_attendance is null or expected_attendance >= 0),
  source text not null default 'admin',
  confidence numeric(4,3) not null default 0.700 check (confidence >= 0 and confidence <= 1),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_mobility_events_updated_at on public.mobility_events;
create trigger set_mobility_events_updated_at
before update on public.mobility_events
for each row execute function public.handle_updated_at();

create index if not exists idx_mobility_events_active_time
  on public.mobility_events(is_active, starts_at);

alter table public.mobility_events enable row level security;

drop policy if exists mobility_events_active_read on public.mobility_events;
create policy mobility_events_active_read
  on public.mobility_events
  for select
  to authenticated
  using (is_active = true or public.is_platform_admin());

drop policy if exists mobility_events_admin_write on public.mobility_events;
create policy mobility_events_admin_write
  on public.mobility_events
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create or replace function public.has_active_driver_subscription(
  p_profile_id uuid,
  p_vehicle_type_id text default null,
  p_required_tier text default 'pro'
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.driver_subscriptions ds
    left join public.subscription_plans sp on sp.id = ds.plan_id
    where ds.profile_id = p_profile_id
      and ds.status in ('trialing', 'active')
      and ds.current_period_start <= now()
      and ds.current_period_end > now()
      and (
        p_vehicle_type_id is null
        or ds.vehicle_type_id is null
        or ds.vehicle_type_id = p_vehicle_type_id
        or sp.vehicle_type_id = p_vehicle_type_id
      )
      and (
        p_required_tier is null
        or ds.tier = p_required_tier
        or sp.tier = p_required_tier
      )
  );
$$;

revoke all on function public.has_active_driver_subscription(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.has_active_driver_subscription(uuid, text, text)
  to authenticated;

create or replace function public.rpc_get_driver_trip_entitlement()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile record;
  v_rule public.driver_entitlement_rules%rowtype;
  v_period_start date := date_trunc('month', timezone('utc', now()))::date;
  v_period_end date := (date_trunc('month', timezone('utc', now())) + interval '1 month')::date;
  v_used integer := 0;
  v_has_subscription boolean := false;
begin
  select p.id, p.vehicle_type::text as vehicle_type_id, p.is_driver
  into v_profile
  from public.profiles p
  where p.id = auth.uid();

  if not found then
    raise exception using
      message = 'PROFILE_REQUIRED',
      detail = 'Create a profile before checking driver entitlements.';
  end if;

  select *
  into v_rule
  from public.driver_entitlement_rules
  where vehicle_type_id = v_profile.vehicle_type_id
    and is_active = true;

  if not found then
    return json_build_object(
      'vehicle_type_id', v_profile.vehicle_type_id,
      'free_trip_limit_per_month', null,
      'used_this_month', 0,
      'remaining_this_month', null,
      'has_active_subscription', false,
      'subscription_required', false,
      'required_tier', null,
      'period_start', v_period_start,
      'period_end', v_period_end
    );
  end if;

  select count(*)::integer
  into v_used
  from public.driver_trip_entitlement_usage u
  where u.profile_id = auth.uid()
    and u.vehicle_type_id = v_rule.vehicle_type_id
    and u.period_start = v_period_start;

  v_has_subscription := public.has_active_driver_subscription(
    auth.uid(),
    v_rule.vehicle_type_id,
    v_rule.required_tier
  );

  return json_build_object(
    'vehicle_type_id', v_rule.vehicle_type_id,
    'free_trip_limit_per_month', v_rule.free_trip_limit_per_month,
    'used_this_month', v_used,
    'remaining_this_month', greatest(v_rule.free_trip_limit_per_month - v_used, 0),
    'has_active_subscription', v_has_subscription,
    'subscription_required',
      v_rule.requires_subscription_after_limit
      and not v_has_subscription
      and v_used >= v_rule.free_trip_limit_per_month,
    'required_tier', v_rule.required_tier,
    'period_start', v_period_start,
    'period_end', v_period_end
  );
end;
$$;

revoke all on function public.rpc_get_driver_trip_entitlement()
  from public, anon, authenticated;
grant execute on function public.rpc_get_driver_trip_entitlement()
  to authenticated;

-- Force client trip creation through the audited RPC below.
drop policy if exists trips_insert_own on public.trips;
drop policy if exists trips_insert_rpc_only on public.trips;
create policy trips_insert_rpc_only
  on public.trips
  for insert
  to authenticated
  with check (false);

create or replace function public.rpc_create_trip(p_payload json)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_profile record;
  v_new_id uuid;
  v_origin text := nullif(trim(v_payload->>'origin'), '');
  v_destination text := nullif(trim(v_payload->>'destination'), '');
  v_departure_date text := nullif(trim(v_payload->>'departure_date'), '');
  v_departure_time text := nullif(trim(v_payload->>'departure_time'), '');
  v_role text := coalesce(nullif(trim(v_payload->>'role'), ''), 'passenger');
  v_vehicle_type text;
  v_recurring_days integer[] := '{}'::integer[];
  v_rule public.driver_entitlement_rules%rowtype;
  v_period_start date := date_trunc('month', timezone('utc', now()))::date;
  v_period_end date := (date_trunc('month', timezone('utc', now())) + interval '1 month')::date;
  v_used integer := 0;
  v_should_count_entitlement boolean := false;
begin
  if v_user_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception using
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Please sign in with WhatsApp before scheduling trips.';
  end if;

  select
    p.id,
    coalesce(nullif(p.display_name, ''), nullif(p.name, ''), '') as display_name,
    p.phone,
    p.whatsapp,
    p.vehicle_type::text as profile_vehicle_type,
    p.is_driver
  into v_profile
  from public.profiles p
  where p.id = v_user_id;

  if not found then
    raise exception using
      message = 'PROFILE_REQUIRED',
      detail = 'Create a profile before scheduling trips.';
  end if;

  if coalesce(nullif(v_profile.whatsapp, ''), nullif(v_profile.phone, '')) is null then
    raise exception using
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'A WhatsApp number is required before scheduling trips.';
  end if;

  v_vehicle_type := coalesce(
    nullif(trim(v_payload->>'vehicle_type'), ''),
    v_profile.profile_vehicle_type,
    'cab'
  );

  if v_origin is null
    or v_destination is null
    or v_departure_date is null
    or v_departure_time is null
    or v_role not in ('passenger', 'driver') then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Origin, destination, date, time, and role are required.';
  end if;

  if not exists (
    select 1
    from public.vehicle_types vt
    where vt.id = v_vehicle_type
      and vt.is_active = true
  ) then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Selected vehicle type is not available.';
  end if;

  if jsonb_typeof(v_payload->'recurring_days') = 'array' then
    select coalesce(array_agg(value::integer order by ordinality), '{}'::integer[])
    into v_recurring_days
    from jsonb_array_elements_text(v_payload->'recurring_days')
      with ordinality as days(value, ordinality);
  end if;

  if v_role = 'driver' then
    select *
    into v_rule
    from public.driver_entitlement_rules
    where vehicle_type_id = v_vehicle_type
      and is_active = true;

    if found and v_rule.requires_subscription_after_limit then
      if not public.has_active_driver_subscription(v_user_id, v_vehicle_type, v_rule.required_tier) then
        select count(*)::integer
        into v_used
        from public.driver_trip_entitlement_usage u
        where u.profile_id = v_user_id
          and u.vehicle_type_id = v_vehicle_type
          and u.period_start = v_period_start;

        if v_used >= v_rule.free_trip_limit_per_month then
          raise exception using
            message = 'MOTO_PRO_SUBSCRIPTION_REQUIRED',
            detail = format(
              'Free %s trip limit reached for this month. Upgrade to %s to continue.',
              v_vehicle_type,
              v_rule.required_tier
            );
        end if;

        v_should_count_entitlement := true;
      end if;
    end if;
  end if;

  insert into public.trips (
    author_id,
    author_name,
    origin,
    origin_lat,
    origin_lng,
    destination,
    dest_lat,
    dest_lng,
    departure_date,
    departure_time,
    role,
    vehicle_type,
    note,
    whatsapp,
    seats,
    is_recurring,
    recurring_days,
    starts_at,
    origin_place_id,
    destination_place_id
  )
  values (
    v_user_id,
    v_profile.display_name,
    v_origin,
    nullif(v_payload->>'origin_lat', '')::double precision,
    nullif(v_payload->>'origin_lng', '')::double precision,
    v_destination,
    nullif(v_payload->>'dest_lat', '')::double precision,
    nullif(v_payload->>'dest_lng', '')::double precision,
    v_departure_date,
    v_departure_time,
    v_role,
    v_vehicle_type,
    nullif(trim(v_payload->>'note'), ''),
    coalesce(nullif(v_profile.whatsapp, ''), nullif(v_profile.phone, ''), ''),
    coalesce(nullif(v_payload->>'seats', '')::integer, 1),
    coalesce(nullif(v_payload->>'is_recurring', '')::boolean, false),
    v_recurring_days,
    case
      when v_departure_date ~ '^\d{4}-\d{2}-\d{2}$'
        and v_departure_time ~ '^\d{2}:\d{2}$'
      then (v_departure_date || ' ' || v_departure_time)::timestamp at time zone 'UTC'
      else null
    end,
    nullif(trim(v_payload->>'origin_place_id'), ''),
    nullif(trim(v_payload->>'destination_place_id'), '')
  )
  returning id into v_new_id;

  if v_should_count_entitlement then
    insert into public.driver_trip_entitlement_usage (
      profile_id,
      trip_id,
      vehicle_type_id,
      period_start,
      period_end
    )
    values (
      v_user_id,
      v_new_id,
      v_vehicle_type,
      v_period_start,
      v_period_end
    );
  end if;

  return v_new_id;
end;
$$;

revoke all on function public.rpc_create_trip(json)
  from public, anon, authenticated;
grant execute on function public.rpc_create_trip(json)
  to authenticated;

create or replace function public.rpc_suggest_trip_pools(
  p_trip_id uuid,
  p_limit integer default 10
)
returns table (
  trip_id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  departure_time text,
  role text,
  vehicle_type text,
  score numeric,
  reason text
)
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select *
    from public.trips
    where id = p_trip_id
      and (author_id = auth.uid() or (status = 'active' and is_active = true))
  )
  select
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    t.departure_date,
    t.departure_time,
    t.role,
    t.vehicle_type,
    (
      100
      - least(abs(coalesce(t.origin_lat, 0) - coalesce(b.origin_lat, 0)) * 100, 35)
      - least(abs(coalesce(t.origin_lng, 0) - coalesce(b.origin_lng, 0)) * 100, 35)
      - case when t.role <> b.role then 0 else 12 end
      - case when t.vehicle_type = b.vehicle_type then 0 else 20 end
    )::numeric(8,2) as score,
    case
      when t.role <> b.role then 'Driver/passenger match on the same travel day'
      else 'Passenger pooling opportunity on a similar route'
    end as reason
  from base b
  join public.trips t on t.id <> b.id
  where t.status = 'active'
    and t.is_active = true
    and t.departure_date = b.departure_date
    and (t.role <> b.role or (t.role = 'passenger' and b.role = 'passenger'))
    and (
      t.vehicle_type = b.vehicle_type
      or t.role = 'passenger'
      or b.role = 'passenger'
    )
  order by score desc, t.created_at desc
  limit greatest(coalesce(p_limit, 10), 1);
$$;

revoke all on function public.rpc_suggest_trip_pools(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_suggest_trip_pools(uuid, integer)
  to authenticated;

create or replace function public.rpc_get_driver_demand_zones(
  p_user_lat double precision default null,
  p_user_lng double precision default null,
  p_radius_km double precision default 25,
  p_limit integer default 20
)
returns table (
  zone_id text,
  label text,
  latitude double precision,
  longitude double precision,
  probability numeric,
  reason text,
  source text,
  starts_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with passenger_trip_zones as (
    select
      'trip:' || round(t.origin_lat::numeric, 3)::text || ':' ||
        round(t.origin_lng::numeric, 3)::text as zone_id,
      t.origin as label,
      avg(t.origin_lat) as latitude,
      avg(t.origin_lng) as longitude,
      least(0.95, 0.35 + count(*) * 0.08)::numeric(4,3) as probability,
      count(*)::integer as volume,
      min(t.starts_at) as starts_at
    from public.trips t
    where t.status = 'active'
      and t.is_active = true
      and t.role = 'passenger'
      and t.origin_lat is not null
      and t.origin_lng is not null
      and coalesce(t.starts_at, now()) between now() and now() + interval '24 hours'
    group by 1, t.origin
  ),
  event_zones as (
    select
      'event:' || e.id::text as zone_id,
      coalesce(e.venue_name, e.title) as label,
      e.latitude,
      e.longitude,
      least(0.98, e.confidence + coalesce(e.expected_attendance, 0) / 10000.0)::numeric(4,3) as probability,
      greatest(coalesce(e.expected_attendance, 0), 1) as volume,
      e.starts_at
    from public.mobility_events e
    where e.is_active = true
      and e.latitude is not null
      and e.longitude is not null
      and e.starts_at between now() and now() + interval '72 hours'
  ),
  combined as (
    select
      zone_id,
      label,
      latitude,
      longitude,
      probability,
      'Scheduled passenger demand nearby'::text as reason,
      'scheduled_trips'::text as source,
      starts_at,
      volume
    from passenger_trip_zones
    union all
    select
      zone_id,
      label,
      latitude,
      longitude,
      probability,
      'Event demand signal'::text as reason,
      'events'::text as source,
      starts_at,
      volume
    from event_zones
  )
  select
    c.zone_id,
    c.label,
    c.latitude,
    c.longitude,
    c.probability,
    c.reason,
    c.source,
    c.starts_at
  from combined c
  where (
    p_user_lat is null
    or p_user_lng is null
    or (
      111.045 * sqrt(
        power(c.latitude - p_user_lat, 2) +
        power((c.longitude - p_user_lng) * cos(radians(p_user_lat)), 2)
      )
    ) <= greatest(coalesce(p_radius_km, 25), 1)
  )
  order by c.probability desc, c.volume desc, c.starts_at asc
  limit greatest(coalesce(p_limit, 20), 1);
$$;

revoke all on function public.rpc_get_driver_demand_zones(double precision, double precision, double precision, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_get_driver_demand_zones(double precision, double precision, double precision, integer)
  to authenticated;

commit;
