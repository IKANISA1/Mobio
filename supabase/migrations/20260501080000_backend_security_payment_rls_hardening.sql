begin;

-- Phase 1 backend hardening:
-- - Remove broad profile/trip/driver-location reads.
-- - Route peer profile lookups through a minimal public-profile RPC.
-- - Disable legacy in-app BioPay wallet transfer RPCs.
-- - Make external/manual payment status changes auditable with source,
--   amount, currency, and payment method context.

-- ---------------------------------------------------------------------------
-- Profiles: self/admin table reads, minimal peer lookup RPC for chat/trip UI.
-- ---------------------------------------------------------------------------

drop policy if exists profiles_select_authenticated on public.profiles;
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid() or public.is_platform_admin());

create or replace function public.rpc_get_public_profile(p_profile_id uuid)
returns table (
  id uuid,
  member_id text,
  name text,
  display_name text,
  role text,
  vehicle_type text,
  vehicle_number_plate text,
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
    p.is_driver,
    p.avatar_url,
    p.created_at
  from public.profiles p
  where p.id = p_profile_id;
end;
$$;

comment on function public.rpc_get_public_profile(uuid)
  is 'Returns minimal non-sensitive profile fields for authenticated chat/trip directory use without exposing full profiles table rows.';

revoke all on function public.rpc_get_public_profile(uuid) from public;
revoke all on function public.rpc_get_public_profile(uuid) from anon;
revoke all on function public.rpc_get_public_profile(uuid) from authenticated;
grant execute on function public.rpc_get_public_profile(uuid) to authenticated;

revoke select on public.profiles from public, anon;
grant select, insert, update on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Trips: WhatsApp login is mandatory, so directory reads are authenticated only.
-- ---------------------------------------------------------------------------

drop policy if exists trips_select_active_public on public.trips;
drop policy if exists trips_select_directory_authenticated on public.trips;
drop policy if exists trips_select_active_authenticated_directory on public.trips;
create policy trips_select_active_authenticated_directory
  on public.trips
  for select
  to authenticated
  using (is_active = true and status in ('active', 'approved'));

revoke select on public.trips from public, anon;
grant select, insert, update, delete on public.trips to authenticated;

-- ---------------------------------------------------------------------------
-- Driver locations: authenticated directory reads, driver-only writes.
-- ---------------------------------------------------------------------------

alter table public.driver_locations enable row level security;

drop policy if exists "Drivers can update their own location" on public.driver_locations;
drop policy if exists "Anyone can view online driver locations" on public.driver_locations;
drop policy if exists driver_locations_online_read_authenticated on public.driver_locations;
drop policy if exists driver_locations_driver_insert on public.driver_locations;
drop policy if exists driver_locations_driver_update on public.driver_locations;
drop policy if exists driver_locations_driver_delete on public.driver_locations;
drop policy if exists driver_locations_admin_manage on public.driver_locations;

create policy driver_locations_online_read_authenticated
  on public.driver_locations
  for select
  to authenticated
  using (
    is_online = true
    or driver_id = auth.uid()
    or public.is_platform_admin()
  );

create policy driver_locations_driver_insert
  on public.driver_locations
  for insert
  to authenticated
  with check (
    driver_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (p.is_driver = true or p.role = 'driver')
    )
  );

create policy driver_locations_driver_update
  on public.driver_locations
  for update
  to authenticated
  using (
    driver_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (p.is_driver = true or p.role = 'driver')
    )
  )
  with check (
    driver_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (p.is_driver = true or p.role = 'driver')
    )
  );

create policy driver_locations_driver_delete
  on public.driver_locations
  for delete
  to authenticated
  using (
    driver_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (p.is_driver = true or p.role = 'driver')
    )
  );

create policy driver_locations_admin_manage
  on public.driver_locations
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create index if not exists idx_driver_locations_online_updated
  on public.driver_locations (is_online, updated_at desc)
  where is_online = true;

