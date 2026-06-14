create table if not exists public.driver_subscription_momo_transactions (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.driver_subscription_momo_sms_receipts(id) on delete restrict,
  payment_request_id uuid references public.driver_subscription_payment_requests(id) on delete set null,
  subscription_id uuid references public.driver_subscriptions(id) on delete set null,
  sms_hash text not null,
  sender text,
  received_at timestamptz not null,
  amount_rwf bigint check (amount_rwf is null or amount_rwf > 0),
  currency text not null default 'RWF' check (currency = 'RWF'),
  momo_pay_code text not null default '12345',
  reference_code text,
  payer_phone text,
  payer_name text,
  provider_transaction_ref text,
  status text not null
    check (status in ('received', 'matched', 'duplicate', 'ambiguous', 'unmatched', 'ignored', 'failed')),
  parser_source text not null default 'openai' check (parser_source = 'openai'),
  openai_model text,
  parser_version text,
  parse_confidence numeric check (parse_confidence is null or (parse_confidence >= 0 and parse_confidence <= 1)),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_driver_subscription_momo_transactions_receipt
  on public.driver_subscription_momo_transactions(receipt_id);

create unique index if not exists uq_driver_subscription_momo_transactions_provider_ref
  on public.driver_subscription_momo_transactions(provider_transaction_ref)
  where provider_transaction_ref is not null and provider_transaction_ref <> '';

create index if not exists idx_driver_subscription_momo_transactions_request
  on public.driver_subscription_momo_transactions(payment_request_id, status, received_at desc);

create index if not exists idx_driver_subscription_momo_transactions_subscription
  on public.driver_subscription_momo_transactions(subscription_id, received_at desc);

drop trigger if exists set_driver_subscription_momo_transactions_updated_at
  on public.driver_subscription_momo_transactions;
create trigger set_driver_subscription_momo_transactions_updated_at
before update on public.driver_subscription_momo_transactions
for each row execute function public.handle_updated_at();

alter table public.driver_subscription_momo_transactions enable row level security;

drop policy if exists driver_subscription_momo_transactions_admin_read
  on public.driver_subscription_momo_transactions;
create policy driver_subscription_momo_transactions_admin_read
  on public.driver_subscription_momo_transactions
  for select
  to authenticated
  using (public.is_platform_admin());

revoke insert, update, delete on public.driver_subscription_momo_transactions from anon, authenticated;
grant select on public.driver_subscription_momo_transactions to authenticated;
grant all on public.driver_subscription_momo_transactions to service_role;

create or replace function public._sync_driver_subscription_momo_transaction_from_receipt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_subscription_id uuid;
begin
  if new.matched_payment_request_id is not null then
    select ds.id
    into v_subscription_id
    from public.driver_subscriptions ds
    where ds.metadata->>'payment_request_id' = new.matched_payment_request_id::text
    order by ds.created_at desc
    limit 1;
  end if;

  insert into public.driver_subscription_momo_transactions (
    receipt_id,
    payment_request_id,
    subscription_id,
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
    parser_source,
    openai_model,
    parser_version,
    parse_confidence,
    metadata
  )
  values (
    new.id,
    new.matched_payment_request_id,
    v_subscription_id,
    new.sms_hash,
    new.sender,
    new.received_at,
    new.amount_rwf,
    new.momo_pay_code,
    new.reference_code,
    new.payer_phone,
    new.payer_name,
    new.provider_transaction_ref,
    new.status,
    coalesce(nullif(new.metadata->>'parser_source', ''), 'openai'),
    nullif(new.metadata->>'openai_model', ''),
    nullif(new.metadata->>'parser_version', ''),
    case
      when jsonb_typeof(new.metadata->'confidence') = 'number'
      then (new.metadata->>'confidence')::numeric
      else null
    end,
    new.metadata
  )
  on conflict (receipt_id) do update
  set
    payment_request_id = excluded.payment_request_id,
    subscription_id = coalesce(excluded.subscription_id, public.driver_subscription_momo_transactions.subscription_id),
    sender = excluded.sender,
    received_at = excluded.received_at,
    amount_rwf = excluded.amount_rwf,
    momo_pay_code = excluded.momo_pay_code,
    reference_code = excluded.reference_code,
    payer_phone = excluded.payer_phone,
    payer_name = excluded.payer_name,
    provider_transaction_ref = excluded.provider_transaction_ref,
    status = excluded.status,
    parser_source = excluded.parser_source,
    openai_model = excluded.openai_model,
    parser_version = excluded.parser_version,
    parse_confidence = excluded.parse_confidence,
    metadata = excluded.metadata,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists sync_driver_subscription_momo_transaction_from_receipt
  on public.driver_subscription_momo_sms_receipts;
create trigger sync_driver_subscription_momo_transaction_from_receipt
after insert or update of matched_payment_request_id, status, amount_rwf, momo_pay_code, reference_code, payer_phone, payer_name, provider_transaction_ref, metadata
on public.driver_subscription_momo_sms_receipts
for each row execute function public._sync_driver_subscription_momo_transaction_from_receipt();

create or replace function public._sync_driver_subscription_momo_transaction_from_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment_request_id uuid;
begin
  if new.metadata ? 'payment_request_id' then
    v_payment_request_id := nullif(new.metadata->>'payment_request_id', '')::uuid;
  end if;

  if v_payment_request_id is not null then
    update public.driver_subscription_momo_transactions
    set subscription_id = new.id,
        updated_at = now()
    where payment_request_id = v_payment_request_id
      and subscription_id is null;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_driver_subscription_momo_transaction_from_subscription
  on public.driver_subscriptions;
create trigger sync_driver_subscription_momo_transaction_from_subscription
after insert or update of metadata
on public.driver_subscriptions
for each row execute function public._sync_driver_subscription_momo_transaction_from_subscription();

revoke all on function public._sync_driver_subscription_momo_transaction_from_receipt() from public, anon, authenticated;
revoke all on function public._sync_driver_subscription_momo_transaction_from_subscription() from public, anon, authenticated;
grant execute on function public._sync_driver_subscription_momo_transaction_from_receipt() to service_role;
grant execute on function public._sync_driver_subscription_momo_transaction_from_subscription() to service_role;

comment on table public.driver_subscription_momo_transactions
  is 'OpenAI-parsed MoMo SMS payment transactions allocated to driver subscription payment requests and activated subscriptions.';
