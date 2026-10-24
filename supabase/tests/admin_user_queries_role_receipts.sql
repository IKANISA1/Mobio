-- Isolated full-schema SQL assertions; synthetic JWT contexts, no OTP/JWT delivery claim.
begin;
set local statement_timeout='90s';
create temp table qa_role_actors(name text primary key,user_id uuid default gen_random_uuid(),
  session_id uuid default gen_random_uuid(),provider text,phone text);
insert into qa_role_actors(name,provider,phone) values
 ('owner','admin_whatsapp_otp','+250700008401'),('other','admin_whatsapp_otp','+250700008402'),
 ('reader','admin_whatsapp_otp','+250700008403'),('manager','admin_whatsapp_otp','+250700008404'),
 ('consumer','whatsapp_cloud_otp','+250700008405'),('a','whatsapp_cloud_otp','+250700008406'),
 ('z','whatsapp_cloud_otp','+250700008407'),('tie1','whatsapp_cloud_otp','+250700008408'),
 ('tie2','whatsapp_cloud_otp','+250700008409'),('unnamed','whatsapp_cloud_otp','+250700008410');
create temp table qa_role_results(label text);
create temp table qa_role_values(name text primary key,value jsonb);
grant select on qa_role_actors to authenticated,service_role;
grant select,insert,update on qa_role_values to authenticated,service_role;
grant select,insert on qa_role_results to authenticated,service_role;
create function pg_temp.qa_role_check(label text,value boolean) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
  insert into pg_temp.qa_role_results values(label); end $$;
create function pg_temp.qa_role_identity(p_name text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',user_id,'session_id',session_id,
    'role','authenticated','is_anonymous',false,'app_metadata',jsonb_build_object('provider',provider))::text,true)
    from pg_temp.qa_role_actors where name=p_name;
end $$;
create function pg_temp.qa_role_error(label text,statement text,expected_state text,expected_message text)
returns void language plpgsql as $$
declare rejected boolean:=false; state text; message text;
begin begin execute statement; exception when others then
  get stacked diagnostics state=returned_sqlstate,message=message_text;
  if state<>expected_state or message<>expected_message then raise exception 'ASSERTION FAILED: % returned %/%',label,state,message; end if;
  rejected:=true; end; perform pg_temp.qa_role_check(label,rejected); end $$;
create function pg_temp.qa_role_target(snapshot jsonb,p_name text,next_role text) returns jsonb language sql as $$
  select jsonb_build_object('target_id',r->>'id','expected_role',r->>'role',
    'expected_revision',r->'role_revision','requested_role',next_role)
  from jsonb_array_elements(snapshot->'rows') r join pg_temp.qa_role_actors a on a.user_id::text=r->>'id'
  where a.name=p_name
$$;

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
  select user_id,phone,now(),jsonb_build_object('provider',provider),'{}',false from qa_role_actors;
insert into auth.sessions(id,user_id,created_at,not_after) select session_id,user_id,now(),now()+interval '1 hour' from qa_role_actors;
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_role_actors));
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
  select phone,'+250',true from qa_role_actors where provider='admin_whatsapp_otp';