create index if not exists idx_driver_locations_vehicle_online_updated
  on public.driver_locations (vehicle_type_id, is_online, updated_at desc)
  where is_online = true;

revoke all on public.driver_locations from public, anon;
grant select, insert, update, delete on public.driver_locations to authenticated;

-- ---------------------------------------------------------------------------
-- Payments: external USSD/manual review only, no client-created confirmations.
-- ---------------------------------------------------------------------------

alter table public.payment_intents
  drop constraint if exists payment_intents_status_check;

alter table public.payment_intents
  add constraint payment_intents_status_check
  check (
    status in (
      'created',
      'instruction_issued',
      'pending_confirmation',
      'processing',
      'authorized',
      'manual_review_required',
      'manually_confirmed',
      'paid',
      'completed',
      'failed',
      'disputed',
      'refunded',
      'cancelled',
      'expired'
    )
  );

alter table public.payment_events
  add column if not exists amount numeric(14,2),
  add column if not exists currency char(3),
  add column if not exists payment_method text,
  add column if not exists source text not null default 'legacy_backfill',
  add column if not exists metadata jsonb not null default '{}'::jsonb;

update public.payment_events e
set
  amount = coalesce(e.amount, i.amount),
  currency = coalesce(e.currency, i.currency),
  payment_method = coalesce(e.payment_method, i.payment_method),
  source = case
    when e.source is null or e.source = 'unknown' then 'legacy_backfill'
    else e.source
  end,
  metadata = coalesce(e.metadata, '{}'::jsonb)
from public.payment_intents i
where i.id = e.intent_id;

alter table public.payment_events
  alter column source set default 'legacy_backfill',
  alter column source set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null;

alter table public.payment_events
  drop constraint if exists payment_events_status_check,
  drop constraint if exists payment_events_source_check,
  drop constraint if exists payment_events_amount_non_negative_check,
  drop constraint if exists payment_events_currency_format_check,
  drop constraint if exists payment_events_payment_method_check;

alter table public.payment_events
  add constraint payment_events_status_check
  check (
    status in (
      'created',
      'instruction_issued',
      'pending_confirmation',
      'processing',
      'authorized',
      'manual_review_required',
      'manually_confirmed',
      'paid',
      'completed',
      'failed',
      'disputed',
      'refunded',
      'cancelled',
      'expired'
    )
  ),
  add constraint payment_events_source_check
  check (
    source in (
      'legacy_backfill',
      'external_ussd_sms',
      'manual_admin_review',
      'system',
      'edge_function',
      'unknown'
    )
  ),
  add constraint payment_events_amount_non_negative_check
  check (amount is null or amount >= 0),
  add constraint payment_events_currency_format_check
  check (currency is null or currency::text ~ '^[A-Z]{3}$'),
  add constraint payment_events_payment_method_check
  check (
    payment_method is null
    or payment_method in (
      'ussd_momo',
      'external_ussd',
      'manual_ussd',
      'mobile_money',
      'momo',
      'manual_review',
      'qr',
      'nfc',
      'cash',
      'face_id',
      'unknown'
    )
  );

drop policy if exists "Users select own intents" on public.payment_intents;
drop policy if exists "Users insert own intents" on public.payment_intents;
drop policy if exists "Admin manage intents" on public.payment_intents;
drop policy if exists payment_intents_select_participants on public.payment_intents;
drop policy if exists payment_intents_admin_manage on public.payment_intents;

create policy payment_intents_select_participants
  on public.payment_intents
  for select
  to authenticated
  using (
    payer_id = auth.uid()
    or payee_id = auth.uid()
    or public.is_platform_admin()
  );

create policy payment_intents_admin_manage
  on public.payment_intents
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists "Users select own events" on public.payment_events;
drop policy if exists "Users insert own events" on public.payment_events;
drop policy if exists "Admin manage events" on public.payment_events;
drop policy if exists payment_events_select_participants on public.payment_events;
drop policy if exists payment_events_admin_manage on public.payment_events;

