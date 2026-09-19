-- Disposable full-schema database only. Actual Auth/session rows, SQL roles and
-- RLS checks; every synthetic row and state change rolls back. This is not an
-- OTP-delivery, JWT-signature or Realtime-websocket test.
begin;
create temp table qa_identity_actors (
  name text primary key, user_id uuid default gen_random_uuid(),
  session_id uuid default gen_random_uuid()
);
insert into qa_identity_actors(name) values ('A'), ('B'), ('anonymous'), ('unverified');
create temp table qa_identity_results(name text);
grant select on qa_identity_actors to authenticated;
grant select, insert on qa_identity_results to authenticated;

create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_identity_results values (label);
end;
$$;
create function pg_temp.qa_identity(actor text, overrides jsonb default '{}')
returns void language plpgsql as $$
declare claims jsonb;
begin
  select jsonb_build_object('sub', user_id, 'session_id', session_id,
    'role', 'authenticated', 'is_anonymous', name = 'anonymous',
    'app_metadata', jsonb_build_object('provider', 'whatsapp_cloud_otp'))
  into strict claims from pg_temp.qa_identity_actors where name = actor;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', (claims || overrides)::text, true);
end;
$$;
create function pg_temp.qa_authentication_denied(label text) returns void
language plpgsql as $$
begin
  begin
    perform public.enforce_live_api_session();
    raise exception 'ASSERTION FAILED: pre-request accepted %', label;
  exception when sqlstate 'PT401' then
    perform pg_temp.qa_check(label, true);
  end;
end;
$$;
create function pg_temp.qa_chat_denied(label text) returns void
language plpgsql as $$
begin
  begin
    perform public.rpc_get_or_create_chat_conversation(
      (select user_id from pg_temp.qa_identity_actors where name = 'B'));
    raise exception 'ASSERTION FAILED: chat creation accepted %', label;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'Authentication required' then raise; end if;
    perform pg_temp.qa_check(label, true);
  end;
end;
$$;

insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, is_anonymous)
select user_id, case name when 'A' then '+250700003001' when 'B' then '+250700003002' end,
  case when name in ('A', 'B') then now() end,
  jsonb_build_object('provider', case when name in ('A', 'B') then 'whatsapp_cloud_otp' else 'email' end),
  '{}', name = 'anonymous' from qa_identity_actors;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now()+interval '1 hour' from qa_identity_actors;

select pg_temp.qa_identity('A');
select pg_temp.qa_check('live session resolves the exact user',
  public.live_auth_user_id() = (select user_id from qa_identity_actors where name = 'A'));
select pg_temp.qa_check('verified phone and trusted provider resolve app identity',
  public.verified_app_user_id() = (select user_id from qa_identity_actors where name = 'A'));
select public.enforce_live_api_session();

set local role authenticated;
select pg_temp.qa_check('verified SQL role can read its own profile only', (
  select count(*) = 1 and bool_and(id = auth.uid()) from public.profiles
  where id in (select user_id from qa_identity_actors)
));
select pg_temp.qa_check('verified SQL role can create a local conversation',
  (public.rpc_get_or_create_chat_conversation(
    (select user_id from qa_identity_actors where name = 'B'))).id is not null);
reset role;

select pg_temp.qa_identity('anonymous');
select pg_temp.qa_check('live anonymous session can bootstrap', public.live_auth_user_id() is not null);
select public.enforce_live_api_session();
select pg_temp.qa_check('anonymous session has no verified app identity', public.verified_app_user_id() is null);
set local role authenticated;
select pg_temp.qa_chat_denied('anonymous SQL role cannot create a conversation');
select pg_temp.qa_check('anonymous SQL role cannot read its private profile',
  not exists (select 1 from public.profiles where id = auth.uid()));
reset role;
select pg_temp.qa_identity('anonymous', '{"is_anonymous":false}');
select pg_temp.qa_check('anonymous database flag defeats a spoofed JWT flag', public.verified_app_user_id() is null);

select pg_temp.qa_identity('unverified');
select pg_temp.qa_check('unverified live session can bootstrap', public.live_auth_user_id() is not null);
select public.enforce_live_api_session();
select pg_temp.qa_check('unverified session has no app identity', public.verified_app_user_id() is null);
set local role authenticated;
select pg_temp.qa_chat_denied('unverified SQL role cannot create a conversation');
reset role;
update auth.users set raw_user_meta_data = '{"provider":"whatsapp_cloud_otp","phone_confirmed_at":"2026-01-01"}'
where id = (select user_id from qa_identity_actors where name = 'unverified');
select pg_temp.qa_check('user-editable metadata cannot verify identity', public.verified_app_user_id() is null);

