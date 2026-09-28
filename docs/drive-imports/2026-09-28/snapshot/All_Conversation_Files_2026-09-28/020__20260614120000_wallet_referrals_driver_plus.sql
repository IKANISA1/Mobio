begin;

-- Wallet, referrals, and Mobio Plus access are server-owned. Clients can read
-- their own records and call RPCs, but cannot mutate balances or subscriptions.

create table if not exists public.token_wallets (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  balance_tokens bigint not null default 0 check (balance_tokens >= 0),
  lifetime_earned_tokens bigint not null default 0 check (lifetime_earned_tokens >= 0),
  lifetime_sent_tokens bigint not null default 0 check (lifetime_sent_tokens >= 0),
  lifetime_received_tokens bigint not null default 0 check (lifetime_received_tokens >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.token_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  counterparty_profile_id uuid references public.profiles(id) on delete set null,
  direction text not null check (direction in ('credit', 'debit')),
  amount_tokens bigint not null check (amount_tokens > 0),
  reason text not null check (
    reason in (
      'referral_reward',
      'wallet_transfer',
      'subscription_payment',
      'admin_adjustment'
    )
  ),
  reference_type text,
  reference_id uuid,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_transfers (
  id uuid primary key default gen_random_uuid(),
  sender_profile_id uuid not null references public.profiles(id) on delete cascade,
  receiver_profile_id uuid not null references public.profiles(id) on delete cascade,
  amount_tokens bigint not null check (amount_tokens > 0),
  status text not null default 'completed' check (status in ('completed', 'reversed')),
  idempotency_key text not null,
  note text,
  created_at timestamptz not null default now(),
  unique (sender_profile_id, idempotency_key),
  check (sender_profile_id <> receiver_profile_id)
);

create table if not exists public.app_referral_codes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  code text not null unique,
  share_url text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id)
);

create table if not exists public.app_referral_events (
  id uuid primary key default gen_random_uuid(),
  referral_code_id uuid not null references public.app_referral_codes(id) on delete cascade,
  inviter_profile_id uuid not null references public.profiles(id) on delete cascade,
  invitee_profile_id uuid references public.profiles(id) on delete set null,
  status text not null default 'opened'
    check (status in ('opened', 'installed', 'signed_up', 'qualified', 'rewarded', 'rejected')),
  install_id text,
  device_hash text,
  platform text,
  reward_tokens bigint not null default 0 check (reward_tokens >= 0),
  reward_ledger_entry_id uuid references public.token_ledger_entries(id) on delete set null,
  rejected_reason text,
  metadata jsonb not null default '{}'::jsonb,
  opened_at timestamptz not null default now(),
  installed_at timestamptz,
  signed_up_at timestamptz,
  rewarded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (invitee_profile_id is null or invitee_profile_id <> inviter_profile_id)
);

create unique index if not exists uq_referral_reward_once
  on public.app_referral_events(inviter_profile_id, invitee_profile_id)
  where status = 'rewarded' and invitee_profile_id is not null;

create unique index if not exists uq_referral_reward_install_once
  on public.app_referral_events(lower(install_id))
  where status = 'rewarded' and install_id is not null and install_id <> '';

create unique index if not exists uq_referral_reward_device_once
  on public.app_referral_events(lower(device_hash))
  where status = 'rewarded' and device_hash is not null and device_hash <> '';

