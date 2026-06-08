-- Mobio public transport foundation.
-- Adds booking-specific agency, fleet, schedule, seat, payment, and tracking
-- tables without reviving the removed legacy payment or ride-request schema.

begin;

insert into public.platform_permissions (permission_key, description)
values
  ('transport.agencies.manage', 'Manage public transport agencies, fleets, routes, and schedules.'),
  ('transport.bookings.manage', 'Manage public transport bookings and passenger ticket operations.'),
  ('transport.tracking.ingest', 'Ingest trusted bus location events from driver apps or GPS hardware.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key)
select p.id, permission.permission_key
from public.profiles p
cross join (values
  ('transport.agencies.manage'),
  ('transport.bookings.manage'),
  ('transport.tracking.ingest')
) as permission(permission_key)
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

create table if not exists public.transport_agencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null unique,
  phone text,
  whatsapp text,
  email text,
  service_area text not null default 'rwanda',
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint transport_agencies_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{1,80}$')
);

create table if not exists public.agency_buses (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.transport_agencies(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plate_number text not null,
  display_name text not null,
  vehicle_type text not null default 'bus',
  capacity integer not null check (capacity > 0 and capacity <= 120),
  current_driver_id uuid references public.profiles(id) on delete set null,
  tracking_mode text not null default 'none',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint agency_buses_tracking_mode_check
    check (tracking_mode in ('none', 'driver_app', 'gps_hardware')),
  constraint agency_buses_vehicle_type_check check (vehicle_type = 'bus'),
  constraint agency_buses_plate_unique unique (agency_id, plate_number)
);

create table if not exists public.transport_routes (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.transport_agencies(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_code text not null,
  origin_name text not null,
  destination_name text not null,
  origin_lat double precision,
  origin_lng double precision,
  destination_lat double precision,
  destination_lng double precision,
  province_scope text not null default 'kigali',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint transport_routes_scope_check
    check (province_scope in ('kigali', 'province', 'inter_province')),
  constraint transport_routes_code_unique unique (agency_id, route_code)
);

create table if not exists public.route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.transport_routes(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  stop_name text not null,
  stop_order integer not null check (stop_order >= 0),
  latitude double precision,
  longitude double precision,
  is_terminal boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint route_stops_order_unique unique (route_id, stop_order)
);

create table if not exists public.bus_schedules (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.transport_agencies(id) on delete cascade,
  bus_id uuid references public.agency_buses(id) on delete set null,
  route_id uuid not null references public.transport_routes(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  departure_at timestamptz not null,
  arrival_window_start timestamptz,
  arrival_window_end timestamptz,
  fare_amount numeric(12, 2) not null default 0 check (fare_amount >= 0),
  currency text not null default 'RWF',
  status text not null default 'scheduled',
  booking_cutoff_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint bus_schedules_status_check
    check (status in ('scheduled', 'boarding', 'departed', 'arrived', 'cancelled')),
  constraint bus_schedules_arrival_window_check
    check (arrival_window_end is null or arrival_window_start is null or arrival_window_end >= arrival_window_start)
);

create table if not exists public.bus_seat_inventory (
  schedule_id uuid primary key references public.bus_schedules(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  total_seats integer not null check (total_seats > 0 and total_seats <= 120),
  available_seats integer not null check (available_seats >= 0),
  held_seats integer not null default 0 check (held_seats >= 0),
  confirmed_seats integer not null default 0 check (confirmed_seats >= 0),
  seat_map jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint bus_seat_inventory_counts_check
    check (available_seats + held_seats + confirmed_seats <= total_seats)
);

create table if not exists public.bus_bookings (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.bus_schedules(id) on delete restrict,
  agency_id uuid not null references public.transport_agencies(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  passenger_id uuid not null references public.profiles(id) on delete cascade,
  passenger_name text,
  passenger_phone text,
  seat_count integer not null check (seat_count > 0 and seat_count <= 20),
  seat_numbers jsonb not null default '[]'::jsonb,
  status text not null default 'held',
  payment_status text not null default 'pending',
  amount numeric(12, 2) not null default 0 check (amount >= 0),
  currency text not null default 'RWF',
  hold_expires_at timestamptz,
  ticket_reference text not null unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint bus_bookings_status_check
    check (status in ('held', 'confirmed', 'cancelled', 'expired')),
  constraint bus_bookings_payment_status_check
    check (payment_status in ('pending', 'paid', 'failed', 'refunded', 'refund_pending'))
);

create table if not exists public.bus_booking_payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bus_bookings(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null,
  provider_reference text,
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'RWF',
  status text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint bus_booking_payments_status_check
    check (status in ('pending', 'paid', 'failed', 'refunded', 'refund_pending')),
  constraint bus_booking_payments_reference_unique unique (provider, provider_reference)
);

create table if not exists public.bus_tracking_sources (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid not null references public.agency_buses(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_type text not null,
  label text not null,
  external_device_id text,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint bus_tracking_sources_type_check
    check (source_type in ('driver_app', 'gps_hardware')),
  constraint bus_tracking_sources_device_unique unique (source_type, external_device_id)
);

create table if not exists public.bus_location_events (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid not null references public.agency_buses(id) on delete cascade,
  tracking_source_id uuid references public.bus_tracking_sources(id) on delete set null,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  heading_degrees double precision check (heading_degrees is null or heading_degrees between 0 and 360),
  speed_kph double precision check (speed_kph is null or speed_kph >= 0),
  accuracy_meters double precision check (accuracy_meters is null or accuracy_meters >= 0),
  recorded_at timestamptz not null default timezone('utc', now()),
  received_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_transport_agencies_org_active
  on public.transport_agencies(organization_id, is_active, name);
create index if not exists idx_agency_buses_agency_active
  on public.agency_buses(agency_id, is_active, plate_number);
create index if not exists idx_transport_routes_agency_active
  on public.transport_routes(agency_id, is_active, origin_name, destination_name);
create index if not exists idx_route_stops_route_order
  on public.route_stops(route_id, stop_order);
create index if not exists idx_bus_schedules_route_departure
  on public.bus_schedules(route_id, departure_at)
  where status in ('scheduled', 'boarding');
create index if not exists idx_bus_schedules_agency_departure
  on public.bus_schedules(agency_id, departure_at);
create index if not exists idx_bus_bookings_passenger_created
  on public.bus_bookings(passenger_id, created_at desc);
create index if not exists idx_bus_bookings_schedule_status
  on public.bus_bookings(schedule_id, status, created_at desc);
create index if not exists idx_bus_booking_payments_booking_created
  on public.bus_booking_payments(booking_id, created_at desc);
create index if not exists idx_bus_location_events_bus_recorded
  on public.bus_location_events(bus_id, recorded_at desc);
create index if not exists idx_bus_location_events_org_recorded
  on public.bus_location_events(organization_id, recorded_at desc);

alter table public.transport_agencies enable row level security;
alter table public.agency_buses enable row level security;
alter table public.transport_routes enable row level security;
alter table public.route_stops enable row level security;
alter table public.bus_schedules enable row level security;
alter table public.bus_seat_inventory enable row level security;
alter table public.bus_bookings enable row level security;
alter table public.bus_booking_payments enable row level security;
alter table public.bus_tracking_sources enable row level security;
alter table public.bus_location_events enable row level security;

revoke all on public.transport_agencies from anon;
revoke all on public.agency_buses from anon;
revoke all on public.transport_routes from anon;
revoke all on public.route_stops from anon;
revoke all on public.bus_schedules from anon;
revoke all on public.bus_seat_inventory from anon;
revoke all on public.bus_bookings from anon;
revoke all on public.bus_booking_payments from anon;
revoke all on public.bus_tracking_sources from anon;
revoke all on public.bus_location_events from anon;

grant select on public.transport_agencies to authenticated;
grant select on public.agency_buses to authenticated;
grant select on public.transport_routes to authenticated;
grant select on public.route_stops to authenticated;
grant select on public.bus_schedules to authenticated;
grant select on public.bus_seat_inventory to authenticated;
grant select, insert, update on public.bus_bookings to authenticated;
grant select on public.bus_booking_payments to authenticated;
grant select on public.bus_tracking_sources to authenticated;
grant select on public.bus_location_events to authenticated;
grant all on public.transport_agencies to service_role;
grant all on public.agency_buses to service_role;
grant all on public.transport_routes to service_role;
grant all on public.route_stops to service_role;
grant all on public.bus_schedules to service_role;
grant all on public.bus_seat_inventory to service_role;
grant all on public.bus_bookings to service_role;
grant all on public.bus_booking_payments to service_role;
grant all on public.bus_tracking_sources to service_role;
grant all on public.bus_location_events to service_role;

drop policy if exists transport_agencies_read_active_or_admin on public.transport_agencies;
create policy transport_agencies_read_active_or_admin
  on public.transport_agencies
  for select
  to authenticated
  using (
    is_active = true
    or public.can_access_organization(organization_id, 'transport.agencies.manage')
  );

drop policy if exists transport_agencies_manage on public.transport_agencies;
create policy transport_agencies_manage
  on public.transport_agencies
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists agency_buses_read_active_or_admin on public.agency_buses;
create policy agency_buses_read_active_or_admin
  on public.agency_buses
  for select
  to authenticated
  using (
    is_active = true
    or current_driver_id = auth.uid()
    or public.can_access_organization(organization_id, 'transport.agencies.manage')
  );

drop policy if exists agency_buses_manage on public.agency_buses;
create policy agency_buses_manage
  on public.agency_buses
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists transport_routes_read_active_or_admin on public.transport_routes;
create policy transport_routes_read_active_or_admin
  on public.transport_routes
  for select
  to authenticated
  using (
    is_active = true
    or public.can_access_organization(organization_id, 'transport.agencies.manage')
  );

drop policy if exists transport_routes_manage on public.transport_routes;
create policy transport_routes_manage
  on public.transport_routes
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists route_stops_read_route_access on public.route_stops;
create policy route_stops_read_route_access
  on public.route_stops
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.transport_routes route_row
      where route_row.id = route_id
        and (
          route_row.is_active = true
          or public.can_access_organization(route_row.organization_id, 'transport.agencies.manage')
        )
    )
  );

drop policy if exists route_stops_manage on public.route_stops;
create policy route_stops_manage
  on public.route_stops
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists bus_schedules_read_bookable_or_admin on public.bus_schedules;
create policy bus_schedules_read_bookable_or_admin
  on public.bus_schedules
  for select
  to authenticated
  using (
    status in ('scheduled', 'boarding', 'departed', 'arrived')
    or public.can_access_organization(organization_id, 'transport.agencies.manage')
  );

drop policy if exists bus_schedules_manage on public.bus_schedules;
create policy bus_schedules_manage
  on public.bus_schedules
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists bus_seat_inventory_read_schedule_access on public.bus_seat_inventory;
create policy bus_seat_inventory_read_schedule_access
  on public.bus_seat_inventory
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.bus_schedules schedule_row
      where schedule_row.id = schedule_id
        and (
          schedule_row.status in ('scheduled', 'boarding')
          or public.can_access_organization(schedule_row.organization_id, 'transport.agencies.manage')
        )
    )
  );

drop policy if exists bus_seat_inventory_manage on public.bus_seat_inventory;
create policy bus_seat_inventory_manage
  on public.bus_seat_inventory
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.agencies.manage'))
  with check (public.can_access_organization(organization_id, 'transport.agencies.manage'));

drop policy if exists bus_bookings_select_owner_or_agency on public.bus_bookings;
create policy bus_bookings_select_owner_or_agency
  on public.bus_bookings
  for select
  to authenticated
  using (
    passenger_id = auth.uid()
    or public.can_access_organization(organization_id, 'transport.bookings.manage')
  );

drop policy if exists bus_bookings_update_owner_hold_or_agency on public.bus_bookings;
create policy bus_bookings_update_owner_hold_or_agency
  on public.bus_bookings
  for update
  to authenticated
  using (
    (passenger_id = auth.uid() and status = 'held')
    or public.can_access_organization(organization_id, 'transport.bookings.manage')
  )
  with check (
    passenger_id = auth.uid()
    or public.can_access_organization(organization_id, 'transport.bookings.manage')
  );

drop policy if exists bus_booking_payments_select_owner_or_agency on public.bus_booking_payments;
create policy bus_booking_payments_select_owner_or_agency
  on public.bus_booking_payments
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.bus_bookings booking
      where booking.id = booking_id
        and (
          booking.passenger_id = auth.uid()
          or public.can_access_organization(booking.organization_id, 'transport.bookings.manage')
        )
    )
  );

drop policy if exists bus_tracking_sources_select_driver_or_agency on public.bus_tracking_sources;
create policy bus_tracking_sources_select_driver_or_agency
  on public.bus_tracking_sources
  for select
  to authenticated
  using (
    public.can_access_organization(organization_id, 'transport.tracking.ingest')
    or exists (
      select 1
      from public.agency_buses bus
      where bus.id = bus_id
        and bus.current_driver_id = auth.uid()
    )
  );

drop policy if exists bus_tracking_sources_manage on public.bus_tracking_sources;
create policy bus_tracking_sources_manage
  on public.bus_tracking_sources
  for all
  to authenticated
  using (public.can_access_organization(organization_id, 'transport.tracking.ingest'))
  with check (public.can_access_organization(organization_id, 'transport.tracking.ingest'));

drop policy if exists bus_location_events_select_active_or_agency on public.bus_location_events;
create policy bus_location_events_select_active_or_agency
  on public.bus_location_events
  for select
  to authenticated
  using (
    recorded_at >= timezone('utc', now()) - interval '24 hours'
    or public.can_access_organization(organization_id, 'transport.agencies.manage')
  );

create or replace function public.mobio_public_transport_ticket_reference()
returns text
language sql
volatile
security definer
set search_path = ''
as $$
  select 'MB-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
$$;

revoke all on function public.mobio_public_transport_ticket_reference() from public, anon, authenticated;

create or replace function public.rpc_search_bus_schedules(
  p_origin_search text default null,
  p_destination_search text default null,
  p_departure_date date default null,
  p_agency_id uuid default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  schedule_id uuid,
  agency_id uuid,
  agency_name text,
  bus_id uuid,
  bus_display_name text,
  plate_number text,
  route_id uuid,
  route_code text,
  origin_name text,
  destination_name text,
  departure_at timestamptz,
  arrival_window_start timestamptz,
  arrival_window_end timestamptz,
  fare_amount numeric,
  currency text,
  available_seats integer,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    schedule.id,
    agency.id,
    agency.name,
    bus.id,
    bus.display_name,
    bus.plate_number,
    route.id,
    route.route_code,
    route.origin_name,
    route.destination_name,
    schedule.departure_at,
    schedule.arrival_window_start,
    schedule.arrival_window_end,
    schedule.fare_amount,
    schedule.currency,
    coalesce(inventory.available_seats, 0),
    schedule.status
  from public.bus_schedules schedule
  join public.transport_agencies agency on agency.id = schedule.agency_id
  join public.transport_routes route on route.id = schedule.route_id
  left join public.agency_buses bus on bus.id = schedule.bus_id
  left join public.bus_seat_inventory inventory on inventory.schedule_id = schedule.id
  where agency.is_active = true
    and route.is_active = true
    and schedule.status in ('scheduled', 'boarding')
    and (schedule.booking_cutoff_at is null or schedule.booking_cutoff_at > timezone('utc', now()))
    and (p_agency_id is null or agency.id = p_agency_id)
    and (p_departure_date is null or schedule.departure_at::date = p_departure_date)
    and (
      p_origin_search is null
      or route.origin_name ilike '%' || trim(p_origin_search) || '%'
    )
    and (
      p_destination_search is null
      or route.destination_name ilike '%' || trim(p_destination_search) || '%'
    )
  order by schedule.departure_at asc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.rpc_hold_bus_seats(
  p_schedule_id uuid,
  p_seat_count integer,
  p_seat_numbers jsonb default '[]'::jsonb,
  p_passenger_name text default null,
  p_passenger_phone text default null
)
returns table (
  booking_id uuid,
  ticket_reference text,
  status text,
  payment_status text,
  hold_expires_at timestamptz,
  amount numeric,
  currency text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_schedule public.bus_schedules%rowtype;
  v_inventory public.bus_seat_inventory%rowtype;
  v_booking public.bus_bookings%rowtype;
  v_hold_expires_at timestamptz := timezone('utc', now()) + interval '10 minutes';
begin
  if v_user_id is null then
    raise exception 'Please sign in to book a seat.';
  end if;
  if p_schedule_id is null or p_seat_count is null or p_seat_count < 1 or p_seat_count > 20 then
    raise exception 'Invalid seat hold request.';
  end if;

  select *
  into v_schedule
  from public.bus_schedules
  where id = p_schedule_id
    and status in ('scheduled', 'boarding')
    and (booking_cutoff_at is null or booking_cutoff_at > timezone('utc', now()))
  for update;

  if not found then
    raise exception 'Schedule is not available for booking.';
  end if;

  select *
  into v_inventory
  from public.bus_seat_inventory
  where schedule_id = p_schedule_id
  for update;

  if not found or v_inventory.available_seats < p_seat_count then
    raise exception 'Not enough seats are available.';
  end if;

  update public.bus_seat_inventory
  set
    available_seats = available_seats - p_seat_count,
    held_seats = held_seats + p_seat_count,
    updated_at = timezone('utc', now())
  where schedule_id = p_schedule_id;

  insert into public.bus_bookings (
    schedule_id,
    agency_id,
    organization_id,
    passenger_id,
    passenger_name,
    passenger_phone,
    seat_count,
    seat_numbers,
    status,
    payment_status,
    amount,
    currency,
    hold_expires_at,
    ticket_reference
  )
  values (
    v_schedule.id,
    v_schedule.agency_id,
    v_schedule.organization_id,
    v_user_id,
    nullif(trim(coalesce(p_passenger_name, '')), ''),
    nullif(trim(coalesce(p_passenger_phone, '')), ''),
    p_seat_count,
    coalesce(p_seat_numbers, '[]'::jsonb),
    'held',
    'pending',
    v_schedule.fare_amount * p_seat_count,
    v_schedule.currency,
    v_hold_expires_at,
    public.mobio_public_transport_ticket_reference()
  )
  returning * into v_booking;

  return query
  select
    v_booking.id,
    v_booking.ticket_reference,
    v_booking.status,
    v_booking.payment_status,
    v_booking.hold_expires_at,
    v_booking.amount,
    v_booking.currency;
end;
$$;

create or replace function public.rpc_confirm_bus_booking(
  p_booking_id uuid,
  p_payment_provider text,
  p_provider_reference text,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  booking_id uuid,
  ticket_reference text,
  status text,
  payment_status text,
  amount numeric,
  currency text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_booking public.bus_bookings%rowtype;
begin
  select *
  into v_booking
  from public.bus_bookings
  where id = p_booking_id
    and status = 'held'
    and payment_status = 'pending'
  for update;

  if not found then
    raise exception 'Booking is not available for confirmation.';
  end if;
  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.can_access_organization(v_booking.organization_id, 'transport.bookings.manage')
  ) then
    raise exception 'Payment confirmation requires agency or service authorization.';
  end if;
  if v_booking.hold_expires_at is not null and v_booking.hold_expires_at <= timezone('utc', now()) then
    update public.bus_bookings
    set status = 'expired',
        updated_at = timezone('utc', now())
    where id = v_booking.id;
    raise exception 'Booking hold expired.';
  end if;

  update public.bus_seat_inventory
  set
    held_seats = greatest(held_seats - v_booking.seat_count, 0),
    confirmed_seats = confirmed_seats + v_booking.seat_count,
    updated_at = timezone('utc', now())
  where schedule_id = v_booking.schedule_id;

  update public.bus_bookings
  set
    status = 'confirmed',
    payment_status = 'paid',
    updated_at = timezone('utc', now())
  where id = v_booking.id
  returning * into v_booking;

  insert into public.bus_booking_payments (
    booking_id,
    organization_id,
    provider,
    provider_reference,
    amount,
    currency,
    status,
    metadata
  )
  values (
    v_booking.id,
    v_booking.organization_id,
    nullif(trim(coalesce(p_payment_provider, '')), ''),
    nullif(trim(coalesce(p_provider_reference, '')), ''),
    v_booking.amount,
    v_booking.currency,
    'paid',
    coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (provider, provider_reference) do update
  set
    status = 'paid',
    metadata = excluded.metadata,
    updated_at = timezone('utc', now());

  return query
  select
    v_booking.id,
    v_booking.ticket_reference,
    v_booking.status,
    v_booking.payment_status,
    v_booking.amount,
    v_booking.currency;
end;
$$;

create or replace function public.rpc_cancel_bus_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_booking public.bus_bookings%rowtype;
begin
  if v_user_id is null then
    raise exception 'Please sign in to cancel this booking.';
  end if;

  select *
  into v_booking
  from public.bus_bookings
  where id = p_booking_id
    and (
      passenger_id = v_user_id
      or public.can_access_organization(organization_id, 'transport.bookings.manage')
    )
    and status in ('held', 'confirmed')
  for update;

  if not found then
    raise exception 'Booking is not cancellable.';
  end if;

  if v_booking.status = 'held' then
    update public.bus_seat_inventory
    set
      available_seats = available_seats + v_booking.seat_count,
      held_seats = greatest(held_seats - v_booking.seat_count, 0),
      updated_at = timezone('utc', now())
    where schedule_id = v_booking.schedule_id;
  else
    update public.bus_seat_inventory
    set
      available_seats = available_seats + v_booking.seat_count,
      confirmed_seats = greatest(confirmed_seats - v_booking.seat_count, 0),
      updated_at = timezone('utc', now())
    where schedule_id = v_booking.schedule_id;
  end if;

  update public.bus_bookings
  set
    status = 'cancelled',
    payment_status = case
      when payment_status = 'paid' then 'refund_pending'
      else payment_status
    end,
    updated_at = timezone('utc', now())
  where id = v_booking.id;

  update public.bus_booking_payments
  set
    status = 'refund_pending',
    updated_at = timezone('utc', now())
  where booking_id = v_booking.id
    and status = 'paid';
end;
$$;

create or replace function public.rpc_get_bus_payment_status(p_booking_id uuid)
returns table (
  booking_id uuid,
  booking_status text,
  payment_status text,
  latest_provider text,
  latest_provider_reference text,
  amount numeric,
  currency text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    booking.id,
    booking.status,
    booking.payment_status,
    payment.provider,
    payment.provider_reference,
    booking.amount,
    booking.currency,
    coalesce(payment.updated_at, booking.updated_at)
  from public.bus_bookings booking
  left join lateral (
    select p.*
    from public.bus_booking_payments p
    where p.booking_id = booking.id
    order by p.created_at desc
    limit 1
  ) payment on true
  where booking.id = p_booking_id
    and (
      booking.passenger_id = auth.uid()
      or public.can_access_organization(booking.organization_id, 'transport.bookings.manage')
    );
end;
$$;

create or replace function public.rpc_ingest_bus_location(
  p_bus_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_heading_degrees double precision default null,
  p_speed_kph double precision default null,
  p_accuracy_meters double precision default null,
  p_tracking_source_id uuid default null,
  p_recorded_at timestamptz default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bus public.agency_buses%rowtype;
  v_event_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Please sign in to publish vehicle location.';
  end if;

  select *
  into v_bus
  from public.agency_buses
  where id = p_bus_id
    and is_active = true;

  if not found then
    raise exception 'Bus is not active.';
  end if;

  if not (
    v_bus.current_driver_id = auth.uid()
    or public.can_access_organization(v_bus.organization_id, 'transport.tracking.ingest')
  ) then
    raise exception 'Not authorized to publish this bus location.';
  end if;

  insert into public.bus_location_events (
    bus_id,
    tracking_source_id,
    organization_id,
    latitude,
    longitude,
    heading_degrees,
    speed_kph,
    accuracy_meters,
    recorded_at,
    metadata
  )
  values (
    p_bus_id,
    p_tracking_source_id,
    v_bus.organization_id,
    p_latitude,
    p_longitude,
    p_heading_degrees,
    p_speed_kph,
    p_accuracy_meters,
    coalesce(p_recorded_at, timezone('utc', now())),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_event_id;

  update public.bus_tracking_sources
  set
    last_seen_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_tracking_source_id;

  update public.agency_buses
  set updated_at = timezone('utc', now())
  where id = p_bus_id;

  return v_event_id;
end;
$$;

revoke all on function public.rpc_search_bus_schedules(text, text, date, uuid, integer, integer) from public, anon, authenticated;
revoke all on function public.rpc_hold_bus_seats(uuid, integer, jsonb, text, text) from public, anon, authenticated;
revoke all on function public.rpc_confirm_bus_booking(uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_cancel_bus_booking(uuid) from public, anon, authenticated;
revoke all on function public.rpc_get_bus_payment_status(uuid) from public, anon, authenticated;
revoke all on function public.rpc_ingest_bus_location(uuid, double precision, double precision, double precision, double precision, double precision, uuid, timestamptz, jsonb) from public, anon, authenticated;

grant execute on function public.rpc_search_bus_schedules(text, text, date, uuid, integer, integer) to authenticated;
grant execute on function public.rpc_hold_bus_seats(uuid, integer, jsonb, text, text) to authenticated;
grant execute on function public.rpc_confirm_bus_booking(uuid, text, text, jsonb) to authenticated;
grant execute on function public.rpc_cancel_bus_booking(uuid) to authenticated;
grant execute on function public.rpc_get_bus_payment_status(uuid) to authenticated;
grant execute on function public.rpc_ingest_bus_location(uuid, double precision, double precision, double precision, double precision, double precision, uuid, timestamptz, jsonb) to authenticated;

commit;