select pg_temp.qa_identity('A', '{"is_anonymous":true}');
select pg_temp.qa_check('anonymous JWT flag defeats verified database attributes', public.verified_app_user_id() is null);
select pg_temp.qa_identity('A', '{"is_anonymous":null}');
select pg_temp.qa_check('missing anonymous assertion does not verify identity', public.verified_app_user_id() is null);
select pg_temp.qa_identity('A');
update auth.users set phone_confirmed_at = null where id = auth.uid();
select pg_temp.qa_check('removing phone verification revokes app identity', public.verified_app_user_id() is null);
update auth.users set phone_confirmed_at = now(), raw_app_meta_data = '{"provider":"email"}' where id = auth.uid();
select pg_temp.qa_check('untrusted server provider revokes app identity', public.verified_app_user_id() is null);
update auth.users set raw_app_meta_data = '{"provider":"admin_whatsapp_otp"}' where id = auth.uid();
select pg_temp.qa_check('trusted Admin provider retains verified identity', public.verified_app_user_id() = auth.uid());
update auth.users set raw_app_meta_data = '{"provider":"whatsapp_cloud_otp"}', banned_until = now()+interval '1 hour' where id = auth.uid();
select pg_temp.qa_check('currently banned user has no live identity', public.live_auth_user_id() is null);
select pg_temp.qa_authentication_denied('REST guard rejects a banned user');
update auth.users set banned_until = now()-interval '1 second' where id = auth.uid();
select pg_temp.qa_check('elapsed ban restores live identity', public.live_auth_user_id() = auth.uid());
update auth.users set banned_until = null, deleted_at = now() where id = auth.uid();
select pg_temp.qa_check('soft-deleted user has no live identity', public.live_auth_user_id() is null);
select pg_temp.qa_authentication_denied('REST guard rejects a deleted user');
update auth.users set deleted_at = null where id = auth.uid();
update auth.sessions set not_after = now() where user_id = auth.uid();
select pg_temp.qa_check('session expiry boundary is exclusive', public.live_auth_user_id() is null);
select pg_temp.qa_authentication_denied('REST guard rejects an expired session');
update auth.sessions set not_after = null where user_id = auth.uid();
select pg_temp.qa_check('non-expiring live session is accepted', public.live_auth_user_id() = auth.uid());

select pg_temp.qa_identity('A', jsonb_build_object('session_id',
  (select session_id from qa_identity_actors where name = 'B')));
select pg_temp.qa_check('another user session cannot supply identity', public.live_auth_user_id() is null);
select pg_temp.qa_authentication_denied('REST guard rejects mismatched user and session');
select pg_temp.qa_identity('A', '{"session_id":null}');
select pg_temp.qa_authentication_denied('REST guard rejects a missing session');
select pg_temp.qa_identity('A', '{"session_id":"invalid"}');
select pg_temp.qa_authentication_denied('REST guard rejects a malformed session without a cast error');
select pg_temp.qa_identity('A', '{"sub":"invalid"}');
select pg_temp.qa_authentication_denied('REST guard rejects a malformed subject without a cast error');
select pg_temp.qa_identity('A');
delete from auth.sessions where id = (select session_id from qa_identity_actors where name = 'A');
select pg_temp.qa_authentication_denied('REST guard rejects a revoked session');
set local role authenticated;
select pg_temp.qa_check('RLS independently hides revoked user data outside REST',
  not exists (select 1 from public.profiles where id = auth.uid()));
select pg_temp.qa_chat_denied('protected RPC independently rejects a revoked session');
reset role;
insert into auth.sessions(id, user_id, created_at) select gen_random_uuid(), user_id, now()
from qa_identity_actors where name = 'A';
select pg_temp.qa_authentication_denied('another live session does not restore a revoked session');

select set_config('request.jwt.claims', '{"role":"anon"}', true);
select public.enforce_live_api_session();
select pg_temp.qa_check('guest remains without a verified app identity', public.verified_app_user_id() is null);
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select public.enforce_live_api_session();
select pg_temp.qa_check('trusted service path needs no fabricated user identity', public.verified_app_user_id() is null);

-- Catch migration omissions and future ownership paths that bypass the guard.
select pg_temp.qa_check('all application ownership routines use verified identity', not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and p.proname <> 'live_auth_user_id'
    and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass
      and d.objid = p.oid and d.deptype = 'e')
    and position('auth.uid()' in pg_get_functiondef(p.oid)) > 0
));
select pg_temp.qa_check('public and Storage ownership policies use verified identity', not exists (
  select 1 from pg_policies where schemaname in ('public', 'storage')
    and (position('auth.uid()' in coalesce(qual, '')) > 0
      or position('auth.uid()' in coalesce(with_check, '')) > 0)
));
select pg_temp.qa_check('PostgREST role has the live-session hook', exists (
  select 1 from pg_db_role_setting s cross join lateral unnest(s.setconfig) setting
  where s.setrole = 'authenticator'::regrole and s.setdatabase = 0
    and setting = 'pgrst.db_pre_request=public.enforce_live_api_session'
));
select name as passed_assertion from qa_identity_results order by name;
select count(*) as passed_assertions from qa_identity_results;
rollback;
