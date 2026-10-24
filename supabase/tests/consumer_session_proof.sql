-- Disposable full-schema fixture, actual SQL roles/Auth session rows; rolled back.
-- Signed Auth-issued JWT acceptance is covered by test_auth_session_authority.sh.
begin;
create temp table qa_consumer_actor(name text primary key,id uuid default gen_random_uuid(),
 sid uuid default gen_random_uuid(),other_sid uuid default gen_random_uuid(),otp uuid default gen_random_uuid(),phone text,provider text);
insert into qa_consumer_actor(name,phone,provider)values
 ('consumer','+250700009701','whatsapp_cloud_otp'),('admin','+250700009702','admin_whatsapp_otp'),
 ('review','+250700009703','store_review');
create temp table qa_consumer_results(label text);
grant select on qa_consumer_actor to authenticated,service_role;
grant select,insert on qa_consumer_results to authenticated,service_role;
create function pg_temp.qa_check(label text,value boolean)returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',label;end if;
 insert into pg_temp.qa_consumer_results values(label);end$$;
create function pg_temp.qa_identity(actor text,sid_override uuid default null)returns void language plpgsql as $$
declare c jsonb;begin select jsonb_build_object('sub',id,'session_id',coalesce(sid_override,sid),
 'role','authenticated','is_anonymous',false,'app_metadata',jsonb_build_object('provider',provider))into strict c
 from pg_temp.qa_consumer_actor where name=actor;
 perform set_config('request.jwt.claim.sub','',true);perform set_config('request.jwt.claim.role','',true);
 perform set_config('request.jwt.claims',c::text,true);end$$;
create function pg_temp.qa_denied(label text,statement text)returns void language plpgsql as $$
begin begin execute statement;exception when insufficient_privilege or unique_violation then
 perform pg_temp.qa_check(label,true);return;end;
 raise exception 'ASSERTION FAILED: accepted %',label;end$$;
insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
 select id,case when name='review' then null else phone end,now(),
 jsonb_build_object('provider',provider,'role',case when name='admin' then 'admin' else 'passenger' end),'{}',false from qa_consumer_actor;
insert into auth.sessions(id,user_id,created_at,not_after)
 select sid,id,now(),now()+interval '1 hour' from qa_consumer_actor union all
 select other_sid,id,now(),now()+interval '1 hour' from qa_consumer_actor;
insert into public.otp_codes(id,phone,purpose,code,code_hash,verified,expires_at)
 select otp,phone,case when name='admin' then 'admin_login' else 'app_login' end,'000000',repeat('a',64),true,now()+interval '5 minutes' from qa_consumer_actor;
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 select phone,'+250',true from qa_consumer_actor where name='admin';
select pg_temp.qa_identity('consumer');
select pg_temp.qa_check('new password-like session lacks consumer authority',public.verified_app_user_id() is null);
set local role authenticated;
select pg_temp.qa_denied('client cannot register consumer proof',
 'select public.rpc_register_app_whatsapp_session(id,sid,otp::text) from pg_temp.qa_consumer_actor where name=''consumer''');
select pg_temp.qa_denied('client cannot write private proof','insert into mobio_private.consumer_session_proofs(session_id,user_id,phone_e164,otp_reference,authenticated_at) select sid,id,phone,otp::text,now() from pg_temp.qa_consumer_actor where name=''consumer''');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select public.rpc_register_app_whatsapp_session(id,sid,otp::text) from qa_consumer_actor where name='consumer';
select public.rpc_register_admin_session(id,sid,otp::text) from qa_consumer_actor where name='admin';
select public.rpc_register_store_review_principal(id,'SQL fixture') from qa_consumer_actor where name='review';
select pg_temp.qa_denied('service cannot directly write proof registry','insert into mobio_private.consumer_session_proofs(session_id,user_id,phone_e164,otp_reference,authenticated_at) select other_sid,id,phone,''invented'',now() from pg_temp.qa_consumer_actor where name=''consumer''');
select pg_temp.qa_denied('one consumed OTP cannot prove two SIDs','select public.rpc_register_app_whatsapp_session(id,other_sid,otp::text) from pg_temp.qa_consumer_actor where name=''consumer''');
reset role;
select pg_temp.qa_identity('consumer');
select pg_temp.qa_check('consumed OTP grants exact consumer SID',public.verified_app_user_id()=(select id from qa_consumer_actor where name='consumer'));
set local role authenticated;
select pg_temp.qa_check('caller RPC returns exact user and SID',public.rpc_verified_interactive_session()=
 (select jsonb_build_object('user_id',id,'session_id',sid)from qa_consumer_actor where name='consumer'));
select pg_temp.qa_check('proved consumer can read its profile',(select count(*)=1 from public.profiles where id=auth.uid()));
reset role;
select pg_temp.qa_identity('consumer',(select other_sid from qa_consumer_actor where name='consumer'));
select pg_temp.qa_check('independent SID does not inherit durable account metadata',public.verified_app_user_id() is null);
select pg_temp.qa_denied('unproved caller cannot cold restore authority','select public.rpc_verified_interactive_session()');
select pg_temp.qa_identity('consumer');
update auth.users set phone='250700009799' where id=(select id from qa_consumer_actor where name='consumer');
select pg_temp.qa_check('direct changed phone revokes original proof',public.verified_app_user_id() is null);
select pg_temp.qa_denied('changed phone directory is rejected','select public._mobio_verified_phone_owner(''+250700009799'')');
update auth.users set phone=(select phone from qa_consumer_actor where name='consumer') where id=(select id from qa_consumer_actor where name='consumer');
select pg_temp.qa_check('durable exact phone binding restores original eligible SID',public.verified_app_user_id() is not null);
select pg_temp.qa_identity('admin');
select pg_temp.qa_check('fresh normal Admin remains verified',public.verified_admin_user_id()=(select id from qa_consumer_actor where name='admin'));
select pg_temp.qa_check('Admin provider with passenger profile still uses valid lease',public.verified_app_user_id()=(select id from qa_consumer_actor where name='admin'));
update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '1 second'
 where user_id=(select id from qa_consumer_actor where name='admin');
select pg_temp.qa_check('Admin provider cannot evade stale lease through passenger profile',public.verified_app_user_id() is null);
select pg_temp.qa_identity('review');
update auth.users set phone=(select phone from qa_consumer_actor where name='review'),phone_confirmed_at=now(),
 raw_app_meta_data='{"provider":"whatsapp_cloud_otp","role":"passenger"}' where id=(select id from qa_consumer_actor where name='review');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.qa_denied('permanent reviewer cannot register proof after provider tamper',
 'select public.rpc_register_app_whatsapp_session(id,sid,otp::text) from pg_temp.qa_consumer_actor where name=''review''');
reset role;
select pg_temp.qa_check('recipient predicate permanently excludes reviewer',not mobio_private.verified_interactive_account_is_eligible((select id from qa_consumer_actor where name='review')));
select count(*)||' consumer-session assertions passed' as result from qa_consumer_results;
rollback;