create table if not exists public.driver_plus_rules (
  vehicle_type_id text primary key references public.vehicle_types(id) on delete cascade,
  requires_plus boolean not null default true,
  free_trial_days integer not null default 0 check (free_trial_days >= 0),
  free_daily_request_limit integer not null default 0 check (free_daily_request_limit >= 0),
  free_total_request_limit integer not null default 0 check (free_total_request_limit >= 0),
  is_free_forever boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.driver_request_entitlement_usage (
  id uuid primary key default gen_random_uuid(),
  driver_profile_id uuid not null references public.profiles(id) on delete cascade,
  passenger_profile_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid references public.chat_conversations(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  vehicle_type_id text not null references public.vehicle_types(id) on delete restrict,
  request_date date not null default timezone('utc', now())::date,
  allowed boolean not null default false,
  allowance_source text not null default 'blocked'
    check (allowance_source in ('plus', 'free_trial', 'bus_free', 'blocked')),
  channel text not null default 'in_app_chat'
    check (channel in ('in_app_chat', 'whatsapp')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (driver_profile_id <> passenger_profile_id)
);

create unique index if not exists uq_driver_request_usage_conversation
  on public.driver_request_entitlement_usage(conversation_id)
  where conversation_id is not null;

create index if not exists idx_driver_request_usage_driver_date
  on public.driver_request_entitlement_usage(driver_profile_id, vehicle_type_id, request_date);

create table if not exists public.driver_subscription_payment_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  vehicle_type_id text not null references public.vehicle_types(id) on delete restrict,
  payment_method text not null check (payment_method in ('tokens', 'momo_ussd')),
  amount_tokens bigint not null check (amount_tokens > 0),
  amount_rwf bigint not null check (amount_rwf > 0),
  currency text not null default 'RWF' check (currency = 'RWF'),
  reference_code text not null unique,
  momo_pay_code text not null default '12345',
  ussd_code text,
  status text not null default 'pending'
    check (status in ('pending', 'dialer_opened', 'confirmed', 'expired', 'cancelled', 'failed')),
  provider_transaction_ref text,
  confirmation_source text,
  metadata jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_driver_subscription_payment_requests_profile_status
  on public.driver_subscription_payment_requests(profile_id, status, created_at desc);

create table if not exists public.driver_subscription_momo_sms_receipts (
  id uuid primary key default gen_random_uuid(),
  raw_sms text not null,
  sms_hash text not null unique,
  sender text,
  received_at timestamptz not null default now(),
  amount_rwf bigint check (amount_rwf is null or amount_rwf > 0),
  momo_pay_code text not null default '12345',
  reference_code text,
  payer_phone text,
  payer_name text,
  provider_transaction_ref text,
  matched_payment_request_id uuid references public.driver_subscription_payment_requests(id) on delete set null,
  status text not null default 'received'
    check (status in ('received', 'matched', 'duplicate', 'ambiguous', 'unmatched', 'ignored', 'failed')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_driver_subscription_momo_sms_provider_ref
  on public.driver_subscription_momo_sms_receipts(provider_transaction_ref)
  where provider_transaction_ref is not null and provider_transaction_ref <> '';

create index if not exists idx_driver_subscription_momo_sms_receipts_status
  on public.driver_subscription_momo_sms_receipts(status, received_at desc);

drop trigger if exists set_token_wallets_updated_at on public.token_wallets;
create trigger set_token_wallets_updated_at
before update on public.token_wallets
for each row execute function public.handle_updated_at();

drop trigger if exists set_app_referral_codes_updated_at on public.app_referral_codes;
create trigger set_app_referral_codes_updated_at
before update on public.app_referral_codes
for each row execute function public.handle_updated_at();

drop trigger if exists set_app_referral_events_updated_at on public.app_referral_events;
create trigger set_app_referral_events_updated_at
before update on public.app_referral_events
for each row execute function public.handle_updated_at();

drop trigger if exists set_driver_plus_rules_updated_at on public.driver_plus_rules;
create trigger set_driver_plus_rules_updated_at
before update on public.driver_plus_rules
for each row execute function public.handle_updated_at();

drop trigger if exists set_driver_subscription_payment_requests_updated_at
  on public.driver_subscription_payment_requests;
create trigger set_driver_subscription_payment_requests_updated_at
before update on public.driver_subscription_payment_requests
for each row execute function public.handle_updated_at();

drop trigger if exists set_driver_subscription_momo_sms_receipts_updated_at
  on public.driver_subscription_momo_sms_receipts;
create trigger set_driver_subscription_momo_sms_receipts_updated_at
before update on public.driver_subscription_momo_sms_receipts
for each row execute function public.handle_updated_at();

alter table public.token_wallets enable row level security;
alter table public.token_ledger_entries enable row level security;
alter table public.wallet_transfers enable row level security;
alter table public.app_referral_codes enable row level security;
alter table public.app_referral_events enable row level security;
alter table public.driver_plus_rules enable row level security;
alter table public.driver_request_entitlement_usage enable row level security;
alter table public.driver_subscription_payment_requests enable row level security;
alter table public.driver_subscription_momo_sms_receipts enable row level security;

drop policy if exists token_wallets_owner_read on public.token_wallets;
create policy token_wallets_owner_read
  on public.token_wallets
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists token_ledger_entries_owner_read on public.token_ledger_entries;
create policy token_ledger_entries_owner_read
  on public.token_ledger_entries
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists wallet_transfers_participant_read on public.wallet_transfers;
create policy wallet_transfers_participant_read
  on public.wallet_transfers
  for select
  to authenticated
  using (
    auth.uid() in (sender_profile_id, receiver_profile_id)
    or public.is_platform_admin()
  );

drop policy if exists app_referral_codes_owner_read on public.app_referral_codes;
create policy app_referral_codes_owner_read
  on public.app_referral_codes
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists app_referral_events_participant_read on public.app_referral_events;
create policy app_referral_events_participant_read
  on public.app_referral_events
  for select
  to authenticated
  using (
    auth.uid() in (inviter_profile_id, invitee_profile_id)
    or public.is_platform_admin()
  );

drop policy if exists driver_plus_rules_read on public.driver_plus_rules;
create policy driver_plus_rules_read
  on public.driver_plus_rules
  for select
  to authenticated
  using (is_active = true or public.is_platform_admin());

drop policy if exists driver_plus_rules_admin_write on public.driver_plus_rules;
create policy driver_plus_rules_admin_write
  on public.driver_plus_rules
  for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

drop policy if exists driver_request_entitlement_usage_owner_read on public.driver_request_entitlement_usage;
create policy driver_request_entitlement_usage_owner_read
  on public.driver_request_entitlement_usage
  for select
  to authenticated
  using (
    auth.uid() in (driver_profile_id, passenger_profile_id)
    or public.is_platform_admin()
  );

drop policy if exists driver_subscription_payment_requests_owner_read
  on public.driver_subscription_payment_requests;
create policy driver_subscription_payment_requests_owner_read
  on public.driver_subscription_payment_requests
  for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists driver_subscription_momo_sms_receipts_admin_read
  on public.driver_subscription_momo_sms_receipts;
create policy driver_subscription_momo_sms_receipts_admin_read
  on public.driver_subscription_momo_sms_receipts
  for select
  to authenticated
  using (public.is_platform_admin());

revoke insert, update, delete on public.token_wallets from anon, authenticated;
revoke insert, update, delete on public.token_ledger_entries from anon, authenticated;
revoke insert, update, delete on public.wallet_transfers from anon, authenticated;
revoke insert, update, delete on public.app_referral_codes from anon, authenticated;
revoke insert, update, delete on public.app_referral_events from anon, authenticated;
revoke insert, update, delete on public.driver_request_entitlement_usage from anon, authenticated;
revoke insert, update, delete on public.driver_subscription_payment_requests from anon, authenticated;
revoke insert, update, delete on public.driver_subscription_momo_sms_receipts from anon, authenticated;

grant select on public.token_wallets to authenticated;
grant select on public.token_ledger_entries to authenticated;
grant select on public.wallet_transfers to authenticated;
grant select on public.app_referral_codes to authenticated;
grant select on public.app_referral_events to authenticated;
grant select on public.driver_plus_rules to authenticated;
grant select on public.driver_request_entitlement_usage to authenticated;
grant select on public.driver_subscription_payment_requests to authenticated;
grant select on public.driver_subscription_momo_sms_receipts to authenticated;

insert into public.driver_plus_rules (
  vehicle_type_id,
  requires_plus,
  free_trial_days,
  free_daily_request_limit,
  free_total_request_limit,
  is_free_forever,
  is_active
)
values
  ('moto', true, 30, 1, 30, false, true),
  ('cab', true, 30, 1, 30, false, true),
  ('trike', true, 30, 1, 30, false, true),
  ('truck', true, 30, 1, 30, false, true),
  ('private', true, 0, 0, 0, false, true),
  ('bus', false, 0, 0, 0, true, true)
on conflict (vehicle_type_id) do update
set
  requires_plus = excluded.requires_plus,
  free_trial_days = excluded.free_trial_days,
  free_daily_request_limit = excluded.free_daily_request_limit,
  free_total_request_limit = excluded.free_total_request_limit,
  is_free_forever = excluded.is_free_forever,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.subscription_plans (
  vehicle_type_id,
  country_id,
  interval_days,
  price,
  currency,
  is_active,
  tier,
  name,
  description,
  features
)
values
  ('moto', 'RW', 1, 300, 'RWF', true, 'plus', 'Mobio Plus Daily', 'Moto Taxi daily Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('moto', 'RW', 30, 5000, 'RWF', true, 'plus', 'Mobio Plus Monthly', 'Moto Taxi monthly Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('cab', 'RW', 1, 1000, 'RWF', true, 'plus', 'Mobio Plus Daily', 'Cab daily Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('cab', 'RW', 30, 15000, 'RWF', true, 'plus', 'Mobio Plus Monthly', 'Cab monthly Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('truck', 'RW', 1, 1000, 'RWF', true, 'plus', 'Mobio Plus Daily', 'Truck daily Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('truck', 'RW', 30, 15000, 'RWF', true, 'plus', 'Mobio Plus Monthly', 'Truck monthly Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('trike', 'RW', 1, 1000, 'RWF', true, 'plus', 'Mobio Plus Daily', 'Trike daily Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('trike', 'RW', 30, 15000, 'RWF', true, 'plus', 'Mobio Plus Monthly', 'Trike monthly Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('private', 'RW', 1, 5000, 'RWF', true, 'plus', 'Mobio Plus Daily', 'Private vehicle daily Mobio Plus access', '{"requests":"plus"}'::jsonb),
  ('private', 'RW', 30, 30000, 'RWF', true, 'plus', 'Mobio Plus Monthly', 'Private vehicle monthly Mobio Plus access', '{"requests":"plus"}'::jsonb)
on conflict on constraint subscription_plans_unique_scope do update
set
  price = excluded.price,
  currency = excluded.currency,
  is_active = excluded.is_active,
  tier = excluded.tier,
  name = excluded.name,
  description = excluded.description,
  features = excluded.features,
  updated_at = now();

create or replace function public._mobio_is_service_role()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    ''
  ) = 'service_role';
$$;

create or replace function public._ensure_token_wallet(p_profile_id uuid)
returns public.token_wallets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wallet public.token_wallets%rowtype;
begin
  insert into public.token_wallets(profile_id)
  values (p_profile_id)
  on conflict (profile_id) do nothing;

  select *
  into v_wallet
  from public.token_wallets
  where profile_id = p_profile_id
  for update;

  return v_wallet;
end;
$$;

create or replace function public._credit_tokens(
  p_profile_id uuid,
  p_amount_tokens bigint,
  p_reason text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_counterparty_profile_id uuid default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_id uuid;
begin
  if p_amount_tokens <= 0 then
    raise exception using message = 'INVALID_TOKEN_AMOUNT';
  end if;

  perform public._ensure_token_wallet(p_profile_id);

  update public.token_wallets
  set
    balance_tokens = balance_tokens + p_amount_tokens,
    lifetime_earned_tokens = lifetime_earned_tokens + p_amount_tokens,
    lifetime_received_tokens = lifetime_received_tokens + p_amount_tokens,
    updated_at = now()
  where profile_id = p_profile_id;

  insert into public.token_ledger_entries (
    profile_id,
    counterparty_profile_id,
    direction,
    amount_tokens,
    reason,
    reference_type,
    reference_id,
    note,
    metadata
  )
  values (
    p_profile_id,
    p_counterparty_profile_id,
    'credit',
    p_amount_tokens,
    p_reason,
    p_reference_type,
    p_reference_id,
    p_note,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_ledger_id;

  return v_ledger_id;
end;
$$;

create or replace function public._debit_tokens(
  p_profile_id uuid,
  p_amount_tokens bigint,
  p_reason text,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_counterparty_profile_id uuid default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_id uuid;
  v_balance bigint;
begin
  if p_amount_tokens <= 0 then
    raise exception using message = 'INVALID_TOKEN_AMOUNT';
  end if;

  perform public._ensure_token_wallet(p_profile_id);

  select balance_tokens
  into v_balance
  from public.token_wallets
  where profile_id = p_profile_id
  for update;

  if v_balance < p_amount_tokens then
    raise exception using
      message = 'INSUFFICIENT_TOKENS',
      detail = 'Token balance is lower than the requested amount.';
  end if;

  update public.token_wallets
  set
    balance_tokens = balance_tokens - p_amount_tokens,
    lifetime_sent_tokens = lifetime_sent_tokens + p_amount_tokens,
    updated_at = now()
  where profile_id = p_profile_id;

  insert into public.token_ledger_entries (
    profile_id,
    counterparty_profile_id,
    direction,
    amount_tokens,
    reason,
    reference_type,
    reference_id,
    note,
    metadata
  )
  values (
    p_profile_id,
    p_counterparty_profile_id,
    'debit',
    p_amount_tokens,
    p_reason,
    p_reference_type,
    p_reference_id,
    p_note,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_ledger_id;

  return v_ledger_id;
end;
$$;

create or replace function public.rpc_get_wallet_summary()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_wallet public.token_wallets%rowtype;
  v_referral_code public.app_referral_codes%rowtype;
  v_successful_referrals integer := 0;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  v_wallet := public._ensure_token_wallet(v_user_id);

  select *
  into v_referral_code
  from public.app_referral_codes
  where profile_id = v_user_id
  limit 1;

  select count(*)::integer
  into v_successful_referrals
  from public.app_referral_events
  where inviter_profile_id = v_user_id
    and status = 'rewarded';

  return json_build_object(
    'profile_id', v_user_id,
    'balance_tokens', v_wallet.balance_tokens,
    'rwf_equivalent', v_wallet.balance_tokens,
    'lifetime_earned_tokens', v_wallet.lifetime_earned_tokens,
    'lifetime_sent_tokens', v_wallet.lifetime_sent_tokens,
    'lifetime_received_tokens', v_wallet.lifetime_received_tokens,
    'successful_referrals', v_successful_referrals,
    'referral_code', v_referral_code.code,
    'share_url', v_referral_code.share_url
  );
end;
$$;

create or replace function public.rpc_list_token_ledger(p_limit integer default 50)
returns setof public.token_ledger_entries
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.token_ledger_entries
  where profile_id = auth.uid()
  order by created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

create or replace function public.rpc_transfer_tokens(
  p_receiver_member_id text,
  p_amount_tokens bigint,
  p_note text default null,
  p_idempotency_key text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender_id uuid := auth.uid();
  v_receiver_id uuid;
  v_transfer_id uuid;
  v_key text := coalesce(nullif(trim(p_idempotency_key), ''), gen_random_uuid()::text);
  v_sender_ledger_id uuid;
  v_receiver_ledger_id uuid;
begin
  if v_sender_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if p_amount_tokens <= 0 then
    raise exception using message = 'INVALID_TOKEN_AMOUNT';
  end if;

  select id
  into v_receiver_id
  from public.profiles
  where regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g')
        = regexp_replace(coalesce(p_receiver_member_id, ''), '[^0-9]', '', 'g')
  limit 1;

  if v_receiver_id is null then
    raise exception using message = 'RECEIVER_NOT_FOUND';
  end if;

  if v_receiver_id = v_sender_id then
    raise exception using message = 'SELF_TRANSFER_NOT_ALLOWED';
  end if;

  select id
  into v_transfer_id
  from public.wallet_transfers
  where sender_profile_id = v_sender_id
    and idempotency_key = v_key;

  if v_transfer_id is not null then
    return json_build_object('transfer_id', v_transfer_id, 'status', 'completed');
  end if;

  insert into public.wallet_transfers (
    sender_profile_id,
    receiver_profile_id,
    amount_tokens,
    idempotency_key,
    note
  )
  values (v_sender_id, v_receiver_id, p_amount_tokens, v_key, nullif(trim(coalesce(p_note, '')), ''))
  returning id into v_transfer_id;

  v_sender_ledger_id := public._debit_tokens(
    v_sender_id,
    p_amount_tokens,
    'wallet_transfer',
    'wallet_transfers',
    v_transfer_id,
    v_receiver_id,
    p_note
  );

  v_receiver_ledger_id := public._credit_tokens(
    v_receiver_id,
    p_amount_tokens,
    'wallet_transfer',
    'wallet_transfers',
    v_transfer_id,
    v_sender_id,
    p_note
  );

  return json_build_object(
    'transfer_id', v_transfer_id,
    'status', 'completed',
    'sender_ledger_entry_id', v_sender_ledger_id,
    'receiver_ledger_entry_id', v_receiver_ledger_id
  );
end;
$$;

create or replace function public.rpc_get_or_create_referral_code()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_member_id text;
  v_code text;
  v_row public.app_referral_codes%rowtype;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  select regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g')
  into v_member_id
  from public.profiles
  where id = v_user_id;

  v_code := 'MOBI' || lpad(coalesce(nullif(v_member_id, ''), substring(replace(v_user_id::text, '-', ''), 1, 6)), 6, '0');

  insert into public.app_referral_codes(profile_id, code, share_url)
  values (v_user_id, v_code, 'https://mobio.ikanisa.com/invite/' || v_code)
  on conflict (profile_id) do update
  set
    is_active = true,
    updated_at = now()
  returning * into v_row;

  return json_build_object(
    'id', v_row.id,
    'code', v_row.code,
    'share_url', v_row.share_url,
    'reward_tokens', 100
  );
end;
$$;

create or replace function public.rpc_record_referral_open(
  p_code text,
  p_platform text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code public.app_referral_codes%rowtype;
  v_event_id uuid;
begin
  select *
  into v_code
  from public.app_referral_codes
  where code = upper(trim(p_code))
    and is_active = true;

  if not found then
    raise exception using message = 'INVALID_REFERRAL_CODE';
  end if;

  insert into public.app_referral_events(
    referral_code_id,
    inviter_profile_id,
    status,
    platform,
    metadata
  )
  values (
    v_code.id,
    v_code.profile_id,
    'opened',
    nullif(trim(coalesce(p_platform, '')), ''),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_event_id;

  return json_build_object('event_id', v_event_id, 'status', 'opened');
end;
$$;

create or replace function public.rpc_complete_referral_signup(
  p_code text,
  p_install_id text default null,
  p_device_hash text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitee_id uuid := auth.uid();
  v_code public.app_referral_codes%rowtype;
  v_event_id uuid;
  v_ledger_id uuid;
  v_install_id text := nullif(trim(coalesce(p_install_id, '')), '');
  v_device_hash text := nullif(trim(coalesce(p_device_hash, '')), '');
begin
  if v_invitee_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  select *
  into v_code
  from public.app_referral_codes
  where code = upper(trim(p_code))
    and is_active = true;

  if not found then
    raise exception using message = 'INVALID_REFERRAL_CODE';
  end if;

  if v_code.profile_id = v_invitee_id then
    insert into public.app_referral_events (
      referral_code_id,
      inviter_profile_id,
      invitee_profile_id,
      status,
      install_id,
      device_hash,
      rejected_reason,
      metadata,
      signed_up_at
    )
    values (
      v_code.id,
      v_code.profile_id,
      v_invitee_id,
      'rejected',
      nullif(trim(coalesce(p_install_id, '')), ''),
      nullif(trim(coalesce(p_device_hash, '')), ''),
      'self_referral',
      coalesce(p_metadata, '{}'::jsonb),
      now()
    )
    returning id into v_event_id;

    return json_build_object('event_id', v_event_id, 'status', 'rejected');
  end if;

  select id
  into v_event_id
  from public.app_referral_events
  where inviter_profile_id = v_code.profile_id
    and invitee_profile_id = v_invitee_id
    and status = 'rewarded'
  limit 1;

  if v_event_id is not null then
    return json_build_object('event_id', v_event_id, 'status', 'already_rewarded');
  end if;

  if v_install_id is null then
    insert into public.app_referral_events (
      referral_code_id,
      inviter_profile_id,
      invitee_profile_id,
      status,
      device_hash,
      rejected_reason,
      metadata,
      signed_up_at
    )
    values (
      v_code.id,
      v_code.profile_id,
      v_invitee_id,
      'signed_up',
      v_device_hash,
      'install_not_verified',
      coalesce(p_metadata, '{}'::jsonb),
      now()
    )
    returning id into v_event_id;

    return json_build_object(
      'event_id', v_event_id,
      'status', 'signed_up',
      'reward_tokens', 0,
      'reward_pending_reason', 'install_not_verified'
    );
  end if;

  select id
  into v_event_id
  from public.app_referral_events
  where status = 'rewarded'
    and lower(install_id) = lower(v_install_id)
  limit 1;

  if v_event_id is not null then
    insert into public.app_referral_events (
      referral_code_id,
      inviter_profile_id,
      invitee_profile_id,
      status,
      install_id,
      device_hash,
      rejected_reason,
      metadata,
      installed_at,
      signed_up_at
    )
    values (
      v_code.id,
      v_code.profile_id,
      v_invitee_id,
      'rejected',
      v_install_id,
      v_device_hash,
      'duplicate_install',
      coalesce(p_metadata, '{}'::jsonb),
      now(),
      now()
    )
    returning id into v_event_id;

    return json_build_object('event_id', v_event_id, 'status', 'rejected');
  end if;

  if v_device_hash is not null then
    select id
    into v_event_id
    from public.app_referral_events
    where status = 'rewarded'
      and lower(device_hash) = lower(v_device_hash)
    limit 1;

    if v_event_id is not null then
      insert into public.app_referral_events (
        referral_code_id,
        inviter_profile_id,
        invitee_profile_id,
        status,
        install_id,
        device_hash,
        rejected_reason,
        metadata,
        installed_at,
        signed_up_at
      )
      values (
        v_code.id,
        v_code.profile_id,
        v_invitee_id,
        'rejected',
        v_install_id,
        v_device_hash,
        'duplicate_device',
        coalesce(p_metadata, '{}'::jsonb),
        now(),
        now()
      )
      returning id into v_event_id;

      return json_build_object('event_id', v_event_id, 'status', 'rejected');
    end if;
  end if;

  insert into public.app_referral_events (
    referral_code_id,
    inviter_profile_id,
    invitee_profile_id,
    status,
    install_id,
    device_hash,
    metadata,
    installed_at,
    signed_up_at
  )
  values (
    v_code.id,
    v_code.profile_id,
    v_invitee_id,
    'qualified',
    v_install_id,
    v_device_hash,
    coalesce(p_metadata, '{}'::jsonb),
    now(),
    now()
  )
  returning id into v_event_id;

  v_ledger_id := public._credit_tokens(
    v_code.profile_id,
    100,
    'referral_reward',
    'app_referral_events',
    v_event_id,
    v_invitee_id,
    'Successful Mobio app share'
  );

  update public.app_referral_events
  set
    status = 'rewarded',
    reward_tokens = 100,
    reward_ledger_entry_id = v_ledger_id,
    rewarded_at = now(),
    updated_at = now()
  where id = v_event_id;

  return json_build_object(
    'event_id', v_event_id,
    'status', 'rewarded',
    'reward_tokens', 100
  );
end;
$$;

create or replace function public._driver_plus_status_for(
  p_driver_id uuid,
  p_conversation_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_rule public.driver_plus_rules%rowtype;
  v_vehicle_type text;
  v_has_subscription boolean := false;
  v_today date := timezone('utc', now())::date;
  v_used_today integer := 0;
  v_used_total integer := 0;
  v_trial_started_at timestamptz;
  v_trial_ends_at timestamptz;
  v_trial_available boolean := false;
  v_conversation_allowed boolean := false;
  v_can_access boolean := false;
begin
  select *
  into v_profile
  from public.profiles
  where id = p_driver_id;

  if not found then
    return jsonb_build_object('driver_id', p_driver_id, 'exists', false);
  end if;

  v_vehicle_type := coalesce(v_profile.vehicle_type::text, 'cab');

  select *
  into v_rule
  from public.driver_plus_rules
  where vehicle_type_id = v_vehicle_type
    and is_active = true;

  if not found then
    v_rule.vehicle_type_id := v_vehicle_type;
    v_rule.requires_plus := true;
    v_rule.free_trial_days := 0;
    v_rule.free_daily_request_limit := 0;
    v_rule.free_total_request_limit := 0;
    v_rule.is_free_forever := false;
  end if;

  v_has_subscription := public.has_active_driver_subscription(
    p_driver_id,
    v_vehicle_type,
    'plus'
  ) or public.has_active_driver_subscription(
    p_driver_id,
    v_vehicle_type,
    'pro'
  );

  select count(*)::integer
  into v_used_today
  from public.driver_request_entitlement_usage u
  where u.driver_profile_id = p_driver_id
    and u.vehicle_type_id = v_vehicle_type
    and u.request_date = v_today
    and u.allowed = true
    and u.allowance_source = 'free_trial';

  select count(*)::integer
  into v_used_total
  from public.driver_request_entitlement_usage u
  where u.driver_profile_id = p_driver_id
    and u.vehicle_type_id = v_vehicle_type
    and u.allowed = true
    and u.allowance_source = 'free_trial';

  if v_rule.free_trial_days > 0 then
    select min(created_at)
    into v_trial_started_at
    from public.driver_request_entitlement_usage u
    where u.driver_profile_id = p_driver_id
      and u.vehicle_type_id = v_vehicle_type
      and u.allowed = true
      and u.allowance_source = 'free_trial';

    v_trial_started_at := coalesce(v_trial_started_at, now());
    v_trial_ends_at := v_trial_started_at + make_interval(days => v_rule.free_trial_days);
    v_trial_available :=
      now() < v_trial_ends_at
      and v_used_today < v_rule.free_daily_request_limit
      and v_used_total < v_rule.free_total_request_limit;
  end if;

  if p_conversation_id is not null then
    select coalesce(bool_or(allowed), false)
    into v_conversation_allowed
    from public.driver_request_entitlement_usage
    where driver_profile_id = p_driver_id
      and conversation_id = p_conversation_id;
  end if;

  v_can_access :=
    v_rule.is_free_forever
    or not v_rule.requires_plus
    or v_has_subscription
    or v_conversation_allowed
    or v_trial_available;

  return jsonb_build_object(
    'driver_id', p_driver_id,
    'exists', true,
    'vehicle_type_id', v_vehicle_type,
    'requires_plus', v_rule.requires_plus,
    'is_free_forever', v_rule.is_free_forever,
    'has_active_subscription', v_has_subscription,
    'trial_ends_at', v_trial_ends_at,
    'free_trial_days', v_rule.free_trial_days,
    'free_daily_request_limit', v_rule.free_daily_request_limit,
    'free_total_request_limit', v_rule.free_total_request_limit,
    'used_today', v_used_today,
    'used_total', v_used_total,
    'remaining_today', greatest(v_rule.free_daily_request_limit - v_used_today, 0),
    'remaining_total', greatest(v_rule.free_total_request_limit - v_used_total, 0),
    'conversation_allowed', v_conversation_allowed,
    'can_receive_new_request', v_rule.is_free_forever or not v_rule.requires_plus or v_has_subscription or v_trial_available,
    'can_reply', v_can_access,
    'can_read_messages', v_can_access,
    'can_show_whatsapp', v_can_access,
    'upgrade_required', not v_can_access
  );
end;
$$;

create or replace function public.rpc_get_driver_plus_status(p_driver_id uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid := coalesce(p_driver_id, auth.uid());
begin
  if v_driver_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  return public._driver_plus_status_for(v_driver_id, null)::json;
end;
$$;

create or replace function public._record_driver_request_entitlement(
  p_driver_id uuid,
  p_passenger_id uuid,
  p_conversation_id uuid,
  p_trip_id uuid,
  p_channel text default 'in_app_chat'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status jsonb;
  v_vehicle_type text;
  v_allowed boolean;
  v_source text;
  v_existing public.driver_request_entitlement_usage%rowtype;
begin
  if p_driver_id is null or p_passenger_id is null or p_driver_id = p_passenger_id then
    return jsonb_build_object('allowed', false, 'source', 'blocked');
  end if;

  select *
  into v_existing
  from public.driver_request_entitlement_usage
  where conversation_id = p_conversation_id
  limit 1;

  if found then
    return jsonb_build_object(
      'allowed', v_existing.allowed,
      'source', v_existing.allowance_source
    );
  end if;

  v_status := public._driver_plus_status_for(p_driver_id, null);
  v_vehicle_type := coalesce(v_status->>'vehicle_type_id', 'cab');
  v_allowed := coalesce((v_status->>'can_receive_new_request')::boolean, false);
  v_source := case
    when coalesce((v_status->>'is_free_forever')::boolean, false) then 'bus_free'
    when coalesce((v_status->>'has_active_subscription')::boolean, false) then 'plus'
    when v_allowed then 'free_trial'
    else 'blocked'
  end;

  insert into public.driver_request_entitlement_usage (
    driver_profile_id,
    passenger_profile_id,
    conversation_id,
    trip_id,
    vehicle_type_id,
    allowed,
    allowance_source,
    channel
  )
  values (
    p_driver_id,
    p_passenger_id,
    p_conversation_id,
    p_trip_id,
    v_vehicle_type,
    v_allowed,
    v_source,
    coalesce(nullif(p_channel, ''), 'in_app_chat')
  )
  on conflict do nothing;

  return jsonb_build_object('allowed', v_allowed, 'source', v_source);
end;
$$;

create or replace function public._driver_can_reply_to_conversation(
  p_driver_id uuid,
  p_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((public._driver_plus_status_for(p_driver_id, p_conversation_id)->>'can_reply')::boolean, false);
$$;

create or replace function public.rpc_get_or_create_chat_conversation(
  p_peer_id uuid,
  p_trip_id uuid default null
)
returns public.chat_conversations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
  v_trip public.trips%rowtype;
  v_conversation public.chat_conversations%rowtype;
  v_low_id uuid;
  v_high_id uuid;
  v_context_type text := case when p_trip_id is null then 'direct' else 'trip' end;
  v_driver_id uuid;
  v_passenger_id uuid;
begin
  if v_self_id is null then
    raise exception 'Authentication required';
  end if;

  if p_peer_id is null or p_peer_id = v_self_id then
    raise exception 'A different peer is required';
  end if;

  if p_trip_id is not null then
    select *
    into v_trip
    from public.trips
    where id = p_trip_id;

    if not found then
      raise exception 'Trip not found';
    end if;

    if v_self_id <> v_trip.author_id and p_peer_id <> v_trip.author_id then
      raise exception 'Trip chat must include the trip author';
    end if;
  end if;

  v_low_id := least(v_self_id, p_peer_id);
  v_high_id := greatest(v_self_id, p_peer_id);

  select *
  into v_conversation
  from public.chat_conversations
  where participant_low_id = v_low_id
    and participant_high_id = v_high_id
    and (
      (p_trip_id is null and trip_id is null and context_type = 'direct')
      or trip_id = p_trip_id
    )
  limit 1;

  if not found then
    insert into public.chat_conversations (
      trip_id,
      participant_low_id,
      participant_high_id,
      created_by,
      context_type
    )
    values (
      p_trip_id,
      v_low_id,
      v_high_id,
      v_self_id,
      v_context_type
    )
    returning *
    into v_conversation;

    insert into public.chat_messages (
      conversation_id,
      sender_id,
      message_type,
      body,
      metadata
    )
    values (
      v_conversation.id,
      null,
      'system',
      'Chat started in Mobio. Keep pickup and trip details here.',
      jsonb_build_object('seed', 'privacy_notice')
    );
  end if;

  if p_trip_id is not null and v_trip.role = 'driver' then
    v_driver_id := v_trip.author_id;
    v_passenger_id := case
      when v_self_id = v_driver_id then p_peer_id
      else v_self_id
    end;

    if v_self_id <> v_driver_id then
      perform public._record_driver_request_entitlement(
        v_driver_id,
        v_passenger_id,
        v_conversation.id,
        p_trip_id,
        'in_app_chat'
      );
    end if;
  end if;

  return v_conversation;
end;
$$;

create or replace function public.handle_chat_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_preview text;
begin
  v_preview := left(new.body, 160);

  select *
  into v_conversation
  from public.chat_conversations
  where id = new.conversation_id;

  if found and v_conversation.trip_id is not null and new.sender_id is not null then
    select *
    into v_trip
    from public.trips
    where id = v_conversation.trip_id;

    if found
      and v_trip.role = 'driver'
      and new.sender_id is distinct from v_trip.author_id
      and not public._driver_can_reply_to_conversation(v_trip.author_id, v_conversation.id) then
      v_preview := 'Mobio Plus required to read this passenger message.';
    end if;
  end if;

  update public.chat_conversations
  set
    last_message_at = new.created_at,
    last_message_preview = v_preview,
    updated_at = now()
  where id = new.conversation_id;

  return new;
end;
$$;

drop policy if exists chat_messages_insert_sender on public.chat_messages;
drop policy if exists chat_messages_insert_rpc_only on public.chat_messages;
create policy chat_messages_insert_rpc_only
  on public.chat_messages
  for insert
  to authenticated
  with check (false);

create or replace function public.rpc_send_chat_message(
  p_conversation_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_message_id uuid;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if v_body is null then
    raise exception using message = 'EMPTY_MESSAGE';
  end if;

  select *
  into v_conversation
  from public.chat_conversations
  where id = p_conversation_id
    and v_user_id in (participant_low_id, participant_high_id);

  if not found then
    raise exception using message = 'CONVERSATION_NOT_FOUND';
  end if;

  if v_conversation.trip_id is not null then
    select *
    into v_trip
    from public.trips
    where id = v_conversation.trip_id;

    if found and v_trip.role = 'driver' and v_trip.author_id = v_user_id then
      if not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id) then
        raise exception using
          message = 'MOBIO_PLUS_REQUIRED',
          detail = 'Upgrade to Mobio Plus to read and respond to passenger requests.';
      end if;
    end if;
  end if;

  insert into public.chat_messages (
    conversation_id,
    sender_id,
    message_type,
    body,
    metadata
  )
  values (
    p_conversation_id,
    v_user_id,
    'text',
    v_body,
    '{}'::jsonb
  )
  returning id into v_message_id;

  return v_message_id;
end;
$$;

create or replace function public.rpc_list_chat_messages(
  p_conversation_id uuid,
  p_limit integer default 100
)
returns table (
  id uuid,
  conversation_id uuid,
  sender_id uuid,
  message_type text,
  body text,
  metadata jsonb,
  created_at timestamptz,
  read_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_redact boolean := false;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  select *
  into v_conversation
  from public.chat_conversations c
  where c.id = p_conversation_id
    and v_user_id in (c.participant_low_id, c.participant_high_id);

  if not found then
    raise exception using message = 'CONVERSATION_NOT_FOUND';
  end if;

  if v_conversation.trip_id is not null then
    select *
    into v_trip
    from public.trips
    where trips.id = v_conversation.trip_id;

    if found and v_trip.role = 'driver' and v_trip.author_id = v_user_id then
      v_redact := not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id);
    end if;
  end if;

  return query
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    m.message_type,
    case
      when v_redact
        and m.message_type = 'text'
        and m.sender_id is distinct from v_user_id
      then 'Mobio Plus required to read this passenger message.'
      else m.body
    end as body,
    case
      when v_redact
        and m.message_type = 'text'
        and m.sender_id is distinct from v_user_id
      then m.metadata || jsonb_build_object('redacted', true, 'redaction_reason', 'mobio_plus_required')
      else m.metadata
    end as metadata,
    m.created_at,
    m.read_at
  from public.chat_messages m
  where m.conversation_id = p_conversation_id
  order by m.created_at asc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
end;
$$;

create or replace function public._activate_driver_subscription(
  p_request_id uuid,
  p_confirmation_source text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.driver_subscription_payment_requests%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_start timestamptz;
  v_end timestamptz;
  v_subscription_id uuid;
begin
  select *
  into v_request
  from public.driver_subscription_payment_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception using message = 'SUBSCRIPTION_PAYMENT_NOT_FOUND';
  end if;

  select *
  into v_plan
  from public.subscription_plans
  where id = v_request.plan_id;

  if not found then
    raise exception using message = 'SUBSCRIPTION_PLAN_NOT_FOUND';
  end if;

  select greatest(now(), coalesce(max(current_period_end), now()))
  into v_start
  from public.driver_subscriptions
  where profile_id = v_request.profile_id
    and vehicle_type_id = v_request.vehicle_type_id
    and status in ('trialing', 'active')
    and current_period_end > now();

  v_end := v_start + make_interval(days => v_plan.interval_days);

  insert into public.driver_subscriptions (
    profile_id,
    plan_id,
    vehicle_type_id,
    tier,
    status,
    current_period_start,
    current_period_end,
    provider,
    external_subscription_id,
    metadata
  )
  values (
    v_request.profile_id,
    v_request.plan_id,
    v_request.vehicle_type_id,
    coalesce(v_plan.tier, 'plus'),
    'active',
    v_start,
    v_end,
    v_request.payment_method,
    v_request.reference_code,
    jsonb_build_object(
      'payment_request_id', v_request.id,
      'confirmation_source', p_confirmation_source
    )
  )
  returning id into v_subscription_id;

  return v_subscription_id;
end;
$$;

create or replace function public.rpc_start_driver_subscription(
  p_plan_id uuid,
  p_payment_method text
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_plan public.subscription_plans%rowtype;
  v_request_id uuid := gen_random_uuid();
  v_member_id text;
  v_amount bigint;
  v_reference text;
  v_ussd text;
  v_subscription_id uuid;
  v_ledger_id uuid;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if p_payment_method not in ('tokens', 'momo_ussd') then
    raise exception using message = 'INVALID_PAYMENT_METHOD';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = v_user_id;

  if not found or not coalesce(v_profile.is_driver, false) then
    raise exception using message = 'DRIVER_PROFILE_REQUIRED';
  end if;

  select *
  into v_plan
  from public.subscription_plans
  where id = p_plan_id
    and is_active = true
    and currency = 'RWF';

  if not found then
    raise exception using message = 'SUBSCRIPTION_PLAN_NOT_FOUND';
  end if;

  if v_plan.vehicle_type_id <> coalesce(v_profile.vehicle_type::text, '') then
    raise exception using
      message = 'PLAN_VEHICLE_TYPE_MISMATCH',
      detail = 'Selected subscription does not match the driver vehicle type.';
  end if;

  v_amount := ceil(v_plan.price)::bigint;
  v_member_id := regexp_replace(coalesce(v_profile.member_id, ''), '[^0-9]', '', 'g');
  if v_member_id = '' then
    v_member_id := substring(replace(v_user_id::text, '-', ''), 1, 6);
  end if;
  v_member_id := lpad(substring(v_member_id, 1, 6), 6, '0');
  v_reference := upper(v_member_id || '-' || substring(replace(v_request_id::text, '-', ''), 1, 8));
  v_ussd := '*182*8*1*12345*' || v_amount::text || '#';

  insert into public.driver_subscription_payment_requests (
    id,
    profile_id,
    plan_id,
    vehicle_type_id,
    payment_method,
    amount_tokens,
    amount_rwf,
    reference_code,
    momo_pay_code,
    ussd_code,
    status,
    metadata
  )
  values (
    v_request_id,
    v_user_id,
    v_plan.id,
    v_plan.vehicle_type_id,
    p_payment_method,
    v_amount,
    v_amount,
    v_reference,
    '12345',
    case when p_payment_method = 'momo_ussd' then v_ussd else null end,
    case when p_payment_method = 'tokens' then 'confirmed' else 'pending' end,
    jsonb_build_object(
      'member_id', v_member_id,
      'plan_interval_days', v_plan.interval_days
    )
  );

  if p_payment_method = 'tokens' then
    v_ledger_id := public._debit_tokens(
      v_user_id,
      v_amount,
      'subscription_payment',
      'driver_subscription_payment_requests',
      v_request_id,
      null,
      'Mobio Plus subscription ' || v_reference,
      jsonb_build_object('plan_id', v_plan.id, 'vehicle_type_id', v_plan.vehicle_type_id)
    );

    update public.driver_subscription_payment_requests
    set
      confirmed_at = now(),
      confirmation_source = 'token_wallet',
      metadata = metadata || jsonb_build_object('token_ledger_entry_id', v_ledger_id),
      updated_at = now()
    where id = v_request_id;

    v_subscription_id := public._activate_driver_subscription(v_request_id, 'token_wallet');
  end if;

  return json_build_object(
    'id', v_request_id,
    'status', case when p_payment_method = 'tokens' then 'confirmed' else 'pending' end,
    'payment_method', p_payment_method,
    'reference_code', v_reference,
    'amount_tokens', v_amount,
    'amount_rwf', v_amount,
    'currency', 'RWF',
    'momo_pay_code', '12345',
    'ussd_code', case when p_payment_method = 'momo_ussd' then v_ussd else null end,
    'subscription_id', v_subscription_id,
    'expires_at', (select expires_at from public.driver_subscription_payment_requests where id = v_request_id)
  );
end;
$$;

create or replace function public.rpc_record_driver_subscription_dialer_opened(
  p_request_id uuid
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.driver_subscription_payment_requests%rowtype;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  update public.driver_subscription_payment_requests
  set status = 'dialer_opened', updated_at = now()
  where id = p_request_id
    and profile_id = v_user_id
    and payment_method = 'momo_ussd'
    and status = 'pending'
  returning * into v_request;

  if not found then
    select *
    into v_request
    from public.driver_subscription_payment_requests
    where id = p_request_id
      and profile_id = v_user_id;
  end if;

  if not found then
    raise exception using message = 'SUBSCRIPTION_PAYMENT_NOT_FOUND';
  end if;

  return row_to_json(v_request);
end;
$$;

create or replace function public.rpc_ingest_driver_subscription_momo_sms(
  p_raw_sms text,
  p_sender text default null,
  p_received_at timestamptz default null,
  p_parsed jsonb default '{}'::jsonb
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_raw_sms text := nullif(trim(coalesce(p_raw_sms, '')), '');
  v_sender text := nullif(trim(coalesce(p_sender, '')), '');
  v_received_at timestamptz := coalesce(p_received_at, now());
  v_parsed jsonb := coalesce(p_parsed, '{}'::jsonb);
  v_sms_hash text;
  v_amount bigint;
  v_amount_text text;
  v_reference text;
  v_member_id text;
  v_momo_pay_code text;
  v_payer_phone text;
  v_payer_name text;
  v_provider_ref text;
  v_match text[];
  v_receipt public.driver_subscription_momo_sms_receipts%rowtype;
  v_request public.driver_subscription_payment_requests%rowtype;
  v_candidate_count integer := 0;
  v_subscription_id uuid;
begin
  if not (public._mobio_is_service_role() or public.is_platform_admin()) then
    raise exception using message = 'ADMIN_OR_SERVICE_ROLE_REQUIRED';
  end if;

  if v_raw_sms is null then
    raise exception using message = 'RAW_SMS_REQUIRED';
  end if;

  v_sms_hash := encode(extensions.digest(v_raw_sms || '|' || coalesce(v_sender, ''), 'sha256'), 'hex');
  v_reference := upper(nullif(trim(coalesce(v_parsed->>'reference_code', '')), ''));
  v_momo_pay_code := nullif(regexp_replace(coalesce(v_parsed->>'momo_pay_code', '12345'), '[^0-9]', '', 'g'), '');
  v_payer_phone := nullif(regexp_replace(coalesce(v_parsed->>'payer_phone', ''), '[^0-9]', '', 'g'), '');
  v_payer_name := nullif(trim(coalesce(v_parsed->>'payer_name', '')), '');
  v_provider_ref := nullif(trim(coalesce(v_parsed->>'provider_transaction_ref', '')), '');

  v_amount_text := nullif(regexp_replace(coalesce(v_parsed->>'amount_rwf', ''), '[^0-9]', '', 'g'), '');
  if v_amount_text is not null then
    v_amount := v_amount_text::bigint;
  end if;

  if v_amount is null then
    v_match := regexp_match(v_raw_sms, '([0-9][0-9, .]*)\s*(RWF|FRW|RF)', 'i');
    if v_match is not null then
      v_amount_text := nullif(regexp_replace(v_match[1], '[^0-9]', '', 'g'), '');
      if v_amount_text is not null then
        v_amount := v_amount_text::bigint;
      end if;
    end if;
  end if;

  if v_reference is null then
    v_match := regexp_match(v_raw_sms, '([0-9]{6}-[A-Za-z0-9]{8})');
    if v_match is not null then
      v_reference := upper(v_match[1]);
    end if;
  end if;

  if v_provider_ref is null then
    v_match := regexp_match(v_raw_sms, '(?:TxId|TxnId|Trans(?:action)?(?:\s+Id)?|Ref(?:erence)?)[:#\s]+([A-Za-z0-9.-]{6,})', 'i');
    if v_match is not null then
      v_provider_ref := v_match[1];
    end if;
  end if;

  if v_provider_ref is not null then
    v_provider_ref := nullif(regexp_replace(v_provider_ref, '[.,;:]+$', ''), '');
  end if;

  if v_reference is not null then
    v_member_id := split_part(v_reference, '-', 1);
  else
    v_member_id := nullif(regexp_replace(coalesce(v_parsed->>'member_id', ''), '[^0-9]', '', 'g'), '');
  end if;

  select *
  into v_receipt
  from public.driver_subscription_momo_sms_receipts
  where sms_hash = v_sms_hash
    or (
      v_provider_ref is not null
      and provider_transaction_ref = v_provider_ref
    )
  limit 1;

  if found then
    return json_build_object(
      'id', v_receipt.id,
      'status', v_receipt.status,
      'reference_code', v_receipt.reference_code,
      'matched_payment_request_id', v_receipt.matched_payment_request_id,
      'duplicate', true
    );
  end if;

  insert into public.driver_subscription_momo_sms_receipts (
    raw_sms,
    sms_hash,
    sender,
    received_at,
    amount_rwf,
    momo_pay_code,
    reference_code,
    payer_phone,
    payer_name,
    provider_transaction_ref,
    status,
    metadata
  )
  values (
    v_raw_sms,
    v_sms_hash,
    v_sender,
    v_received_at,
    v_amount,
    coalesce(v_momo_pay_code, '12345'),
    v_reference,
    v_payer_phone,
    v_payer_name,
    v_provider_ref,
    'received',
    v_parsed
  )
  returning * into v_receipt;

  if coalesce(v_momo_pay_code, '12345') <> '12345' then
    update public.driver_subscription_momo_sms_receipts
    set status = 'ignored',
        metadata = metadata || jsonb_build_object('ignored_reason', 'momo_pay_code_mismatch'),
        updated_at = now()
    where id = v_receipt.id
    returning * into v_receipt;

    return json_build_object('id', v_receipt.id, 'status', v_receipt.status);
  end if;

  if v_reference is not null then
    select *
    into v_request
    from public.driver_subscription_payment_requests
    where reference_code = v_reference
      and payment_method = 'momo_ussd'
      and status in ('pending', 'dialer_opened')
    for update;

    v_candidate_count := case when found then 1 else 0 end;
  elsif v_amount is not null then
    select count(*)::integer
    into v_candidate_count
    from public.driver_subscription_payment_requests r
    where r.payment_method = 'momo_ussd'
      and r.status in ('pending', 'dialer_opened')
      and r.amount_rwf = v_amount
      and r.momo_pay_code = '12345'
      and r.created_at <= v_received_at + interval '10 minutes'
      and r.expires_at >= v_received_at - interval '10 minutes'
      and (
        v_member_id is null
        or regexp_replace(coalesce(r.metadata->>'member_id', ''), '[^0-9]', '', 'g') = v_member_id
      );

    if v_candidate_count = 1 then
      select *
      into v_request
      from public.driver_subscription_payment_requests r
      where r.payment_method = 'momo_ussd'
        and r.status in ('pending', 'dialer_opened')
        and r.amount_rwf = v_amount
        and r.momo_pay_code = '12345'
        and r.created_at <= v_received_at + interval '10 minutes'
        and r.expires_at >= v_received_at - interval '10 minutes'
        and (
          v_member_id is null
          or regexp_replace(coalesce(r.metadata->>'member_id', ''), '[^0-9]', '', 'g') = v_member_id
        )
      order by r.created_at desc
      limit 1
      for update;
    end if;
  end if;

  if v_candidate_count = 0 then
    update public.driver_subscription_momo_sms_receipts
    set status = 'unmatched',
        metadata = metadata || jsonb_build_object('match_reason', 'no_pending_payment_request'),
        updated_at = now()
    where id = v_receipt.id
    returning * into v_receipt;

    return json_build_object('id', v_receipt.id, 'status', v_receipt.status);
  end if;

  if v_candidate_count > 1 then
    update public.driver_subscription_momo_sms_receipts
    set status = 'ambiguous',
        metadata = metadata || jsonb_build_object('candidate_count', v_candidate_count),
        updated_at = now()
    where id = v_receipt.id
    returning * into v_receipt;

    return json_build_object(
      'id', v_receipt.id,
      'status', v_receipt.status,
      'candidate_count', v_candidate_count
    );
  end if;

  update public.driver_subscription_payment_requests
  set
    status = 'confirmed',
    confirmed_at = v_received_at,
    confirmation_source = 'momo_sms_bridge',
    provider_transaction_ref = coalesce(v_provider_ref, provider_transaction_ref),
    metadata = metadata || jsonb_build_object(
      'momo_sms_receipt_id', v_receipt.id,
      'momo_sms_sender', v_sender,
      'momo_sms_received_at', v_received_at
    ),
    updated_at = now()
  where id = v_request.id;

  update public.driver_subscription_momo_sms_receipts
  set
    status = 'matched',
    reference_code = coalesce(reference_code, v_request.reference_code),
    matched_payment_request_id = v_request.id,
    updated_at = now()
  where id = v_receipt.id
  returning * into v_receipt;

  v_subscription_id := public._activate_driver_subscription(
    v_request.id,
    'momo_sms_bridge'
  );

  return json_build_object(
    'id', v_receipt.id,
    'status', v_receipt.status,
    'reference_code', v_receipt.reference_code,
    'matched_payment_request_id', v_request.id,
    'subscription_id', v_subscription_id
  );
end;
$$;

create or replace function public.rpc_confirm_driver_subscription_payment(
  p_reference_code text,
  p_confirmation_source text default 'momo_sms_bridge',
  p_provider_transaction_ref text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.driver_subscription_payment_requests%rowtype;
  v_subscription_id uuid;
begin
  if not (public._mobio_is_service_role() or public.is_platform_admin()) then
    raise exception using message = 'ADMIN_OR_SERVICE_ROLE_REQUIRED';
  end if;

  select *
  into v_request
  from public.driver_subscription_payment_requests
  where reference_code = upper(trim(p_reference_code))
    and payment_method = 'momo_ussd'
  for update;

  if not found then
    raise exception using message = 'SUBSCRIPTION_PAYMENT_NOT_FOUND';
  end if;

  if v_request.status = 'confirmed' then
    return json_build_object(
      'id', v_request.id,
      'status', 'confirmed',
      'reference_code', v_request.reference_code,
      'already_confirmed', true
    );
  end if;

  update public.driver_subscription_payment_requests
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmation_source = nullif(trim(coalesce(p_confirmation_source, '')), ''),
    provider_transaction_ref = nullif(trim(coalesce(p_provider_transaction_ref, '')), ''),
    metadata = metadata || coalesce(p_metadata, '{}'::jsonb),
    updated_at = now()
  where id = v_request.id;

  v_subscription_id := public._activate_driver_subscription(
    v_request.id,
    coalesce(nullif(trim(coalesce(p_confirmation_source, '')), ''), 'momo_sms_bridge')
  );

  return json_build_object(
    'id', v_request.id,
    'status', 'confirmed',
    'reference_code', v_request.reference_code,
    'subscription_id', v_subscription_id
  );
end;
$$;

revoke all on function public._mobio_is_service_role() from public, anon, authenticated;
revoke all on function public._ensure_token_wallet(uuid) from public, anon, authenticated;
revoke all on function public._credit_tokens(uuid, bigint, text, text, uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public._debit_tokens(uuid, bigint, text, text, uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public._driver_plus_status_for(uuid, uuid) from public, anon, authenticated;
revoke all on function public._record_driver_request_entitlement(uuid, uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public._driver_can_reply_to_conversation(uuid, uuid) from public, anon, authenticated;
revoke all on function public._activate_driver_subscription(uuid, text) from public, anon, authenticated;

revoke all on function public.rpc_get_wallet_summary() from public, anon, authenticated;
revoke all on function public.rpc_list_token_ledger(integer) from public, anon, authenticated;
revoke all on function public.rpc_transfer_tokens(text, bigint, text, text) from public, anon, authenticated;
revoke all on function public.rpc_get_or_create_referral_code() from public, anon, authenticated;
revoke all on function public.rpc_record_referral_open(text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_complete_referral_signup(text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_get_driver_plus_status(uuid) from public, anon, authenticated;
revoke all on function public.rpc_send_chat_message(uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_list_chat_messages(uuid, integer) from public, anon, authenticated;
revoke all on function public.rpc_start_driver_subscription(uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_record_driver_subscription_dialer_opened(uuid) from public, anon, authenticated;
revoke all on function public.rpc_ingest_driver_subscription_momo_sms(text, text, timestamptz, jsonb) from public, anon, authenticated;
revoke all on function public.rpc_confirm_driver_subscription_payment(text, text, text, jsonb) from public, anon, authenticated;

grant execute on function public.rpc_get_wallet_summary() to authenticated;
grant execute on function public.rpc_list_token_ledger(integer) to authenticated;
grant execute on function public.rpc_transfer_tokens(text, bigint, text, text) to authenticated;
grant execute on function public.rpc_get_or_create_referral_code() to authenticated;
grant execute on function public.rpc_record_referral_open(text, text, jsonb) to anon, authenticated;
grant execute on function public.rpc_complete_referral_signup(text, text, text, jsonb) to authenticated;
grant execute on function public.rpc_get_driver_plus_status(uuid) to authenticated;
grant execute on function public.rpc_get_or_create_chat_conversation(uuid, uuid) to authenticated;
grant execute on function public.rpc_send_chat_message(uuid, text) to authenticated;
grant execute on function public.rpc_list_chat_messages(uuid, integer) to authenticated;
grant execute on function public.rpc_start_driver_subscription(uuid, text) to authenticated;
grant execute on function public.rpc_record_driver_subscription_dialer_opened(uuid) to authenticated;
grant execute on function public.rpc_ingest_driver_subscription_momo_sms(text, text, timestamptz, jsonb) to authenticated, service_role;
grant execute on function public.rpc_confirm_driver_subscription_payment(text, text, text, jsonb) to authenticated, service_role;

revoke select on public.chat_messages from anon, authenticated;

comment on table public.driver_subscription_payment_requests
  is 'Mobio Plus payment intents. MoMo uses USSD only and stores a reference code for SMS bridge/admin allocation.';

comment on table public.driver_subscription_momo_sms_receipts
  is 'Service-role/admin MoMo SMS receipts for Mobio Plus subscription reconciliation. Duplicate SMS messages are idempotent and ambiguous matches never activate subscriptions.';

commit;
