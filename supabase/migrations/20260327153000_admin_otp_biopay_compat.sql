begin;

-- ============================================================================
-- Admin OTP + secure BioPay compatibility
-- ============================================================================

create table if not exists public.otp_codes (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  profile_id uuid references public.profiles(id) on delete set null,
  code text not null check (char_length(code) = 6),
  expires_at timestamptz not null,
  attempts integer not null default 0 check (attempts >= 0),
  verified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.otp_codes
  add column if not exists profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists attempts integer,
  add column if not exists verified boolean,
  add column if not exists created_at timestamptz;

update public.otp_codes
set attempts = 0
where attempts is null;

update public.otp_codes
set verified = false
where verified is null;

update public.otp_codes
set created_at = timezone('utc', now())
where created_at is null;

alter table public.otp_codes
  alter column phone set not null,
  alter column code set not null,
  alter column expires_at set not null,
  alter column attempts set default 0,
  alter column attempts set not null,
  alter column verified set default false,
  alter column verified set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

create index if not exists idx_otp_phone_created
  on public.otp_codes(phone, created_at desc);

create index if not exists idx_otp_profile_created
  on public.otp_codes(profile_id, created_at desc);

create or replace function public.cleanup_expired_otps()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  delete from public.otp_codes
  where expires_at < timezone('utc', now()) - interval '1 hour';
end;
$$;

alter table public.otp_codes enable row level security;

revoke all on public.otp_codes from anon, authenticated;
grant all on public.otp_codes to service_role;

revoke all on function public.cleanup_expired_otps() from public, anon, authenticated;
grant execute on function public.cleanup_expired_otps() to service_role;

do $$ begin
  create type public.biopay_tx_type_enum as enum ('send', 'receive', 'top_up', 'withdraw');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.biopay_tx_status_enum as enum ('pending', 'completed', 'failed', 'cancelled');
exception when duplicate_object then null;
end $$;

create table if not exists public.biopay_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  balance numeric(12, 2) not null default 0.00 check (balance >= 0),
  currency text not null default 'RWF',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.biopay_wallets
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

drop trigger if exists set_biopay_wallets_updated_at on public.biopay_wallets;
create trigger set_biopay_wallets_updated_at
before update on public.biopay_wallets
for each row
execute function public.handle_updated_at();

create table if not exists public.biopay_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.biopay_wallets(id) on delete cascade,
  counterpart uuid references public.biopay_wallets(id),
  type public.biopay_tx_type_enum not null,
  status public.biopay_tx_status_enum not null default 'pending',
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'RWF',
  note text,
  qr_code_ref text,
  expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.biopay_transactions
  add column if not exists expires_at timestamptz,
  add column if not exists created_at timestamptz not null default timezone('utc', now());

create index if not exists idx_biopay_wallets_user
  on public.biopay_wallets(user_id);

create index if not exists idx_biopay_tx_wallet
  on public.biopay_transactions(wallet_id);

create index if not exists idx_biopay_tx_created
  on public.biopay_transactions(created_at desc);

create index if not exists idx_biopay_tx_qr_pending
  on public.biopay_transactions(qr_code_ref)
  where status = 'pending';

alter table public.biopay_wallets enable row level security;
alter table public.biopay_transactions enable row level security;

drop policy if exists "Users can view own wallet" on public.biopay_wallets;
drop policy if exists "Users can update own wallet" on public.biopay_wallets;
drop policy if exists "Users can view own transactions" on public.biopay_transactions;
drop policy if exists "Users can insert own transactions" on public.biopay_transactions;

create policy "Users can view own wallet"
  on public.biopay_wallets for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can view own transactions"
  on public.biopay_transactions for select
  to authenticated
  using (
    wallet_id in (
      select id from public.biopay_wallets where user_id = auth.uid()
    )
  );

revoke all on public.biopay_wallets from anon, authenticated;
revoke all on public.biopay_transactions from anon, authenticated;
grant select on public.biopay_wallets to authenticated;
grant select on public.biopay_transactions to authenticated;
grant all on public.biopay_wallets to service_role;
grant all on public.biopay_transactions to service_role;

create or replace function public.rpc_admin_list_users(
  p_role text default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  display_name text,
  phone text,
  role public.user_role_enum,
  is_driver boolean,
  vehicle_type public.vehicle_type_enum,
  member_id text,
  has_face_id boolean,
  is_online boolean,
  created_at timestamptz
)
language plpgsql
security definer set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.role = 'admin'
  ) then
    raise exception 'Unauthorized: admin role required';
  end if;

  return query
  select
    p.id,
    p.name,
    p.display_name,
    p.phone,
    p.role,
    p.is_driver,
    p.vehicle_type,
    p.member_id,
    exists (
      select 1
      from public.biopay_profiles bp
      where regexp_replace(coalesce(bp.recipient_phone_e164, ''), '[^0-9]', '', 'g') =
            regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
        and bp.status in ('pending', 'active', 'suspended')
    ) as has_face_id,
    p.is_online,
    p.created_at
  from public.profiles p
  where (p_role is null or p.role = p_role::public.user_role_enum)
    and (
      p_search is null or
      p.name ilike '%' || p_search || '%' or
      coalesce(p.display_name, '') ilike '%' || p_search || '%' or
      p.phone ilike '%' || p_search || '%' or
      p.member_id ilike '%' || p_search || '%'
    )
  order by p.created_at desc
  limit greatest(p_limit, 1)
  offset greatest(p_offset, 0);
