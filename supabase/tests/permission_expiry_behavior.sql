-- Disposable database only. Synthetic identity/session/grant rows roll back.
begin;
create temp table qa_permission_actor (user_id uuid, session_id uuid);
insert into qa_permission_actor values (gen_random_uuid(), gen_random_uuid());
create temp table qa_permission_results (name text);
create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %', label; end if;
  insert into pg_temp.qa_permission_results values (label);
end;
$$;

insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data)
select user_id, '+250700001001', now(),
  '{"provider":"admin_whatsapp_otp","qa_fixture":true}', '{}' from qa_permission_actor;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now()+interval '1 hour' from qa_permission_actor;
-- Explicit SQL-only positive OTP/session setup; no Admin lease or grant is added.
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_permission_actor));

-- A delegated explicit grant still requires the separate Admin login marker
-- and verified-phone allowlist. Leave profile.role as passenger so this test
-- measures the explicit grant instead of the existing full-Admin fallback.
insert into public.admin_whatsapp_numbers(phone_e164, country_code, is_active)
values ('+250700001001', '+250', true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', user_id, 'session_id', session_id, 'role', 'authenticated',
  'is_anonymous', false, 'app_metadata', jsonb_build_object('provider','admin_whatsapp_otp'))::text, true)
from qa_permission_actor;
insert into public.profile_platform_permissions(profile_id, permission_key, expires_at)
select user_id, 'admin.users.read', now()+interval '5 minutes' from qa_permission_actor;
select pg_temp.qa_check('future grant alone cannot bypass Admin session lease',
  not public.has_platform_permission('admin.users.read'));
insert into mobio_private.admin_session_leases
  (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
select session_id,user_id,'permission-expiry-qa',now(),now(),
  now()+interval '15 minutes',now()+interval '8 hours' from qa_permission_actor;

do $$
declare zone text;
begin
  foreach zone in array array['UTC','Pacific/Auckland','America/Los_Angeles'] loop
    perform set_config('TimeZone', zone, true);
    update public.profile_platform_permissions set expires_at=now()-interval '5 minutes'
    where profile_id=(select user_id from pg_temp.qa_permission_actor);
    perform pg_temp.qa_check('expired grant denied in '||zone,
      not public.has_platform_permission('admin.users.read'));
    update public.profile_platform_permissions set expires_at=now()+interval '5 minutes'
    where profile_id=(select user_id from pg_temp.qa_permission_actor);
    perform pg_temp.qa_check('future grant accepted in '||zone,
      public.has_platform_permission('admin.users.read'));
  end loop;
  update public.profile_platform_permissions set expires_at=null
  where profile_id=(select user_id from pg_temp.qa_permission_actor);
  perform pg_temp.qa_check('non-expiring grant accepted',public.has_platform_permission('admin.users.read'));
  perform pg_temp.qa_check('grant does not confer another permission',not public.has_platform_permission('admin.users.write'));
  delete from public.profile_platform_permissions where profile_id=(select user_id from pg_temp.qa_permission_actor);
  perform pg_temp.qa_check('removed grant denied',not public.has_platform_permission('admin.users.read'));
end;
$$;
select name as passed_assertion from qa_permission_results order by name;
select count(*) as passed_assertions from qa_permission_results;
rollback;
