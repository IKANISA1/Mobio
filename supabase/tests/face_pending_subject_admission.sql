-- Installed-schema SQL-context checks; not signed Auth HTTP.
-- Synthetic subjects, processing policy and all probes roll back; no provider.
begin;
set local statement_timeout='90s';
set local request.jwt.claims='{"role":"service_role"}';
create temp table qa_pending_actor(name text primary key,id uuid default gen_random_uuid(),
 sid uuid default gen_random_uuid(),otp uuid default gen_random_uuid(),method uuid default gen_random_uuid(),
 phone text,provider text,operation uuid,vector text,revision bigint,request uuid default gen_random_uuid(),
 action uuid default gen_random_uuid());
insert into qa_pending_actor(name,phone,provider) values
 ('consumer','+250700008501','whatsapp_cloud_otp'),('admin','+250700008502','admin_whatsapp_otp'),
 ('other','+250700008503','whatsapp_cloud_otp');
create temp table qa_pending_result(label text);
create temp table qa_pending_saved(name text primary key,value jsonb);
grant select on qa_pending_actor to authenticated,service_role;
create function pg_temp.qa_pending_check(label text,ok boolean) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
 insert into pg_temp.qa_pending_result values(label);
end $$;
create function pg_temp.qa_pending_snapshot() returns jsonb language sql as $$
 select jsonb_build_object('profiles',(select jsonb_agg(to_jsonb(p) order by p.id) from public.biopay_profiles p),
  'operations',(select jsonb_agg(to_jsonb(o) order by o.id) from public.biopay_provider_operations o),
  'revisions',(select jsonb_agg(to_jsonb(r) order by r.vector_id) from public.biopay_face_revisions r),
  'cleanup',(select jsonb_agg(to_jsonb(c) order by c.vector_id) from public.biopay_face_cleanup c),
  'audit',(select jsonb_agg(to_jsonb(a) order by a.id) from public.biopay_audit_events a));
$$;
create function pg_temp.qa_pending_admit(actor text) returns jsonb language sql as $$
 select public.rpc_biopay_face_pending_admission(vector,operation) from pg_temp.qa_pending_actor where name=actor
$$;
create function pg_temp.qa_pending_denied(label text,actor text) returns void language plpgsql as $$
declare before jsonb; result jsonb;
begin
 before:=pg_temp.qa_pending_snapshot(); result:=pg_temp.qa_pending_admit(actor);
 perform pg_temp.qa_pending_check(label,result->>'protocol'='mobio.face-pending-admission.v1'
  and result->>'admitted'='false' and result->>'code'='PENDING_UNAVAILABLE'
  and not(result ?| array['user_id','session_id','vector_id','operation_id','revision','model_version','expires_at'])
  and before=pg_temp.qa_pending_snapshot());
end $$;
create function pg_temp.qa_pending_error(label text,statement text,state text,message text) returns void language plpgsql as $$
declare rejected boolean:=false; actual_state text; actual_message text;
begin
 begin execute statement;
 exception when others then
  get stacked diagnostics actual_state=returned_sqlstate,actual_message=message_text;
  if actual_state<>state or actual_message<>message then raise exception 'ASSERTION FAILED: % got %/%',label,actual_state,actual_message; end if;
  rejected:=true;
 end;
 perform pg_temp.qa_pending_check(label,rejected);
end $$;
create function pg_temp.qa_pending_begin(actor text) returns void language plpgsql as $$
declare a pg_temp.qa_pending_actor%rowtype; op uuid; rv jsonb;
begin
 select * into strict a from pg_temp.qa_pending_actor where name=actor;
 op:=public.rpc_reserve_biopay_provider_operation(a.id,'enroll',a.sid,replace(gen_random_uuid()::text,'-',''),repeat('a',64));
 rv:=public.rpc_biopay_face_authority(a.id,a.sid,'begin_enroll',jsonb_build_object('operation_id',op,
  'method_id',a.method,'consent',true,'consent_version','face-discovery-v1'));
 update pg_temp.qa_pending_actor set operation=op,vector=rv->>'vector_id',revision=(rv->>'revision')::bigint where name=actor;
end $$;

insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)
 select id,phone,now(),false,jsonb_build_object('provider',provider),'{"qa_fixture":true}' from qa_pending_actor;
insert into auth.sessions(id,user_id,created_at,not_after)
 select sid,id,now(),now()+interval '1 hour' from qa_pending_actor;
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 select phone,'+250',true from qa_pending_actor where name='admin';
insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at)
 select otp,phone,id,'000000',repeat('a',64),case when provider='admin_whatsapp_otp' then 'admin_login' else 'app_login' end,
 true,now()+interval '5 minutes' from qa_pending_actor;
select public.rpc_register_app_whatsapp_session(id,sid,otp::text) from qa_pending_actor where provider='whatsapp_cloud_otp';
select public.rpc_register_admin_session(id,sid,otp::text) from qa_pending_actor where name='admin';
update public.profiles set role='admin' where id=(select id from qa_pending_actor where name='admin');
insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label)
 select method,id,'mtn_rw','mobileWallet',phone,'Synthetic pending receiving' from qa_pending_actor;
