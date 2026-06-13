-- MOBI scheduling production hardening:
-- - normalize and validate schedule payloads server-side
-- - make create idempotent by client_request_id
-- - move user edit/cancel through audited RPCs
-- - preserve route place ids and bounded recurrence metadata

alter table public.trips
  add column if not exists client_request_id text,
  add column if not exists recurrence_end_date date,
  add column if not exists recurrence_skip_dates date[] not null default '{}'::date[],
  add column if not exists cancelled_at timestamptz;

create unique index if not exists idx_trips_author_client_request
  on public.trips(author_id, client_request_id)
  where client_request_id is not null;

create index if not exists idx_trips_starts_at_active
  on public.trips(starts_at)
  where is_active = true and status = 'active';

create table if not exists public.trip_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.profiles(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.trip_audit_events enable row level security;

drop policy if exists trip_audit_events_select_own on public.trip_audit_events;
create policy trip_audit_events_select_own
  on public.trip_audit_events
  for select
  to authenticated
  using (actor_user_id = auth.uid());

revoke all on public.trip_audit_events from public, anon, authenticated;
grant select on public.trip_audit_events to authenticated;
grant all on public.trip_audit_events to service_role;

drop policy if exists trips_update_own on public.trips;
drop policy if exists trips_delete_own on public.trips;
drop policy if exists trips_update_rpc_only on public.trips;
create policy trips_update_rpc_only
  on public.trips
  for update
  to authenticated
  using (false)
  with check (false);

create or replace function public._normalize_trip_schedule_payload(p_payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_origin text := nullif(trim(v_payload->>'origin'), '');
  v_destination text := nullif(trim(v_payload->>'destination'), '');
  v_departure_date_text text := nullif(trim(v_payload->>'departure_date'), '');
  v_departure_time_text text := nullif(trim(v_payload->>'departure_time'), '');
  v_departure_date date;
  v_departure_time time;
  v_starts_at timestamptz;
  v_role text := coalesce(nullif(trim(v_payload->>'role'), ''), 'passenger');
  v_vehicle_type text := coalesce(nullif(trim(v_payload->>'vehicle_type'), ''), 'cab');
  v_is_recurring boolean := false;
  v_recurring_days integer[] := '{}'::integer[];
  v_recurring_count integer := 0;
  v_recurring_distinct_count integer := 0;
  v_recurrence_end_date date;
  v_recurrence_skip_dates date[] := '{}'::date[];
  v_origin_lat double precision;
  v_origin_lng double precision;
  v_dest_lat double precision;
  v_dest_lng double precision;
  v_note text := nullif(trim(v_payload->>'note'), '');
  v_origin_place_id text := nullif(trim(v_payload->>'origin_place_id'), '');
  v_destination_place_id text := nullif(trim(v_payload->>'destination_place_id'), '');
  v_client_request_id text := nullif(trim(v_payload->>'client_request_id'), '');
begin
  if v_origin is null
    or v_destination is null
    or v_departure_date_text is null
    or v_departure_time_text is null
    or v_role not in ('passenger', 'driver') then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Origin, destination, date, time, and role are required.';
  end if;

  if lower(v_origin) = lower(v_destination) then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Pickup and destination must be different.';
  end if;

  if v_departure_date_text !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Departure date must use YYYY-MM-DD format.';
  end if;

  begin
    v_departure_date := v_departure_date_text::date;
  exception when others then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Departure date is invalid.';
  end;

  if v_departure_time_text !~ '^([01]\d|2[0-3]):[0-5]\d$' then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Departure time must use 24-hour HH:MM format.';
  end if;

  v_departure_time := v_departure_time_text::time;
  v_starts_at := (v_departure_date + v_departure_time) at time zone 'UTC';

  if v_starts_at <= timezone('utc', now()) then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Departure time must be in the future.';
  end if;

  begin
    v_origin_lat := nullif(v_payload->>'origin_lat', '')::double precision;
    v_origin_lng := nullif(v_payload->>'origin_lng', '')::double precision;
    v_dest_lat := nullif(v_payload->>'dest_lat', '')::double precision;
    v_dest_lng := nullif(v_payload->>'dest_lng', '')::double precision;
  exception when others then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Route coordinates are invalid.';
  end;

  if (v_origin_lat is not null and (v_origin_lat < -90 or v_origin_lat > 90))
    or (v_dest_lat is not null and (v_dest_lat < -90 or v_dest_lat > 90))
    or (v_origin_lng is not null and (v_origin_lng < -180 or v_origin_lng > 180))
    or (v_dest_lng is not null and (v_dest_lng < -180 or v_dest_lng > 180)) then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Route coordinates are outside valid ranges.';
  end if;

  if v_note is not null and length(v_note) > 500 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Trip note must be 500 characters or less.';
  end if;

  if v_origin_place_id is not null and length(v_origin_place_id) > 256 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Pickup place reference is too long.';
  end if;

  if v_destination_place_id is not null and length(v_destination_place_id) > 256 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Destination place reference is too long.';
  end if;

  if v_client_request_id is not null and length(v_client_request_id) > 128 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Client request reference is too long.';
  end if;

  begin
    v_is_recurring := coalesce(nullif(v_payload->>'is_recurring', '')::boolean, false);
  exception when others then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Repeat setting is invalid.';
  end;

  if jsonb_typeof(v_payload->'recurring_days') = 'array' then
    begin
      select
        coalesce(array_agg(value::integer order by value::integer), '{}'::integer[]),
        count(*)::integer,
        count(distinct value::integer)::integer
      into v_recurring_days, v_recurring_count, v_recurring_distinct_count
      from jsonb_array_elements_text(v_payload->'recurring_days') as days(value);
    exception when others then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Recurring days must be valid weekday indices.';
    end;
  elsif v_payload ? 'recurring_days' then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Recurring days must be a list of weekday indices.';
  end if;

  if jsonb_typeof(v_payload->'recurrence_skip_dates') = 'array' then
    begin
      select coalesce(array_agg(value::date order by value::date), '{}'::date[])
      into v_recurrence_skip_dates
      from jsonb_array_elements_text(v_payload->'recurrence_skip_dates') as days(value);
    exception when others then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Skipped repeat dates must be valid dates.';
    end;
  elsif v_payload ? 'recurrence_skip_dates' then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Skipped repeat dates must be a list of dates.';
  end if;

  if exists (select 1 from unnest(v_recurring_days) as day_index where day_index < 0 or day_index > 6) then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Recurring days must be between 0 and 6.';
  end if;

  if v_recurring_count <> v_recurring_distinct_count then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Recurring days must not contain duplicates.';
  end if;

  if v_is_recurring then
    if coalesce(array_length(v_recurring_days, 1), 0) = 0 then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Choose at least one repeat day or turn repeat off.';
    end if;

    if nullif(trim(v_payload->>'recurrence_end_date'), '') is not null then
      begin
        v_recurrence_end_date := nullif(trim(v_payload->>'recurrence_end_date'), '')::date;
      exception when others then
        raise exception using
          message = 'INVALID_TRIP_PAYLOAD',
          detail = 'Repeat end date is invalid.';
      end;
    else
      v_recurrence_end_date := v_departure_date + 90;
    end if;

    if v_recurrence_end_date < v_departure_date then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Repeat end date cannot be before departure date.';
    end if;

    if v_recurrence_end_date > v_departure_date + 180 then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Recurring trips can be scheduled up to 180 days ahead.';
    end if;

    if exists (
      select 1
      from unnest(v_recurrence_skip_dates) as skip_date
      where skip_date < v_departure_date
         or skip_date > v_recurrence_end_date
    ) then
      raise exception using
        message = 'INVALID_TRIP_PAYLOAD',
        detail = 'Skipped repeat dates must stay inside the repeat window.';
    end if;
  else
    v_recurrence_skip_dates := '{}'::date[];
  end if;

  return jsonb_build_object(
    'origin', v_origin,
    'origin_lat', v_origin_lat,
    'origin_lng', v_origin_lng,
    'destination', v_destination,
    'dest_lat', v_dest_lat,
    'dest_lng', v_dest_lng,
    'departure_date', to_char(v_departure_date, 'YYYY-MM-DD'),
    'departure_time', to_char(v_departure_time, 'HH24:MI'),
    'starts_at', v_starts_at,
    'role', v_role,
    'vehicle_type', v_vehicle_type,
    'note', v_note,
    'is_recurring', v_is_recurring,
    'recurring_days', to_jsonb(v_recurring_days),
    'recurrence_end_date', v_recurrence_end_date,
    'recurrence_skip_dates', to_jsonb(v_recurrence_skip_dates),
    'origin_place_id', v_origin_place_id,
    'destination_place_id', v_destination_place_id,
    'client_request_id', v_client_request_id
  );
end;
$$;

revoke all on function public._normalize_trip_schedule_payload(jsonb)
  from public, anon, authenticated;

create or replace function public.rpc_create_trip(p_payload json)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_normalized jsonb;
  v_profile record;
  v_new_id uuid;
  v_existing_id uuid;
  v_vehicle_type text;
  v_recurring_days integer[] := '{}'::integer[];
  v_recurrence_skip_dates date[] := '{}'::date[];
  v_client_request_id text;
  v_seats integer := 1;
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

  v_normalized := public._normalize_trip_schedule_payload(v_payload);
  v_vehicle_type := v_normalized->>'vehicle_type';
  v_client_request_id := nullif(v_normalized->>'client_request_id', '');

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

  begin
    v_seats := coalesce(nullif(v_payload->>'seats', '')::integer, 1);
  exception when others then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Seat count is invalid.';
  end;

  if v_seats < 1 or v_seats > 8 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Seat count must be between 1 and 8.';
  end if;

  if v_client_request_id is not null then
    select id
    into v_existing_id
    from public.trips
    where author_id = v_user_id
      and client_request_id = v_client_request_id
    limit 1;

    if found then
      return v_existing_id;
    end if;
  end if;

  select coalesce(array_agg(value::integer order by ordinality), '{}'::integer[])
  into v_recurring_days
  from jsonb_array_elements_text(v_normalized->'recurring_days')
    with ordinality as days(value, ordinality);

  select coalesce(array_agg(value::date order by ordinality), '{}'::date[])
  into v_recurrence_skip_dates
  from jsonb_array_elements_text(v_normalized->'recurrence_skip_dates')
    with ordinality as days(value, ordinality);

  if v_normalized->>'role' = 'driver' then
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
    recurrence_end_date,
    recurrence_skip_dates,
    starts_at,
    origin_place_id,
    destination_place_id,
    client_request_id
  )
  values (
    v_user_id,
    v_profile.display_name,
    v_normalized->>'origin',
    (v_normalized->>'origin_lat')::double precision,
    (v_normalized->>'origin_lng')::double precision,
    v_normalized->>'destination',
    (v_normalized->>'dest_lat')::double precision,
    (v_normalized->>'dest_lng')::double precision,
    v_normalized->>'departure_date',
    v_normalized->>'departure_time',
    v_normalized->>'role',
    v_vehicle_type,
    nullif(v_normalized->>'note', ''),
    coalesce(nullif(v_profile.whatsapp, ''), nullif(v_profile.phone, ''), ''),
    v_seats,
    (v_normalized->>'is_recurring')::boolean,
    v_recurring_days,
    nullif(v_normalized->>'recurrence_end_date', '')::date,
    v_recurrence_skip_dates,
    (v_normalized->>'starts_at')::timestamptz,
    nullif(v_normalized->>'origin_place_id', ''),
    nullif(v_normalized->>'destination_place_id', ''),
    v_client_request_id
  )
  returning id into v_new_id;

  insert into public.trip_audit_events(actor_user_id, trip_id, action, details)
  values (
    v_user_id,
    v_new_id,
    'trip.created',
    jsonb_build_object(
      'client_request_id', v_client_request_id,
      'role', v_normalized->>'role',
      'vehicle_type', v_vehicle_type,
      'starts_at', v_normalized->>'starts_at',
      'is_recurring', (v_normalized->>'is_recurring')::boolean
    )
  );

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

drop function if exists public.rpc_update_trip(uuid, json);
create or replace function public.rpc_update_trip(
  p_trip_id uuid,
  p_payload json
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload::jsonb, '{}'::jsonb);
  v_normalized jsonb;
  v_trip public.trips%rowtype;
  v_vehicle_type text;
  v_recurring_days integer[] := '{}'::integer[];
  v_recurrence_skip_dates date[] := '{}'::date[];
begin
  if v_user_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception using
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Please sign in with WhatsApp before editing trips.';
  end if;

  select *
  into v_trip
  from public.trips
  where id = p_trip_id
    and author_id = v_user_id
  for update;

  if not found then
    raise exception using
      message = 'TRIP_NOT_FOUND',
      detail = 'Trip not found or you do not have permission to edit it.';
  end if;

  if v_trip.status = 'cancelled' or coalesce(v_trip.is_active, false) = false then
    raise exception using
      message = 'TRIP_NOT_EDITABLE',
      detail = 'Cancelled trips cannot be edited.';
  end if;

  v_normalized := public._normalize_trip_schedule_payload(v_payload);
  v_vehicle_type := v_normalized->>'vehicle_type';

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

  select coalesce(array_agg(value::integer order by ordinality), '{}'::integer[])
  into v_recurring_days
  from jsonb_array_elements_text(v_normalized->'recurring_days')
    with ordinality as days(value, ordinality);

  select coalesce(array_agg(value::date order by ordinality), '{}'::date[])
  into v_recurrence_skip_dates
  from jsonb_array_elements_text(v_normalized->'recurrence_skip_dates')
    with ordinality as days(value, ordinality);

  update public.trips
  set
    origin = v_normalized->>'origin',
    origin_lat = (v_normalized->>'origin_lat')::double precision,
    origin_lng = (v_normalized->>'origin_lng')::double precision,
    destination = v_normalized->>'destination',
    dest_lat = (v_normalized->>'dest_lat')::double precision,
    dest_lng = (v_normalized->>'dest_lng')::double precision,
    departure_date = v_normalized->>'departure_date',
    departure_time = v_normalized->>'departure_time',
    role = v_normalized->>'role',
    vehicle_type = v_vehicle_type,
    note = nullif(v_normalized->>'note', ''),
    is_recurring = (v_normalized->>'is_recurring')::boolean,
    recurring_days = v_recurring_days,
    recurrence_end_date = nullif(v_normalized->>'recurrence_end_date', '')::date,
    recurrence_skip_dates = v_recurrence_skip_dates,
    starts_at = (v_normalized->>'starts_at')::timestamptz,
    origin_place_id = nullif(v_normalized->>'origin_place_id', ''),
    destination_place_id = nullif(v_normalized->>'destination_place_id', ''),
    updated_at = timezone('utc', now())
  where id = p_trip_id
    and author_id = v_user_id;

  insert into public.trip_audit_events(actor_user_id, trip_id, action, details)
  values (
    v_user_id,
    p_trip_id,
    'trip.updated',
    jsonb_build_object(
      'old_starts_at', v_trip.starts_at,
      'new_starts_at', v_normalized->>'starts_at',
      'old_vehicle_type', v_trip.vehicle_type,
      'new_vehicle_type', v_vehicle_type,
      'is_recurring', (v_normalized->>'is_recurring')::boolean
    )
  );

  return p_trip_id;
end;
$$;

revoke all on function public.rpc_update_trip(uuid, json)
  from public, anon, authenticated;
grant execute on function public.rpc_update_trip(uuid, json)
  to authenticated;

drop function if exists public.rpc_cancel_trip(uuid, text);
create or replace function public.rpc_cancel_trip(
  p_trip_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_trip public.trips%rowtype;
  v_reason text := nullif(trim(p_reason), '');
begin
  if v_user_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise exception using
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Please sign in with WhatsApp before cancelling trips.';
  end if;

  if v_reason is not null and length(v_reason) > 240 then
    raise exception using
      message = 'INVALID_TRIP_PAYLOAD',
      detail = 'Cancellation reason must be 240 characters or less.';
  end if;

  select *
  into v_trip
  from public.trips
  where id = p_trip_id
    and author_id = v_user_id
  for update;

  if not found then
    raise exception using
      message = 'TRIP_NOT_FOUND',
      detail = 'Trip not found or you do not have permission to cancel it.';
  end if;

  if v_trip.status = 'cancelled' or coalesce(v_trip.is_active, false) = false then
    return p_trip_id;
  end if;

  update public.trips
  set
    status = 'cancelled',
    is_active = false,
    cancelled_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_trip_id
    and author_id = v_user_id;

  insert into public.trip_audit_events(actor_user_id, trip_id, action, details)
  values (
    v_user_id,
    p_trip_id,
    'trip.cancelled',
    jsonb_build_object(
      'reason', v_reason,
      'old_status', v_trip.status,
      'old_starts_at', v_trip.starts_at
    )
  );

  return p_trip_id;
end;
$$;

revoke all on function public.rpc_cancel_trip(uuid, text)
  from public, anon, authenticated;
grant execute on function public.rpc_cancel_trip(uuid, text)
  to authenticated;

create or replace function public._trip_occurs_on(
  p_departure_date text,
  p_is_recurring boolean,
  p_recurring_days integer[],
  p_recurrence_end_date date,
  p_recurrence_skip_dates date[],
  p_match_date date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_departure_date date;
  v_recurrence_end_date date;
begin
  if p_match_date is null then
    return false;
  end if;

  begin
    v_departure_date := nullif(trim(p_departure_date), '')::date;
  exception when others then
    return false;
  end;

  if not coalesce(p_is_recurring, false) then
    return p_match_date = v_departure_date;
  end if;

  if p_recurring_days is null or array_length(p_recurring_days, 1) is null then
    return false;
  end if;

  v_recurrence_end_date := coalesce(
    p_recurrence_end_date,
    v_departure_date + 90
  );

  return p_match_date >= v_departure_date
    and p_match_date <= v_recurrence_end_date
    and extract(isodow from p_match_date)::integer - 1 = any(p_recurring_days)
    and not (
      coalesce(p_recurrence_skip_dates, '{}'::date[])
        @> array[p_match_date]::date[]
    );
end;
$$;

revoke all on function public._trip_occurs_on(
  text,
  boolean,
  integer[],
  date,
  date[],
  date
) from public, anon, authenticated;

drop function if exists public.rpc_suggest_trip_pools(uuid, integer);
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
  ),
  match_days as (
    select day::date as match_date
    from generate_series(
      current_date,
      current_date + interval '14 days',
      interval '1 day'
    ) as generated(day)
  )
  select
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    to_char(d.match_date, 'YYYY-MM-DD') as departure_date,
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
  join match_days d
    on public._trip_occurs_on(
      b.departure_date,
      b.is_recurring,
      b.recurring_days,
      b.recurrence_end_date,
      b.recurrence_skip_dates,
      d.match_date
    )
   and public._trip_occurs_on(
      t.departure_date,
      t.is_recurring,
      t.recurring_days,
      t.recurrence_end_date,
      t.recurrence_skip_dates,
      d.match_date
    )
  where t.status = 'active'
    and t.is_active = true
    and (t.role <> b.role or (t.role = 'passenger' and b.role = 'passenger'))
    and (
      t.vehicle_type = b.vehicle_type
      or t.role = 'passenger'
      or b.role = 'passenger'
    )
  order by d.match_date asc, score desc, t.created_at desc
  limit greatest(coalesce(p_limit, 10), 1);
$$;

revoke all on function public.rpc_suggest_trip_pools(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.rpc_suggest_trip_pools(uuid, integer)
  to authenticated;

comment on function public.rpc_create_trip(json)
  is 'Creates a validated, idempotent, audited scheduled trip.';
comment on function public.rpc_update_trip(uuid, json)
  is 'Updates an owned scheduled trip through server-side validation and audit logging.';
comment on function public.rpc_cancel_trip(uuid, text)
  is 'Cancels an owned scheduled trip through an audited RPC.';
comment on function public.rpc_suggest_trip_pools(uuid, integer)
  is 'Suggests pool matches across single and recurring trip occurrences.';
