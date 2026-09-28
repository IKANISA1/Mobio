-- Forward BODY: default-off, per-collector allocation policy; exact invoice/merchant evidence.
-- This file has NOT been executed against PostgreSQL in this implementation environment.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

create table if not exists public.momobio_allocation_policies (
  collector_id uuid primary key references public.momobio_collectors(id) on delete cascade,
  enabled boolean not null default false,
  allowed_senders text[] not null default '{}',
  merchant_codes text[] not null default '{}',
  min_confidence numeric not null default 0.95 check(min_confidence between 0.95 and 1),
  evidence_policy text not null default 'mtn-en-received-invoice-v1'
    check(evidence_policy='mtn-en-received-invoice-v1'),
  acceptance_record text,
  updated_at timestamptz not null default now(),
  check(not enabled or (cardinality(allowed_senders)>0 and cardinality(merchant_codes)>0
    and length(trim(coalesce(acceptance_record,'')))>0))
);
alter table public.momobio_allocation_policies enable row level security;
revoke all on public.momobio_allocation_policies from public,anon,authenticated;
grant select,insert,update,delete on public.momobio_allocation_policies to service_role;
-- NO enabled policy or guessed merchant is seeded by this migration.

create or replace function public.rpc_ingest_driver_subscription_momo_sms(
  p_raw_sms text, p_sender text default null, p_received_at timestamptz default null,
  p_parsed jsonb default '{}'::jsonb
) returns json language plpgsql security definer set search_path='' as $$
declare
  v_raw text:=nullif(trim(coalesce(p_raw_sms,'')),'');
  v_sender text:=nullif(trim(coalesce(p_sender,'')),'');
  v_parsed jsonb:=coalesce(p_parsed,'{}'::jsonb);
  v_hash text; v_reference text; v_provider_ref text; v_merchant text;
  v_collector uuid; v_amount bigint; v_confidence numeric;
  v_policy public.momobio_allocation_policies%rowtype;
  v_receipt public.driver_subscription_momo_sms_receipts%rowtype;
  v_existing public.driver_subscription_momo_sms_receipts%rowtype;
  v_request public.driver_subscription_payment_requests%rowtype;
  v_reason text; v_parts text[]; v_count integer; v_explicit text;
  v_subscription uuid;
