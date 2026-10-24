-- Rollback-only installed-schema behavior fixture. Synthetic SQL claims/sessions
-- prove database authority, separately from the actual Auth/JWT HTTP fixture.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create temp table qa_fm_actors(name text primary key,user_id uuid not null default gen_random_uuid(),
 session_id uuid not null default gen_random_uuid(),phone text not null,provider text not null,
 otp_id uuid not null default gen_random_uuid());
insert into qa_fm_actors(name,phone,provider) values
 ('payer','+250700001101','whatsapp_cloud_otp'),
 ('recipient','+250700001102','whatsapp_cloud_otp'),
 ('admin','+250700001103','admin_whatsapp_otp'),
 ('unproven','+250700001104','whatsapp_cloud_otp'),
 ('review','+250700001105','whatsapp_cloud_otp');
create temp table qa_fm_results(label text);
create temp table qa_fm_context(method_id uuid default gen_random_uuid(),method2_id uuid default gen_random_uuid(),
 op_id uuid,vector_id text,old_vector text,scan_id uuid,revision jsonb,replacement jsonb,result jsonb,before_denial jsonb);
insert into qa_fm_context default values;
create function pg_temp.qa_fm_check(label text,ok boolean) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
 insert into pg_temp.qa_fm_results values(label);
end $$;
create function pg_temp.qa_fm_identity(actor text) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claim.role','',true);
 perform set_config('request.jwt.claims',(select jsonb_build_object('sub',user_id,'session_id',session_id,
  'role','authenticated','is_anonymous',false,'app_metadata',jsonb_build_object('provider',provider))::text
  from pg_temp.qa_fm_actors where name=actor),true);
end $$;
create function pg_temp.qa_fm_service() returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claim.role','',true);
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
end $$;
create function pg_temp.qa_fm_call(actor text,action text,data jsonb default '{}') returns jsonb language plpgsql as $$
declare result jsonb;
begin
 perform pg_temp.qa_fm_service();
 select public.rpc_biopay_face_authority(user_id,session_id,action,data) into result
 from pg_temp.qa_fm_actors where name=actor;
 return result;
end $$;
create function pg_temp.qa_fm_reserve(actor text,action text default 'resolve') returns uuid language plpgsql as $$
declare result uuid;
begin
 perform pg_temp.qa_fm_service();
 select public.rpc_reserve_biopay_provider_operation(user_id,action,session_id,
  replace(gen_random_uuid()::text,'-',''),repeat('a',64)) into result from pg_temp.qa_fm_actors where name=actor;
 return result;
end $$;
create function pg_temp.qa_fm_error(label text,statement text,message text,state text default '42501') returns void language plpgsql as $$
declare actual_state text;actual_message text;denied boolean:=false;
begin
 begin execute statement;
 exception when others then
  get stacked diagnostics actual_state=returned_sqlstate,actual_message=message_text;
  if actual_state<>state or actual_message<>message then
   raise exception 'ASSERTION FAILED: % returned %/%',label,actual_state,actual_message;
  end if;
  denied:=true;
 end;
 perform pg_temp.qa_fm_check(label,denied);
end $$;
create function pg_temp.qa_fm_snapshot() returns jsonb language sql as $$
 select jsonb_build_object('profiles',(select jsonb_agg(to_jsonb(p) order by p.id) from public.biopay_profiles p),
  'operations',(select jsonb_agg(to_jsonb(o) order by o.id) from public.biopay_provider_operations o),
  'revisions',(select jsonb_agg(to_jsonb(r) order by r.vector_id) from public.biopay_face_revisions r),
  'audit',(select jsonb_agg(to_jsonb(a) order by a.id) from public.biopay_audit_events a));
$$;

select pg_temp.qa_fm_service();
insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)
 select user_id,phone,now(),false,jsonb_build_object('provider',provider),'{"qa_fixture":true}' from qa_fm_actors;
insert into auth.sessions(id,user_id,created_at,not_after)
 select session_id,user_id,now(),now()+interval '1 hour' from qa_fm_actors;
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 select phone,'+250',true from qa_fm_actors where name='admin';
insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at)
 select otp_id,phone,user_id,'000000',repeat('a',64),case when provider='admin_whatsapp_otp' then 'admin_login' else 'app_login' end,
 true,now()+interval '5 minutes' from qa_fm_actors;