insert into mobio_private.admin_session_leases(session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
  select session_id,user_id,'qa-role-'||name,now(),now(),now()+interval '15 minutes',now()+interval '8 hours'
  from qa_role_actors where provider='admin_whatsapp_otp';
update public.profiles p set role=case when a.name in('owner','other') then 'admin'::public.user_role_enum else 'passenger'::public.user_role_enum end,
  name='M-'||a.name,display_name=null,is_driver=false,
  member_id=(500000+row_number)::text
  from (select a.*,row_number() over(order by name)::integer from qa_role_actors a) a where p.id=a.user_id;
update public.profiles set name='zz-source',display_name='Alpha' where id=(select user_id from qa_role_actors where name='a');
update public.profiles set name='aa-source',display_name='Zulu' where id=(select user_id from qa_role_actors where name='z');
update public.profiles set name='Bravo',display_name=case when id=(select user_id from qa_role_actors where name='tie2') then '  ' else null end
  where id in(select user_id from qa_role_actors where name in('tie1','tie2'));
update public.profiles set name='',display_name='' where id=(select user_id from qa_role_actors where name='unnamed');
insert into public.profile_platform_permissions(profile_id,permission_key)
  select user_id,x.key from qa_role_actors cross join lateral (values('admin.users.read'),('admin.users.manage')) x(key)
  where name in('manager','consumer');
insert into public.profile_platform_permissions(profile_id,permission_key)
  select user_id,'admin.users.read' from qa_role_actors where name='reader';

select pg_temp.qa_role_identity('owner');
set local role authenticated;
insert into qa_role_values values('page',public.rpc_admin_users_page(p_search=>'7000084',p_sort=>'name_asc',p_page_size=>2));
select pg_temp.qa_role_check('global display label order and exact count',
  (select value->'rows'->0->>'display_name'='Alpha' and (value->>'total_exact')::int=10 and (value->>'has_next_page')::boolean from qa_role_values where name='page'));
insert into qa_role_values values('page2',public.rpc_admin_users_page(p_search=>'7000084',p_sort=>'name_asc',p_page_size=>2,
  p_snapshot_id=>(select (value->>'snapshot_id')::uuid from qa_role_values where name='page'),p_offset=>2));
select pg_temp.qa_role_check('tie UUID order spans page boundary',
  (select (value->'rows'->1->>'id')::uuid from qa_role_values where name='page') <
  (select (value->'rows'->0->>'id')::uuid from qa_role_values where name='page2'));
select pg_temp.qa_role_error('page size binding',
  format('select public.rpc_admin_users_page(p_search=>''7000084'',p_sort=>''name_asc'',p_page_size=>3,p_snapshot_id=>%L::uuid)',
    (select value->>'snapshot_id' from qa_role_values where name='page')),'P0001','ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH');
select pg_temp.qa_role_error('sort binding',
  format('select public.rpc_admin_users_page(p_search=>''7000084'',p_sort=>''newest'',p_page_size=>2,p_snapshot_id=>%L::uuid)',
    (select value->>'snapshot_id' from qa_role_values where name='page')),'P0001','ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH');
select pg_temp.qa_role_error('page bound', 'select public.rpc_admin_users_page(p_page_size=>101)','22023','ADMIN_USERS_QUERY_INVALID');
select pg_temp.qa_role_error('offset alignment','select public.rpc_admin_users_page(p_page_size=>25,p_offset=>1)','22023','ADMIN_USERS_QUERY_INVALID');
select pg_temp.qa_role_error('fresh query cannot start at aligned later offset','select public.rpc_admin_users_page(p_page_size=>2,p_offset=>2)','22023','ADMIN_USERS_QUERY_INVALID');
insert into qa_role_values values('all',public.rpc_admin_users_page(p_search=>'7000084',p_sort=>'name_asc',p_page_size=>100));
insert into qa_role_values values('desc',public.rpc_admin_users_page(p_search=>'7000084',p_sort=>'name_desc',p_page_size=>100));
select pg_temp.qa_role_check('descending display order', (select value->'rows'->0->>'display_name'='Zulu' from qa_role_values where name='desc'));
select pg_temp.qa_role_check('unnamed fallback frozen as empty source fields',exists(select 1 from qa_role_values,jsonb_array_elements(value->'rows') r
  where name='all' and r->>'name'='' and r->>'display_name'=''));
select pg_temp.qa_role_error('maximum three snapshots','select public.rpc_admin_users_page()','P0001','ADMIN_USERS_SNAPSHOT_LIMIT');
select pg_temp.qa_role_error('raw snapshot rows denied','select * from mobio_private.admin_user_snapshot_rows','42501','permission denied for schema mobio_private');
select pg_temp.qa_role_error('release validates null handle before effects','select public.rpc_admin_users_release_snapshot(null)','22023','ADMIN_USERS_QUERY_INVALID');
insert into qa_role_values values('release',public.rpc_admin_users_release_snapshot((select (value->>'snapshot_id')::uuid from qa_role_values where name='desc')));
select pg_temp.qa_role_check('release is bound to current owner and exact handle',
  (select value->>'protocol'='mobio.admin-users.v1' and value->>'actor_id'=(select user_id::text from qa_role_actors where name='owner')
    and value->>'session_id'=(select session_id::text from qa_role_actors where name='owner')
    and value->>'snapshot_id'=(select value->>'snapshot_id' from qa_role_values where name='desc')
    and value->>'released'='true' and value->>'already_absent'='false' from qa_role_values where name='release'));
select pg_temp.qa_role_check('same release is authoritative idempotent absence',
  public.rpc_admin_users_release_snapshot((select (value->>'snapshot_id')::uuid from qa_role_values where name='desc'))->>'already_absent'='true');
insert into qa_role_values values('after-release',public.rpc_admin_users_page(p_search=>'7000084',p_page_size=>100));
select pg_temp.qa_role_check('explicit release permits fourth ordinary query within same TTL',
  (select (value->>'total_exact')::int=10 from qa_role_values where name='after-release'));
reset role;
select pg_temp.qa_role_check('release physically removes only superseded cache rows',
  not exists(select 1 from mobio_private.admin_user_snapshot_rows where snapshot_id=(select (value->>'snapshot_id')::uuid from qa_role_values where name='desc'))
  and exists(select 1 from mobio_private.admin_user_snapshot_rows where snapshot_id=(select (value->>'snapshot_id')::uuid from qa_role_values where name='all')));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
update public.profiles set name='changed',display_name='Changed after snapshot',phone='+250799999997' where id=(select user_id from qa_role_actors where name='a');
select pg_temp.qa_role_identity('owner');set local role authenticated;
select pg_temp.qa_role_check('snapshot values immutable after live edit',
  public.rpc_admin_users_page(p_search=>'7000084',p_sort=>'name_asc',p_page_size=>2,
    p_snapshot_id=>(select (value->>'snapshot_id')::uuid from qa_role_values where name='page'))->'rows'
  =(select value->'rows' from qa_role_values where name='page'));
insert into qa_role_values values('reservation',to_jsonb(gen_random_uuid()));
insert into qa_role_values values('batch',public.rpc_admin_role_reserve(
  (select (value#>>'{}')::uuid from qa_role_values where name='reservation'),
  (select (value->>'snapshot_id')::uuid from qa_role_values where name='after-release'),
  jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'a','driver'),
    pg_temp.qa_role_target((select value from qa_role_values where name='all'),'z','driver'),
    pg_temp.qa_role_target((select value from qa_role_values where name='all'),'owner','driver'),
    pg_temp.qa_role_target((select value from qa_role_values where name='all'),'tie2','passenger'))));
select pg_temp.qa_role_check('server-owned IDs and contiguous immutable order',
  (select jsonb_array_length(value->'operations')=4 and value->'operations'->0->>'ordinal'='1'
    and value->'operations'->3->>'ordinal'='4' and value->'operations'->0->>'display_label'='Alpha'
    and value->'operations'->2->>'skip_reason'='self' and value->'operations'->3->>'skip_reason'='same_role' from qa_role_values where name='batch'));
select pg_temp.qa_role_check('reservation replay retains exact immutable IDs and tuples',
  (select public.rpc_admin_role_reserve((value->>'reservation_id')::uuid,(value->'batch'->>'snapshot_id')::uuid,
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'a','driver'),
      pg_temp.qa_role_target((select value from qa_role_values where name='all'),'z','driver'),
      pg_temp.qa_role_target((select value from qa_role_values where name='all'),'owner','driver'),
      pg_temp.qa_role_target((select value from qa_role_values where name='all'),'tie2','passenger')))->'operations'=value->'operations'
   from qa_role_values where name='batch'));
