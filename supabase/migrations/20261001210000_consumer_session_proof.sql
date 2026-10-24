-- CR23: durable account metadata is not proof of the caller's WhatsApp login.
-- Existing sessions receive no implicit proof. Existing trusted phone authority
-- is snapshotted once; previously compromised accounts require reconciliation.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table mobio_private.whatsapp_identity_bindings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_e164 text unique not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  provider text not null check (provider in ('whatsapp_cloud_otp','admin_whatsapp_otp')),
  bound_at timestamptz not null,
  otp_reference text not null
);
create table mobio_private.consumer_session_proofs (
  session_id uuid primary key references auth.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null,
  otp_reference text unique not null,
  authenticated_at timestamptz not null,
  revoked_at timestamptz
);
create index consumer_session_proofs_user_idx on mobio_private.consumer_session_proofs(user_id);
alter table mobio_private.whatsapp_identity_bindings enable row level security;
alter table mobio_private.consumer_session_proofs enable row level security;
revoke all on mobio_private.whatsapp_identity_bindings, mobio_private.consumer_session_proofs
  from public, anon, authenticated, service_role;
insert into mobio_private.whatsapp_identity_bindings(user_id,phone_e164,provider,bound_at,otp_reference)
select u.id, '+' || ltrim(u.phone,'+'), u.raw_app_meta_data->>'provider', clock_timestamp(),
  'migration:20261001210000:' || u.id::text
from auth.users u where u.phone_confirmed_at is not null and not coalesce(u.is_anonymous,false)
  and u.deleted_at is null and (u.banned_until is null or u.banned_until <= clock_timestamp())
  and '+' || ltrim(u.phone,'+') ~ '^\+[1-9][0-9]{7,14}$'
  and u.raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp','admin_whatsapp_otp')
  and not exists(select 1 from mobio_private.store_review_principals r where r.user_id=u.id);

