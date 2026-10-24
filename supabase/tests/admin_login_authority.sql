-- Actual isolated Auth/session rows and SQL roles. Roll back every fixture.
-- The JWT claims below are SQL test contexts, not signature/OTP verification.
begin;
create temp table qa_admin_actor(user_id uuid, session_id uuid);
insert into qa_admin_actor values (gen_random_uuid(),gen_random_uuid());
create temp table qa_admin_results(name text);
grant select on qa_admin_actor to authenticated;
grant select,insert on qa_admin_results to authenticated;
create function pg_temp.qa_check(label text, value boolean) returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
  insert into pg_temp.qa_admin_results values(label);
end $$;
create function pg_temp.qa_claims(provider text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',user_id,'session_id',session_id,'role','authenticated','is_anonymous',false,
    'app_metadata',jsonb_build_object('provider',provider))::text,true)
  from pg_temp.qa_admin_actor;
end $$;
create function pg_temp.qa_admin_rpc_denied(label text) returns void language plpgsql as $$
begin
  begin
    perform public.rpc_admin_list_users(p_limit=>2);
    raise exception 'ASSERTION FAILED: Admin RPC accepted %',label;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'Unauthorized: admin.users.read permission required' then raise; end if;
    perform pg_temp.qa_check(label,true);
  end;
end $$;

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
select user_id,'+250700004001',now(),'{"provider":"whatsapp_cloud_otp"}','{}',false from qa_admin_actor;
insert into auth.sessions(id,user_id,created_at,not_after)
select session_id,user_id,now(),now()+interval '1 hour' from qa_admin_actor;
-- Explicit SQL-only positive OTP/session setup; no Admin lease or grant is added.
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_admin_actor));

insert into public.profile_platform_permissions(profile_id,permission_key)
select user_id,'admin.users.read' from qa_admin_actor;
select pg_temp.qa_claims('whatsapp_cloud_otp');
select pg_temp.qa_check('consumer identity remains verified',public.verified_app_user_id()=auth.uid());
select pg_temp.qa_check('consumer grant does not establish Admin login',public.verified_admin_user_id() is null);
select pg_temp.qa_check('explicit grant cannot bypass Admin purpose or allowlist',not public.has_platform_permission('admin.users.read'));
set local role authenticated;
select pg_temp.qa_admin_rpc_denied('consumer with an explicit grant is denied by the actual Admin RPC');
reset role;

insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
values ('+250700004001','+250',true);
select pg_temp.qa_check('allowlisting alone does not establish Admin purpose',public.verified_admin_user_id() is null);
update public.profiles set role='admin' where id=auth.uid();
select pg_temp.qa_check('profile promotion cannot elevate a consumer JWT',public.verified_app_user_id() is null);
select pg_temp.qa_check('profile role and allowlist cannot bypass Admin login',not public.has_platform_permission('platform.admin'));
set local role authenticated;
select pg_temp.qa_admin_rpc_denied('promoted consumer is denied by the actual Admin RPC');
select pg_temp.qa_check('legacy role-based RLS hides the promoted consumer profile',
  not exists(select 1 from public.profiles where id=auth.uid()));
reset role;

update auth.users set raw_app_meta_data='{"provider":"admin_whatsapp_otp"}' where id=auth.uid();
select pg_temp.qa_check('server metadata alone does not elevate the old consumer JWT',public.verified_admin_user_id() is null);
select pg_temp.qa_claims('admin_whatsapp_otp');
update auth.users set raw_app_meta_data='{"provider":"whatsapp_cloud_otp"}' where id=auth.uid();
select pg_temp.qa_check('Admin JWT marker also needs trusted server metadata',public.verified_admin_user_id() is null);
update auth.users set raw_app_meta_data='{"provider":"admin_whatsapp_otp"}' where id=auth.uid();
select pg_temp.qa_check('Admin markers without a server lease remain denied',public.verified_admin_user_id() is null);
insert into mobio_private.admin_session_leases
  (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
select session_id,user_id,'admin-qa-lease',now(),now(),now()+interval '15 minutes',now()+interval '8 hours'
from pg_temp.qa_admin_actor;
select pg_temp.qa_check('verified Admin markers and allowlisted Auth phone resolve identity',public.verified_admin_user_id()=auth.uid());
select pg_temp.qa_check('verified Admin retains its application identity',public.verified_app_user_id()=auth.uid());
select pg_temp.qa_check('existing full-Admin permission fallback remains available',public.has_platform_permission('platform.admin'));
set local role authenticated;
select pg_temp.qa_check('authorized Admin RPC returns fixture users',
  (select count(*)>0 from public.rpc_admin_list_users(p_limit=>2)));
select pg_temp.qa_check('authorized Admin can read its own profile',exists(select 1 from public.profiles where id=auth.uid()));
reset role;

-- An Admin-purpose identity with a delegated explicit grant retains its scope;
-- profile.role no longer supplies the full-Admin fallback in this branch.
update public.profiles set role='passenger' where id=auth.uid();
select pg_temp.qa_check('delegated Admin-purpose grant remains usable',public.has_platform_permission('admin.users.read'));
select pg_temp.qa_check('delegated grant does not confer another permission',not public.has_platform_permission('admin.users.manage'));
update public.profile_platform_permissions set expires_at=now()-interval '1 second' where profile_id=auth.uid();
select pg_temp.qa_check('expired delegated Admin grant remains denied',not public.has_platform_permission('admin.users.read'));
update public.profile_platform_permissions set expires_at=null where profile_id=auth.uid();
update public.admin_whatsapp_numbers set is_active=false where phone_e164='+250700004001';
select pg_temp.qa_check('allowlist removal revokes Admin identity immediately',public.verified_admin_user_id() is null);
select pg_temp.qa_check('explicit grants do not survive allowlist removal',not public.has_platform_permission('admin.users.read'));
update public.admin_whatsapp_numbers set is_active=true where phone_e164='+250700004001';

update auth.users set phone='+250700004999' where id=auth.uid();
select pg_temp.qa_check('allowlisted profile phone cannot substitute for the Auth phone',public.verified_admin_user_id() is null);
update auth.users set phone='+250700004001',phone_confirmed_at=null where id=auth.uid();
select pg_temp.qa_check('Admin Auth phone must still be verified',public.verified_admin_user_id() is null);
update auth.users set phone_confirmed_at=now(),is_anonymous=true where id=auth.uid();
select pg_temp.qa_check('anonymous Auth identity cannot become Admin',public.verified_admin_user_id() is null);
update auth.users set is_anonymous=false where id=auth.uid();
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{is_anonymous}','true')::text,true);
select pg_temp.qa_check('anonymous JWT cannot become Admin',public.verified_admin_user_id() is null);
select pg_temp.qa_claims('admin_whatsapp_otp');
update auth.users set banned_until=now()+interval '1 hour' where id=auth.uid();
select pg_temp.qa_check('banned Admin identity remains revoked',public.verified_admin_user_id() is null);
update auth.users set banned_until=null where id=auth.uid();
update auth.sessions set not_after=now() where user_id=auth.uid();
select pg_temp.qa_check('expired Admin session remains revoked',public.verified_admin_user_id() is null);
update auth.sessions set not_after=null where user_id=auth.uid();
delete from auth.sessions where user_id=auth.uid();
select pg_temp.qa_check('deleted Admin session remains revoked',public.verified_admin_user_id() is null);
select pg_temp.qa_check('revoked Admin session cannot use its grant',not public.has_platform_permission('admin.users.read'));

select name as passed_assertion from qa_admin_results order by name;
select count(*) as passed_assertions from qa_admin_results;
rollback;
