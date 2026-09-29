-- Disposable full-schema database only. Synthetic Auth users and all writes roll back.
-- Exercises effective SQL-role grants and protected profile mutations; this is
-- not a live Auth, signed JWT, PostgREST or hosted-deployment acceptance test.
begin;

create temp table qa_profile_actors (
  label text primary key,
  user_id uuid not null default gen_random_uuid(),
  session_id uuid not null default gen_random_uuid()
);
insert into qa_profile_actors(label) values ('owner'), ('other');
create temp table qa_profile_results(label text primary key);
grant select on qa_profile_actors to authenticated;
grant insert on qa_profile_results to authenticated;

create function pg_temp.qa_profile_check(label text, passed boolean)
returns void language plpgsql as $$
begin
  if passed is distinct from true then
    raise exception 'ASSERTION FAILED: %', label;
  end if;
  insert into pg_temp.qa_profile_results values (label);
end;
$$;

insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data,
  raw_user_meta_data, is_anonymous)
select user_id, case label when 'owner' then '+250700004001' else '+250700004002' end,
  now(), '{"provider":"whatsapp_cloud_otp"}', '{}', false
from qa_profile_actors;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now() + interval '1 hour'
from qa_profile_actors;
create temp table qa_profile_baseline as
select id, role, is_driver, organization_id, member_id, whatsapp_verified_at,
  phone, whatsapp_e164, auth_provider, created_at
from public.profiles where id in (select user_id from qa_profile_actors);

select pg_temp.qa_profile_check('identity guard trigger is enabled', exists (
  select 1 from pg_trigger
  where tgrelid='public.profiles'::regclass
    and tgname='guard_profile_identity_authority'
    and not tgisinternal and tgenabled in ('O','A')
));
select pg_temp.qa_profile_check('profile owner update policy checks role and driver authority', exists (
  select 1 from pg_policies
  where schemaname='public' and tablename='profiles'
    and policyname='profiles_update_own'
    and with_check like '%role%' and with_check like '%is_driver%'
    and with_check like '%organization_id%'
));
select pg_temp.qa_profile_check('private phone-owner helper denies client roles',
  not has_function_privilege('anon','public._mobio_verified_phone_owner(text)','execute')
  and not has_function_privilege('authenticated','public._mobio_verified_phone_owner(text)','execute'));
select pg_temp.qa_profile_check('phone lookup RPC is service-only',
  not has_function_privilege('anon','public.rpc_lookup_verified_phone_owner(text)','execute')
  and not has_function_privilege('authenticated','public.rpc_lookup_verified_phone_owner(text)','execute')
  and has_function_privilege('service_role','public.rpc_lookup_verified_phone_owner(text)','execute'));

select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims',(
  select jsonb_build_object('sub',user_id,'session_id',session_id,
    'role','authenticated','is_anonymous',false,
    'app_metadata',jsonb_build_object('provider','whatsapp_cloud_otp'))::text
  from qa_profile_actors where label='owner'
),true);
select pg_temp.qa_profile_check('synthetic owner has live verified identity',
  public.verified_app_user_id()=(select user_id from qa_profile_actors where label='owner'));

set local role authenticated;
select pg_temp.qa_profile_check('owner reads exactly its own profile', (
  select count(*)=1 and bool_and(id=auth.uid()) from public.profiles
  where id in (select user_id from qa_profile_actors)
));
update public.profiles set name='QA allowed profile edit' where id=auth.uid();
select pg_temp.qa_profile_check('ordinary owner profile edit succeeds', (
  select name='QA allowed profile edit' from public.profiles where id=auth.uid()
));

do $$
declare changed integer;
begin
  update public.profiles set name='QA cross-owner write'
  where id=(select user_id from pg_temp.qa_profile_actors where label='other');
  get diagnostics changed=row_count;
  perform pg_temp.qa_profile_check('cross-owner direct update changes zero rows',changed=0);
end;
$$;

do $$
begin
  begin
    update public.profiles set member_id=member_id || '7' where id=auth.uid();
    raise exception 'member ID mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('member ID direct mutation denied',true);
  end;
  begin
    update public.profiles set phone='+250700009999' where id=auth.uid();
    raise exception 'verified phone mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('verified phone direct mutation denied',true);
  end;
  begin
    update public.profiles set whatsapp_verified_at=now() where id=auth.uid();
    raise exception 'verification timestamp mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('verification timestamp direct mutation denied',true);
  end;
  begin
    update public.profiles set role='admin' where id=auth.uid();
    raise exception 'admin role mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('admin role direct mutation denied',true);
  end;
  begin
    update public.profiles set is_driver=true where id=auth.uid();
    raise exception 'driver flag mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('driver flag direct mutation denied',true);
  end;
  begin
    update public.profiles set organization_id=gen_random_uuid() where id=auth.uid();
    raise exception 'organization mutation was accepted';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('organization direct mutation denied',true);
  end;
  begin
    perform public.rpc_update_profile('{"phone":"+250700009999"}'::json);
    raise exception 'profile RPC changed verified phone';
  exception when insufficient_privilege then
    perform pg_temp.qa_profile_check('profile RPC cannot change verified phone',true);
  end;
  begin
    perform public.rpc_admin_update_user_role(
      (select user_id from pg_temp.qa_profile_actors where label='other'),'admin');
    raise exception 'ordinary user changed another role through Admin RPC'
      using errcode='PZ001';
  exception when insufficient_privilege or raise_exception then
    perform pg_temp.qa_profile_check('Admin role RPC denies ordinary user',true);
  end;
end;
$$;

select public.rpc_update_profile('{"display_name":"QA allowed display name","role":"admin"}'::json);
select pg_temp.qa_profile_check('profile RPC permits display name without role escalation', (
  select display_name='QA allowed display name' and role='passenger'
  from public.profiles where id=auth.uid()
));
reset role;

select pg_temp.qa_profile_check('denied mutations preserved both identities', (
  select count(*)=2 and bool_and(
    p.role is not distinct from b.role
    and p.is_driver is not distinct from b.is_driver
    and p.organization_id is not distinct from b.organization_id
    and p.member_id is not distinct from b.member_id
    and p.whatsapp_verified_at is not distinct from b.whatsapp_verified_at
    and p.phone is not distinct from b.phone
    and p.whatsapp_e164 is not distinct from b.whatsapp_e164
    and p.auth_provider is not distinct from b.auth_provider
    and p.created_at is not distinct from b.created_at)
  from public.profiles p join qa_profile_baseline b using (id)
));
select label as passed_assertion from qa_profile_results order by label;
rollback;