select public.rpc_register_app_whatsapp_session(user_id,session_id,otp_id::text)
 from qa_fm_actors where name in ('payer','recipient','review');
select public.rpc_register_admin_session(user_id,session_id,otp_id::text) from qa_fm_actors where name='admin';
insert into mobio_private.store_review_principals(user_id,change_ref)
 select user_id,'CR11/12 rollback test' from qa_fm_actors where name='review';
insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label)
 select method_id,user_id,'mtn_rw','mobileWallet','+250788001102','Synthetic receiving' from qa_fm_context,qa_fm_actors where name='recipient';
insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label)
 select method2_id,user_id,'mtn_rw','mobileWallet','+250788001106','Synthetic replacement' from qa_fm_context,qa_fm_actors where name='recipient';
update public.biopay_face_policy set enabled=true,min_score=.8,min_margin=.08,
 acceptance_evidence='https://fixture.invalid/controlled-policy',accepted_at=now();
update public.biopay_provider_routes set face_enabled=true,face_tested_at=now(),
 face_evidence_url='https://fixture.invalid/controlled-route',valid_until=now()+interval '1 day'
 where face_instruction_template is not null;

select pg_temp.qa_fm_check('Face RPCs retain service-only ACL',
 not has_function_privilege('authenticated','public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)','EXECUTE')
 and not has_function_privilege('anon','public.rpc_reserve_biopay_provider_operation(uuid,text,uuid,text,text)','EXECUTE')
 and has_function_privilege('service_role','public.rpc_biopay_face_maintenance(text[])','EXECUTE'));
select pg_temp.qa_fm_check('quota has no service or anonymous bypass',
 not has_function_privilege('service_role','public.rpc_consume_maps_quota(text)','EXECUTE')
 and not has_function_privilege('anon','public.rpc_consume_maps_quota(text)','EXECUTE')
 and has_function_privilege('authenticated','public.rpc_consume_maps_quota(text)','EXECUTE'));
select pg_temp.qa_fm_service();
select pg_temp.qa_fm_error('service transport cannot substitute a foreign Auth session',
 $$select public.fn_biopay_face_session((select user_id from pg_temp.qa_fm_actors where name='payer'),
 (select session_id from pg_temp.qa_fm_actors where name='recipient'))$$,'BIOPAY_SESSION_INVALID');
select pg_temp.qa_fm_error('unproven consumer Face reservation denied',
 $$select pg_temp.qa_fm_reserve('unproven')$$,'BIOPAY_SESSION_INVALID');
select pg_temp.qa_fm_error('registered review with ordinary metadata denied',
 $$select pg_temp.qa_fm_reserve('review')$$,'BIOPAY_SESSION_INVALID');