begin
  -- Automatic allocation is a signed-collector server operation, not a direct admin-client RPC.
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if v_raw is null or length(v_raw)>10000 or v_sender is null or length(v_sender)>100
    or p_received_at is null then
    raise exception 'INVALID_SMS_ENVELOPE' using errcode='22023';
  end if;
  v_hash:=encode(extensions.digest(v_raw||'|'||v_sender,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('momo-sms:'||v_hash,0));
  select * into v_receipt from public.driver_subscription_momo_sms_receipts where sms_hash=v_hash;
  if found then
    return json_build_object('id',v_receipt.id,'status',v_receipt.status,'duplicate',true,
      'matched_payment_request_id',v_receipt.matched_payment_request_id);
  end if;

  v_reference:=upper(nullif(trim(v_parsed->>'reference_code'),''));
  v_provider_ref:=nullif(trim(v_parsed->>'provider_transaction_ref'),'');
  v_merchant:=nullif(trim(v_parsed->>'momo_pay_code'),'');
  if coalesce(v_parsed->>'verified_collector_id','') ~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' then
    v_collector:=(v_parsed->>'verified_collector_id')::uuid;
  end if;
  select * into v_policy from public.momobio_allocation_policies
    where collector_id=v_collector and enabled for share;
  if not found then v_reason:='allocation_policy_disabled_or_missing'; end if;
  perform 1 from public.momobio_collectors
    where id=v_collector and revoked_at is null and expires_at>now() for share;
  if not found then v_reason:='collector_unavailable'; end if;
  if not exists(select 1 from unnest(v_policy.allowed_senders) as s(value)
    where lower(trim(value))=lower(v_sender)) then v_reason:='sender_not_approved'; end if;
  if v_merchant is null or v_merchant !~ '^[0-9]{3,20}$'
    or not coalesce(v_merchant=any(v_policy.merchant_codes),false) then v_reason:='merchant_not_approved'; end if;
  if v_parsed->'is_momo_payment' is distinct from 'true'::jsonb
    or v_parsed->'allocation_eligible' is distinct from 'true'::jsonb
    or v_parsed->>'evidence_policy' is distinct from 'mtn-en-received-invoice-v1' then
    v_reason:='payment_evidence_required';
  end if;
  if jsonb_typeof(v_parsed->'confidence')='number' then
    v_confidence:=(v_parsed->>'confidence')::numeric;
  end if;
  if v_confidence is null or v_confidence<coalesce(v_policy.min_confidence,0.95) or v_confidence>1 then
    v_reason:='classification_evidence_insufficient';
  end if;
  if jsonb_typeof(v_parsed->'amount_rwf')='number'
    and coalesce(v_parsed->>'amount_rwf','') ~ '^[1-9][0-9]{0,15}$' then
    if (v_parsed->>'amount_rwf')::numeric<=9007199254740991 then
      v_amount:=(v_parsed->>'amount_rwf')::bigint;
    end if;
  end if;
  if v_amount is null then v_reason:='invalid_amount'; end if;
  if v_reference is null or v_reference !~ '^[0-9]{6}-[A-Z0-9]{8}$' then v_reason:='invoice_reference_required'; end if;
  if v_provider_ref is null or v_provider_ref !~ '^[A-Za-z0-9][A-Za-z0-9._-]{5,79}$' then v_reason:='provider_reference_required'; end if;
  if p_received_at>now()+interval '5 minutes' then v_reason:='future_receipt_timestamp'; end if;

  -- Independent raw-field corroboration. No amount/time-only or suffix-based fallback.
  v_parts:=regexp_match(v_raw,'^\s*You have received\s+([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)\s+(RWF|FRW)\M','i');
  if v_parts is null then v_reason:='raw_amount_currency_unproven';
  elsif replace(v_parts[1],',','')::numeric is distinct from v_amount::numeric then
    v_reason:='raw_amount_currency_unproven';
  end if;
  select count(*),min(upper(parts[1])) into v_count,v_explicit
    from regexp_matches(v_raw,'\m(?:Reference|Code)\s*[:#]?\s*([0-9]{6}-[A-Za-z0-9]{8})\M','gi') as m(parts);
  if v_count<>1 or v_explicit is distinct from v_reference then v_reason:='raw_invoice_unproven'; end if;
  select count(*),min(regexp_replace(parts[1],'[.,;:]+$','')) into v_count,v_explicit
    from regexp_matches(v_raw,'\m(?:TxId|TxnId|Transaction\s+Id)\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9._-]{5,79})','gi') as m(parts);
  if v_count<>1 or v_explicit is distinct from v_provider_ref then v_reason:='raw_provider_reference_unproven'; end if;
  select count(*),min(parts[1]) into v_count,v_explicit
    from regexp_matches(v_raw,'\m(?:Payee\s+code|Merchant\s+code)\s*[:#]?\s*([0-9]{3,20})\M','gi') as m(parts);
  if v_count<>1 or v_explicit is distinct from v_merchant then v_reason:='raw_merchant_unproven'; end if;

  if v_reason is null then
    perform pg_advisory_xact_lock(hashtextextended('momo-tx:'||v_provider_ref,0));
    select * into v_existing from public.driver_subscription_momo_sms_receipts
      where provider_transaction_ref=v_provider_ref;
    if found then
      if v_existing.reference_code=v_reference and v_existing.amount_rwf=v_amount
        and v_existing.momo_pay_code=v_merchant then
        return json_build_object('id',v_existing.id,'status',v_existing.status,'duplicate',true,
          'matched_payment_request_id',v_existing.matched_payment_request_id);
      end if;
      v_reason:='provider_reference_already_bound';
    end if;
  end if;
  if v_reason is null then
    select * into v_request from public.driver_subscription_payment_requests
      where reference_code=v_reference for update;
    if not found then v_reason:='invoice_unavailable';
    elsif v_request.payment_method<>'momo_ussd' or v_request.status not in ('pending','dialer_opened') then
      v_reason:='invoice_not_pending';
    elsif v_request.amount_rwf<>v_amount or v_request.currency<>'RWF' or v_request.momo_pay_code<>v_merchant then
      v_reason:='invoice_amount_currency_or_merchant_mismatch';
    elsif p_received_at<v_request.created_at or p_received_at>v_request.expires_at then
      v_reason:='invoice_time_mismatch';
    end if;
  end if;
  if v_reason is not null then
    -- Unproven references do not reserve the unique provider reference or create credit.
    insert into public.driver_subscription_momo_sms_receipts(raw_sms,sms_hash,sender,received_at,momo_pay_code,status,metadata)
    values(v_raw,v_hash,v_sender,p_received_at,'','unmatched',jsonb_build_object(
      'review_required',true,'review_reason',v_reason,'verified_collector_id',v_collector,
      'evidence_policy','mtn-en-received-invoice-v1')) returning * into v_receipt;
    return json_build_object('id',v_receipt.id,'status','unmatched','review_required',true);
  end if;

  insert into public.driver_subscription_momo_sms_receipts(raw_sms,sms_hash,sender,received_at,
    amount_rwf,momo_pay_code,reference_code,provider_transaction_ref,status,matched_payment_request_id,metadata)
  values(v_raw,v_hash,v_sender,p_received_at,v_amount,v_merchant,v_reference,v_provider_ref,'matched',v_request.id,
    jsonb_build_object('verified_collector_id',v_collector,'evidence_policy','mtn-en-received-invoice-v1'))
  returning * into v_receipt;
  update public.driver_subscription_payment_requests set status='confirmed',confirmed_at=p_received_at,
    confirmation_source='momo_sms_bridge',provider_transaction_ref=v_provider_ref,
    metadata=metadata||jsonb_build_object('momo_sms_receipt_id',v_receipt.id),updated_at=now()
    where id=v_request.id;
  v_subscription:=public._activate_driver_subscription(v_request.id,'momo_sms_bridge');
  return json_build_object('id',v_receipt.id,'status','matched','reference_code',v_reference,
    'matched_payment_request_id',v_request.id,'subscription_id',v_subscription);
end $$;
revoke all on function public.rpc_ingest_driver_subscription_momo_sms(text,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.rpc_ingest_driver_subscription_momo_sms(text,text,timestamptz,jsonb) to service_role;

-- Current activation function with a shared entitlement lock added before period calculation.
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

  if v_request.status <> 'confirmed' then
    raise exception using message = 'SUBSCRIPTION_PAYMENT_NOT_CONFIRMED';
  end if;

  -- Different paid invoices lock the same entitlement before reading/adding periods.
  perform pg_advisory_xact_lock(hashtextextended(
    'driver-entitlement:'||v_request.profile_id::text||':'||v_request.vehicle_type_id,0));

  -- The locked invoice can activate once even if trusted callers retry.
  select id into v_subscription_id from public.driver_subscriptions
  where external_subscription_id=v_request.reference_code
    and profile_id=v_request.profile_id
  order by created_at limit 1;
  if v_subscription_id is not null then return v_subscription_id; end if;

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
$$
;

revoke all on function public._activate_driver_subscription(uuid,text) from public,anon,authenticated;
notify pgrst, 'reload schema';
commit;