-- VOLATILE intentionally re-reads committed authority after an action's locks.
-- No row locks here: RLS and STABLE RPCs run in read-only PostgREST transactions.
-- A recipient may be signed out; account eligibility does not require a session.
create function mobio_private.verified_interactive_account_is_eligible(p_user_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare account auth.users%rowtype; binding mobio_private.whatsapp_identity_bindings%rowtype;
  stamp timestamptz := clock_timestamp();
begin
  select * into account from auth.users where id=p_user_id;
  stamp:=clock_timestamp();
  if not found or account.deleted_at is not null or coalesce(account.is_anonymous,false)
    or account.banned_until > stamp or account.phone_confirmed_at is null
    or account.raw_app_meta_data->>'provider' not in ('whatsapp_cloud_otp','admin_whatsapp_otp')
    or account.raw_app_meta_data->>'provider' is null
    or exists(select 1 from mobio_private.store_review_principals where user_id=p_user_id)
    then return false; end if;
  select * into binding from mobio_private.whatsapp_identity_bindings where user_id=p_user_id;
  if not found or binding.phone_e164 is distinct from '+' || ltrim(account.phone,'+')
    then return false; end if;
  if account.raw_app_meta_data->>'provider'='admin_whatsapp_otp' then
    return exists(select 1 from public.admin_whatsapp_numbers where is_active
      and phone_e164=binding.phone_e164);
  end if;
  return not exists(select 1 from public.profiles where id=p_user_id and role='admin');
end $$;
revoke all on function mobio_private.verified_interactive_account_is_eligible(uuid)
  from public, anon, authenticated, service_role;

-- Used by service-only Face/Maps wrappers with an explicit validated owner/SID.
create function mobio_private.require_verified_interactive_session(
  p_user_id uuid, p_session_id uuid, p_requires_recent boolean default false
) returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare provider text; lease mobio_private.admin_session_leases%rowtype;
  policy mobio_private.admin_session_policy%rowtype; stamp timestamptz := clock_timestamp();
begin
  perform 1 from auth.users where id=p_user_id for share;
  perform 1 from mobio_private.whatsapp_identity_bindings where user_id=p_user_id for share;
  if p_requires_recent is null or not mobio_private.verified_interactive_account_is_eligible(p_user_id)
    then raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
  perform 1 from auth.sessions where id=p_session_id and user_id=p_user_id
    for share;
  if not found then raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
  stamp:=clock_timestamp();
  if exists(select 1 from auth.sessions where id=p_session_id and not_after<=stamp) then
    raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
  select raw_app_meta_data->>'provider' into provider from auth.users where id=p_user_id;
  if provider='admin_whatsapp_otp' then
    select * into lease from mobio_private.admin_session_leases
      where session_id=p_session_id and user_id=p_user_id for share;
    stamp:=clock_timestamp();
    if not found or lease.revoked_at is not null or lease.authenticated_at > stamp
      or lease.idle_expires_at <= stamp or lease.absolute_expires_at <= stamp then
      if p_requires_recent then
        raise exception 'ADMIN_REAUTHENTICATION_REQUIRED' using errcode='42501';
      end if;
      raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
    if p_requires_recent then
      select * into strict policy from mobio_private.admin_session_policy where singleton;
      if lease.authenticated_at <= stamp-make_interval(secs=>policy.recent_auth_seconds) then
        raise exception 'ADMIN_REAUTHENTICATION_REQUIRED' using errcode='42501'; end if;
    end if;
  elsif not exists(select 1 from mobio_private.consumer_session_proofs p
    join mobio_private.whatsapp_identity_bindings b on b.user_id=p.user_id
    where p.user_id=p_user_id and p.session_id=p_session_id and p.revoked_at is null
      and p.authenticated_at <= stamp and p.phone_e164=b.phone_e164) then
    raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501';
  end if;
  if exists(select 1 from auth.sessions where id=p_session_id and not_after<=clock_timestamp()) then
    raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
  return p_user_id;
end $$;
revoke all on function mobio_private.require_verified_interactive_session(uuid,uuid,boolean)
  from public, anon, authenticated, service_role;

create function mobio_private.interactive_session_is_verified(p_user_id uuid,p_session_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare provider text; stamp timestamptz;
begin
  if not mobio_private.verified_interactive_account_is_eligible(p_user_id) then return false; end if;
  select raw_app_meta_data->>'provider' into provider from auth.users where id=p_user_id;
  stamp:=clock_timestamp();
  if not exists(select 1 from auth.sessions where id=p_session_id and user_id=p_user_id
    and (not_after is null or not_after>stamp)) then return false; end if;
  if provider='admin_whatsapp_otp' then
    return exists(select 1 from mobio_private.admin_session_leases where session_id=p_session_id and user_id=p_user_id
      and revoked_at is null and authenticated_at<=stamp and idle_expires_at>stamp and absolute_expires_at>stamp);
  end if;
  return exists(select 1 from mobio_private.consumer_session_proofs p
    join mobio_private.whatsapp_identity_bindings b on b.user_id=p.user_id
    where p.user_id=p_user_id and p.session_id=p_session_id and p.revoked_at is null
      and p.authenticated_at<=stamp and p.phone_e164=b.phone_e164);
end $$;
revoke all on function mobio_private.interactive_session_is_verified(uuid,uuid)
  from public, anon, authenticated, service_role;

create function mobio_private.bind_whatsapp_otp_account(p_user_id uuid,p_otp_reference text,p_purpose text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare account auth.users%rowtype; otp public.otp_codes%rowtype;
  binding mobio_private.whatsapp_identity_bindings%rowtype; phone text;
begin
  select * into account from auth.users where id=p_user_id for share;
  if not found or account.deleted_at is not null or coalesce(account.is_anonymous,false)
    or account.banned_until > clock_timestamp() or account.phone_confirmed_at is null
    or account.raw_app_meta_data->>'provider' is distinct from
      (case when p_purpose='admin_login' then 'admin_whatsapp_otp' else 'whatsapp_cloud_otp' end)
    or exists(select 1 from mobio_private.store_review_principals where user_id=p_user_id)
    then raise exception 'WHATSAPP_BINDING_REJECTED' using errcode='42501'; end if;
  phone := '+' || ltrim(account.phone,'+');
  select * into otp from public.otp_codes where id::text=p_otp_reference for share;
  if not found or p_purpose not in ('app_login','admin_login') or otp.purpose<>p_purpose
    or not otp.verified or otp.expires_at <= clock_timestamp()
    or '+' || ltrim(otp.phone,'+') is distinct from phone
    or otp.code_hash is null or length(otp.code_hash)<>64 then
    raise exception 'WHATSAPP_BINDING_REJECTED' using errcode='42501'; end if;
  insert into mobio_private.whatsapp_identity_bindings(user_id,phone_e164,provider,bound_at,otp_reference)
    values(p_user_id,phone,account.raw_app_meta_data->>'provider',clock_timestamp(),p_otp_reference)
    on conflict(user_id) do nothing;
  select * into strict binding from mobio_private.whatsapp_identity_bindings where user_id=p_user_id for share;
  if binding.phone_e164 is distinct from phone then
    raise exception 'WHATSAPP_BINDING_REJECTED' using errcode='42501'; end if;
  return phone;
end $$;
revoke all on function mobio_private.bind_whatsapp_otp_account(uuid,text,text)
  from public, anon, authenticated, service_role;

create function public.rpc_register_app_whatsapp_session(p_user_id uuid,p_session_id uuid,p_otp_reference text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare phone text; proof mobio_private.consumer_session_proofs%rowtype; stamp timestamptz:=clock_timestamp();
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  phone:=mobio_private.bind_whatsapp_otp_account(p_user_id,p_otp_reference,'app_login');
  perform 1 from auth.sessions where id=p_session_id and user_id=p_user_id
    and created_at between stamp-interval '2 minutes' and stamp
    and (not_after is null or not_after > stamp) for share;
  if not found then raise exception 'WHATSAPP_SESSION_BINDING_REJECTED' using errcode='42501'; end if;
  insert into mobio_private.consumer_session_proofs(session_id,user_id,phone_e164,otp_reference,authenticated_at)
    values(p_session_id,p_user_id,phone,p_otp_reference,stamp) on conflict(session_id) do nothing;
  select * into strict proof from mobio_private.consumer_session_proofs where session_id=p_session_id;
  if proof.user_id<>p_user_id or proof.otp_reference<>p_otp_reference or proof.revoked_at is not null
    then raise exception 'WHATSAPP_SESSION_BINDING_REJECTED' using errcode='42501'; end if;
  perform mobio_private.require_verified_interactive_session(p_user_id,p_session_id,false);
  return jsonb_build_object('user_id',p_user_id,'session_id',p_session_id);
end $$;
revoke all on function public.rpc_register_app_whatsapp_session(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.rpc_register_app_whatsapp_session(uuid,uuid,text) to service_role;

-- Returning legacy accounts can only be selected after this request's OTP claim.
-- The durable binding prevents a changed Auth phone from reassigning ownership.
create function public.rpc_lookup_whatsapp_otp_phone_owner(p_phone text,p_otp_reference text,p_purpose text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare candidate auth.users%rowtype; matches integer; binding_phone text;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_phone !~ '^\+[1-9][0-9]{7,14}$' or p_purpose not in ('app_login','admin_login')
    or not exists(select 1 from public.otp_codes where id::text=p_otp_reference
      and purpose=p_purpose and verified and expires_at>clock_timestamp()
      and phone=p_phone and code_hash is not null and length(code_hash)=64) then
    raise exception 'WHATSAPP_BINDING_REJECTED' using errcode='42501'; end if;
  select count(*) into matches from auth.users where phone in(p_phone,substring(p_phone from 2));
  if matches=0 then return null; end if;
  if matches<>1 then raise exception 'AMBIGUOUS_PHONE_IDENTITY' using errcode='42501'; end if;
  select * into strict candidate from auth.users where phone in(p_phone,substring(p_phone from 2)) for share;
  select phone_e164 into binding_phone from mobio_private.whatsapp_identity_bindings where user_id=candidate.id for share;
  if candidate.deleted_at is not null or coalesce(candidate.is_anonymous,false)
    or candidate.banned_until>clock_timestamp() or candidate.phone_confirmed_at is null
    or candidate.raw_app_meta_data->>'provider' not in ('whatsapp_cloud_otp','admin_whatsapp_otp')
    or candidate.raw_app_meta_data->>'provider' is null or binding_phone is distinct from p_phone
    or exists(select 1 from mobio_private.store_review_principals where user_id=candidate.id) then
    raise exception 'PHONE_IDENTITY_UNAVAILABLE' using errcode='42501'; end if;
  return candidate.id;
end $$;
revoke all on function public.rpc_lookup_whatsapp_otp_phone_owner(text,text,text) from public,anon,authenticated;
grant execute on function public.rpc_lookup_whatsapp_otp_phone_owner(text,text,text) to service_role;

create function public.rpc_verified_interactive_session()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid:=public.verified_app_user_id(); sid uuid;
begin
  if actor is null then raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end if;
  begin sid:=(auth.jwt()->>'session_id')::uuid;
  exception when invalid_text_representation then raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode='42501'; end;
  perform mobio_private.require_verified_interactive_session(actor,sid,false);
  return jsonb_build_object('user_id',actor,'session_id',sid);
end $$;
revoke all on function public.rpc_verified_interactive_session() from public,anon,service_role;
grant execute on function public.rpc_verified_interactive_session() to authenticated;

-- Guarded installed-body rewrites preserve previous review denial, Admin leases,
-- owners/search paths/ACLs and future-auth denial. Unknown bodies abort deployment.
do $$
declare routine record; definition text; anchor text; signature text;
begin
  foreach signature in array array['public.verified_app_user_id()','public.verified_admin_user_id()'] loop
    select oid,proowner,proacl,proconfig into strict routine from pg_proc where oid=signature::regprocedure;
    definition:=pg_get_functiondef(routine.oid); anchor:='and not public.is_store_review_principal()';
    if position(anchor in definition)=0 or position('public.live_auth_user_id()' in definition)=0 then
      raise exception 'Unexpected installed interactive identity body: %',signature; end if;
    definition:=replace(definition,anchor,anchor || E'\n    and mobio_private.interactive_session_is_verified(u.id, (auth.jwt()->>''session_id'')::uuid)');
    if signature='public.verified_app_user_id()' then
      anchor:='u.raw_app_meta_data->>''provider'' in (''whatsapp_cloud_otp'', ''admin_whatsapp_otp'')';
      if position(anchor in definition)=0 then raise exception 'Unexpected installed consumer provider body'; end if;
      definition:=replace(definition,anchor,anchor || E'\n    and auth.jwt()->''app_metadata''->>''provider'' = u.raw_app_meta_data->>''provider''\n    and (u.raw_app_meta_data->>''provider'' <> ''admin_whatsapp_otp'' or public.verified_admin_user_id() = u.id)');
    end if;
    execute definition;
    if exists(select 1 from pg_proc where oid=routine.oid and (proowner<>routine.proowner
      or proacl is distinct from routine.proacl or proconfig is distinct from routine.proconfig)) then
      raise exception 'Interactive identity owner/ACL/search_path changed'; end if;
  end loop;
  select oid,proowner,proacl,proconfig into strict routine from pg_proc
    where oid='public.rpc_register_admin_session(uuid,uuid,text)'::regprocedure;
  definition:=pg_get_functiondef(routine.oid); anchor:='insert into mobio_private.admin_session_leases';
  if position(anchor in definition)=0 then raise exception 'Unexpected Admin lease registration body'; end if;
  execute replace(definition,anchor,'perform mobio_private.bind_whatsapp_otp_account(p_user_id,p_otp_id,''admin_login'');' || E'\n  ' || anchor);
  if exists(select 1 from pg_proc where oid=routine.oid and (proowner<>routine.proowner
    or proacl is distinct from routine.proacl or proconfig is distinct from routine.proconfig)) then
    raise exception 'Admin registration owner/ACL/search_path changed'; end if;
  select oid,proowner,proacl,proconfig into strict routine from pg_proc
    where oid='public._mobio_verified_phone_owner(text)'::regprocedure;
  definition:=pg_get_functiondef(routine.oid); anchor:='return candidate.id;';
  if position(anchor in definition)=0 then raise exception 'Unexpected phone directory body'; end if;
  execute replace(definition,anchor,'if not mobio_private.verified_interactive_account_is_eligible(candidate.id) then raise exception ''PHONE_IDENTITY_UNAVAILABLE'' using errcode=''42501''; end if;' || E'\n  ' || anchor);
  select oid,proowner,proacl,proconfig into strict routine from pg_proc
    where oid='public.enforce_live_api_session()'::regprocedure;
  definition:=pg_get_functiondef(routine.oid);
  anchor:='if auth.role() = ''authenticated'' and public.live_auth_user_id() is null then';
  if position(anchor in definition)=0 or position('public.is_store_review_principal()' in definition)=0 then
    raise exception 'Unexpected installed PostgREST admission hook'; end if;
  anchor:=E'\nend;';
  if position(anchor in definition)=0 then raise exception 'Unexpected PostgREST hook end'; end if;
  -- Keep the admission hook executable before the later Admin-purpose guard
  -- migration. Eligible exact Admin-purpose transport with an invalid lease
  -- receives the same actionable rejection as sensitive RPCs. A valid but
  -- stale Admin retains read access; sensitive mutations still require recency.
  execute replace(definition,anchor,E'\n  if auth.role() = ''authenticated'' and public.verified_app_user_id() is null\n    and exists(select 1 from auth.users u where u.id=public.live_auth_user_id()\n      and not coalesce(u.is_anonymous,false) and auth.jwt()->''is_anonymous''=''false''::jsonb\n      and u.raw_app_meta_data->>''provider''=''admin_whatsapp_otp''\n      and auth.jwt()->''app_metadata''->>''provider''=''admin_whatsapp_otp''\n      and mobio_private.verified_interactive_account_is_eligible(u.id)) then\n    perform public.require_recent_admin_session();\n  end if;\n  if auth.role() = ''authenticated''\n    and exists(select 1 from auth.users where id=public.live_auth_user_id() and not coalesce(is_anonymous,false))\n    and public.verified_app_user_id() is null then\n    raise sqlstate ''PT403'' using message = ''Verified WhatsApp session required'';\n  end if;' || anchor);
  if exists(select 1 from pg_proc where oid=routine.oid and (proowner<>routine.proowner
    or proacl is distinct from routine.proacl or proconfig is distinct from routine.proconfig)) then
    raise exception 'PostgREST hook owner/ACL/search_path changed'; end if;
end $$;
notify pgrst,'reload schema';
commit;
