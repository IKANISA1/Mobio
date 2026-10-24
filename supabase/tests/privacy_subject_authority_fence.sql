-- STAGED / UNEXECUTED. Same disposable real-schema connection as the proposed
-- forward migration. Actual SQL rows/roles; no signed-JWT or provider claim.
-- All synthetic cases, policy changes and deletion probes roll back.
begin;
set local statement_timeout='90s';
set local request.jwt.claims='{"role":"service_role"}';
create temp table qa_fence_actors(name text primary key,id uuid default gen_random_uuid(),
  sid uuid default gen_random_uuid(),otp uuid default gen_random_uuid(),
  request_id uuid default gen_random_uuid(),action_id uuid default gen_random_uuid(),phone text,provider text);
insert into qa_fence_actors(name,phone,provider) values
  ('consumer','+250700007901','whatsapp_cloud_otp'),('healthy','+250700007902','whatsapp_cloud_otp'),
  ('admin','+250700007903','admin_whatsapp_otp'),('operator','+250700007904','admin_whatsapp_otp'),
  ('target','+250700007905','whatsapp_cloud_otp'),('missing','+250700007906','whatsapp_cloud_otp'),
  ('review',null,'store_review');
create temp table qa_fence_values(name text primary key,value jsonb);
create temp table qa_fence_results(label text);
grant select on qa_fence_actors to service_role,authenticated;
grant select,insert,update on qa_fence_values to service_role,authenticated;
grant select,insert on qa_fence_results to service_role,authenticated;
create function pg_temp.qa_fence_check(label text,value boolean) returns void language plpgsql as $$
begin
  if value is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
  insert into pg_temp.qa_fence_results values(label);
end $$;
create function pg_temp.qa_fence_error(label text,statement text,expected_state text,expected_message text)
returns void language plpgsql as $$
declare rejected boolean:=false; state text; message text;
begin
  begin execute statement;
  exception when others then
    get stacked diagnostics state=returned_sqlstate,message=message_text;
    if state<>expected_state or message<>expected_message then
      raise exception 'ASSERTION FAILED: % got %/%',label,state,message; end if;
    rejected:=true;
  end;
  perform pg_temp.qa_fence_check(label,rejected);
end $$;
create function pg_temp.qa_fence_identity(p_name text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claim.role','',true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',id,'session_id',sid,'role','authenticated',
    'is_anonymous',false,'app_metadata',jsonb_build_object('provider',provider))::text,true)
    from pg_temp.qa_fence_actors where name=p_name;
end $$;
create function pg_temp.qa_fence_args(p_name text,p_revision integer default 1,p_plan text default repeat('a',64),
  p_inventory text default repeat('b',64),p_action uuid default null) returns text language sql as $$
  select format('public.rpc_privacy_activate_subject_fence(%L::uuid,%L::uuid,%s,%L,%L,''qa/fence'')',
    request_id,coalesce(p_action,action_id),p_revision,p_plan,p_inventory)
  from pg_temp.qa_fence_actors where name=p_name
$$;

select pg_temp.qa_fence_check('migration installs empty ordinary fence',
  (select count(*)=0 from mobio_private.privacy_subject_authority_fences));
select pg_temp.qa_fence_check('new RPC is service-only',
  has_function_privilege('service_role','public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)','EXECUTE')
  and not has_function_privilege('authenticated','public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)','EXECUTE')
  and not has_function_privilege('anon','public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)','EXECUTE'));
select pg_temp.qa_fence_check('no direct client or service fence CRUD',
  not has_table_privilege('service_role','mobio_private.privacy_subject_authority_fences','SELECT,INSERT,UPDATE,DELETE')
  and not has_table_privilege('authenticated','mobio_private.privacy_subject_authority_fences','SELECT,INSERT,UPDATE,DELETE'));