-- Adversarial fixture only: even forged allowlist/lease/provider records cannot
-- promote an already registered reviewer into service-side Face authority.
update auth.users set raw_app_meta_data='{"provider":"admin_whatsapp_otp"}' where id=(select user_id from qa_fm_actors where name='review');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 select phone,'+250',true from qa_fm_actors where name='review';
insert into mobio_private.admin_session_leases(session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
 select session_id,user_id,'forged-review-'||otp_id::text,clock_timestamp(),clock_timestamp(),
 clock_timestamp()+interval '15 minutes',clock_timestamp()+interval '8 hours' from qa_fm_actors where name='review';
select pg_temp.qa_fm_error('registered review with forged fresh Admin authority denied',
 $$select pg_temp.qa_fm_reserve('review')$$,'BIOPAY_SESSION_INVALID');
update auth.users set phone='250700001198' where id=(select user_id from qa_fm_actors where name='review');
select pg_temp.qa_fm_error('registered review after phone tamper denied',
 $$select pg_temp.qa_fm_reserve('review')$$,'BIOPAY_SESSION_INVALID');
update auth.users set banned_until=now()+interval '1 hour' where id=(select user_id from qa_fm_actors where name='payer');
select pg_temp.qa_fm_error('banned caller denied',$$select pg_temp.qa_fm_reserve('payer')$$,'BIOPAY_SESSION_INVALID');
update auth.users set banned_until=null where id=(select user_id from qa_fm_actors where name='payer');
update auth.sessions set not_after=now()-interval '1 second' where id=(select session_id from qa_fm_actors where name='payer');
select pg_temp.qa_fm_error('expired caller denied',$$select pg_temp.qa_fm_reserve('payer')$$,'BIOPAY_SESSION_INVALID');
update auth.sessions set not_after=now()+interval '1 hour' where id=(select session_id from qa_fm_actors where name='payer');

-- An Admin provider account needs its exact lease even with passenger profile.
update mobio_private.admin_session_leases set authenticated_at=now()-interval '6 minutes'
 where user_id=(select user_id from qa_fm_actors where name='admin');
update qa_fm_context set before_denial=pg_temp.qa_fm_snapshot();
select pg_temp.qa_fm_error('stale Admin reservation denied',$$select pg_temp.qa_fm_reserve('admin')$$,'ADMIN_REAUTHENTICATION_REQUIRED');
do $$declare action text; begin
 foreach action in array array['begin_enroll','activate','pause','remove','resume','change_method','fail_enroll','resolve','prepare_handoff','handoff'] loop
  perform pg_temp.qa_fm_error('stale Admin action '||action,format('select pg_temp.qa_fm_call(''admin'',%L)',action),'ADMIN_REAUTHENTICATION_REQUIRED');
 end loop;
end $$;
select pg_temp.qa_fm_check('stale Admin denial changes no Face target',(select before_denial=pg_temp.qa_fm_snapshot() from qa_fm_context));
select pg_temp.qa_fm_check('live stale Admin status remains readable',pg_temp.qa_fm_call('admin','status')->>'status'='not_started');
create temp table qa_fm_admin_lease_backup as select * from mobio_private.admin_session_leases
 where user_id=(select user_id from qa_fm_actors where name='admin');
do $lease_cases$declare lease_state text;action text;begin
 foreach lease_state in array array['missing','revoked','future','idle','absolute'] loop
  delete from mobio_private.admin_session_leases where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  insert into mobio_private.admin_session_leases select * from pg_temp.qa_fm_admin_lease_backup;
  if lease_state='missing' then
   delete from mobio_private.admin_session_leases where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  elsif lease_state='revoked' then
   update mobio_private.admin_session_leases set revoked_at=clock_timestamp()
    where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  elsif lease_state='future' then
   update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()+interval '1 minute',
    last_activity_at=clock_timestamp()+interval '2 minutes'
    where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  elsif lease_state='idle' then
   update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '1 second'
    where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  elsif lease_state='absolute' then
   update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '2 seconds',
    absolute_expires_at=clock_timestamp()-interval '1 second'
    where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
  end if;
  perform pg_temp.qa_fm_error(lease_state||' Admin reservation keeps exact reauth',
   $$select pg_temp.qa_fm_reserve('admin')$$,'ADMIN_REAUTHENTICATION_REQUIRED');
  foreach action in array array['begin_enroll','activate','pause','remove','resume','change_method','fail_enroll','resolve','prepare_handoff','handoff'] loop
   perform pg_temp.qa_fm_error(lease_state||' Admin sensitive action '||action,
    format('select pg_temp.qa_fm_call(''admin'',%L)',action),'ADMIN_REAUTHENTICATION_REQUIRED');
  end loop;
  perform pg_temp.qa_fm_error(lease_state||' Admin gains no readable Face identity',
   $$select pg_temp.qa_fm_call('admin','status')$$,'BIOPAY_SESSION_INVALID');
  perform pg_temp.qa_fm_check(lease_state||' Admin denial changes no Face target',
   (select before_denial=pg_temp.qa_fm_snapshot() from pg_temp.qa_fm_context));
 end loop;
 delete from mobio_private.admin_session_leases where session_id=(select session_id from pg_temp.qa_fm_admin_lease_backup);
 insert into mobio_private.admin_session_leases select * from pg_temp.qa_fm_admin_lease_backup;
end $lease_cases$;
update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()+interval '1 minute',last_activity_at=clock_timestamp()+interval '1 minute'
 where user_id=(select user_id from qa_fm_actors where name='admin');
select pg_temp.qa_fm_error('future Admin authentication denied',$$select pg_temp.qa_fm_reserve('admin')$$,'ADMIN_REAUTHENTICATION_REQUIRED');
update mobio_private.admin_session_leases set authenticated_at=now(),last_activity_at=now()
 where user_id=(select user_id from qa_fm_actors where name='admin');
update auth.sessions set not_after=clock_timestamp()-interval '1 second'
 where id=(select session_id from qa_fm_actors where name='admin');
select pg_temp.qa_fm_error('expired Admin Auth transport stays generic',
 $$select pg_temp.qa_fm_reserve('admin')$$,'BIOPAY_SESSION_INVALID');
update auth.sessions set not_after=now()+interval '1 hour'
 where id=(select session_id from qa_fm_actors where name='admin');
select pg_temp.qa_fm_check('fresh Admin reservation allowed',pg_temp.qa_fm_reserve('admin') is not null);
update mobio_private.admin_session_leases set revoked_at=now() where user_id=(select user_id from qa_fm_actors where name='admin');
select pg_temp.qa_fm_error('revoked Admin lease denied',$$select pg_temp.qa_fm_reserve('admin')$$,'ADMIN_REAUTHENTICATION_REQUIRED');
update mobio_private.admin_session_leases set revoked_at=null where user_id=(select user_id from qa_fm_actors where name='admin');

-- Enroll B, resolve as A without a payer face/method; then delete B's session.
update qa_fm_context set op_id=pg_temp.qa_fm_reserve('recipient','enroll');
update qa_fm_context set revision=pg_temp.qa_fm_call('recipient','begin_enroll',jsonb_build_object('operation_id',op_id,
 'method_id',method_id,'consent',true,'consent_version','face-discovery-v1'));
update qa_fm_context set vector_id=revision->>'vector_id';
select pg_temp.qa_fm_check('consumer enrollment activation allowed',
 (select pg_temp.qa_fm_call('recipient','activate',jsonb_build_object('vector_id',vector_id))->>'status'='active' from qa_fm_context));
-- Pending replacement keeps the prior active face. Close scores for vectors
-- belonging to the same recipient are not an unrelated-person ambiguity.
update qa_fm_context set replacement=pg_temp.qa_fm_call('recipient','begin_enroll',jsonb_build_object(
 'operation_id',pg_temp.qa_fm_reserve('recipient','enroll'),'method_id',method_id,
 'consent',true,'consent_version','face-discovery-v1'));
update qa_fm_context set scan_id=pg_temp.qa_fm_reserve('payer');
select pg_temp.qa_fm_check('same-owner close candidates keep prior active recipient during replacement',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id,
  'model_version',revision->>'model_version','candidates',jsonb_build_array(
   jsonb_build_object('id',vector_id,'score',.91),jsonb_build_object('id',replacement->>'vector_id','score',.90))))->>'status'='dial_ready'
  from qa_fm_context));