create policy payment_events_select_participants
  on public.payment_events
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.payment_intents i
      where i.id = intent_id
        and (
          i.payer_id = auth.uid()
          or i.payee_id = auth.uid()
          or public.is_platform_admin()
        )
    )
  );

create policy payment_events_admin_manage
  on public.payment_events
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

revoke insert, update, delete on public.payment_intents from anon, authenticated;
revoke insert, update, delete on public.payment_events from anon, authenticated;
grant select on public.payment_intents to authenticated;
grant select on public.payment_events to authenticated;
grant select, insert, update, delete on public.payment_intents to service_role;
grant select, insert, update, delete on public.payment_events to service_role;

create index if not exists idx_payment_intents_payer_created
  on public.payment_intents (payer_id, created_at desc);

create index if not exists idx_payment_intents_payee_created
  on public.payment_intents (payee_id, created_at desc);

create index if not exists idx_payment_intents_status_updated
  on public.payment_intents (status, updated_at desc);

create index if not exists idx_payment_events_intent_created
  on public.payment_events (intent_id, created_at desc);

create index if not exists idx_risk_flags_resolved_created
  on public.risk_flags (resolved, created_at desc);

-- QR/NFC session tables stay private; scan flows must use resolver RPCs.
drop policy if exists "Public select qr sessions" on public.qr_payment_sessions;
drop policy if exists "Public select nfc sessions" on public.nfc_payment_sessions;
revoke select on public.qr_payment_sessions from public, anon;
revoke select on public.nfc_payment_sessions from public, anon;

-- ---------------------------------------------------------------------------
-- Legacy in-app BioPay wallet RPCs: disabled in favor of external USSD only.
-- ---------------------------------------------------------------------------

create or replace function public.fn_biopay_generate_qr(
  p_amount numeric,
  p_currency text default 'RWF',
  p_note text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '0A000',
    message = 'In-app BioPay QR payments are disabled. Use external USSD instructions only.';
end;
$$;

create or replace function public.fn_biopay_resolve_qr_payload(p_qr_ref text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '0A000',
    message = 'In-app BioPay QR payments are disabled. Use external USSD instructions only.';
end;
$$;

create or replace function public.fn_biopay_scan_and_charge(p_qr_ref text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '0A000',
    message = 'In-app BioPay scan-and-charge is disabled. Use external USSD instructions only.';
end;
$$;

comment on function public.fn_biopay_generate_qr(numeric, text, text)
  is 'Disabled: MOBI payments are external USSD/manual confirmation only.';
comment on function public.fn_biopay_resolve_qr_payload(text)
  is 'Disabled: MOBI payments are external USSD/manual confirmation only.';
comment on function public.fn_biopay_scan_and_charge(text)
  is 'Disabled: MOBI payments are external USSD/manual confirmation only.';

revoke all on function public.fn_biopay_generate_qr(numeric, text, text) from public;
revoke all on function public.fn_biopay_generate_qr(numeric, text, text) from anon;
revoke all on function public.fn_biopay_generate_qr(numeric, text, text) from authenticated;
revoke all on function public.fn_biopay_resolve_qr_payload(text) from public;
revoke all on function public.fn_biopay_resolve_qr_payload(text) from anon;
revoke all on function public.fn_biopay_resolve_qr_payload(text) from authenticated;
revoke all on function public.fn_biopay_scan_and_charge(text) from public;
revoke all on function public.fn_biopay_scan_and_charge(text) from anon;
revoke all on function public.fn_biopay_scan_and_charge(text) from authenticated;

revoke all on function public.rpc_get_biopay_wallet() from public;
revoke all on function public.rpc_get_biopay_wallet() from anon;
revoke all on function public.rpc_get_biopay_wallet() from authenticated;
revoke all on function public.rpc_update_biopay_handle(text, text) from public;
revoke all on function public.rpc_update_biopay_handle(text, text) from anon;
revoke all on function public.rpc_update_biopay_handle(text, text) from authenticated;

commit;
