begin;

-- Final hardening pass for the remaining production risks:
-- - Make tenant keys mandatory on operational and legacy sensitive tables.
-- - Replace remaining direct admin role checks with platform permissions.
-- - Replace legacy storage policies with canonical least-privilege policies.
-- - Add campaign approval and notification consent primitives.
-- - Keep disabled in-app BioPay transfer RPCs lint-clean while still blocked.

insert into public.platform_permissions (permission_key, description)
values
  ('admin.broadcasts.send', 'Send approved operational broadcasts.'),
  ('admin.broadcasts.approve', 'Approve promotional campaign broadcasts.'),
  ('admin.campaigns.read', 'Read campaign approval and consent records.'),
  ('admin.audit.write', 'Write administrative audit records.'),
  ('admin.trips.manage', 'Manage trip records.'),
  ('platform.config.manage', 'Manage platform reference configuration.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key)
select p.id, permission.permission_key
from public.profiles p
cross join (
  values
    ('admin.broadcasts.send'),
    ('admin.broadcasts.approve'),
    ('admin.campaigns.read'),
    ('admin.audit.write'),
    ('admin.trips.manage'),
    ('platform.config.manage')
) as permission(permission_key)
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

create or replace function public.default_organization_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select org.id
  from public.organizations org
  where org.slug = 'mobi-platform'
  order by org.created_at asc
  limit 1;
$$;

revoke all on function public.default_organization_id() from public, anon, authenticated;
grant execute on function public.default_organization_id() to authenticated;

-- Canonical foundations for legacy objects that existed remotely before this
-- hardening pass. Keep the definitions minimal and aligned with the client
-- models so clean-checkout migration replay does not depend on dashboard drift.
create table if not exists public.promo_video_jobs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  category text,
  prompt text,
  output_path text,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  organization_id uuid references public.organizations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_requests (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips(id) on delete set null,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  responder_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'request'
    check (type in ('request', 'offer')),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  message text,
  metadata jsonb not null default '{}'::jsonb,
  organization_id uuid references public.organizations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ride_requests_not_self_check
    check (requester_id <> responder_id)
);

create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null default '',
  place_id text,
  formatted_address text not null default '',
  latitude double precision,
  longitude double precision,
  metadata jsonb not null default '{}'::jsonb,
  organization_id uuid references public.organizations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trip_requests (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'accepted', 'declined', 'cancelled')),
  message text,
  metadata jsonb not null default '{}'::jsonb,
  organization_id uuid references public.organizations(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_promo_video_jobs_updated_at on public.promo_video_jobs;
create trigger set_promo_video_jobs_updated_at
before update on public.promo_video_jobs
for each row execute function public.handle_updated_at();

drop trigger if exists set_ride_requests_updated_at on public.ride_requests;
create trigger set_ride_requests_updated_at
before update on public.ride_requests
for each row execute function public.handle_updated_at();

drop trigger if exists set_saved_places_updated_at on public.saved_places;
create trigger set_saved_places_updated_at
before update on public.saved_places
for each row execute function public.handle_updated_at();

drop trigger if exists set_trip_requests_updated_at on public.trip_requests;
create trigger set_trip_requests_updated_at
before update on public.trip_requests
for each row execute function public.handle_updated_at();

create unique index if not exists uq_ride_requests_pending_actor_trip_type
  on public.ride_requests(
    requester_id,
    responder_id,
    coalesce(trip_id, '00000000-0000-0000-0000-000000000000'::uuid),
    type
  )
  where status = 'pending';

create index if not exists idx_ride_requests_requester_status
  on public.ride_requests(requester_id, status, created_at desc);
create index if not exists idx_ride_requests_responder_status
  on public.ride_requests(responder_id, status, created_at desc);
create index if not exists idx_trip_requests_trip_status
  on public.trip_requests(trip_id, status, created_at desc);
create index if not exists idx_trip_requests_requester_status
  on public.trip_requests(requester_id, status, created_at desc);
create index if not exists idx_saved_places_user_updated
  on public.saved_places(user_id, updated_at desc);

alter table public.promo_video_jobs enable row level security;
alter table public.ride_requests enable row level security;
alter table public.saved_places enable row level security;
alter table public.trip_requests enable row level security;

revoke all on public.promo_video_jobs from anon, authenticated;
revoke all on public.ride_requests from anon, authenticated;
revoke all on public.saved_places from anon, authenticated;
revoke all on public.trip_requests from anon, authenticated;

grant all on public.promo_video_jobs to service_role;
grant select, insert, update, delete on public.ride_requests to authenticated;
grant select, insert, update, delete on public.saved_places to authenticated;
grant select, insert, update, delete on public.trip_requests to authenticated;
grant all on public.ride_requests to service_role;
grant all on public.saved_places to service_role;
grant all on public.trip_requests to service_role;

drop policy if exists ride_requests_participant_read on public.ride_requests;
create policy ride_requests_participant_read
  on public.ride_requests
  for select
  to authenticated
  using (requester_id = auth.uid() or responder_id = auth.uid());

drop policy if exists ride_requests_requester_insert on public.ride_requests;
create policy ride_requests_requester_insert
  on public.ride_requests
  for insert
  to authenticated
  with check (requester_id = auth.uid());

drop policy if exists ride_requests_participant_update on public.ride_requests;
create policy ride_requests_participant_update
  on public.ride_requests
  for update
  to authenticated
  using (requester_id = auth.uid() or responder_id = auth.uid())
  with check (requester_id = auth.uid() or responder_id = auth.uid());

drop policy if exists saved_places_owner_read on public.saved_places;
create policy saved_places_owner_read
  on public.saved_places
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists saved_places_owner_insert on public.saved_places;
create policy saved_places_owner_insert
  on public.saved_places
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists saved_places_owner_update on public.saved_places;
create policy saved_places_owner_update
  on public.saved_places
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists saved_places_owner_delete on public.saved_places;
create policy saved_places_owner_delete
  on public.saved_places
  for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists trip_requests_owner_read on public.trip_requests;
create policy trip_requests_owner_read
  on public.trip_requests
  for select
  to authenticated
  using (requester_id = auth.uid());

drop policy if exists trip_requests_owner_insert on public.trip_requests;
create policy trip_requests_owner_insert
  on public.trip_requests
  for insert
  to authenticated
  with check (requester_id = auth.uid());

drop policy if exists trip_requests_owner_update on public.trip_requests;
create policy trip_requests_owner_update
  on public.trip_requests
  for update
  to authenticated
  using (requester_id = auth.uid())
  with check (requester_id = auth.uid());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'media',
    'media',
    true,
    52428800,
    array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'video/mp4',
      'application/pdf'
    ]
  ),
  (
    'tickets',
    'tickets',
    false,
    10485760,
    array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf'
    ]
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Add tenant keys to legacy operational tables that were still missing them.
alter table public.admin_whatsapp_numbers
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.app_auth_attempts
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.otp_codes
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.promo_video_jobs
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.ride_requests
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.saved_places
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.trip_requests
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;