update public.biopay_face_cleanup set not_before=clock_timestamp()-interval '1 second'
 where vector_id in (select vector_id from qa_fm_context union select replacement->>'vector_id' from qa_fm_context);
select public.rpc_biopay_face_maintenance(array[(select vector_id from qa_fm_context),(select replacement->>'vector_id' from qa_fm_context)]);
select pg_temp.qa_fm_check('cleanup protects active pointer and pending replacement operation',
 (select deleted_at is null from public.biopay_face_cleanup where vector_id=(select vector_id from qa_fm_context))
 and (select deleted_at is null from public.biopay_face_cleanup where vector_id=(select replacement->>'vector_id' from qa_fm_context)));
select pg_temp.qa_fm_check('replacement activation allowed',
 (select pg_temp.qa_fm_call('recipient','activate',jsonb_build_object('vector_id',replacement->>'vector_id'))->>'status'='active' from qa_fm_context));
select pg_temp.qa_fm_check('cached old vector is unavailable after replacement',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
update qa_fm_context set scan_id=pg_temp.qa_fm_reserve('payer');
select pg_temp.qa_fm_check('stale top cannot fall through to lower current vector',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id,
  'model_version',revision->>'model_version','candidates',jsonb_build_array(
   jsonb_build_object('id',vector_id,'score',.91),jsonb_build_object('id',replacement->>'vector_id','score',.90))))->>'code'='RECIPIENT_UNAVAILABLE'
  from qa_fm_context));
update public.biopay_face_cleanup set not_before=clock_timestamp()-interval '1 second'
 where vector_id in (select vector_id from qa_fm_context union select replacement->>'vector_id' from qa_fm_context);