end;
$$;

create or replace function public.rpc_get_biopay_wallet()
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  result json;
  wallet_id uuid;
begin
  select id
  into wallet_id
  from public.biopay_wallets
  where user_id = auth.uid();

  if wallet_id is null then
    insert into public.biopay_wallets (user_id, balance, currency)
    values (auth.uid(), 0.00, 'RWF')
    returning id into wallet_id;
  end if;

  select json_build_object(
    'id', w.id,
    'user_id', w.user_id,
    'balance', w.balance,
    'currency', w.currency,
    'is_active', w.is_active,
    'member_id', p.member_id,
    'handle_type', p.biopay_handle_type,
    'handle_value', p.biopay_handle_value,
    'has_face_id',
      exists (
        select 1
        from public.biopay_profiles bp
        where regexp_replace(coalesce(bp.recipient_phone_e164, ''), '[^0-9]', '', 'g') =
              regexp_replace(coalesce(p.phone, ''), '[^0-9]', '', 'g')
          and bp.status in ('pending', 'active', 'suspended')
      )
  )
  into result
  from public.biopay_wallets w
  join public.profiles p on p.id = w.user_id
  where w.user_id = auth.uid();

  return result;
end;
$$;

create or replace function public.rpc_update_biopay_handle(
  p_handle_type text,
  p_handle_value text
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  normalized_handle_type text;
begin
  normalized_handle_type := case lower(trim(coalesce(p_handle_type, '')))
    when 'phone' then 'number'
    when 'number' then 'number'
    when 'code' then 'code'
    else null
  end;

  if normalized_handle_type is null then
    raise exception 'Invalid BioPay handle type';
  end if;

  update public.profiles set
    biopay_handle_type = normalized_handle_type,
    biopay_handle_value = trim(coalesce(p_handle_value, ''))
  where id = auth.uid();
end;
$$;

create or replace function public.fn_biopay_generate_qr(
  p_amount numeric,
  p_currency text default 'RWF',
  p_note text default null
)
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  wallet_id uuid;
  tx_id uuid;
  qr_ref text;
  tx_expires_at timestamptz;
  result json;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select id into wallet_id
  from public.biopay_wallets
  where user_id = auth.uid();

  if wallet_id is null then
    insert into public.biopay_wallets (user_id, balance, currency)
    values (auth.uid(), 0.00, coalesce(nullif(trim(p_currency), ''), 'RWF'))
    returning id into wallet_id;
  end if;

  qr_ref := 'MOBI-' || substring(
    md5(random()::text || clock_timestamp()::text || coalesce(auth.uid()::text, 'anon'))
    from 1 for 16
  );
  tx_expires_at := timezone('utc', now()) + interval '30 minutes';

  insert into public.biopay_transactions (
    wallet_id,
    type,
    status,
    amount,
    currency,
    note,
    qr_code_ref,
    expires_at
  ) values (
    wallet_id,
    'receive',
    'pending',
    p_amount,
    coalesce(nullif(trim(p_currency), ''), 'RWF'),
    p_note,
    qr_ref,
    tx_expires_at
  )
  returning id into tx_id;

  select json_build_object(
    'qr_reference', qr_ref,
    'transaction_id', tx_id,
    'amount', p_amount,
    'currency', coalesce(nullif(trim(p_currency), ''), 'RWF'),
    'receiver_id', auth.uid(),
    'receiver_member_id', (select member_id from public.profiles where id = auth.uid()),
    'expires_at', tx_expires_at
  )
  into result;

  return result;
end;
$$;

create or replace function public.fn_biopay_resolve_qr_payload(p_qr_ref text)
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  result json;
begin
  select json_build_object(
    'transaction_id', t.id,
    'amount', t.amount,
    'currency', t.currency,
    'note', t.note,
    'status', t.status,
    'receiver_id', w.user_id,
    'receiver_name', coalesce(p.display_name, p.name),
    'receiver_member_id', p.member_id,
    'created_at', t.created_at
  )
  into result
  from public.biopay_transactions t
  join public.biopay_wallets w on w.id = t.wallet_id
  join public.profiles p on p.id = w.user_id
  where t.qr_code_ref = p_qr_ref
    and t.status = 'pending'
    and coalesce(t.expires_at, t.created_at + interval '30 minutes') > timezone('utc', now());

  return result;
end;
$$;

create or replace function public.fn_biopay_scan_and_charge(p_qr_ref text)
returns json
language plpgsql
security definer set search_path = ''
as $$
declare
  tx record;
  payer_wallet_id uuid;
  result json;
begin
  select t.*, w.user_id as receiver_user_id
  into tx
  from public.biopay_transactions t
  join public.biopay_wallets w on w.id = t.wallet_id
  where t.qr_code_ref = p_qr_ref
    and t.status = 'pending'
    and coalesce(t.expires_at, t.created_at + interval '30 minutes') > timezone('utc', now());

  if tx is null then
    return json_build_object('success', false, 'error', 'QR code not found or already used');
  end if;

  if tx.receiver_user_id = auth.uid() then
    return json_build_object('success', false, 'error', 'Cannot pay yourself');
  end if;

  select id into payer_wallet_id
  from public.biopay_wallets
  where user_id = auth.uid();

  if payer_wallet_id is null then
    insert into public.biopay_wallets (user_id, balance, currency)
    values (auth.uid(), 0.00, tx.currency)
    returning id into payer_wallet_id;
  end if;

  if (select balance from public.biopay_wallets where id = payer_wallet_id) < tx.amount then
    return json_build_object('success', false, 'error', 'Insufficient balance');
  end if;

  update public.biopay_wallets
  set balance = balance - tx.amount
  where id = payer_wallet_id;

  update public.biopay_wallets
  set balance = balance + tx.amount
  where id = tx.wallet_id;

  update public.biopay_transactions
  set
    status = 'completed',
    counterpart = payer_wallet_id
  where id = tx.id;

  insert into public.biopay_transactions (
    wallet_id,
    counterpart,
    type,
    status,
    amount,
    currency,
    note,
    qr_code_ref
  ) values (
    payer_wallet_id,
    tx.wallet_id,
    'send',
    'completed',
    tx.amount,
    tx.currency,
    tx.note,
    p_qr_ref
  );

  select json_build_object(
    'success', true,
    'transaction_id', tx.id,
    'amount', tx.amount,
    'currency', tx.currency
  )
  into result;

  return result;
end;
$$;

grant execute on function public.rpc_admin_list_users(text, text, integer, integer) to authenticated;
grant execute on function public.rpc_get_biopay_wallet() to authenticated;
grant execute on function public.rpc_update_biopay_handle(text, text) to authenticated;
grant execute on function public.fn_biopay_generate_qr(numeric, text, text) to authenticated;
grant execute on function public.fn_biopay_resolve_qr_payload(text) to authenticated;
grant execute on function public.fn_biopay_scan_and_charge(text) to authenticated;

commit;