alter table public.biopay_abuse_reports
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_enrollment_audit
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_face_embeddings
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_match_audit
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_match_rate_limits
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_profiles
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_rate_limits
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_transactions
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;
alter table public.biopay_wallets
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict;

update public.admin_whatsapp_numbers
set organization_id = public.default_organization_id()
where organization_id is null;

update public.app_auth_attempts target
set organization_id = coalesce(
  public.profile_organization_id(target.user_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.otp_codes
set organization_id = public.default_organization_id()
where organization_id is null;

update public.promo_video_jobs
set organization_id = public.default_organization_id()
where organization_id is null;

update public.ride_requests target
set organization_id = coalesce(
  public.profile_organization_id(target.requester_id),
  public.profile_organization_id(target.responder_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.saved_places target
set organization_id = coalesce(
  public.profile_organization_id(target.user_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.trip_requests target
set organization_id = coalesce(
  (select trip.organization_id from public.trips trip where trip.id = target.trip_id),
  public.profile_organization_id(target.requester_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_abuse_reports target
set organization_id = coalesce(
  public.profile_organization_id(target.profile_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_enrollment_audit target
set organization_id = coalesce(
  public.profile_organization_id(target.profile_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_face_embeddings target
set organization_id = coalesce(
  public.profile_organization_id(target.profile_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_match_audit target
set organization_id = coalesce(
  public.profile_organization_id(target.matched_profile_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_match_rate_limits
set organization_id = public.default_organization_id()
where organization_id is null;

update public.biopay_profiles
set organization_id = public.default_organization_id()
where organization_id is null;

update public.biopay_rate_limits
set organization_id = public.default_organization_id()
where organization_id is null;

update public.biopay_wallets target
set organization_id = coalesce(
  public.profile_organization_id(target.user_id),
  public.default_organization_id()
)
where target.organization_id is null;

update public.biopay_transactions target
set organization_id = coalesce(
  wallet.organization_id,
  public.default_organization_id()
)
from public.biopay_wallets wallet
where wallet.id = target.wallet_id
  and target.organization_id is null;

update public.biopay_transactions
set organization_id = public.default_organization_id()
where organization_id is null;

-- Existing tenant columns are already backfilled; make them mandatory and
-- ensure future writes cannot silently omit organization_id.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'admin_access_attempts',
    'admin_audit_log',
    'admin_audit_logs',
    'admin_whatsapp_numbers',
    'app_auth_attempts',
    'biopay_abuse_reports',
    'biopay_enrollment_audit',
    'biopay_face_embeddings',
    'biopay_match_audit',
    'biopay_match_rate_limits',
    'biopay_profiles',
    'biopay_rate_limits',
    'biopay_transactions',
    'biopay_wallets',
    'chat_conversations',
    'chat_messages',
    'driver_locations',
    'driver_subscriptions',
    'driver_trip_entitlement_usage',
    'favorite_addresses',
    'mobility_events',
    'nfc_payment_sessions',
    'notifications',
    'otp_codes',
    'payment_events',
    'payment_intents',
    'profiles',
    'promo_video_jobs',
    'qr_payment_sessions',
    'ride_requests',
    'risk_flags',
    'saved_places',
    'sms_raw_queue',
    'transactions',
    'trip_requests',
    'trips'
  ]
  loop
    execute format(
      'update public.%I set organization_id = public.default_organization_id() where organization_id is null',
      v_table
    );
    execute format(
      'alter table public.%I alter column organization_id set default public.default_organization_id()',
      v_table
    );
    execute format(
      'alter table public.%I alter column organization_id set not null',
      v_table
    );
  end loop;
end $$;

create index if not exists idx_admin_whatsapp_numbers_organization
  on public.admin_whatsapp_numbers(organization_id, is_active);
create index if not exists idx_app_auth_attempts_organization_created
  on public.app_auth_attempts(organization_id, created_at desc);
create index if not exists idx_otp_codes_organization_created
  on public.otp_codes(organization_id, created_at desc);
create index if not exists idx_promo_video_jobs_organization_status
  on public.promo_video_jobs(organization_id, status, created_at desc);
create index if not exists idx_ride_requests_organization_status
  on public.ride_requests(organization_id, status, created_at desc);
create index if not exists idx_saved_places_organization_user
  on public.saved_places(organization_id, user_id, updated_at desc);
create index if not exists idx_trip_requests_organization_status
  on public.trip_requests(organization_id, status, created_at desc);
create index if not exists idx_biopay_wallets_organization_user
  on public.biopay_wallets(organization_id, user_id);
create index if not exists idx_biopay_transactions_organization_created
  on public.biopay_transactions(organization_id, created_at desc);

create or replace function public.enforce_ride_request_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_org uuid;
  v_responder_org uuid;
begin
  v_requester_org := public.profile_organization_id(new.requester_id);
  v_responder_org := public.profile_organization_id(new.responder_id);

  if v_requester_org is null then
    raise exception 'Requester organization is required.';
  end if;

  if v_responder_org is not null and v_responder_org <> v_requester_org then
    raise exception 'Ride request participants must belong to the same organization.';
  end if;

  if new.organization_id is not null and new.organization_id <> v_requester_org then
    raise exception 'Ride request organization does not match requester.';
  end if;

  new.organization_id := v_requester_org;
  return new;
end;
$$;

drop trigger if exists trg_ride_requests_enforce_organization on public.ride_requests;
create trigger trg_ride_requests_enforce_organization
before insert or update of requester_id, responder_id, organization_id
on public.ride_requests
for each row
execute function public.enforce_ride_request_organization();

create or replace function public.enforce_trip_request_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trip_org uuid;
  v_requester_org uuid;
begin
  select trip.organization_id
  into v_trip_org
  from public.trips trip
  where trip.id = new.trip_id;

  v_requester_org := public.profile_organization_id(new.requester_id);

  if v_trip_org is null then
    v_trip_org := coalesce(v_requester_org, public.default_organization_id());
  end if;

  if v_requester_org is not null and v_requester_org <> v_trip_org then
    raise exception 'Trip request organization does not match requester.';
  end if;

  if new.organization_id is not null and new.organization_id <> v_trip_org then
    raise exception 'Trip request organization does not match trip.';
  end if;

  new.organization_id := v_trip_org;
  return new;
end;
$$;

drop trigger if exists trg_trip_requests_enforce_organization on public.trip_requests;
create trigger trg_trip_requests_enforce_organization
before insert or update of trip_id, requester_id, organization_id
on public.trip_requests
for each row
execute function public.enforce_trip_request_organization();

create or replace function public.enforce_saved_place_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_org uuid;
begin
  v_user_org := public.profile_organization_id(new.user_id);

  if v_user_org is null then
    raise exception 'Saved place organization is required.';
  end if;

  if new.organization_id is not null and new.organization_id <> v_user_org then
    raise exception 'Saved place organization does not match user.';
  end if;

  new.organization_id := v_user_org;
  return new;
end;
$$;

drop trigger if exists trg_saved_places_enforce_organization on public.saved_places;
create trigger trg_saved_places_enforce_organization
before insert or update of user_id, organization_id
on public.saved_places
for each row
execute function public.enforce_saved_place_organization();

create or replace function public.enforce_biopay_wallet_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_org uuid;
begin
  v_user_org := public.profile_organization_id(new.user_id);

  if v_user_org is null then
    v_user_org := public.default_organization_id();
  end if;

  if new.organization_id is not null and new.organization_id <> v_user_org then
    raise exception 'BioPay wallet organization does not match user.';
  end if;

  new.organization_id := v_user_org;
  return new;
end;
$$;

drop trigger if exists trg_biopay_wallets_enforce_organization on public.biopay_wallets;
create trigger trg_biopay_wallets_enforce_organization
before insert or update of user_id, organization_id
on public.biopay_wallets
for each row
execute function public.enforce_biopay_wallet_organization();

create or replace function public.enforce_biopay_transaction_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wallet_org uuid;
begin
  select wallet.organization_id
  into v_wallet_org
  from public.biopay_wallets wallet
  where wallet.id = new.wallet_id;

  if v_wallet_org is null then
    v_wallet_org := public.default_organization_id();
  end if;

  if new.organization_id is not null and new.organization_id <> v_wallet_org then
    raise exception 'BioPay transaction organization does not match wallet.';
  end if;

  new.organization_id := v_wallet_org;
  return new;
end;
$$;

drop trigger if exists trg_biopay_transactions_enforce_organization on public.biopay_transactions;
create trigger trg_biopay_transactions_enforce_organization
before insert or update of wallet_id, organization_id
on public.biopay_transactions
for each row
execute function public.enforce_biopay_transaction_organization();

-- Replace remaining direct role checks in RLS policies.
drop policy if exists "Admin select audit logs" on public.admin_audit_logs;
create policy admin_audit_logs_select_permission
  on public.admin_audit_logs
  for select
  to authenticated
  using (public.has_platform_permission('admin.audit.read'));

drop policy if exists "Admin insert audit logs" on public.admin_audit_logs;
create policy admin_audit_logs_insert_permission
  on public.admin_audit_logs
  for insert
  to authenticated
  with check (public.has_platform_permission('admin.audit.write'));

drop policy if exists profiles_delete_admin on public.profiles;
create policy profiles_delete_admin
  on public.profiles
  for delete
  to authenticated
  using (public.has_platform_permission('admin.users.manage'));

drop policy if exists admin_read_access on public.promo_video_jobs;
create policy promo_video_jobs_admin_read
  on public.promo_video_jobs
  for select
  to authenticated
  using (public.has_platform_permission('admin.campaigns.read'));

drop policy if exists "Admin manage qr sessions" on public.qr_payment_sessions;
create policy qr_payment_sessions_admin_manage
  on public.qr_payment_sessions
  for all
  to authenticated
  using (public.has_platform_permission('admin.finance.review'))
  with check (public.has_platform_permission('admin.finance.review'));

drop policy if exists "Admin manage risk flags" on public.risk_flags;
create policy risk_flags_admin_manage
  on public.risk_flags
  for all
  to authenticated
  using (public.has_platform_permission('admin.finance.review'))
  with check (public.has_platform_permission('admin.finance.review'));

drop policy if exists trips_update_admin on public.trips;
create policy trips_update_admin
  on public.trips
  for update
  to authenticated
  using (public.has_platform_permission('admin.trips.manage'))
  with check (public.has_platform_permission('admin.trips.manage'));

drop policy if exists trips_delete_admin on public.trips;
create policy trips_delete_admin
  on public.trips
  for delete
  to authenticated
  using (public.has_platform_permission('admin.trips.manage'));

drop policy if exists vehicle_types_admin_insert on public.vehicle_types;
create policy vehicle_types_admin_insert
  on public.vehicle_types
  for insert
  to authenticated
  with check (public.has_platform_permission('platform.config.manage'));

drop policy if exists vehicle_types_admin_update on public.vehicle_types;
create policy vehicle_types_admin_update
  on public.vehicle_types
  for update
  to authenticated
  using (public.has_platform_permission('platform.config.manage'))
  with check (public.has_platform_permission('platform.config.manage'));

drop policy if exists vehicle_types_admin_delete on public.vehicle_types;
create policy vehicle_types_admin_delete
  on public.vehicle_types
  for delete
  to authenticated
  using (public.has_platform_permission('platform.config.manage'));

drop policy if exists vehicle_type_countries_admin_insert on public.vehicle_type_countries;
create policy vehicle_type_countries_admin_insert
  on public.vehicle_type_countries
  for insert
  to authenticated
  with check (public.has_platform_permission('platform.config.manage'));

drop policy if exists vehicle_type_countries_admin_delete on public.vehicle_type_countries;
create policy vehicle_type_countries_admin_delete
  on public.vehicle_type_countries
  for delete
  to authenticated
  using (public.has_platform_permission('platform.config.manage'));

-- Campaign approval and consent primitives.
create table if not exists public.notification_consents (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid not null default public.default_organization_id() references public.organizations(id) on delete restrict,
  consent_type text not null,
  channel text not null default 'in_app',
  status text not null default 'unknown',
  source text not null default 'app',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (profile_id, consent_type, channel),
  constraint notification_consents_type_check check (
    consent_type in ('promotional', 'operational', 'product_updates')
  ),
  constraint notification_consents_channel_check check (
    channel in ('in_app', 'push', 'whatsapp', 'sms', 'email')
  ),
  constraint notification_consents_status_check check (
    status in ('granted', 'denied', 'unknown', 'revoked')
  )
);

create table if not exists public.campaign_approvals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.default_organization_id() references public.organizations(id) on delete restrict,
  campaign_type text not null,
  title text not null,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'pending_approval',
  requested_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid references public.profiles(id) on delete restrict,
  approval_notes text,
  requested_at timestamptz not null default timezone('utc', now()),
  approved_at timestamptz,
  sent_by uuid references public.profiles(id) on delete restrict,
  sent_at timestamptz,
  recipient_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint campaign_approvals_type_check check (
    campaign_type in ('promo', 'system_announcement')
  ),
  constraint campaign_approvals_status_check check (
    status in ('pending_approval', 'approved', 'rejected', 'sent', 'cancelled')
  ),
  constraint campaign_approvals_recipient_count_check check (recipient_count >= 0)
);

alter table public.notification_consents enable row level security;
alter table public.campaign_approvals enable row level security;

create index if not exists idx_notification_consents_org_status
  on public.notification_consents(organization_id, consent_type, channel, status);
create index if not exists idx_campaign_approvals_org_status
  on public.campaign_approvals(organization_id, status, requested_at desc);

drop policy if exists notification_consents_select_own_or_admin on public.notification_consents;
create policy notification_consents_select_own_or_admin
  on public.notification_consents
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.has_platform_permission('admin.campaigns.read')
  );

drop policy if exists notification_consents_insert_own on public.notification_consents;
create policy notification_consents_insert_own
  on public.notification_consents
  for insert
  to authenticated
  with check (
    profile_id = auth.uid()
    and organization_id = public.profile_organization_id(auth.uid())
  );

drop policy if exists notification_consents_update_own on public.notification_consents;
create policy notification_consents_update_own
  on public.notification_consents
  for update
  to authenticated
  using (profile_id = auth.uid())
  with check (
    profile_id = auth.uid()
    and organization_id = public.profile_organization_id(auth.uid())
  );

drop policy if exists notification_consents_admin_manage on public.notification_consents;
create policy notification_consents_admin_manage
  on public.notification_consents
  for all
  to authenticated
  using (public.has_platform_permission('admin.campaigns.read'))
  with check (public.has_platform_permission('admin.campaigns.read'));

drop policy if exists campaign_approvals_admin_read on public.campaign_approvals;
create policy campaign_approvals_admin_read
  on public.campaign_approvals
  for select
  to authenticated
  using (
    public.has_platform_permission('admin.campaigns.read')
    or public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  );

drop policy if exists campaign_approvals_admin_manage on public.campaign_approvals;
create policy campaign_approvals_admin_manage
  on public.campaign_approvals
  for all
  to authenticated
  using (
    public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  )
  with check (
    public.has_platform_permission('admin.broadcasts.send')
    or public.has_platform_permission('admin.broadcasts.approve')
  );

grant select, insert, update, delete on public.notification_consents to authenticated;
grant select on public.campaign_approvals to authenticated;
grant all on public.notification_consents to service_role;
grant all on public.campaign_approvals to service_role;

create or replace function public.enforce_notification_consent_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_org uuid;
begin
  v_profile_org := public.profile_organization_id(new.profile_id);

  if v_profile_org is null then
    raise exception 'Notification consent organization is required.';
  end if;

  if new.organization_id is not null and new.organization_id <> v_profile_org then
    raise exception 'Notification consent organization does not match profile.';
  end if;

  new.organization_id := v_profile_org;
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_notification_consents_enforce_organization on public.notification_consents;
create trigger trg_notification_consents_enforce_organization
before insert or update of profile_id, organization_id, status, metadata
on public.notification_consents
for each row
execute function public.enforce_notification_consent_organization();

create or replace function public.rpc_admin_request_campaign_approval(
  p_campaign_type text,
  p_title text,
  p_body text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign_type text := lower(trim(coalesce(p_campaign_type, '')));
  v_title text := trim(coalesce(p_title, ''));
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_organization_id uuid := public.profile_organization_id(auth.uid());
  v_campaign_id uuid;
begin
  if not public.has_platform_permission('admin.broadcasts.send') then
    raise exception 'Unauthorized: admin.broadcasts.send permission required';
  end if;

  if v_campaign_type not in ('promo', 'system_announcement') then
    raise exception 'Unsupported campaign type.';
  end if;

  if v_campaign_type = 'promo' and not public.has_platform_permission('admin.broadcasts.approve') then
    -- Senders may request promo approval; approval is enforced separately.
    null;
  end if;

  if length(v_title) < 3 or length(v_title) > 120 then
    raise exception 'Campaign title must be between 3 and 120 characters.';
  end if;

  if v_body is not null and length(v_body) > 1000 then
    raise exception 'Campaign body must be 1000 characters or fewer.';
  end if;

  if jsonb_typeof(v_metadata) is distinct from 'object' then
    raise exception 'Campaign metadata must be a JSON object.';
  end if;

  v_organization_id := coalesce(v_organization_id, public.default_organization_id());

  insert into public.campaign_approvals (
    organization_id,
    campaign_type,
    title,
    body,
    metadata,
    status,
    requested_by
  )
  values (
    v_organization_id,
    v_campaign_type,
    v_title,
    v_body,
    v_metadata,
    'pending_approval',
    auth.uid()
  )
  returning id into v_campaign_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    organization_id,
    details
  )
  values (
    auth.uid(),
    'campaign_approval_requested',
    'campaign_approval',
    v_campaign_id,
    v_organization_id,
    jsonb_build_object(
      'campaign_type', v_campaign_type,
      'source', 'rpc_admin_request_campaign_approval'
    )
  );

  return v_campaign_id;
end;
$$;

create or replace function public.rpc_admin_approve_campaign(
  p_campaign_id uuid,
  p_approved boolean,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.campaign_approvals%rowtype;
  v_status text;
begin
  if not public.has_platform_permission('admin.broadcasts.approve') then
    raise exception 'Unauthorized: admin.broadcasts.approve permission required';
  end if;

  select *
  into v_campaign
  from public.campaign_approvals
  where id = p_campaign_id
  for update;

  if v_campaign.id is null then
    raise exception 'Campaign approval request not found.';
  end if;

  if v_campaign.status <> 'pending_approval' then
    raise exception 'Campaign is not pending approval.';
  end if;

  v_status := case when coalesce(p_approved, false) then 'approved' else 'rejected' end;

  update public.campaign_approvals
  set
    status = v_status,
    approved_by = auth.uid(),
    approval_notes = nullif(trim(coalesce(p_notes, '')), ''),
    approved_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_campaign_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    organization_id,
    details
  )
  values (
    auth.uid(),
    'campaign_approval_' || v_status,
    'campaign_approval',
    p_campaign_id,
    v_campaign.organization_id,
    jsonb_build_object(
      'campaign_type', v_campaign.campaign_type,
      'source', 'rpc_admin_approve_campaign'
    )
  );

  return p_campaign_id;
end;
$$;

create or replace function public.rpc_admin_send_approved_campaign(
  p_campaign_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.campaign_approvals%rowtype;
  v_inserted integer;
begin
  if not public.has_platform_permission('admin.broadcasts.send') then
    raise exception 'Unauthorized: admin.broadcasts.send permission required';
  end if;

  select *
  into v_campaign
  from public.campaign_approvals
  where id = p_campaign_id
  for update;

  if v_campaign.id is null then
    raise exception 'Campaign approval request not found.';
  end if;

  if v_campaign.status <> 'approved' then
    raise exception 'Campaign must be approved before sending.';
  end if;

  if v_campaign.campaign_type = 'promo' then
    with recipients as (
      select p.id
      from public.profiles p
      where p.organization_id = v_campaign.organization_id
        and exists (
          select 1
          from public.notification_consents consent
          where consent.profile_id = p.id
            and consent.organization_id = p.organization_id
            and consent.consent_type = 'promotional'
            and consent.channel in ('in_app', 'push')
            and consent.status = 'granted'
        )
    )
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata
    )
    select
      recipients.id,
      v_campaign.organization_id,
      'promo',
      v_campaign.title,
      v_campaign.body,
      v_campaign.metadata || jsonb_build_object(
        'source', 'approved_admin_promo',
        'campaign_id', v_campaign.id::text,
        'sent_by', auth.uid()::text,
        'sent_at', timezone('utc', now())::text
      )
    from recipients;
  else
    insert into public.notifications (
      user_id,
      organization_id,
      type,
      title,
      body,
      metadata
    )
    select
      p.id,
      v_campaign.organization_id,
      'system_announcement',
      v_campaign.title,
      v_campaign.body,
      v_campaign.metadata || jsonb_build_object(
        'source', 'approved_admin_announcement',
        'campaign_id', v_campaign.id::text,
        'sent_by', auth.uid()::text,
        'sent_at', timezone('utc', now())::text
      )
    from public.profiles p
    where p.organization_id = v_campaign.organization_id;
  end if;

  get diagnostics v_inserted = row_count;

  update public.campaign_approvals
  set
    status = 'sent',
    sent_by = auth.uid(),
    sent_at = timezone('utc', now()),
    recipient_count = v_inserted,
    updated_at = timezone('utc', now())
  where id = p_campaign_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    organization_id,
    details
  )
  values (
    auth.uid(),
    'campaign_sent',
    'campaign_approval',
    p_campaign_id,
    v_campaign.organization_id,
    jsonb_build_object(
      'campaign_type', v_campaign.campaign_type,
      'recipient_count', v_inserted,
      'source', 'rpc_admin_send_approved_campaign'
    )
  );

  return v_inserted;
end;
$$;

create or replace function public.rpc_admin_send_promo(
  p_title text,
  p_body text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_campaign_id uuid;
begin
  if jsonb_typeof(v_metadata) is distinct from 'object' then
    raise exception 'Promo metadata must be a JSON object.';
  end if;

  v_campaign_id := nullif(trim(coalesce(v_metadata ->> 'campaign_id', '')), '')::uuid;

  if v_campaign_id is null then
    perform public.rpc_admin_request_campaign_approval('promo', p_title, p_body, v_metadata);
    return 0;
  end if;

  return public.rpc_admin_send_approved_campaign(v_campaign_id);
end;
$$;

create or replace function public.rpc_admin_send_announcement(
  p_title text,
  p_body text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_organization_id uuid := coalesce(public.profile_organization_id(auth.uid()), public.default_organization_id());
  v_campaign_id uuid;
  v_inserted integer;
begin
  if not public.has_platform_permission('admin.broadcasts.send') then
    raise exception 'Unauthorized: admin.broadcasts.send permission required';
  end if;

  if length(v_title) < 3 or length(v_title) > 120 then
    raise exception 'Announcement title must be between 3 and 120 characters.';
  end if;

  if v_body is not null and length(v_body) > 1000 then
    raise exception 'Announcement body must be 1000 characters or fewer.';
  end if;

  if jsonb_typeof(v_metadata) is distinct from 'object' then
    raise exception 'Announcement metadata must be a JSON object.';
  end if;

  insert into public.campaign_approvals (
    organization_id,
    campaign_type,
    title,
    body,
    metadata,
    status,
    requested_by,
    approved_by,
    approved_at
  )
  values (
    v_organization_id,
    'system_announcement',
    v_title,
    v_body,
    v_metadata,
    'approved',
    auth.uid(),
    auth.uid(),
    timezone('utc', now())
  )
  returning id into v_campaign_id;

  insert into public.notifications (
    user_id,
    organization_id,
    type,
    title,
    body,
    metadata
  )
  select
    p.id,
    v_organization_id,
    'system_announcement',
    v_title,
    v_body,
    v_metadata || jsonb_build_object(
      'source', 'admin_announcement',
      'campaign_id', v_campaign_id::text,
      'sent_by', auth.uid()::text,
      'sent_at', timezone('utc', now())::text
    )
  from public.profiles p
  where p.organization_id = v_organization_id;

  get diagnostics v_inserted = row_count;

  update public.campaign_approvals
  set
    status = 'sent',
    sent_by = auth.uid(),
    sent_at = timezone('utc', now()),
    recipient_count = v_inserted,
    updated_at = timezone('utc', now())
  where id = v_campaign_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    organization_id,
    details
  )
  values (
    auth.uid(),
    'announcement_sent',
    'campaign_approval',
    v_campaign_id,
    v_organization_id,
    jsonb_build_object(
      'recipient_count', v_inserted,
      'source', 'rpc_admin_send_announcement'
    )
  );

  return v_inserted;
end;
$$;

revoke all on function public.rpc_admin_request_campaign_approval(text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_admin_approve_campaign(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.rpc_admin_send_approved_campaign(uuid) from public, anon, authenticated;
revoke all on function public.rpc_admin_send_promo(text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_admin_send_announcement(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.rpc_admin_request_campaign_approval(text, text, text, jsonb) to authenticated;
grant execute on function public.rpc_admin_approve_campaign(uuid, boolean, text) to authenticated;
grant execute on function public.rpc_admin_send_approved_campaign(uuid) to authenticated;
grant execute on function public.rpc_admin_send_promo(text, text, jsonb) to authenticated;
grant execute on function public.rpc_admin_send_announcement(text, text, jsonb) to authenticated;

-- Legacy in-app BioPay transfer RPCs stay disabled. Parameter references keep
-- the Postgres linter from reporting unused-argument warnings.
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
  perform p_amount, p_currency, p_note;
  raise exception 'In-app BioPay QR payments are disabled. Use external USSD/manual payment instructions only.';
end;
$$;

create or replace function public.fn_biopay_resolve_qr_payload(p_qr_ref text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform p_qr_ref;
  raise exception 'In-app BioPay QR resolution is disabled. Use external USSD/manual payment instructions only.';
end;
$$;

create or replace function public.fn_biopay_scan_and_charge(p_qr_ref text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform p_qr_ref;
  raise exception 'In-app BioPay charging is disabled. Use external USSD/manual payment instructions only.';
end;
$$;

revoke all on function public.fn_biopay_generate_qr(numeric, text, text) from public, anon, authenticated;
revoke all on function public.fn_biopay_resolve_qr_payload(text) from public, anon, authenticated;
revoke all on function public.fn_biopay_scan_and_charge(text) from public, anon, authenticated;

-- Canonical storage policies. Drop legacy JWT-role policies and recreate
-- least-privilege object access by bucket.
drop policy if exists storage_avatars_admin_write on storage.objects;
drop policy if exists storage_avatars_owner_delete on storage.objects;
drop policy if exists storage_avatars_owner_update on storage.objects;
drop policy if exists storage_avatars_owner_write on storage.objects;
drop policy if exists storage_avatars_public_read on storage.objects;
drop policy if exists storage_media_admin_delete on storage.objects;
drop policy if exists storage_media_admin_update on storage.objects;
drop policy if exists storage_media_admin_write on storage.objects;
drop policy if exists storage_media_public_read on storage.objects;
drop policy if exists storage_service_role_all on storage.objects;
drop policy if exists storage_tickets_owner_delete on storage.objects;
drop policy if exists storage_tickets_owner_select on storage.objects;
drop policy if exists storage_tickets_owner_update on storage.objects;
drop policy if exists storage_tickets_owner_write on storage.objects;

drop policy if exists avatars_select_public on storage.objects;
create policy avatars_select_public
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists media_public_read on storage.objects;
create policy media_public_read
  on storage.objects
  for select
  to public
  using (bucket_id = 'media');

drop policy if exists media_admin_insert on storage.objects;
create policy media_admin_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'media'
    and public.has_platform_permission('storage.media.manage')
  );

drop policy if exists media_admin_update on storage.objects;
create policy media_admin_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'media'
    and public.has_platform_permission('storage.media.manage')
  )
  with check (
    bucket_id = 'media'
    and public.has_platform_permission('storage.media.manage')
  );

drop policy if exists media_admin_delete on storage.objects;
create policy media_admin_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'media'
    and public.has_platform_permission('storage.media.manage')
  );

drop policy if exists promo_media_public_read on storage.objects;
create policy promo_media_public_read
  on storage.objects
  for select
  to public
  using (bucket_id = 'promo-media');

drop policy if exists promo_media_service_role_write on storage.objects;
create policy promo_media_service_role_write
  on storage.objects
  for all
  to service_role
  using (bucket_id = 'promo-media')
  with check (bucket_id = 'promo-media');

drop policy if exists tickets_owner_select on storage.objects;
create policy tickets_owner_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'tickets'
    and owner = auth.uid()
  );

drop policy if exists tickets_owner_insert on storage.objects;
create policy tickets_owner_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'tickets'
    and owner = auth.uid()
  );

drop policy if exists tickets_owner_update on storage.objects;
create policy tickets_owner_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'tickets'
    and owner = auth.uid()
  )
  with check (
    bucket_id = 'tickets'
    and owner = auth.uid()
  );

drop policy if exists tickets_owner_delete on storage.objects;
create policy tickets_owner_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'tickets'
    and owner = auth.uid()
  );

update storage.buckets
set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
where id = 'tickets';

-- Guard realtime against accidental publication of sensitive tables. Existing
-- app channels for chat, ride requests, driver locations, and user ledger are
-- preserved.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'admin_access_attempts',
    'admin_audit_log',
    'admin_audit_logs',
    'app_auth_attempts',
    'campaign_approvals',
    'notification_consents',
    'otp_codes',
    'payment_events',
    'payment_intents',
    'profiles',
    'qr_payment_sessions',
    'nfc_payment_sessions',
    'risk_flags',
    'sms_raw_queue'
  ]
  loop
    if exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format('alter publication supabase_realtime drop table public.%I', v_table);
    end if;
  end loop;
end $$;

comment on table public.notification_consents
  is 'Per-profile consent records for promotional and operational messaging; promo sends require granted consent.';
comment on table public.campaign_approvals
  is 'Auditable approval workflow for outbound campaigns and admin broadcasts.';

commit;