select public.rpc_biopay_face_maintenance(array[(select vector_id from qa_fm_context),(select replacement->>'vector_id' from qa_fm_context)]);
select pg_temp.qa_fm_check('cleanup deletes expired old vector and protects replacement pointer',
 (select deleted_at is not null from public.biopay_face_cleanup where vector_id=(select vector_id from qa_fm_context))
 and (select deleted_at is null from public.biopay_face_cleanup where vector_id=(select replacement->>'vector_id' from qa_fm_context)));
update qa_fm_context set old_vector=vector_id,vector_id=replacement->>'vector_id',revision=replacement,scan_id=pg_temp.qa_fm_reserve('payer');
select pg_temp.qa_fm_error('prepare requires an existing matched operation',
 $$select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',(select scan_id from pg_temp.qa_fm_context)))$$,'BIOPAY_SESSION_INVALID');
delete from auth.sessions where user_id=(select user_id from qa_fm_actors where name='recipient');
update qa_fm_context set result=pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id,
 'model_version',revision->>'model_version','candidates',jsonb_build_array(jsonb_build_object('id',vector_id,'score',.91))));
select pg_temp.qa_fm_check('signed-out recipient stays eligible and amount-free',
 (select result->>'status'='dial_ready' and result->>'ussd_code'='*182*1*1*0788001102#'
  and result->>'payee_id'=(select user_id::text from qa_fm_actors where name='recipient')
  and not result ? 'amount' and not result ? 'amount_minor' from qa_fm_context));