select pg_temp.qa_role_error('reservation token cannot change reviewed tuple hash',
  format('select public.rpc_admin_role_reserve(%L::uuid,%L::uuid,%L::jsonb)',
    (select value->>'reservation_id' from qa_role_values where name='batch'),
    (select value->>'snapshot_id' from qa_role_values where name='all'),
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'z','driver'))),
  '22023','ADMIN_ROLE_RESERVATION_CONFLICT');
select pg_temp.qa_role_error('open batch blocks overlap',
  format('select public.rpc_admin_role_reserve(gen_random_uuid(),%L::uuid,%L::jsonb)',
    (select value->>'snapshot_id' from qa_role_values where name='all'),
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'z','driver'))),
  'P0001','ADMIN_ROLE_BATCH_OPEN');
select pg_temp.qa_role_error('legacy caller cannot bypass batch fence',
  format('select public.rpc_admin_update_user_role(%L::uuid,''driver'')',(select user_id from qa_role_actors where name='tie1')),
  'P0001','ADMIN_ROLE_BATCH_OPEN');
update qa_role_values set value=public.rpc_admin_role_execute((value->'batch'->>'batch_id')::uuid,(value->'operations'->0->>'operation_id')::uuid) where name='batch';
select pg_temp.qa_role_check('confirmed receipt bound to operation and role version',
  (select value->'operations'->0->>'status'='confirmed' and value->'operations'->0->'receipt'->>'before_role'='passenger'
    and value->'operations'->0->'receipt'->>'after_role'='driver'
    and (value->'operations'->0->'receipt'->>'after_revision')::bigint>(value->'operations'->0->'receipt'->>'before_revision')::bigint
    and value->'operations'->0->'receipt'->>'operation_id'=value->'operations'->0->>'operation_id' from qa_role_values where name='batch'));
