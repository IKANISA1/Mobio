begin;

create table if not exists public.app_platform_settings (
  key text primary key,
  value text not null default '',
  description text,
  is_public boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_app_platform_settings_updated_at
  on public.app_platform_settings;
create trigger set_app_platform_settings_updated_at
before update on public.app_platform_settings
for each row execute function public.handle_updated_at();

alter table public.app_platform_settings enable row level security;

drop policy if exists app_platform_settings_public_read
  on public.app_platform_settings;
create policy app_platform_settings_public_read
  on public.app_platform_settings
  for select
  to anon, authenticated
  using (is_public = true or public.has_platform_permission('platform.config.manage'));

drop policy if exists app_platform_settings_admin_write
  on public.app_platform_settings;
create policy app_platform_settings_admin_write
  on public.app_platform_settings
  for all
  to authenticated
  using (public.has_platform_permission('platform.config.manage'))
  with check (public.has_platform_permission('platform.config.manage'));

revoke insert, update, delete on public.app_platform_settings
  from anon, authenticated;
grant select on public.app_platform_settings to anon, authenticated;
grant all on public.app_platform_settings to service_role;

insert into public.app_platform_settings (key, value, description, is_public)
values
  (
    'insurance_agent_whatsapp_e164',
    '+250795588248',
    'WhatsApp number used by the BioPay motor-insurance promotion banner.',
    true
  ),
  (
    'token_redemption_admin_member_id',
    coalesce(
      (
        select regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g')
        from public.profiles
        where role::text = 'admin'
          and nullif(regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g'), '') is not null
        order by created_at asc
        limit 1
      ),
      ''
    ),
    'Six-digit admin wallet member ID that receives redeemed TOKENS before manual MoMo payout.',
    false
  )
on conflict (key) do update
set
  description = excluded.description,
  is_public = excluded.is_public,
  value = case
    when nullif(public.app_platform_settings.value, '') is null then excluded.value
    else public.app_platform_settings.value
  end,
  updated_at = now();

create table if not exists public.token_redemption_requests (
  id uuid primary key default gen_random_uuid(),
  requester_profile_id uuid not null references public.profiles(id) on delete cascade,
  admin_profile_id uuid not null references public.profiles(id) on delete restrict,
  wallet_transfer_id uuid not null references public.wallet_transfers(id) on delete restrict,
  amount_tokens bigint not null check (amount_tokens >= 5000),
  amount_rwf bigint not null check (amount_rwf >= 5000),
  currency text not null default 'RWF' check (currency = 'RWF'),
  momo_number text not null,
  admin_member_id text not null check (admin_member_id ~ '^[0-9]{6}$'),
  status text not null default 'pending'
    check (status in ('pending', 'cash_sent', 'cancelled', 'failed')),
  idempotency_key text not null,
  admin_note text,
  cash_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_profile_id, idempotency_key)
);

create index if not exists idx_token_redemption_requests_status_created
  on public.token_redemption_requests(status, created_at desc);

create index if not exists idx_token_redemption_requests_requester
  on public.token_redemption_requests(requester_profile_id, created_at desc);

drop trigger if exists set_token_redemption_requests_updated_at
  on public.token_redemption_requests;
create trigger set_token_redemption_requests_updated_at
before update on public.token_redemption_requests
for each row execute function public.handle_updated_at();

alter table public.token_redemption_requests enable row level security;

drop policy if exists token_redemption_requests_owner_read
  on public.token_redemption_requests;
create policy token_redemption_requests_owner_read
  on public.token_redemption_requests
  for select
  to authenticated
  using (requester_profile_id = auth.uid() or public.is_platform_admin());

revoke insert, update, delete on public.token_redemption_requests
  from anon, authenticated;
grant select on public.token_redemption_requests to authenticated;
grant all on public.token_redemption_requests to service_role;

create or replace function public.rpc_get_public_app_setting(
  p_key text,
  p_fallback text default null
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select nullif(trim(value), '')
      from public.app_platform_settings
      where key = p_key
        and is_public = true
      limit 1
    ),
    p_fallback,
    ''
  );
$$;

create or replace function public.rpc_admin_get_platform_settings()
returns json
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception using message = 'PLATFORM_CONFIG_PERMISSION_REQUIRED';
  end if;

  return json_build_object(
    'insurance_agent_whatsapp_e164',
    coalesce(
      (
        select value
        from public.app_platform_settings
        where key = 'insurance_agent_whatsapp_e164'
      ),
      '+250795588248'
    ),
    'token_redemption_admin_member_id',
    coalesce(
      (
        select value
        from public.app_platform_settings
        where key = 'token_redemption_admin_member_id'
      ),
      ''
    )
  );