select pg_temp.qa_fm_check('prepare returns current shortcut without consumption or audit',
 (select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',scan_id))->>'ussd_code'='*182*1*1*0788001102#' from qa_fm_context)
 and (select consumed_at is null from public.biopay_provider_operations where id=(select scan_id from qa_fm_context))
 and not exists(select 1 from public.biopay_audit_events where action='biopay.face.dialer_opened'));
update public.biopay_payment_methods set identifier='+250788001107',version=version+1 where id=(select method_id from qa_fm_context);
select pg_temp.qa_fm_check('prepare reflects changed receiving identifier/version',
 (select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',scan_id))->>'ussd_code'='*182*1*1*0788001107#' from qa_fm_context)
 and (select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',scan_id))->>'receiving_method_version'='2' from qa_fm_context));
update public.biopay_payment_methods set identifier='+250788001102',version=version+1 where id=(select method_id from qa_fm_context);
select pg_temp.qa_fm_check('payer requires no face profile',not exists(select 1 from public.biopay_profiles where user_id=(select user_id from qa_fm_actors where name='payer')));

-- Cached matches and handoff revalidate current moderation and receiving route.
update auth.users set banned_until=now()+interval '1 hour' where id=(select user_id from qa_fm_actors where name='recipient');
select pg_temp.qa_fm_check('banned cached recipient denied',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
select pg_temp.qa_fm_check('banned recipient preparation denied',
 (select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
select pg_temp.qa_fm_check('banned cached recipient handoff denied',
 (select pg_temp.qa_fm_call('payer','handoff',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
select pg_temp.qa_fm_check('denied handoff did not consume or audit',
 (select consumed_at is null from public.biopay_provider_operations where id=(select scan_id from qa_fm_context))
 and not exists(select 1 from public.biopay_audit_events where action='biopay.face.dialer_opened'));
update auth.users set banned_until=null,deleted_at=now() where id=(select user_id from qa_fm_actors where name='recipient');
select pg_temp.qa_fm_check('soft-deleted recipient denied',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
update auth.users set deleted_at=null,phone='250700001199' where id=(select user_id from qa_fm_actors where name='recipient');
select pg_temp.qa_fm_check('tampered confirmed recipient phone denied',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));
update auth.users set phone=(select phone from qa_fm_actors where name='recipient') where id=(select user_id from qa_fm_actors where name='recipient');
update public.biopay_payment_methods set active=false where id=(select method_id from qa_fm_context);
select pg_temp.qa_fm_check('revoked receiving method handoff denied',
 (select pg_temp.qa_fm_call('payer','handoff',jsonb_build_object('operation_id',scan_id))->>'status'='recipient_unavailable' from qa_fm_context));
update public.biopay_payment_methods set active=true where id=(select method_id from qa_fm_context);
update public.biopay_provider_routes set face_enabled=false;
select pg_temp.qa_fm_check('revoked route preparation denied',
 (select pg_temp.qa_fm_call('payer','prepare_handoff',jsonb_build_object('operation_id',scan_id))->>'code'='ROUTE_NOT_CONFIGURED' from qa_fm_context));
select pg_temp.qa_fm_check('revoked route handoff denied',
 (select pg_temp.qa_fm_call('payer','handoff',jsonb_build_object('operation_id',scan_id))->>'code'='ROUTE_NOT_CONFIGURED' from qa_fm_context));
update public.biopay_provider_routes set face_enabled=true where face_instruction_template is not null;
select pg_temp.qa_fm_check('eligible restored recipient handoff recorded',
 (select pg_temp.qa_fm_call('payer','handoff',jsonb_build_object('operation_id',scan_id))->>'status'='recorded' from qa_fm_context));
select pg_temp.qa_fm_call('payer','handoff',jsonb_build_object('operation_id',scan_id)) from qa_fm_context;
select pg_temp.qa_fm_check('allowed handoff audit remains idempotent',
 (select count(*) from public.biopay_audit_events where action='biopay.face.dialer_opened')=1);
select pg_temp.qa_fm_check('service cleanup protects current vector',
 not exists(select 1 from jsonb_array_elements(public.rpc_biopay_face_maintenance('{}')) as item(value) where item.value->>'vector_id'=(select vector_id from qa_fm_context)));

insert into mobio_private.store_review_principals(user_id,change_ref) select user_id,'CR11 recipient permanent review exclusion' from qa_fm_actors where name='recipient';
select pg_temp.qa_fm_check('registered review recipient with normal metadata denied',
 (select pg_temp.qa_fm_call('payer','resolve',jsonb_build_object('operation_id',scan_id))->>'code'='RECIPIENT_UNAVAILABLE' from qa_fm_context));

select pg_temp.qa_fm_error('permanent review registration cannot be removed',
 $$delete from mobio_private.store_review_principals where user_id=(select user_id from pg_temp.qa_fm_actors where name='recipient')$$,'STORE_REVIEW_REGISTRATION_PERMANENT');

-- Account quota retains exactly 100 writes; denial does not increment it.
select pg_temp.qa_fm_identity('payer');
do $$declare i integer;value jsonb;actions text[]:=array['autocomplete','geocode','text_search','place_details','reverse_geocode'];begin
 for i in 1..100 loop
  value:=public.rpc_consume_maps_quota(actions[(i-1)%5+1]);
  perform pg_temp.qa_fm_check('quota allowed request '||i,(value->>'allowed')::boolean and (value->>'remaining')::integer=100-i);
 end loop;
 value:=public.rpc_consume_maps_quota('autocomplete');
 perform pg_temp.qa_fm_check('request101 denied with precise retry',not (value->>'allowed')::boolean
  and (value->>'remaining')::integer=0 and (value->>'retry_after_seconds')::integer between 1 and 300);
end $$;
select pg_temp.qa_fm_check('denials retain quota counter100',
 (select request_count=100 from mobio_private.maps_account_quota where user_id=(select user_id from qa_fm_actors where name='payer')));
select pg_temp.qa_fm_error('compute_route has no quota contract',
 $$select public.rpc_consume_maps_quota('compute_route')$$,'UNSUPPORTED_MAPS_ACTION','22023');
update mobio_private.maps_account_quota set window_started_at=now()-interval '5 minutes' where user_id=(select user_id from qa_fm_actors where name='payer');
select pg_temp.qa_fm_check('elapsed quota window resets',public.rpc_consume_maps_quota('geocode')->>'remaining'='99');
select pg_temp.qa_fm_identity('unproven');
select pg_temp.qa_fm_error('unproven quota caller rejected',
 $$select public.rpc_consume_maps_quota('geocode')$$,'INTERACTIVE_SESSION_REQUIRED');
select pg_temp.qa_fm_check('unproven caller creates no bucket',
 not exists(select 1 from mobio_private.maps_account_quota where user_id=(select user_id from qa_fm_actors where name='unproven')));
select count(*) as passed_face_maps_assertions from qa_fm_results;
rollback;