insert into qa_role_values select 'receipt',value->'operations'->0->'receipt' from qa_role_values where name='batch';
update qa_role_values set value=public.rpc_admin_role_execute((value->'batch'->>'batch_id')::uuid,(value->'operations'->0->>'operation_id')::uuid) where name='batch';
select pg_temp.qa_role_check('receipt replay unchanged',
  (select value->'operations'->0->'receipt' from qa_role_values where name='batch')=(select value from qa_role_values where name='receipt'));
reset role;
select pg_temp.qa_role_check('exactly one existing matched audit',
  (select count(*)=1 from public.admin_audit_log where details->>'operation_id'=(select value->'operations'->0->>'operation_id' from qa_role_values where name='batch')));
update mobio_private.admin_session_leases set authenticated_at=now()-interval '6 minutes'
  where user_id=(select user_id from qa_role_actors where name='owner');
set local role authenticated;
select pg_temp.qa_role_error('freshness precedes reserve argument validation','select public.rpc_admin_role_reserve(null,null,null)','42501','ADMIN_REAUTHENTICATION_REQUIRED');
select pg_temp.qa_role_error('freshness precedes execute argument validation','select public.rpc_admin_role_execute(null,null)','42501','ADMIN_REAUTHENTICATION_REQUIRED');
select pg_temp.qa_role_check('stale recent authentication retains recovery read',
  public.rpc_admin_role_status()->'operations'->0->>'status'='confirmed');
select pg_temp.qa_role_check('cache release needs base authority without recent step-up',
  public.rpc_admin_users_release_snapshot((select (value->>'snapshot_id')::uuid from qa_role_values where name='after-release'))->>'released'='true');
select pg_temp.qa_role_check('cache release preserves immutable outstanding batch and receipt',
  public.rpc_admin_role_status()->'operations'=(select value->'operations' from qa_role_values where name='batch'));
update qa_role_values set value=public.rpc_admin_role_seal((value->'batch'->>'batch_id')::uuid) where name='batch';
select pg_temp.qa_role_check('seal needs base authority and cancels undispatched only',
  (select value->>'reservation_state'='sealed' and value->'operations'->0->>'status'='confirmed'
    and value->'operations'->1->>'status'='not_started' and value->'operations'->2->>'status'='skipped' from qa_role_values where name='batch'));