select pg_temp.qa_fence_check('fence has no Auth/profile foreign key',not exists(
  select 1 from pg_constraint c join pg_class r on r.oid=c.confrelid join pg_namespace n on n.oid=r.relnamespace
  where c.conrelid='mobio_private.privacy_subject_authority_fences'::regclass and c.contype='f'
    and (n.nspname='auth' or r.oid='public.profiles'::regclass)));
select pg_temp.qa_fence_check('activation source never locks Auth/profile/resource rows',
  (select position('from auth.users' in prosrc)=0 and position('from auth.sessions' in prosrc)=0
    and position('from public.profiles' in prosrc)=0 and position('delete from' in prosrc)=0
    and position('update auth.' in prosrc)=0 from pg_proc
    where oid='public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)'::regprocedure));
select pg_temp.qa_fence_check('activation and service fulfil take subject before first case FOR UPDATE',
  (select bool_and(position('lock_privacy_subject' in prosrc)>0
    and position('lock_privacy_subject' in prosrc)<position('for update' in prosrc)) from pg_proc where oid in(
      'public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)'::regprocedure,
      'public.rpc_privacy_fulfil(uuid,uuid,integer,text,jsonb,text)'::regprocedure)));
select pg_temp.qa_fence_check('mutating owner RPC takes locked session before owner/case locking',
  (select position('require_verified_interactive_session' in prosrc)>0
    and position('require_verified_interactive_session' in prosrc)<position('for update' in prosrc)
    from pg_proc where oid='public.rpc_privacy_user(text,uuid,text,boolean)'::regprocedure));

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
  select id,phone,now(),jsonb_build_object('provider',provider) ||
    case when name='review' then '{"role":"passenger"}'::jsonb else '{}'::jsonb end,
    '{}',false from qa_fence_actors where name<>'missing';
insert into auth.sessions(id,user_id,created_at,not_after)
  select sid,id,now(),now()+interval '1 hour' from qa_fence_actors where name not in('missing','review');
insert into public.otp_codes(id,phone,purpose,code,code_hash,verified,expires_at)
  select otp,phone,case when provider='admin_whatsapp_otp' then 'admin_login' else 'app_login' end,
    '000000',repeat('c',64),true,now()+interval '5 minutes' from qa_fence_actors where name not in('missing','review');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
  select phone,'+250',true from qa_fence_actors where provider='admin_whatsapp_otp';
select public.rpc_register_app_whatsapp_session(id,sid,otp::text) from qa_fence_actors
  where name in('consumer','healthy','target');
select public.rpc_register_admin_session(id,sid,otp::text) from qa_fence_actors where provider='admin_whatsapp_otp';
select public.rpc_register_store_review_principal(id,'qa/fence-review') from qa_fence_actors where name='review';
update public.profiles set role='admin' where id in(select id from qa_fence_actors where provider='admin_whatsapp_otp');
insert into public.fcm_tokens(user_id,token,platform,session_id)
  select id,'qa-fence-token-'||name,'android',sid from qa_fence_actors where name in('consumer','healthy');
insert into qa_fence_values(name,value) select name||'-token',jsonb_build_object('id',t.id,'binding_id',t.binding_id)
  from qa_fence_actors a join public.fcm_tokens t on t.user_id=a.id where a.name in('consumer','healthy');
update mobio_private.push_policy set enabled=true where singleton;
with inserted as (insert into public.notifications(user_id,title,body,type,metadata)
  select id,'Synthetic fence','Synthetic SQL fixture','system_announcement','{"channels":["push"]}'
  from qa_fence_actors where name='consumer' returning id)
  insert into qa_fence_values(name,value) select 'consumer-notification',to_jsonb(id) from inserted;