end;
$$;

create or replace function public.rpc_admin_upsert_platform_setting(
  p_key text,
  p_value text
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text := trim(coalesce(p_key, ''));
  v_value text := trim(coalesce(p_value, ''));
  v_is_public boolean;
  v_description text;
begin
  if not public.has_platform_permission('platform.config.manage') then
    raise exception using message = 'PLATFORM_CONFIG_PERMISSION_REQUIRED';
  end if;

  if v_key = 'insurance_agent_whatsapp_e164' then
    v_value := '+' || regexp_replace(v_value, '[^0-9]', '', 'g');
    if v_value !~ '^\+[0-9]{8,15}$' then
      raise exception using message = 'INVALID_INSURANCE_WHATSAPP';
    end if;
    v_is_public := true;
    v_description := 'WhatsApp number used by the BioPay motor-insurance promotion banner.';
  elsif v_key = 'token_redemption_admin_member_id' then
    v_value := regexp_replace(v_value, '[^0-9]', '', 'g');
    if v_value !~ '^[0-9]{6}$' then
      raise exception using message = 'INVALID_ADMIN_WALLET_MEMBER_ID';
    end if;
    if not exists (
      select 1
      from public.profiles
      where regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g') = v_value
        and role::text = 'admin'
    ) then
      raise exception using message = 'ADMIN_WALLET_NOT_FOUND';
    end if;
    v_is_public := false;
    v_description := 'Six-digit admin wallet member ID that receives redeemed TOKENS before manual MoMo payout.';
  else
    raise exception using message = 'UNSUPPORTED_PLATFORM_SETTING';
  end if;

  insert into public.app_platform_settings (
    key,
    value,
    description,
    is_public,
    updated_by
  )
  values (v_key, v_value, v_description, v_is_public, auth.uid())
  on conflict (key) do update
  set
    value = excluded.value,
    description = excluded.description,
    is_public = excluded.is_public,
    updated_by = auth.uid(),
    updated_at = now();

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'upsert_platform_setting',
    'app_platform_setting',
    null,
    jsonb_build_object('key', v_key)
  );

  return public.rpc_admin_get_platform_settings();
end;
$$;

