-- Qualify public transport booking RPC column references for linked lint.
-- Supabase schema lint treats OUT parameters such as status/payment_status as
-- PL/pgSQL variables, so table columns must be explicitly qualified.

begin;

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

  select schedule.*
  into v_schedule
  from public.bus_schedules as schedule
  where schedule.id = p_schedule_id
    and schedule.status in ('scheduled', 'boarding')
    and (schedule.booking_cutoff_at is null or schedule.booking_cutoff_at > timezone('utc', now()))
  for update;

  if not found then
    raise exception 'Schedule is not available for booking.';
  end if;

  select inventory.*
  into v_inventory
  from public.bus_seat_inventory as inventory
  where inventory.schedule_id = p_schedule_id
  for update;

  if not found or v_inventory.available_seats < p_seat_count then
    raise exception 'Not enough seats are available.';
  end if;

  update public.bus_seat_inventory as inventory
  set
    available_seats = inventory.available_seats - p_seat_count,
    held_seats = inventory.held_seats + p_seat_count,
    updated_at = timezone('utc', now())
  where inventory.schedule_id = p_schedule_id;

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
  v_booking public.bus_bookings%rowtype;
begin
  select booking.*
  into v_booking
  from public.bus_bookings as booking
  where booking.id = p_booking_id
    and booking.status = 'held'
    and booking.payment_status = 'pending'
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
    update public.bus_bookings as booking
    set status = 'expired',
        updated_at = timezone('utc', now())
    where booking.id = v_booking.id;
    raise exception 'Booking hold expired.';
  end if;

  update public.bus_seat_inventory as inventory
  set
    held_seats = greatest(inventory.held_seats - v_booking.seat_count, 0),
    confirmed_seats = inventory.confirmed_seats + v_booking.seat_count,
    updated_at = timezone('utc', now())
  where inventory.schedule_id = v_booking.schedule_id;

  update public.bus_bookings as booking
  set
    status = 'confirmed',
    payment_status = 'paid',
    updated_at = timezone('utc', now())
  where booking.id = v_booking.id
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

  select booking.*
  into v_booking
  from public.bus_bookings as booking
  where booking.id = p_booking_id
    and (
      booking.passenger_id = v_user_id
      or public.can_access_organization(booking.organization_id, 'transport.bookings.manage')
    )
    and booking.status in ('held', 'confirmed')
  for update;

  if not found then
    raise exception 'Booking is not cancellable.';
  end if;

  if v_booking.status = 'held' then
    update public.bus_seat_inventory as inventory
    set
      available_seats = inventory.available_seats + v_booking.seat_count,
      held_seats = greatest(inventory.held_seats - v_booking.seat_count, 0),
      updated_at = timezone('utc', now())
    where inventory.schedule_id = v_booking.schedule_id;
  else
    update public.bus_seat_inventory as inventory
    set
      available_seats = inventory.available_seats + v_booking.seat_count,
      confirmed_seats = greatest(inventory.confirmed_seats - v_booking.seat_count, 0),
      updated_at = timezone('utc', now())
    where inventory.schedule_id = v_booking.schedule_id;
  end if;

  update public.bus_bookings as booking
  set
    status = 'cancelled',
    payment_status = case
      when booking.payment_status = 'paid' then 'refund_pending'
      else booking.payment_status
    end,
    updated_at = timezone('utc', now())
  where booking.id = v_booking.id;

  update public.bus_booking_payments as payment
  set
    status = 'refund_pending',
    updated_at = timezone('utc', now())
  where payment.booking_id = v_booking.id
    and payment.status = 'paid';
end;
$$;

revoke all on function public.rpc_hold_bus_seats(uuid, integer, jsonb, text, text) from public, anon, authenticated;
revoke all on function public.rpc_confirm_bus_booking(uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_cancel_bus_booking(uuid) from public, anon, authenticated;

grant execute on function public.rpc_hold_bus_seats(uuid, integer, jsonb, text, text) to authenticated;
grant execute on function public.rpc_confirm_bus_booking(uuid, text, text, jsonb) to authenticated;
grant execute on function public.rpc_cancel_bus_booking(uuid) to authenticated;

commit;