reset role;
update mobio_private.admin_session_leases set authenticated_at=now() where user_id=(select user_id from qa_role_actors where name='owner');
set local role authenticated;
select pg_temp.qa_role_error('sealed batch cannot late execute',
  format('select public.rpc_admin_role_execute(%L::uuid,%L::uuid)',
    (select value->'batch'->>'batch_id' from qa_role_values where name='batch'),(select value->'operations'->1->>'operation_id' from qa_role_values where name='batch')),
  'P0001','ADMIN_ROLE_BATCH_SEALED');
insert into qa_role_values values('early-reservation',to_jsonb(gen_random_uuid()));
select pg_temp.qa_role_check('absent reservation is not authoritative rejection',
  public.rpc_admin_role_status(p_reservation_id=>(select (value#>>'{}')::uuid from qa_role_values where name='early-reservation'))->>'reservation_state'='absent');
insert into qa_role_values values('early-seal',public.rpc_admin_role_seal(p_reservation_id=>(select (value#>>'{}')::uuid from qa_role_values where name='early-reservation')));
select pg_temp.qa_role_check('seal before reserve is explicit exact token fence',
  (select value->>'reservation_state'='sealed_before_reserve' and value->'batch'='null'::jsonb and value->'operations'='[]'::jsonb from qa_role_values where name='early-seal'));
select pg_temp.qa_role_error('late reservation cannot revive sealed token',
  format('select public.rpc_admin_role_reserve(%L::uuid,%L::uuid,%L::jsonb)',
    (select value#>>'{}' from qa_role_values where name='early-reservation'),(select value->>'snapshot_id' from qa_role_values where name='all'),
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'z','driver'))),
  'P0001','ADMIN_ROLE_RESERVATION_SEALED');
reset role;
select pg_temp.qa_role_identity('other');set local role authenticated;
select pg_temp.qa_role_error('foreign actor cannot release existing snapshot',
  format('select public.rpc_admin_users_release_snapshot(%L::uuid)',(select value->>'snapshot_id' from qa_role_values where name='page')),
  '42501','ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH');
select pg_temp.qa_role_check('wrong owner cannot discover batch',
  public.rpc_admin_role_status((select (value->'batch'->>'batch_id')::uuid from qa_role_values where name='batch'))->>'reservation_state'='absent');
select pg_temp.qa_role_error('wrong owner cannot seal reservation',
  format('select public.rpc_admin_role_seal(p_reservation_id=>%L::uuid)',(select value#>>'{}' from qa_role_values where name='early-reservation')),
  'P0001','ADMIN_ROLE_BATCH_NOT_FOUND');
reset role;
select pg_temp.qa_role_identity('reader');set local role authenticated;
select pg_temp.qa_role_check('delegated read grant works',(public.rpc_admin_users_page(p_page_size=>1)->>'total_exact')::int=10);
select pg_temp.qa_role_error('read grant cannot reserve roles','select public.rpc_admin_role_reserve(null,null,null)','42501','ADMIN_ROLE_MANAGE_REQUIRED');
reset role;
select pg_temp.qa_role_identity('manager');set local role authenticated;
select pg_temp.qa_role_check('delegated manager can recover without admin profile role',public.rpc_admin_role_status()->>'reservation_state'='absent');
reset role;
select pg_temp.qa_role_identity('consumer');set local role authenticated;
select pg_temp.qa_role_error('consumer grants do not establish Admin purpose','select public.rpc_admin_users_page()','42501','ADMIN_USERS_READ_REQUIRED');
select pg_temp.qa_role_error('consumer manage grant cannot recover role plans','select public.rpc_admin_role_status()','42501','ADMIN_ROLE_MANAGE_REQUIRED');
select pg_temp.qa_role_error('consumer grants cannot release Admin snapshots',
  format('select public.rpc_admin_users_release_snapshot(%L::uuid)',(select value->>'snapshot_id' from qa_role_values where name='page')),
  '42501','ADMIN_USERS_READ_REQUIRED');
reset role;
-- Role/revision CAS rejects an ABA change; target deletion is a distinct known result.
select pg_temp.qa_role_identity('owner');
update public.profiles set role='driver',is_driver=true where id=(select user_id from qa_role_actors where name='tie1');
update public.profiles set role='passenger',is_driver=false where id=(select user_id from qa_role_actors where name='tie1');
set local role authenticated;
insert into qa_role_values values('aba',public.rpc_admin_role_reserve(gen_random_uuid(),
  (select (value->>'snapshot_id')::uuid from qa_role_values where name='all'),
  jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='all'),'tie1','driver'),
    pg_temp.qa_role_target((select value from qa_role_values where name='all'),'unnamed','driver'))));
update qa_role_values set value=public.rpc_admin_role_execute((value->'batch'->>'batch_id')::uuid,
  (value->'operations'->0->>'operation_id')::uuid) where name='aba';
select pg_temp.qa_role_check('ABA role change produces persisted rejection',
  (select value->'operations'->0->>'status'='known_rejected' and value->'operations'->0->>'rejection_code'='target_changed'
    and value->'operations'->0->'receipt'='null'::jsonb from qa_role_values where name='aba'));
reset role;
delete from auth.users where id=(select user_id from qa_role_actors where name='unnamed');
set local role authenticated;
update qa_role_values set value=public.rpc_admin_role_execute((value->'batch'->>'batch_id')::uuid,
  (value->'operations'->1->>'operation_id')::uuid) where name='aba';
select pg_temp.qa_role_check('missing target produces persisted no-effect rejection',
  (select value->'operations'->1->>'status'='known_rejected' and value->'operations'->1->>'rejection_code'='target_not_found' from qa_role_values where name='aba'));
reset role;
select pg_temp.qa_role_check('rejected operations create no success audit',not exists(select 1 from public.admin_audit_log
  where details->>'batch_id'=(select value->'batch'->>'batch_id' from qa_role_values where name='aba')));
insert into qa_role_values select 'old-owner-sid',to_jsonb(session_id) from qa_role_actors where name='owner';
update qa_role_actors set session_id=gen_random_uuid() where name='owner';
insert into auth.sessions(id,user_id,created_at,not_after) select session_id,user_id,now(),now()+interval '1 hour' from qa_role_actors where name='owner';
insert into mobio_private.admin_session_leases(session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
  select session_id,user_id,'qa-role-replacement',now(),now(),now()+interval '15 minutes',now()+interval '8 hours' from qa_role_actors where name='owner';
select pg_temp.qa_role_identity('owner');set local role authenticated;
select pg_temp.qa_role_error('replacement SID cannot release origin snapshot while it exists',
  format('select public.rpc_admin_users_release_snapshot(%L::uuid)',(select value->>'snapshot_id' from qa_role_values where name='all')),
  '42501','ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH');
reset role;
delete from auth.sessions where id=(select (value#>>'{}')::uuid from qa_role_values where name='old-owner-sid');
select pg_temp.qa_role_identity('owner');set local role authenticated;
select pg_temp.qa_role_check('replacement SID discovers immutable outstanding operations',
  public.rpc_admin_role_status()->'operations'=(select value->'operations' from qa_role_values where name='aba'));
select pg_temp.qa_role_check('replacement SID reads previous confirmed receipt',
  public.rpc_admin_role_status((select (value->'batch'->>'batch_id')::uuid from qa_role_values where name='batch'))->'operations'->0->'receipt'
  =(select value from qa_role_values where name='receipt'));
select pg_temp.qa_role_error('replacement SID cannot execute origin plan',
  format('select public.rpc_admin_role_execute(%L::uuid,%L::uuid)',
    (select value->'batch'->>'batch_id' from qa_role_values where name='aba'),(select value->'operations'->0->>'operation_id' from qa_role_values where name='aba')),
  '42501','ADMIN_ROLE_SESSION_CHANGED');
update qa_role_values set value=public.rpc_admin_role_seal((value->'batch'->>'batch_id')::uuid) where name='aba';
select pg_temp.qa_role_check('replacement SID safely seals without new target effect',
  (select value->>'reservation_state'='sealed' and value->'operations'->0->>'status'='known_rejected' from qa_role_values where name='aba'));
insert into qa_role_values values('fresh',public.rpc_admin_users_page(p_search=>'7000084',p_page_size=>100));
insert into qa_role_values values('atomic',public.rpc_admin_role_reserve(gen_random_uuid(),
  (select (value->>'snapshot_id')::uuid from qa_role_values where name='fresh'),
  jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='fresh'),'tie2','driver'))));
reset role;
update mobio_private.admin_user_snapshots set as_of=now()-interval '11 minutes',expires_at=now()-interval '1 minute'
  where snapshot_id=(select (value->>'snapshot_id')::uuid from qa_role_values where name='fresh');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.qa_role_check('bounded service expiry physically removes snapshot',
  (public.rpc_admin_users_expire_snapshots(1)->>'expired_snapshots')::int=1);
reset role;
select pg_temp.qa_role_check('expiry deletes cached PII while preserving durable tuples',
  not exists(select 1 from mobio_private.admin_user_snapshot_rows where snapshot_id=(select (value->>'snapshot_id')::uuid from qa_role_values where name='fresh'))
  and exists(select 1 from mobio_private.admin_role_operations where batch_id=(select (value->'batch'->>'batch_id')::uuid from qa_role_values where name='atomic')));
create function pg_temp.qa_block_role_audit() returns trigger language plpgsql as $$
begin raise exception 'QA_AUDIT_BLOCKED' using errcode='P0001'; end $$;
create trigger qa_block_role_audit before insert on public.admin_audit_log for each row when(NEW.action='update_role')
  execute function pg_temp.qa_block_role_audit();
select pg_temp.qa_role_identity('owner');set local role authenticated;
select pg_temp.qa_role_error('failed audit rolls back target and version',
  format('select public.rpc_admin_role_execute(%L::uuid,%L::uuid)',
    (select value->'batch'->>'batch_id' from qa_role_values where name='atomic'),(select value->'operations'->0->>'operation_id' from qa_role_values where name='atomic')),
  'P0001','QA_AUDIT_BLOCKED');
select pg_temp.qa_role_check('audit failure leaves recoverable prepared decision',public.rpc_admin_role_status()->'operations'->0->>'status'='prepared');
reset role;
select pg_temp.qa_role_check('audit failure committed no profile mutation',
  (select role='passenger' and not is_driver from public.profiles where id=(select user_id from qa_role_actors where name='tie2'))
  and (select revision=0 from mobio_private.admin_user_role_versions where user_id=(select user_id from qa_role_actors where name='tie2')));
drop trigger qa_block_role_audit on public.admin_audit_log;
set local role authenticated;
update qa_role_values set value=public.rpc_admin_role_execute((value->'batch'->>'batch_id')::uuid,
  (value->'operations'->0->>'operation_id')::uuid) where name='atomic';
select pg_temp.qa_role_check('reserved operation survives physical snapshot expiry',
  (select value->'operations'->0->>'status'='confirmed' from qa_role_values where name='atomic'));
update qa_role_values set value=public.rpc_admin_role_seal((value->'batch'->>'batch_id')::uuid) where name='atomic';
select pg_temp.qa_role_error('missing snapshot cannot authorize fresh reservation',
  format('select public.rpc_admin_role_reserve(gen_random_uuid(),%L::uuid,%L::jsonb)',
    (select value->>'snapshot_id' from qa_role_values where name='fresh'),
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='fresh'),'tie1','driver'))),
  'P0001','ADMIN_USERS_SNAPSHOT_NOT_FOUND');
select pg_temp.qa_role_error('authenticated cannot run cache expiry','select public.rpc_admin_users_expire_snapshots(1)',
  '42501','permission denied for function rpc_admin_users_expire_snapshots');
reset role;
select pg_temp.qa_role_check('database cron expiry path is bounded SQL only',
  exists(select 1 from cron.job where jobname='admin-user-snapshot-expiry' and command='select mobio_private.expire_admin_user_snapshots(100);')
  and current_setting('cron.launch_active_jobs')='off');
select pg_temp.qa_role_identity('manager');set local role authenticated;
insert into qa_role_values values('manager-page',public.rpc_admin_users_page(p_page_size=>100));
reset role;
update mobio_private.admin_user_snapshots set as_of=now()-interval '11 minutes',expires_at=now()-interval '1 minute'
  where snapshot_id=(select (value->>'snapshot_id')::uuid from qa_role_values where name='manager-page');
set local role authenticated;
select pg_temp.qa_role_error('expired snapshot page denied',
  format('select public.rpc_admin_users_page(p_snapshot_id=>%L::uuid,p_page_size=>100)',
    (select value->>'snapshot_id' from qa_role_values where name='manager-page')),'P0001','ADMIN_USERS_SNAPSHOT_EXPIRED');
select pg_temp.qa_role_error('expired snapshot cannot authorize new role plan',
  format('select public.rpc_admin_role_reserve(gen_random_uuid(),%L::uuid,%L::jsonb)',
    (select value->>'snapshot_id' from qa_role_values where name='manager-page'),
    jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='manager-page'),'tie1','driver'))),
  'P0001','ADMIN_USERS_SNAPSHOT_EXPIRED');
