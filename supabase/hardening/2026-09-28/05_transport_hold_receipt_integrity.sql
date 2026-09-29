-- Forward BODY. Rehearse with real PostgreSQL/PostgREST before deployment.
-- Makes seat holds idempotent per passenger/schedule, releases expired holds,
-- and binds a provider receipt to exactly one booking before confirming inventory.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function public._mobio_release_expired_bus_holds(p_schedule_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  released_count integer := 0;
  hold_row record;
begin
  for hold_row in
    select b.id, b.schedule_id, b.seat_count
    from public.bus_bookings b
    where b.status = 'held'
      and b.payment_status = 'pending'
      and b.hold_expires_at is not null
      and b.hold_expires_at <= timezone('utc', now())
      and (p_schedule_id is null or b.schedule_id = p_schedule_id)
    order by b.schedule_id, b.id
    for update skip locked
  loop
    update public.bus_bookings b
    set status = 'expired', updated_at = timezone('utc', now())
    where b.id = hold_row.id and b.status = 'held';
    if found then
      update public.bus_seat_inventory i
      set available_seats = least(i.total_seats, i.available_seats + hold_row.seat_count),
          held_seats = greatest(i.held_seats - hold_row.seat_count, 0),
          updated_at = timezone('utc', now())
      where i.schedule_id = hold_row.schedule_id;
      released_count := released_count + 1;
    end if;
  end loop;
  return released_count;
end
$$;
revoke all on function public._mobio_release_expired_bus_holds(uuid) from public, anon, authenticated;
grant execute on function public._mobio_release_expired_bus_holds(uuid) to service_role;

create or replace function public.rpc_hold_bus_seats(
  p_schedule_id uuid,
  p_seat_count integer,
  p_seat_numbers jsonb default '[]'::jsonb,
  p_passenger_name text default null,
  p_passenger_phone text default null
)
returns table (booking_id uuid,ticket_reference text,status text,payment_status text,hold_expires_at timestamptz,amount numeric,currency text)
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := public.verified_app_user_id();
  v_schedule public.bus_schedules%rowtype;
  v_inventory public.bus_seat_inventory%rowtype;
  v_booking public.bus_bookings%rowtype;
  v_hold_expires_at timestamptz := timezone('utc', now()) + interval '10 minutes';
begin
  if v_user_id is null then raise exception 'Please sign in to book a seat.'; end if;
  if p_schedule_id is null or p_seat_count is null or p_seat_count < 1 or p_seat_count > 20 then
    raise exception 'Invalid seat hold request.';
  end if;

  select s.* into v_schedule from public.bus_schedules s
  where s.id=p_schedule_id and s.status in ('scheduled','boarding')
    and (s.booking_cutoff_at is null or s.booking_cutoff_at > timezone('utc',now()))
  for update;
  if not found then raise exception 'Schedule is not available for booking.'; end if;

  perform public._mobio_release_expired_bus_holds(p_schedule_id);

  -- Schedule row lock serializes competing holds. Return an equivalent active hold
  -- instead of decrementing inventory again on client retry.
  select b.* into v_booking from public.bus_bookings b
  where b.schedule_id=p_schedule_id and b.passenger_id=v_user_id
    and b.status='held' and b.payment_status='pending'
    and (b.hold_expires_at is null or b.hold_expires_at > timezone('utc',now()))
  order by b.created_at desc
  limit 1;
  if found then
    if v_booking.seat_count <> p_seat_count
       or coalesce(v_booking.seat_numbers,'[]'::jsonb) <> coalesce(p_seat_numbers,'[]'::jsonb) then
      raise exception 'An active hold already exists for this schedule.' using errcode='23505';
    end if;
    return query select v_booking.id,v_booking.ticket_reference,v_booking.status,
      v_booking.payment_status,v_booking.hold_expires_at,v_booking.amount,v_booking.currency;
    return;
  end if;

  select i.* into v_inventory from public.bus_seat_inventory i
  where i.schedule_id=p_schedule_id for update;
  if not found or v_inventory.available_seats < p_seat_count then
    raise exception 'Not enough seats are available.';
  end if;

  update public.bus_seat_inventory i
  set available_seats=i.available_seats-p_seat_count,
      held_seats=i.held_seats+p_seat_count,
      updated_at=timezone('utc',now())
  where i.schedule_id=p_schedule_id;

  insert into public.bus_bookings(schedule_id,agency_id,organization_id,passenger_id,
    passenger_name,passenger_phone,seat_count,seat_numbers,status,payment_status,
    amount,currency,hold_expires_at,ticket_reference)
  values(v_schedule.id,v_schedule.agency_id,v_schedule.organization_id,v_user_id,
    nullif(trim(coalesce(p_passenger_name,'')),''),nullif(trim(coalesce(p_passenger_phone,'')),''),
    p_seat_count,coalesce(p_seat_numbers,'[]'::jsonb),'held','pending',
    v_schedule.fare_amount*p_seat_count,v_schedule.currency,v_hold_expires_at,
    public.mobio_public_transport_ticket_reference())
  returning * into v_booking;

  return query select v_booking.id,v_booking.ticket_reference,v_booking.status,
    v_booking.payment_status,v_booking.hold_expires_at,v_booking.amount,v_booking.currency;
end $$;

create or replace function public.rpc_confirm_bus_booking(
  p_booking_id uuid,p_payment_provider text,p_provider_reference text,p_metadata jsonb default '{}'::jsonb
)
returns table (booking_id uuid,ticket_reference text,status text,payment_status text,amount numeric,currency text)
language plpgsql security definer set search_path = '' as $$
declare
  v_booking public.bus_bookings%rowtype;
  v_existing_payment public.bus_booking_payments%rowtype;
  v_provider text := nullif(trim(coalesce(p_payment_provider,'')),'');
  v_reference text := nullif(trim(coalesce(p_provider_reference,'')),'');
begin
  if v_provider is null or v_reference is null or length(v_reference)>200 then
    raise exception 'PAYMENT_REFERENCE_REQUIRED' using errcode='22023';
  end if;

  select b.* into v_booking from public.bus_bookings b where b.id=p_booking_id for update;
  if not found then raise exception 'Booking is not available for confirmation.'; end if;
  if not (public._mobio_is_service_role()
      or public.can_access_organization(v_booking.organization_id,'transport.bookings.manage')) then
    raise exception 'Payment confirmation requires agency or service authorization.';
  end if;

  select p.* into v_existing_payment from public.bus_booking_payments p
  where p.provider=v_provider and p.provider_reference=v_reference for update;
  if found and v_existing_payment.booking_id <> v_booking.id then
    raise exception 'PAYMENT_REFERENCE_ALREADY_USED' using errcode='23505';
  end if;

  if v_booking.status='confirmed' and v_booking.payment_status='paid' then
    if not found then raise exception 'BOOKING_ALREADY_CONFIRMED_WITH_DIFFERENT_RECEIPT' using errcode='23505'; end if;
    return query select v_booking.id,v_booking.ticket_reference,v_booking.status,
      v_booking.payment_status,v_booking.amount,v_booking.currency;
    return;
  end if;
  if v_booking.status<>'held' or v_booking.payment_status<>'pending' then
    raise exception 'Booking is not available for confirmation.';
  end if;

  if v_booking.hold_expires_at is not null and v_booking.hold_expires_at <= timezone('utc',now()) then
    update public.bus_bookings b set status='expired',updated_at=timezone('utc',now()) where b.id=v_booking.id;
    update public.bus_seat_inventory i
      set available_seats=least(i.total_seats,i.available_seats+v_booking.seat_count),
          held_seats=greatest(i.held_seats-v_booking.seat_count,0),
          updated_at=timezone('utc',now())
      where i.schedule_id=v_booking.schedule_id;
    v_booking.status := 'expired';
    return query select v_booking.id,v_booking.ticket_reference,'expired'::text,
      v_booking.payment_status,v_booking.amount,v_booking.currency;
    return;
  end if;

  if v_existing_payment.id is null then
    insert into public.bus_booking_payments(booking_id,organization_id,provider,provider_reference,
      amount,currency,status,metadata)
    values(v_booking.id,v_booking.organization_id,v_provider,v_reference,
      v_booking.amount,v_booking.currency,'paid',coalesce(p_metadata,'{}'::jsonb))
    returning * into v_existing_payment;
  else
    update public.bus_booking_payments p
    set status='paid',metadata=coalesce(p_metadata,'{}'::jsonb),updated_at=timezone('utc',now())
    where p.id=v_existing_payment.id;
  end if;

  update public.bus_seat_inventory i
  set held_seats=greatest(i.held_seats-v_booking.seat_count,0),
      confirmed_seats=i.confirmed_seats+v_booking.seat_count,
      updated_at=timezone('utc',now())
  where i.schedule_id=v_booking.schedule_id;

  update public.bus_bookings b
  set status='confirmed',payment_status='paid',updated_at=timezone('utc',now())
  where b.id=v_booking.id returning * into v_booking;

  return query select v_booking.id,v_booking.ticket_reference,v_booking.status,
    v_booking.payment_status,v_booking.amount,v_booking.currency;
end $$;

revoke all on function public.rpc_hold_bus_seats(uuid,integer,jsonb,text,text) from public,anon;
revoke all on function public.rpc_confirm_bus_booking(uuid,text,text,jsonb) from public,anon;
grant execute on function public.rpc_hold_bus_seats(uuid,integer,jsonb,text,text) to authenticated;
grant execute on function public.rpc_confirm_bus_booking(uuid,text,text,jsonb) to authenticated;

-- A durable sweeper entry point. Scheduling is an operations decision and is not
-- silently created here; production must bind this to the approved scheduler.
create or replace function public.rpc_expire_bus_holds(p_limit integer default 500)
returns integer language plpgsql security definer set search_path='' as $$
declare total_released integer := 0; schedule_row record; released integer;
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  for schedule_row in
    select distinct b.schedule_id from public.bus_bookings b
    where b.status='held' and b.payment_status='pending'
      and b.hold_expires_at <= timezone('utc',now())
    order by b.schedule_id limit least(greatest(coalesce(p_limit,500),1),5000)
  loop
    released := public._mobio_release_expired_bus_holds(schedule_row.schedule_id);
    total_released := total_released + released;
  end loop;
  return total_released;
end $$;
revoke all on function public.rpc_expire_bus_holds(integer) from public,anon,authenticated;
grant execute on function public.rpc_expire_bus_holds(integer) to service_role;

notify pgrst, 'reload schema';
commit;