create or replace function public.rpc_redeem_wallet_tokens(
  p_amount_tokens bigint,
  p_idempotency_key text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_id uuid := auth.uid();
  v_requester public.profiles%rowtype;
  v_admin_member_id text;
  v_admin_id uuid;
  v_key text := coalesce(nullif(trim(p_idempotency_key), ''), gen_random_uuid()::text);
  v_existing public.token_redemption_requests%rowtype;
  v_transfer_id uuid;
  v_redemption_id uuid;
  v_sender_ledger_id uuid;
  v_receiver_ledger_id uuid;
  v_momo_number text;
begin
  if v_requester_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if p_amount_tokens < 5000 then
    raise exception using message = 'MINIMUM_REDEMPTION_TOKENS';
  end if;

  select *
  into v_existing
  from public.token_redemption_requests
  where requester_profile_id = v_requester_id
    and idempotency_key = v_key;

  if found then
    return json_build_object(
      'redemption_id', v_existing.id,
      'transfer_id', v_existing.wallet_transfer_id,
      'status', v_existing.status,
      'admin_member_id', v_existing.admin_member_id,
      'amount_tokens', v_existing.amount_tokens,
      'amount_rwf', v_existing.amount_rwf,
      'momo_number', v_existing.momo_number
    );
  end if;

  select *
  into v_requester
  from public.profiles
  where id = v_requester_id;

  if not found then
    raise exception using message = 'PROFILE_REQUIRED';
  end if;

  v_momo_number := public.fn_momo_local_number(v_requester.momo_number);
  if v_momo_number is null then
    raise exception using message = 'REGISTERED_MOMO_REQUIRED';
  end if;

  select nullif(regexp_replace(coalesce(value, ''), '[^0-9]', '', 'g'), '')
  into v_admin_member_id
  from public.app_platform_settings
  where key = 'token_redemption_admin_member_id';

  if v_admin_member_id is null or v_admin_member_id !~ '^[0-9]{6}$' then
    raise exception using message = 'ADMIN_WALLET_NOT_CONFIGURED';
  end if;

  select id
  into v_admin_id
  from public.profiles
  where regexp_replace(coalesce(member_id, ''), '[^0-9]', '', 'g') = v_admin_member_id
    and role::text = 'admin'
  limit 1;

  if v_admin_id is null then
    raise exception using message = 'ADMIN_WALLET_NOT_FOUND';
  end if;

  if v_admin_id = v_requester_id then
    raise exception using message = 'ADMIN_WALLET_SELF_REDEMPTION';
  end if;

  insert into public.wallet_transfers (
    sender_profile_id,
    receiver_profile_id,
    amount_tokens,
    idempotency_key,
    note
  )
  values (
    v_requester_id,
    v_admin_id,
    p_amount_tokens,
    v_key,
    'Token redemption for manual MoMo cash payout'
  )
  returning id into v_transfer_id;

  v_sender_ledger_id := public._debit_tokens(
    v_requester_id,
    p_amount_tokens,
    'wallet_transfer',
    'wallet_transfers',
    v_transfer_id,
    v_admin_id,
    'Token redemption for manual MoMo cash payout',
    jsonb_build_object('wallet_action', 'token_redemption')
  );

  v_receiver_ledger_id := public._credit_tokens(
    v_admin_id,
    p_amount_tokens,
    'wallet_transfer',
    'wallet_transfers',
    v_transfer_id,
    v_requester_id,
    'Token redemption received for manual MoMo cash payout',
    jsonb_build_object('wallet_action', 'token_redemption')
  );

  insert into public.token_redemption_requests (
    requester_profile_id,
    admin_profile_id,
    wallet_transfer_id,
    amount_tokens,
    amount_rwf,
    momo_number,
    admin_member_id,
    idempotency_key
  )
  values (
    v_requester_id,
    v_admin_id,
    v_transfer_id,
    p_amount_tokens,
    p_amount_tokens,
    v_momo_number,
    v_admin_member_id,
    v_key
  )
  returning id into v_redemption_id;

  return json_build_object(
    'redemption_id', v_redemption_id,
    'transfer_id', v_transfer_id,
    'status', 'pending',
    'admin_member_id', v_admin_member_id,
    'amount_tokens', p_amount_tokens,
    'amount_rwf', p_amount_tokens,
    'momo_number', v_momo_number,
    'sender_ledger_entry_id', v_sender_ledger_id,
    'receiver_ledger_entry_id', v_receiver_ledger_id
  );
end;
$$;

create or replace function public.rpc_admin_list_token_redemption_requests(
  p_status text default 'pending',
  p_limit integer default 20
)
returns table (
  id uuid,
  requester_profile_id uuid,
  requester_name text,
  requester_phone text,
  requester_member_id text,
  admin_member_id text,
  momo_number text,
  amount_tokens bigint,
  amount_rwf bigint,
  status text,
  admin_note text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    request.id,
    request.requester_profile_id,
    coalesce(nullif(profile.display_name, ''), nullif(profile.name, ''), 'Mobio member') as requester_name,
    coalesce(nullif(profile.phone, ''), nullif(profile.whatsapp, '')) as requester_phone,
    profile.member_id as requester_member_id,
    request.admin_member_id,
    request.momo_number,
    request.amount_tokens,
    request.amount_rwf,
    request.status,
    request.admin_note,
    request.created_at
  from public.token_redemption_requests request
  join public.profiles profile on profile.id = request.requester_profile_id
  where public.has_platform_permission('admin.finance.review')
    and (p_status is null or request.status = p_status)
  order by request.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

create or replace function public.rpc_admin_update_token_redemption_status(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.token_redemption_requests%rowtype;
  v_profile public.profiles%rowtype;
begin
  if not public.has_platform_permission('admin.finance.review') then
    raise exception using message = 'ADMIN_FINANCE_PERMISSION_REQUIRED';
  end if;

  if p_status not in ('pending', 'cash_sent', 'cancelled', 'failed') then
    raise exception using message = 'INVALID_REDEMPTION_STATUS';
  end if;

  update public.token_redemption_requests
  set
    status = p_status,
    admin_note = nullif(trim(coalesce(p_admin_note, '')), ''),
    cash_sent_at = case when p_status = 'cash_sent' then now() else cash_sent_at end,
    updated_at = now()
  where id = p_request_id
  returning * into v_request;

  if not found then
    raise exception using message = 'TOKEN_REDEMPTION_NOT_FOUND';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = v_request.requester_profile_id;

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'update_token_redemption_status',
    'token_redemption_request',
    v_request.id,
    jsonb_build_object('status', p_status)
  );

  return json_build_object(
    'id', v_request.id,
    'requester_profile_id', v_request.requester_profile_id,
    'requester_name', coalesce(nullif(v_profile.display_name, ''), nullif(v_profile.name, ''), 'Mobio member'),
    'requester_phone', coalesce(nullif(v_profile.phone, ''), nullif(v_profile.whatsapp, '')),
    'requester_member_id', v_profile.member_id,
    'admin_member_id', v_request.admin_member_id,
    'momo_number', v_request.momo_number,
    'amount_tokens', v_request.amount_tokens,
    'amount_rwf', v_request.amount_rwf,
    'status', v_request.status,
    'admin_note', v_request.admin_note,
    'created_at', v_request.created_at
  );
end;
$$;

create or replace function public.rpc_admin_adjust_user_tokens(
  p_profile_id uuid,
  p_amount_tokens bigint,
  p_note text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_id uuid;
  v_note text := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Admin TOKEN adjustment');
begin
  if not public.has_platform_permission('admin.finance.review') then
    raise exception using message = 'ADMIN_FINANCE_PERMISSION_REQUIRED';
  end if;

  if p_profile_id is null then
    raise exception using message = 'PROFILE_REQUIRED';
  end if;

  if p_amount_tokens <= 0 then
    raise exception using message = 'INVALID_TOKEN_AMOUNT';
  end if;

  if p_amount_tokens > 1000000 then
    raise exception using message = 'TOKEN_ADJUSTMENT_LIMIT_EXCEEDED';
  end if;

  if not exists (select 1 from public.profiles where id = p_profile_id) then
    raise exception using message = 'PROFILE_NOT_FOUND';
  end if;

  v_ledger_id := public._credit_tokens(
    p_profile_id,
    p_amount_tokens,
    'admin_adjustment',
    null,
    null,
    auth.uid(),
    v_note,
    jsonb_build_object('admin_action', 'manual_token_credit')
  );

  insert into public.admin_audit_log (
    admin_id,
    action,
    target_type,
    target_id,
    details
  )
  values (
    auth.uid(),
    'admin_adjust_user_tokens',
    'profile',
    p_profile_id,
    jsonb_build_object(
      'amount_tokens', p_amount_tokens,
      'note', v_note,
      'ledger_entry_id', v_ledger_id
    )
  );

  return json_build_object(
    'ledger_entry_id', v_ledger_id,
    'profile_id', p_profile_id,
    'amount_tokens', p_amount_tokens,
    'status', 'completed'
  );
end;
$$;

revoke all on function public.rpc_get_public_app_setting(text, text)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_get_platform_settings()
  from public, anon, authenticated;
revoke all on function public.rpc_admin_upsert_platform_setting(text, text)
  from public, anon, authenticated;
revoke all on function public.rpc_redeem_wallet_tokens(bigint, text)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_list_token_redemption_requests(text, integer)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_update_token_redemption_status(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.rpc_admin_adjust_user_tokens(uuid, bigint, text)
  from public, anon, authenticated;

grant execute on function public.rpc_get_public_app_setting(text, text)
  to anon, authenticated;
grant execute on function public.rpc_admin_get_platform_settings()
  to authenticated;
grant execute on function public.rpc_admin_upsert_platform_setting(text, text)
  to authenticated;
grant execute on function public.rpc_redeem_wallet_tokens(bigint, text)
  to authenticated;
grant execute on function public.rpc_admin_list_token_redemption_requests(text, integer)
  to authenticated;
grant execute on function public.rpc_admin_update_token_redemption_status(uuid, text, text)
  to authenticated;
grant execute on function public.rpc_admin_adjust_user_tokens(uuid, bigint, text)
  to authenticated;

comment on function public.rpc_redeem_wallet_tokens(bigint, text)
  is 'Creates an idempotent token redemption by moving TOKENS to the configured admin wallet and queueing a manual MoMo payout request.';

comment on function public.rpc_admin_adjust_user_tokens(uuid, bigint, text)
  is 'Admin-only audited TOKEN credit used for manual rewards such as the motor-insurance 3000 TOKEN incentive.';

commit;