reset role;
select pg_temp.qa_role_identity('owner');set local role authenticated;
insert into qa_role_values values('expired-batch-page',public.rpc_admin_users_page(p_page_size=>100));
insert into qa_role_values values('expired-batch',public.rpc_admin_role_reserve(gen_random_uuid(),
  (select (value->>'snapshot_id')::uuid from qa_role_values where name='expired-batch-page'),
  jsonb_build_array(pg_temp.qa_role_target((select value from qa_role_values where name='expired-batch-page'),'tie1','driver'))));
reset role;
update mobio_private.admin_role_batches set reserved_at=now()-interval '11 minutes',execute_expires_at=now()-interval '1 minute'
  where batch_id=(select (value->'batch'->>'batch_id')::uuid from qa_role_values where name='expired-batch');
set local role authenticated;
select pg_temp.qa_role_error('execute TTL denies without automatically closing unknown work',
  format('select public.rpc_admin_role_execute(%L::uuid,%L::uuid)',
    (select value->'batch'->>'batch_id' from qa_role_values where name='expired-batch'),
    (select value->'operations'->0->>'operation_id' from qa_role_values where name='expired-batch')),
  'P0001','ADMIN_ROLE_BATCH_EXPIRED');
select pg_temp.qa_role_check('expired plan stays unresolved until explicit seal',public.rpc_admin_role_status()->'batch'->>'state'='open');
update qa_role_values set value=public.rpc_admin_role_seal((value->'batch'->>'batch_id')::uuid) where name='expired-batch';
select pg_temp.qa_role_check('expired plan seals as not started',
  (select value->'operations'->0->>'status'='not_started' from qa_role_values where name='expired-batch'));
