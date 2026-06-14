alter table public.driver_subscription_payment_requests
  add column if not exists client_request_id text;

create unique index if not exists uq_driver_subscription_payment_requests_client_request
  on public.driver_subscription_payment_requests(profile_id, client_request_id)
  where client_request_id is not null;

comment on column public.driver_subscription_payment_requests.client_request_id
  is 'Client-generated idempotency key for subscription start attempts.';

create or replace function public.rpc_start_driver_subscription(
  p_plan_id uuid,
  p_payment_method text,
  p_client_request_id text
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
  v_request public.driver_subscription_payment_requests%rowtype;
  v_request_id uuid := gen_random_uuid();
  v_client_request_id text := nullif(trim(coalesce(p_client_request_id, '')), '');
  v_member_id text;
  v_amount bigint;
  v_reference text;
  v_ussd text;
  v_subscription_id uuid;
  v_existing_subscription_id text;
  v_ledger_id uuid;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if p_payment_method not in ('tokens', 'momo_ussd') then
    raise exception using message = 'INVALID_PAYMENT_METHOD';
  end if;

  if v_client_request_id is not null then
    select *
    into v_request
    from public.driver_subscription_payment_requests
    where profile_id = v_user_id
      and client_request_id = v_client_request_id
    for update;

    if found then
      select s.id::text
      into v_existing_subscription_id
      from public.driver_subscriptions s
      where s.external_subscription_id = v_request.reference_code
      order by s.created_at desc
      limit 1;

      return json_build_object(
        'id', v_request.id,
        'status', v_request.status,
        'payment_method', v_request.payment_method,
        'reference_code', v_request.reference_code,
        'amount_tokens', v_request.amount_tokens,
        'amount_rwf', v_request.amount_rwf,
        'currency', v_request.currency,
        'momo_pay_code', v_request.momo_pay_code,
        'ussd_code', v_request.ussd_code,
        'subscription_id', coalesce(nullif(v_request.metadata->>'subscription_id', ''), v_existing_subscription_id),
        'expires_at', v_request.expires_at
      );
    end if;
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

  begin
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
      client_request_id,
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
      v_client_request_id,
      jsonb_build_object(
        'member_id', v_member_id,
        'plan_interval_days', v_plan.interval_days,
        'client_request_id', v_client_request_id
      )
    )
    returning *
    into v_request;
  exception
    when unique_violation then
      if v_client_request_id is null then
        raise;
      end if;

      select *
      into v_request
      from public.driver_subscription_payment_requests
      where profile_id = v_user_id
        and client_request_id = v_client_request_id
      for update;

      if not found then
        raise;
      end if;

      select s.id::text
      into v_existing_subscription_id
      from public.driver_subscriptions s
      where s.external_subscription_id = v_request.reference_code
      order by s.created_at desc
      limit 1;

      return json_build_object(
        'id', v_request.id,
        'status', v_request.status,
        'payment_method', v_request.payment_method,
        'reference_code', v_request.reference_code,
        'amount_tokens', v_request.amount_tokens,
        'amount_rwf', v_request.amount_rwf,
        'currency', v_request.currency,
        'momo_pay_code', v_request.momo_pay_code,
        'ussd_code', v_request.ussd_code,
        'subscription_id', coalesce(nullif(v_request.metadata->>'subscription_id', ''), v_existing_subscription_id),
        'expires_at', v_request.expires_at
      );
  end;

  if p_payment_method = 'tokens' then
    v_ledger_id := public._debit_tokens(
      v_user_id,
      v_amount,
      'subscription_payment',
      'driver_subscription_payment_requests',
      v_request.id,
      null,
      'Mobio Plus subscription ' || v_reference,
      jsonb_build_object(
        'plan_id', v_plan.id,
        'vehicle_type_id', v_plan.vehicle_type_id,
        'client_request_id', v_client_request_id
      )
    );

    v_subscription_id := public._activate_driver_subscription(v_request.id, 'token_wallet');

    update public.driver_subscription_payment_requests
    set
      confirmed_at = now(),
      confirmation_source = 'token_wallet',
      metadata = metadata || jsonb_build_object(
        'token_ledger_entry_id', v_ledger_id,
        'subscription_id', v_subscription_id
      ),
      updated_at = now()
    where id = v_request.id
    returning *
    into v_request;
  end if;

  return json_build_object(
    'id', v_request.id,
    'status', v_request.status,
    'payment_method', v_request.payment_method,
    'reference_code', v_request.reference_code,
    'amount_tokens', v_request.amount_tokens,
    'amount_rwf', v_request.amount_rwf,
    'currency', v_request.currency,
    'momo_pay_code', v_request.momo_pay_code,
    'ussd_code', v_request.ussd_code,
    'subscription_id', v_subscription_id,
    'expires_at', v_request.expires_at
  );
end;
$$;

create or replace function public.rpc_start_driver_subscription(
  p_plan_id uuid,
  p_payment_method text
)
returns json
language sql
security definer
set search_path = ''
as $$
  select public.rpc_start_driver_subscription(p_plan_id, p_payment_method, null::text);
$$;

revoke all on function public.rpc_start_driver_subscription(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.rpc_start_driver_subscription(uuid, text, text)
  to authenticated;

revoke all on function public.rpc_start_driver_subscription(uuid, text)
  from public, anon, authenticated;
grant execute on function public.rpc_start_driver_subscription(uuid, text)
  to authenticated;