select pg_temp.qa_pending_begin(name) from qa_pending_actor;
insert into qa_pending_saved(name,value)
 select 'lease',to_jsonb(l) from mobio_private.admin_session_leases l where l.user_id=(select id from qa_pending_actor where name='admin');
insert into qa_pending_saved(name,value)
 select 'model-policy',to_jsonb(p) from public.biopay_face_policy p where p.model_version='yunet2023mar-sface2021dec-opencv4.11-v1';

select pg_temp.qa_pending_check('service-only admission ACL',
 has_function_privilege('service_role','public.rpc_biopay_face_pending_admission(text,uuid)','EXECUTE')
 and not has_function_privilege('authenticated','public.rpc_biopay_face_pending_admission(text,uuid)','EXECUTE')
 and not has_function_privilege('anon','public.rpc_biopay_face_pending_admission(text,uuid)','EXECUTE'));
select pg_temp.qa_pending_check('subject-sensitive admission precedes every Face row lock',
 (select position('require_verified_interactive_session' in prosrc)>0
  and position('require_verified_interactive_session' in prosrc)<position('for share' in prosrc)
  from pg_proc where oid='public.rpc_biopay_face_pending_admission(text,uuid)'::regprocedure));
select pg_temp.qa_pending_check('healthy consumer and fresh Admin exact tuple admitted without effects',
 (select bool_and(result->>'admitted'='true' and (result->>'user_id')::uuid=a.id
  and (result->>'session_id')::uuid=a.sid and result->>'vector_id'=a.vector
  and (result->>'operation_id')::uuid=a.operation and (result->>'revision')::bigint=a.revision
  and result->>'model_version'='yunet2023mar-sface2021dec-opencv4.11-v1'
  and (result->>'expires_at')::timestamptz>(result->>'server_now')::timestamptz)
  from qa_pending_actor a cross join lateral (select pg_temp.qa_pending_admit(a.name) result) x));
insert into qa_pending_saved values('snapshot',pg_temp.qa_pending_snapshot());
select pg_temp.qa_pending_admit(name) from qa_pending_actor;
select pg_temp.qa_pending_check('admission creates no Face mutation/audit/cleanup or case evidence',
 (select value from qa_pending_saved where name='snapshot')=pg_temp.qa_pending_snapshot()
 and not exists(select 1 from mobio_private.privacy_actions where request_id in(select request from qa_pending_actor)));
select pg_temp.qa_pending_error('malformed target rejects',
 'select public.rpc_biopay_face_pending_admission(''untrusted'',gen_random_uuid())','22023','INVALID_FACE_PENDING_ADMISSION');
select set_config('request.jwt.claims','{"role":"authenticated"}',true);
select pg_temp.qa_pending_error('service purpose denial precedes malformed arguments',
 'select public.rpc_biopay_face_pending_admission(null,null)','42501','SERVICE_ROLE_REQUIRED');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.qa_pending_check('missing exact tuple denies',
 (public.rpc_biopay_face_pending_admission('f_'||replace(gen_random_uuid()::text,'-',''),gen_random_uuid())->>'admitted')='false');
select pg_temp.qa_pending_check('different operation cannot authorize a vector',
 (select (public.rpc_biopay_face_pending_admission(a.vector,b.operation)->>'admitted')='false'
  from qa_pending_actor a,qa_pending_actor b where a.name='consumer' and b.name='other'));

