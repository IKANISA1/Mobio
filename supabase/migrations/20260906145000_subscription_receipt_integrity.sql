-- Bind trusted receipt allocation to the invoice amount/time and make activation idempotent.
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

  -- Serialize identical device retries before checking the durable receipt.
  perform pg_advisory_xact_lock(hashtextextended('momo-sms:' || v_sms_hash, 0));
  if v_provider_ref is not null then
    perform pg_advisory_xact_lock(hashtextextended('momo-tx:' || v_provider_ref, 0));
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
    left join public.profiles p on p.id = r.profile_id
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
      and (
        v_payer_phone is null
        or public._momo_phone_match(r.metadata->>'payer_phone', v_payer_phone)
        or public._momo_phone_match(p.phone, v_payer_phone)
        or public._momo_phone_match(p.whatsapp, v_payer_phone)
      );

    if v_candidate_count = 1 then
      select r.*
      into v_request
      from public.driver_subscription_payment_requests r
      left join public.profiles p on p.id = r.profile_id
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
        and (
          v_payer_phone is null
          or public._momo_phone_match(r.metadata->>'payer_phone', v_payer_phone)
          or public._momo_phone_match(p.phone, v_payer_phone)
          or public._momo_phone_match(p.whatsapp, v_payer_phone)
        )
      order by r.created_at desc
      limit 1
      for update of r;
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

  -- A reference identifies an invoice; it does not establish the amount paid.
  -- Keep under/overpayments and stale invoices for explicit Admin review.
  if v_amount is null or v_amount <> v_request.amount_rwf
    or v_request.created_at > v_received_at + interval '10 minutes'
    or v_request.expires_at < v_received_at - interval '10 minutes' then
    update public.driver_subscription_momo_sms_receipts
    set status='unmatched', updated_at=now(),
        metadata=metadata || jsonb_build_object('match_reason', case
          when v_amount is null or v_amount <> v_request.amount_rwf then 'invoice_amount_mismatch'
          else 'invoice_time_mismatch' end)
    where id=v_receipt.id returning * into v_receipt;
    return json_build_object('id',v_receipt.id,'status',v_receipt.status);
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
      'momo_sms_received_at', v_received_at,
      'momo_sms_match_fields', jsonb_strip_nulls(jsonb_build_object(
        'reference_code', v_reference,
        'member_id', v_member_id,
        'payer_phone', v_payer_phone,
        'amount_rwf', v_amount
      ))
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
$$
;

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
