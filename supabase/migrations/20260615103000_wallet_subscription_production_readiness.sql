begin;

create or replace function public._referral_install_confidence(
  p_install_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_install_id text := lower(trim(coalesce(p_install_id, '')));
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
begin
  if v_metadata ? 'install_confidence' then
    return nullif(trim(v_metadata->>'install_confidence'), '');
  end if;

  if v_install_id = '' then
    return 'none';
  end if;

  if v_install_id like 'iosul_%' then
    return 'low_ios_universal_link';
  end if;

  if v_install_id like 'android_referrer_%'
    or v_install_id like 'play_install_referrer_%' then
    return 'high_play_install_referrer';
  end if;

  return 'medium_client_install_id';
end;
$$;

create or replace function public._set_referral_event_confidence_metadata()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_install_confidence text;
  v_reward_confidence text;
begin
  new.metadata := coalesce(new.metadata, '{}'::jsonb);
  v_install_confidence := public._referral_install_confidence(
    new.install_id,
    new.metadata
  );

  if v_install_confidence is not null then
    v_reward_confidence := case
      when new.status = 'rewarded' and v_install_confidence = 'high_play_install_referrer'
        then 'high'
      when new.status = 'rewarded' and v_install_confidence = 'low_ios_universal_link'
        then 'manual_review_recommended'
      when new.status = 'rewarded' and v_install_confidence = 'medium_client_install_id'
        then 'medium'
      when new.status = 'rewarded'
        then 'unknown'
      else coalesce(nullif(new.metadata->>'reward_confidence', ''), 'not_rewarded')
    end;

    new.metadata := new.metadata || jsonb_build_object(
      'install_confidence',
      v_install_confidence,
      'reward_confidence',
      v_reward_confidence
    );
  end if;

  return new;
end;
$$;

drop trigger if exists set_referral_event_confidence_metadata
  on public.app_referral_events;
create trigger set_referral_event_confidence_metadata
before insert or update of status, install_id, metadata
on public.app_referral_events
for each row execute function public._set_referral_event_confidence_metadata();

create or replace function public.rpc_lookup_wallet_transfer_recipient(
  p_receiver_member_id text
)
returns json
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_member_id text := regexp_replace(coalesce(p_receiver_member_id, ''), '[^0-9]', '', 'g');
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if v_member_id !~ '^[0-9]{6}$' then
    raise exception using message = 'INVALID_MEMBER_ID';
  end if;

  select *
  into v_profile
  from public.profiles
  where regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g') = v_member_id
  limit 1;

  if not found then
    raise exception using message = 'RECEIVER_NOT_FOUND';
  end if;

  if v_profile.id = v_user_id then
    raise exception using message = 'SELF_TRANSFER_NOT_ALLOWED';
  end if;

  return json_build_object(
    'member_id', v_member_id,
    'display_name', coalesce(
      nullif(v_profile.display_name, ''),
      nullif(v_profile.name, ''),
      'Mobio member'
    )
  );
end;
$$;

create or replace function public.rpc_admin_reverse_wallet_transfer(
  p_transfer_id uuid,
  p_reason text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transfer public.wallet_transfers%rowtype;
  v_sender_ledger_id uuid;
  v_receiver_ledger_id uuid;
  v_reason text := coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'Admin wallet transfer reversal');
begin
  if not (public._mobio_is_service_role() or public.is_platform_admin()) then
    raise exception using message = 'ADMIN_OR_SERVICE_ROLE_REQUIRED';
  end if;

  select *
  into v_transfer
  from public.wallet_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception using message = 'WALLET_TRANSFER_NOT_FOUND';
  end if;

  if v_transfer.status = 'reversed' then
    return json_build_object(
      'transfer_id', v_transfer.id,
      'status', 'already_reversed'
    );
  end if;

  v_receiver_ledger_id := public._debit_tokens(
    v_transfer.receiver_profile_id,
    v_transfer.amount_tokens,
    'admin_adjustment',
    'wallet_transfers',
    v_transfer.id,
    v_transfer.sender_profile_id,
    v_reason,
    jsonb_build_object('admin_action', 'wallet_transfer_reversal')
  );

  v_sender_ledger_id := public._credit_tokens(
    v_transfer.sender_profile_id,
    v_transfer.amount_tokens,
    'admin_adjustment',
    'wallet_transfers',
    v_transfer.id,
    v_transfer.receiver_profile_id,
    v_reason,
    jsonb_build_object('admin_action', 'wallet_transfer_reversal')
  );

  update public.wallet_transfers
  set
    status = 'reversed',
    note = concat_ws(' | ', nullif(note, ''), v_reason)
  where id = v_transfer.id;

  return json_build_object(
    'transfer_id', v_transfer.id,
    'status', 'reversed',
    'sender_ledger_entry_id', v_sender_ledger_id,
    'receiver_ledger_entry_id', v_receiver_ledger_id
  );
end;
$$;

create or replace function public.rpc_admin_expire_driver_subscription_payment_requests()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (public._mobio_is_service_role() or public.is_platform_admin()) then
    raise exception using message = 'ADMIN_OR_SERVICE_ROLE_REQUIRED';
  end if;

  update public.driver_subscription_payment_requests
  set status = 'expired', updated_at = now()
  where status in ('pending', 'dialer_opened')
    and expires_at < now();

  get diagnostics v_count = row_count;

  return json_build_object('expired_count', v_count);
end;
$$;

create or replace function public.rpc_admin_confirm_momo_sms_receipt(
  p_receipt_id uuid,
  p_review_note text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_receipt public.driver_subscription_momo_sms_receipts%rowtype;
  v_request public.driver_subscription_payment_requests%rowtype;
  v_subscription_id uuid;
  v_already_confirmed boolean := false;
begin
  if not (public._mobio_is_service_role() or public.is_platform_admin()) then
    raise exception using message = 'ADMIN_OR_SERVICE_ROLE_REQUIRED';
  end if;

  select *
  into v_receipt
  from public.driver_subscription_momo_sms_receipts
  where id = p_receipt_id
  for update;

  if not found then
    raise exception using message = 'MOMO_SMS_RECEIPT_NOT_FOUND';
  end if;

  if nullif(trim(coalesce(v_receipt.reference_code, '')), '') is null then
    raise exception using message = 'RECEIPT_REFERENCE_REQUIRED';
  end if;

  select *
  into v_request
  from public.driver_subscription_payment_requests
  where reference_code = upper(trim(v_receipt.reference_code))
    and payment_method = 'momo_ussd'
  for update;

  if not found then
    raise exception using message = 'SUBSCRIPTION_PAYMENT_NOT_FOUND';
  end if;

  v_already_confirmed := v_request.status = 'confirmed';

  if not v_already_confirmed then
    update public.driver_subscription_payment_requests
    set
      status = 'confirmed',
      confirmed_at = coalesce(v_receipt.received_at, now()),
      confirmation_source = 'admin_momo_sms_review',
      provider_transaction_ref = coalesce(
        nullif(v_receipt.provider_transaction_ref, ''),
        provider_transaction_ref
      ),
      metadata = metadata || jsonb_build_object(
        'momo_sms_receipt_id', v_receipt.id,
        'admin_review_note', nullif(trim(coalesce(p_review_note, '')), '')
      ),
      updated_at = now()
    where id = v_request.id;

    v_subscription_id := public._activate_driver_subscription(
      v_request.id,
      'admin_momo_sms_review'
    );
  else
    select s.id
    into v_subscription_id
    from public.driver_subscriptions s
    where s.external_subscription_id = v_request.reference_code
    order by s.created_at desc
    limit 1;
  end if;

  update public.driver_subscription_momo_sms_receipts
  set
    status = 'matched',
    matched_payment_request_id = v_request.id,
    metadata = metadata || jsonb_build_object(
      'admin_reviewed', true,
      'admin_review_note', nullif(trim(coalesce(p_review_note, '')), '')
    ),
    updated_at = now()
  where id = v_receipt.id
  returning * into v_receipt;

  return json_build_object(
    'id', v_receipt.id,
    'status', v_receipt.status,
    'matched_payment_request_id', v_request.id,
    'subscription_id', v_subscription_id,
    'already_confirmed', v_already_confirmed
  );
end;
$$;

revoke all on function public._referral_install_confidence(text, jsonb)
  from public, anon, authenticated;
revoke all on function public._set_referral_event_confidence_metadata()
  from public, anon, authenticated;
revoke all on function public.rpc_lookup_wallet_transfer_recipient(text)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_reverse_wallet_transfer(uuid, text)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_expire_driver_subscription_payment_requests()
  from public, anon, authenticated;
revoke all on function public.rpc_admin_confirm_momo_sms_receipt(uuid, text)
  from public, anon, authenticated;

grant execute on function public.rpc_lookup_wallet_transfer_recipient(text)
  to authenticated;
grant execute on function public.rpc_admin_reverse_wallet_transfer(uuid, text)
  to authenticated, service_role;
grant execute on function public.rpc_admin_expire_driver_subscription_payment_requests()
  to authenticated, service_role;
grant execute on function public.rpc_admin_confirm_momo_sms_receipt(uuid, text)
  to authenticated, service_role;

comment on function public.rpc_lookup_wallet_transfer_recipient(text)
  is 'Resolves a 6-digit member id to a limited display payload before a wallet transfer confirmation.';
comment on function public.rpc_admin_reverse_wallet_transfer(uuid, text)
  is 'Admin-only wallet transfer reversal that posts compensating immutable ledger entries.';
comment on function public.rpc_admin_confirm_momo_sms_receipt(uuid, text)
  is 'Admin-only manual review path for ambiguous or unmatched in-house MoMo SMS receipts.';

commit;