insert into qa_fence_values(name,value) select 'consumer-push-lease',jsonb_build_object('job_id',id,'lease_id',gen_random_uuid())
  from mobio_private.push_jobs where notification_id=(select (value#>>'{}')::uuid from qa_fence_values where name='consumer-notification');
update mobio_private.push_jobs set state='leased',attempts=1,
  lease_id=(select (value->>'lease_id')::uuid from qa_fence_values where name='consumer-push-lease'),
  lease_until=clock_timestamp()+interval '2 minutes'
  where id=(select (value->>'job_id')::uuid from qa_fence_values where name='consumer-push-lease');
select pg_temp.qa_fence_check('ordinary proved token creates exact pre-fence queued job',
  (select count(*)=1 from qa_fence_values where name='consumer-push-lease'));
insert into mobio_private.privacy_requests(request_id,owner_id,originating_session_id,notice_version,
  status,revision,started_at,plan_sha256,inventory_sha256)
  select request_id,id,sid,'qa-fence-v1',case when name='healthy' then 'requested' else 'processing' end,1,
    case when name='healthy' then null else now() end,repeat('a',64),repeat('b',64)
  from qa_fence_actors where name in('consumer','admin','target','missing','healthy');

select pg_temp.qa_fence_identity('consumer');
select pg_temp.qa_fence_check('healthy consumer exact proof remains admitted',
  public.verified_app_user_id()=(select id from qa_fence_actors where name='consumer'));
set local role authenticated;
select pg_temp.qa_fence_error('ordinary caller cannot invoke service activation',
  'select '||pg_temp.qa_fence_args('consumer'),'42501','permission denied for function rpc_privacy_activate_subject_fence');
reset role;
select pg_temp.qa_fence_identity('admin');
select pg_temp.qa_fence_check('healthy fresh Admin remains admitted',
  public.require_recent_admin_session()=(select id from qa_fence_actors where name='admin'));
update mobio_private.admin_session_leases set authenticated_at=now()-interval '6 minutes'
  where user_id=(select id from qa_fence_actors where name='admin');
select pg_temp.qa_fence_error('unfenced stale Admin still requires precise step-up',
  'select public.require_recent_admin_session()','42501','ADMIN_REAUTHENTICATION_REQUIRED');
update mobio_private.admin_session_leases set authenticated_at=now()
  where user_id=(select id from qa_fence_actors where name='admin');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.qa_fence_error('disabled processing denies activation',
  'select '||pg_temp.qa_fence_args('consumer'),'P0001','PRIVACY_PROCESSING_DISABLED');
update mobio_private.privacy_policy set intake_enabled=true,processing_enabled=true,notice_version='qa-fence-v1',
  approval_reference='qa/fence',inventory_sha256=repeat('b',64) where singleton;
select pg_temp.qa_fence_error('unstarted case cannot activate',
  'select '||pg_temp.qa_fence_args('healthy'),'P0001','PRIVACY_NOT_PROCESSING');
select pg_temp.qa_fence_error('missing case cannot activate',format(
  'select public.rpc_privacy_activate_subject_fence(%L,%L,1,%L,%L,''qa/fence'')',gen_random_uuid(),gen_random_uuid(),repeat('a',64),repeat('b',64)),
  'P0001','PRIVACY_REQUEST_NOT_FOUND');
select pg_temp.qa_fence_error('wrong case revision denies',
  'select '||pg_temp.qa_fence_args('consumer',0),'P0001','PRIVACY_REVISION_CONFLICT');
select pg_temp.qa_fence_error('wrong stored plan denies',
  'select '||pg_temp.qa_fence_args('consumer',1,repeat('d',64)),'22023','PRIVACY_APPROVED_PLAN_REQUIRED');
select pg_temp.qa_fence_error('wrong case/policy inventory denies',
  'select '||pg_temp.qa_fence_args('consumer',1,repeat('a',64),repeat('d',64)),'22023','PRIVACY_APPROVED_PLAN_REQUIRED');
select pg_temp.qa_fence_check('rejected requests leave all cases/ledger/fences unchanged',
  not exists(select 1 from mobio_private.privacy_subject_authority_fences)
  and not exists(select 1 from mobio_private.privacy_actions where action='authority_fence')
  and (select bool_and(revision=1) from mobio_private.privacy_requests where request_id in(select request_id from qa_fence_actors)));
set local role service_role;
insert into qa_fence_values(name,value)
  select 'consumer-receipt',public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')
  from qa_fence_actors where name='consumer';
reset role;
select pg_temp.qa_fence_check('receipt derives immutable subject and exactly one revision from case',
  (select value->>'replayed'='false' and value->'receipt'->>'protocol'='mobio.privacy-authority-fence.v1'
    and value->'receipt'->>'subject_user_id'=(select id::text from qa_fence_actors where name='consumer')
    and value->'receipt'->>'request_id'=(select request_id::text from qa_fence_actors where name='consumer')
    and value->'receipt'->>'source_revision'='1' and value->'receipt'->>'applied_revision'='2'
    from qa_fence_values where name='consumer-receipt'));
select pg_temp.qa_fence_check('matched one ledger event/fence with no data deletion',
  (select count(*)=1 from mobio_private.privacy_actions where action_id=(select action_id from qa_fence_actors where name='consumer'))
  and (select count(*)=1 from mobio_private.privacy_subject_authority_fences where subject_user_id=(select id from qa_fence_actors where name='consumer'))
  and exists(select 1 from auth.users where id=(select id from qa_fence_actors where name='consumer'))
  and exists(select 1 from auth.sessions where id=(select sid from qa_fence_actors where name='consumer'))
  and exists(select 1 from public.profiles where id=(select id from qa_fence_actors where name='consumer')));
insert into qa_fence_values(name,value) select 'replayed',public.rpc_privacy_activate_subject_fence(request_id,action_id,1,
  repeat('a',64),repeat('b',64),'qa/fence') from qa_fence_actors where name='consumer';
select pg_temp.qa_fence_check('duplicate activation returns same receipt and no second revision',
  (select value->>'replayed'='true' and value->'receipt'=(select value->'receipt' from qa_fence_values where name='consumer-receipt')
    from qa_fence_values where name='replayed')
  and (select revision=2 from mobio_private.privacy_requests where request_id=(select request_id from qa_fence_actors where name='consumer')));
select pg_temp.qa_fence_error('changed duplicate input denies globally',
  'select '||pg_temp.qa_fence_args('consumer',1,repeat('d',64)),'22023','PRIVACY_ACTION_CONFLICT');
select pg_temp.qa_fence_error('same global action cannot target another case',
  'select '||pg_temp.qa_fence_args('target',1,repeat('a',64),repeat('b',64),(select action_id from qa_fence_actors where name='consumer')),
  '22023','PRIVACY_ACTION_CONFLICT');
select pg_temp.qa_fence_error('another action cannot replace the same subject fence',
  'select '||pg_temp.qa_fence_args('consumer',2,repeat('a',64),repeat('b',64),gen_random_uuid()),'P0001','PRIVACY_SUBJECT_ALREADY_FENCED');
update mobio_private.privacy_policy set processing_enabled=false where singleton;
select pg_temp.qa_fence_check('immutable duplicate receipt readable after policy disable',
  (select public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')->'receipt'
    from qa_fence_actors where name='consumer')=(select value->'receipt' from qa_fence_values where name='consumer-receipt'));
update mobio_private.privacy_policy set processing_enabled=true where singleton;
update mobio_private.privacy_requests set status='blocked',blocked_code='retention_review',revision=revision+1
  where request_id=(select request_id from qa_fence_actors where name='consumer');
select pg_temp.qa_fence_check('immutable receipt replay survives later case change without another revision',
  (select public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')->'receipt'
    from qa_fence_actors where name='consumer')=(select value->'receipt' from qa_fence_values where name='consumer-receipt')
  and (select revision=3 from mobio_private.privacy_requests where request_id=(select request_id from qa_fence_actors where name='consumer')));

select pg_temp.qa_fence_identity('consumer');
select pg_temp.qa_fence_check('live Auth/SID no longer grant ordinary authority',public.verified_app_user_id() is null);
select pg_temp.qa_fence_error('locked sensitive session denies fenced live UUID',format(
  'select mobio_private.require_verified_interactive_session(%L,%L,false)',
  (select id from qa_fence_actors where name='consumer'),(select sid from qa_fence_actors where name='consumer')),
  '42501','INTERACTIVE_SESSION_REQUIRED');
select pg_temp.qa_fence_check('pure private predicate rejects fenced recipient',
  not mobio_private.verified_interactive_account_is_eligible((select id from qa_fence_actors where name='consumer')));
select pg_temp.qa_fence_error('fenced Maps admission cannot charge quota',
  'select public.rpc_consume_maps_quota(''geocode'')','42501','INTERACTIVE_SESSION_REQUIRED');
select pg_temp.qa_fence_check('fenced Maps call leaves no account bucket',
  not exists(select 1 from mobio_private.maps_account_quota where user_id=(select id from qa_fence_actors where name='consumer')));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into qa_fence_values(name,value) select 'consumer-push-denial',public.rpc_push_authorize(
  (value->>'job_id')::uuid,(value->>'lease_id')::uuid) from qa_fence_values where name='consumer-push-lease';
select pg_temp.qa_fence_check('actual final queued push authorization denies fenced bound token',
  (select value->>'allowed'='false' and value->>'reason'='binding_inactive' from qa_fence_values where name='consumer-push-denial')
  and (select state='skipped' and dispatch_started_at is null from mobio_private.push_jobs
    where id=(select (value->>'job_id')::uuid from qa_fence_values where name='consumer-push-lease')));
select pg_temp.qa_fence_check('healthy bound push token still allowed',
  (select mobio_private.push_token_allowed((v.value->>'id')::uuid,(v.value->>'binding_id')::uuid,a.id)
    from qa_fence_values v,qa_fence_actors a where v.name='healthy-token' and a.name='healthy'));
select pg_temp.qa_fence_error('fenced Face caller cannot reserve provider work',format(
  'select public.rpc_reserve_biopay_provider_operation(%L,''resolve'',%L,''qa-fence-key'',repeat(''c'',64))',
  (select id from qa_fence_actors where name='consumer'),(select sid from qa_fence_actors where name='consumer')),
  '42501','BIOPAY_SESSION_INVALID');
select pg_temp.qa_fence_error('fenced Face caller cannot prepare handoff',format(
  'select public.rpc_biopay_face_authority(%L,%L,''prepare_handoff'',''{}''::jsonb)',
  (select id from qa_fence_actors where name='consumer'),(select sid from qa_fence_actors where name='consumer')),
  '42501','BIOPAY_SESSION_INVALID');
select pg_temp.qa_fence_check('fenced Face denial creates no provider operation',
  not exists(select 1 from public.biopay_provider_operations where user_id=(select id from qa_fence_actors where name='consumer')));
select pg_temp.qa_fence_error('fenced owner cannot bind consumed OTP again',format(
  'select mobio_private.bind_whatsapp_otp_account(%L,%L,''app_login'')',
  (select id from qa_fence_actors where name='consumer'),(select otp::text from qa_fence_actors where name='consumer')),
  '42501','WHATSAPP_BINDING_REJECTED');
select pg_temp.qa_fence_error('contextual owner lookup must deny rather than return null',format(
  'select public.rpc_lookup_whatsapp_otp_phone_owner(%L,%L,''app_login'')',
  (select phone from qa_fence_actors where name='consumer'),(select otp::text from qa_fence_actors where name='consumer')),
  '42501','PHONE_IDENTITY_UNAVAILABLE');
select pg_temp.qa_fence_error('legacy owner lookup preserves exact denial',format(
  'select public.rpc_lookup_verified_phone_owner(%L)',(select phone from qa_fence_actors where name='consumer')),
  '42501','PHONE_IDENTITY_UNAVAILABLE');
select pg_temp.qa_fence_error('fenced owner cannot restore/register exact proof',format(
  'select public.rpc_register_app_whatsapp_session(%L,%L,%L)',(select id from qa_fence_actors where name='consumer'),
  (select sid from qa_fence_actors where name='consumer'),(select otp::text from qa_fence_actors where name='consumer')),
  '42501','WHATSAPP_BINDING_REJECTED');
select pg_temp.qa_fence_error('service Auth update cannot re-materialize fenced owner',format(
  'update auth.users set raw_user_meta_data=''{}'' where id=%L',(select id from qa_fence_actors where name='consumer')),
  '42501','SUBJECT_AUTHORITY_FENCED');
select pg_temp.qa_fence_error('service profile write cannot bypass fence',format(
  'update public.profiles set name=''late profile'' where id=%L',(select id from qa_fence_actors where name='consumer')),
  '42501','SUBJECT_AUTHORITY_FENCED');
select pg_temp.qa_fence_error('new Auth session cannot bypass fence',format(
  'insert into auth.sessions(id,user_id,created_at) values(%L,%L,now())',gen_random_uuid(),
  (select id from qa_fence_actors where name='consumer')),'42501','SUBJECT_AUTHORITY_FENCED');
select pg_temp.qa_fence_error('deny ledger cannot be edited',format(
  'update mobio_private.privacy_subject_authority_fences set activated_at=now() where subject_user_id=%L',
  (select id from qa_fence_actors where name='consumer')),'42501','PRIVACY_AUTHORITY_FENCE_IMMUTABLE');
select pg_temp.qa_fence_error('deny ledger cannot be removed',format(
  'delete from mobio_private.privacy_subject_authority_fences where subject_user_id=%L',
  (select id from qa_fence_actors where name='consumer')),'42501','PRIVACY_AUTHORITY_FENCE_IMMUTABLE');

-- Missing-row future materialization and later fixture-only deletion.
select public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')
  from qa_fence_actors where name='missing';
select pg_temp.qa_fence_error('missing-row fence blocks future Auth insert before profile trigger',format(
  'insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous) values(%L,%L,now(),''{"provider":"whatsapp_cloud_otp"}'',''{}'',false)',
  (select id from qa_fence_actors where name='missing'),(select phone from qa_fence_actors where name='missing')),
  '42501','SUBJECT_AUTHORITY_FENCED');
select pg_temp.qa_fence_error('missing-row fence blocks future service profile insert',format(
  'insert into public.profiles(id,name,phone) values(%L,''late insert'',%L)',
  (select id from qa_fence_actors where name='missing'),(select phone from qa_fence_actors where name='missing')),
  '42501','SUBJECT_AUTHORITY_FENCED');
delete from auth.users where id=(select id from qa_fence_actors where name='consumer');
select pg_temp.qa_fence_check('fence and immutable receipt survive fixture Auth/profile cascade',
  not exists(select 1 from auth.users where id=(select id from qa_fence_actors where name='consumer'))
  and not exists(select 1 from public.profiles where id=(select id from qa_fence_actors where name='consumer'))
  and (select receipt=(select value->'receipt' from qa_fence_values where name='consumer-receipt')
    from mobio_private.privacy_subject_authority_fences where subject_user_id=(select id from qa_fence_actors where name='consumer')));
select pg_temp.qa_fence_error('deleted UUID cannot be recreated',format(
  'insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous) values(%L,%L,now(),''{"provider":"whatsapp_cloud_otp"}'',''{}'',false)',
  (select id from qa_fence_actors where name='consumer'),(select phone from qa_fence_actors where name='consumer')),
  '42501','SUBJECT_AUTHORITY_FENCED');
select pg_temp.qa_fence_check('permanent reviewer registry is preserved separately',
  exists(select 1 from mobio_private.store_review_principals where user_id=(select id from qa_fence_actors where name='review'))
  and not mobio_private.verified_interactive_account_is_eligible((select id from qa_fence_actors where name='review'))
  and not exists(select 1 from mobio_private.privacy_subject_authority_fences where subject_user_id=(select id from qa_fence_actors where name='review')));

-- Other-actor target mutation uses the existing target_changed receipt shape.
select pg_temp.qa_fence_identity('operator');
set local role authenticated;
insert into qa_fence_values(name,value) values('target-page',public.rpc_admin_users_page(p_search=>'700007905',p_page_size=>100));
insert into qa_fence_values(name,value) select 'target-batch',public.rpc_admin_role_reserve(gen_random_uuid(),
  (value->>'snapshot_id')::uuid,jsonb_build_array(jsonb_build_object('target_id',value->'rows'->0->>'id',
    'expected_role',value->'rows'->0->>'role','expected_revision',value->'rows'->0->'role_revision','requested_role','driver')))
  from qa_fence_values where name='target-page';
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')
  from qa_fence_actors where name='target';
select pg_temp.qa_fence_identity('operator');
set local role authenticated;
insert into qa_fence_values(name,value) select 'target-execute',public.rpc_admin_role_execute(
  (value->'batch'->>'batch_id')::uuid,(value->'operations'->0->>'operation_id')::uuid)
  from qa_fence_values where name='target-batch';
reset role;
select pg_temp.qa_fence_check('fenced role target is authoritative known rejection without new wire code',
  (select value->'operations'->0->>'status'='known_rejected'
    and value->'operations'->0->>'rejection_code'='target_changed'
    and value->'operations'->0->'receipt'='null'::jsonb from qa_fence_values where name='target-execute'));
select pg_temp.qa_fence_check('fenced role target changes no role or audit',
  (select role='passenger' and not is_driver from public.profiles where id=(select id from qa_fence_actors where name='target'))
  and not exists(select 1 from public.admin_audit_log where details->>'operation_id'=
    (select value->'operations'->0->>'operation_id' from qa_fence_values where name='target-batch')));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.rpc_privacy_fulfil(request_id,gen_random_uuid(),2,'evidence',
  jsonb_build_object('category','face_vectors','outcome','not_applicable','evidence_sha256',repeat('d',64)),
  'qa/post-fence-evidence') from qa_fence_actors where name='target';
select pg_temp.qa_fence_check('service case evidence remains possible after ordinary identity is fenced',
  (select revision=3 and status='processing' from mobio_private.privacy_requests
    where request_id=(select request_id from qa_fence_actors where name='target'))
  and exists(select 1 from mobio_private.privacy_evidence where request_id=(select request_id from qa_fence_actors where name='target')
    and category='face_vectors' and request_revision=3)
  and not mobio_private.verified_interactive_account_is_eligible((select id from qa_fence_actors where name='target')));

select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.rpc_privacy_activate_subject_fence(request_id,action_id,1,repeat('a',64),repeat('b',64),'qa/fence')
  from qa_fence_actors where name='admin';
select pg_temp.qa_fence_identity('admin');
select pg_temp.qa_fence_check('fenced fresh Admin loses base identity',public.verified_admin_user_id() is null and public.verified_app_user_id() is null);
select pg_temp.qa_fence_error('fenced Admin recent gate returns generic authority denial',
  'select public.require_recent_admin_session()','42501','INTERACTIVE_SESSION_REQUIRED');
select pg_temp.qa_fence_error('fenced Admin locked helper does not offer step-up restoration',format(
  'select mobio_private.require_verified_interactive_session(%L,%L,true)',(select id from qa_fence_actors where name='admin'),
  (select sid from qa_fence_actors where name='admin')),'42501','INTERACTIVE_SESSION_REQUIRED');
select pg_temp.qa_fence_identity('healthy');
select pg_temp.qa_fence_check('another proved consumer remains admitted',public.verified_app_user_id()=(select id from qa_fence_actors where name='healthy'));
select pg_temp.qa_fence_identity('operator');
select pg_temp.qa_fence_check('another fresh Admin remains admitted',public.require_recent_admin_session()=(select id from qa_fence_actors where name='operator'));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.qa_fence_check('automatic erasure remains unimplemented',public.rpc_privacy_health()->>'automatic_erasure_implemented'='false');
select count(*)||' staged privacy-authority-fence assertions passed' as result from qa_fence_results;
rollback;