update auth.users set banned_until=now()+interval '1 day' where id=(select id from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('banned subject denies without target effects','consumer');
update auth.users set banned_until=null where id=(select id from qa_pending_actor where name='consumer');
update mobio_private.consumer_session_proofs set revoked_at=now() where user_id=(select id from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('revoked exact proof denies without target effects','consumer');
update mobio_private.consumer_session_proofs set revoked_at=null where user_id=(select id from qa_pending_actor where name='consumer');
update auth.sessions set not_after=now()-interval '1 minute' where id=(select sid from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('expired recorded SID denies without target effects','consumer');
update auth.sessions set not_after=now()+interval '1 hour' where id=(select sid from qa_pending_actor where name='consumer');
update public.biopay_provider_operations set state='failed' where id=(select operation from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('failed operation denies without target effects','consumer');
update public.biopay_provider_operations set state='processing',consumed_at=now() where id=(select operation from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('consumed operation denies without target effects','consumer');
update public.biopay_provider_operations set consumed_at=null,expires_at=now()-interval '1 minute' where id=(select operation from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('expired operation denies without target effects','consumer');
update public.biopay_provider_operations set expires_at=now()+interval '3 minutes' where id=(select operation from qa_pending_actor where name='consumer');
update public.biopay_face_revisions set expires_at=now()-interval '1 minute' where vector_id=(select vector from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('expired pending revision denies without target effects','consumer');
update public.biopay_face_revisions set expires_at=now()+interval '3 minutes',model_version='unrelated-model' where vector_id=(select vector from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('wrong model denies without target effects','consumer');
update public.biopay_face_revisions set model_version='yunet2023mar-sface2021dec-opencv4.11-v1',consent_version='unrelated-consent' where vector_id=(select vector from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('wrong consent denies without target effects','consumer');
update public.biopay_face_revisions set consent_version='face-discovery-v1' where vector_id=(select vector from qa_pending_actor where name='consumer');
delete from public.biopay_face_policy where model_version='yunet2023mar-sface2021dec-opencv4.11-v1';
select pg_temp.qa_pending_denied('missing current model policy denies without target effects','consumer');
insert into public.biopay_face_policy select (jsonb_populate_record(null::public.biopay_face_policy,(select value from qa_pending_saved where name='model-policy'))).*;
update public.biopay_payment_methods set active=false where id=(select method from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('disabled receiving method denies without target effects','consumer');
update public.biopay_payment_methods set active=true where id=(select method from qa_pending_actor where name='consumer');
update public.biopay_profiles set pending_vector_id='f_'||repeat('0',32) where user_id=(select id from qa_pending_actor where name='consumer');
select pg_temp.qa_pending_denied('replaced current vector denies without target effects','consumer');
update public.biopay_profiles set pending_vector_id=(select vector from qa_pending_actor where name='consumer') where user_id=(select id from qa_pending_actor where name='consumer');

do $leases$
declare state text; actor uuid:=(select id from pg_temp.qa_pending_actor where name='admin');
begin
 foreach state in array array['missing','revoked','future','idle','absolute','recent'] loop
  if state='missing' then delete from mobio_private.admin_session_leases where user_id=actor;
  elsif state='revoked' then update mobio_private.admin_session_leases set revoked_at=clock_timestamp() where user_id=actor;
  elsif state='future' then update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()+interval '1 minute',last_activity_at=clock_timestamp()+interval '2 minutes' where user_id=actor;
  elsif state='idle' then update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '1 minute' where user_id=actor;
  elsif state='absolute' then update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '2 minutes',absolute_expires_at=clock_timestamp()-interval '1 minute' where user_id=actor;
  else update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()-make_interval(secs=>(select recent_auth_seconds+1 from mobio_private.admin_session_policy where singleton)) where user_id=actor;
  end if;
  perform pg_temp.qa_pending_denied('Admin '||state||' lease denies before provider admission','admin');
  delete from mobio_private.admin_session_leases where user_id=actor;
  insert into mobio_private.admin_session_leases select (jsonb_populate_record(null::mobio_private.admin_session_leases,(select value from pg_temp.qa_pending_saved where name='lease'))).*;
 end loop;
end $leases$;
select pg_temp.qa_pending_check('fresh Admin positive restored',pg_temp.qa_pending_admit('admin')->>'admitted'='true');
select public.rpc_biopay_face_authority(id,sid,'pause') from qa_pending_actor where name='other';
select pg_temp.qa_pending_denied('actual paused enrollment cannot be probed','other');
select pg_temp.qa_pending_begin('other');
select pg_temp.qa_pending_check('explicit reenrollment has a new admitted current tuple',pg_temp.qa_pending_admit('other')->>'admitted'='true');
select public.rpc_biopay_face_authority(id,sid,'remove') from qa_pending_actor where name='other';
select pg_temp.qa_pending_denied('actual removed enrollment cannot be probed','other');

update mobio_private.privacy_policy set intake_enabled=true,processing_enabled=true,notice_version='qa-face-pending-v1',
 inventory_sha256=repeat('b',64),approval_reference='qa/face-pending' where singleton;
insert into mobio_private.privacy_requests(request_id,owner_id,originating_session_id,notice_version,status,revision,started_at,plan_sha256,inventory_sha256)
 select request,id,sid,'qa-face-pending-v1','processing',1,now(),repeat('a',64),repeat('b',64) from qa_pending_actor where name='consumer';
select public.rpc_privacy_activate_subject_fence(request,action,1,repeat('a',64),repeat('b',64),'qa/face-pending') from qa_pending_actor where name='consumer';
select pg_temp.qa_pending_denied('fenced subject denies before provider admission with no Face effects','consumer');
select pg_temp.qa_pending_check('fence retains exact cleanup intent independently of denied enrollment',
 exists(select 1 from public.biopay_face_cleanup where vector_id=(select vector from qa_pending_actor where name='consumer') and deleted_at is null));
select public.rpc_privacy_fulfil(request,gen_random_uuid(),2,'evidence',jsonb_build_object('category','processors','outcome','not_applicable','evidence_sha256',repeat('d',64)),'qa/face-pending') from qa_pending_actor where name='consumer';
select pg_temp.qa_pending_check('case-authorized evidence remains appendable after fence',
 exists(select 1 from mobio_private.privacy_evidence where request_id=(select request from qa_pending_actor where name='consumer') and category='processors')
 and (select revision=3 from mobio_private.privacy_requests where request_id=(select request from qa_pending_actor where name='consumer')));
select pg_temp.qa_pending_check('unrelated healthy Admin remains admitted after consumer fence',pg_temp.qa_pending_admit('admin')->>'admitted'='true');
select jsonb_build_object('face_pending_sql_assertions',count(*)) from qa_pending_result;
rollback;
