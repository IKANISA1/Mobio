-- Referral reward alignment: manual invite-code entry rewards both sides once.

create unique index if not exists uq_referral_reward_invitee_once
  on public.app_referral_events(invitee_profile_id)
  where status = 'rewarded' and invitee_profile_id is not null;

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
  v_inviter_ledger_id uuid;
  v_invitee_ledger_id uuid;
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
      v_install_id,
      v_device_hash,
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
  where invitee_profile_id = v_invitee_id
    and status = 'rewarded'
  limit 1;

  if v_event_id is not null then
    return json_build_object(
      'event_id', v_event_id,
      'status', 'already_rewarded',
      'reward_tokens', 0
    );
  end if;

  if v_install_id is not null then
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

  v_inviter_ledger_id := public._credit_tokens(
    v_code.profile_id,
    100,
    'referral_reward',
    'app_referral_events',
    v_event_id,
    v_invitee_id,
    'Successful Mobio app share',
    jsonb_build_object('reward_side', 'inviter')
  );

  v_invitee_ledger_id := public._credit_tokens(
    v_invitee_id,
    100,
    'referral_reward',
    'app_referral_events',
    v_event_id,
    v_code.profile_id,
    'Mobio invite code signup reward',
    jsonb_build_object('reward_side', 'invitee')
  );

  update public.app_referral_events
  set
    status = 'rewarded',
    reward_tokens = 100,
    reward_ledger_entry_id = v_inviter_ledger_id,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'invitee_reward_tokens', 100,
      'invitee_reward_ledger_entry_id', v_invitee_ledger_id
    ),
    rewarded_at = now(),
    updated_at = now()
  where id = v_event_id;

  return json_build_object(
    'event_id', v_event_id,
    'status', 'rewarded',
    'reward_tokens', 100,
    'inviter_reward_tokens', 100,
    'invitee_reward_tokens', 100
  );
end;
$$;