reset role;
-- The >10k sentinel rejects the complete result instead of publishing a capped count.
create temp table qa_role_bulk(id uuid default gen_random_uuid(),n integer);
insert into qa_role_bulk(n) select generate_series(1,10001);
insert into auth.users(id,raw_app_meta_data,raw_user_meta_data,is_anonymous)
  select id,'{"provider":"whatsapp_cloud_otp"}','{}',false from qa_role_bulk;
insert into public.profiles(id,name,phone,member_id)
  select id,'too-broad-role-fixture-'||n,'',(800000+n)::text from qa_role_bulk;
set local role authenticated;
select pg_temp.qa_role_error('10001 matching rows fail closed without fabricated exact count',
  'select public.rpc_admin_users_page(p_search=>''too-broad-role-fixture'')','P0001','ADMIN_USERS_QUERY_TOO_BROAD');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
update public.profiles set role='admin' where id=(select id from qa_role_bulk where n=10001);
select pg_temp.qa_role_identity('owner');set local role authenticated;
select pg_temp.qa_role_check('exact 10000 bound preserves all matches before sorting',
  (public.rpc_admin_users_page(p_search=>'too-broad-role-fixture',p_role=>'passenger')->>'total_exact')::integer=10000);
reset role;
select count(*) as admin_user_query_role_assertions from qa_role_results;
rollback;
