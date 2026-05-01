-- MOBI Phase 1 follow-up:
-- - Keep QR/NFC session tables private while allowing authenticated scanners
--   to resolve valid, active scan payloads through RPCs.
-- - Move pg_stat_monitor extension objects out of public when possible so
--   Supabase lint does not fail on extension-owned functions.

create index if not exists idx_nfc_payment_sessions_ndef_payload_hash
  on public.nfc_payment_sessions using hash (ndef_payload);

create or replace function public.rpc_resolve_qr_payment_session(
  p_session_token text
)
returns table (
  session_id uuid,
  intent_id uuid,
  payment_method text,
  payee_id uuid,
  payee_member_id text,
  payee_display_name text,
  amount numeric,
  currency text,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := btrim(coalesce(p_session_token, ''));
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'authentication required';
  end if;

  if length(v_token) < 8 or length(v_token) > 255 then
    raise exception using
      errcode = '22023',
      message = 'invalid QR session token';
  end if;

  return query
  select
    s.id as session_id,
    s.intent_id,
    'qr'::text as payment_method,
    s.payee_id,
    p.member_id as payee_member_id,
    coalesce(nullif(p.display_name, ''), nullif(p.name, ''), 'MOBI member') as payee_display_name,
    coalesce(s.amount, i.amount) as amount,
    coalesce(nullif(i.currency, ''), 'RWF')::text as currency,
    s.status::text as status,
    s.expires_at
  from public.qr_payment_sessions s
  join public.profiles p on p.id = s.payee_id
  left join public.payment_intents i on i.id = s.intent_id
  where s.session_token = v_token
    and s.status = 'active'
    and s.expires_at > now()
  order by s.created_at desc
  limit 1;
end;
$$;

comment on function public.rpc_resolve_qr_payment_session(text)
  is 'Resolves one active QR payment session for an authenticated scanner without exposing qr_payment_sessions table reads.';

revoke all on function public.rpc_resolve_qr_payment_session(text) from public;
revoke all on function public.rpc_resolve_qr_payment_session(text) from anon;
revoke all on function public.rpc_resolve_qr_payment_session(text) from authenticated;
grant execute on function public.rpc_resolve_qr_payment_session(text) to authenticated;

create or replace function public.rpc_resolve_nfc_payment_session(
  p_ndef_payload text
)
returns table (
  session_id uuid,
  intent_id uuid,
  payment_method text,
  payee_id uuid,
  payee_member_id text,
  payee_display_name text,
  amount numeric,
  currency text,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload text := btrim(coalesce(p_ndef_payload, ''));
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'authentication required';
  end if;

  if length(v_payload) < 8 or length(v_payload) > 4096 then
    raise exception using
      errcode = '22023',
      message = 'invalid NFC payload';
  end if;

  return query
  select
    s.id as session_id,
    s.intent_id,
    'nfc'::text as payment_method,
    s.payee_id,
    p.member_id as payee_member_id,
    coalesce(nullif(p.display_name, ''), nullif(p.name, ''), 'MOBI member') as payee_display_name,
    coalesce(s.amount, i.amount) as amount,
    coalesce(nullif(i.currency, ''), 'RWF')::text as currency,
    s.status::text as status,
    s.expires_at
  from public.nfc_payment_sessions s
  join public.profiles p on p.id = s.payee_id
  left join public.payment_intents i on i.id = s.intent_id
  where s.ndef_payload = v_payload
    and s.status = 'active'
    and s.expires_at > now()
  order by s.created_at desc
  limit 1;
end;
$$;

comment on function public.rpc_resolve_nfc_payment_session(text)
  is 'Resolves one active NFC payment session for an authenticated reader without exposing nfc_payment_sessions table reads.';

revoke all on function public.rpc_resolve_nfc_payment_session(text) from public;
revoke all on function public.rpc_resolve_nfc_payment_session(text) from anon;
revoke all on function public.rpc_resolve_nfc_payment_session(text) from authenticated;
grant execute on function public.rpc_resolve_nfc_payment_session(text) to authenticated;

do $$
begin
  create schema if not exists extensions;

  if exists (
    select 1
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pg_stat_monitor'
      and n.nspname = 'public'
  ) then
    begin
      alter extension pg_stat_monitor set schema extensions;
    exception
      when insufficient_privilege then
        raise notice 'Unable to move pg_stat_monitor out of public because the migration role lacks extension ownership.';
      when feature_not_supported then
        raise notice 'Unable to move pg_stat_monitor out of public because the extension does not support schema relocation.';
    end;
  end if;
end $$;
