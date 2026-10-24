-- Rolled-back real SQL role/session fixture; signed JWT/Edge proof is separate.
begin;
create temp table qa_review_context(uid uuid default gen_random_uuid(),sid uuid default gen_random_uuid(),
 other_sid uuid default gen_random_uuid(),challenge uuid default gen_random_uuid());insert into qa_review_context default values;
create temp table qa_review_results(label text);
grant select on qa_review_context to service_role,authenticated;grant select,insert on qa_review_results to service_role,authenticated;
create function pg_temp.qa_check(label text,value boolean)returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',label;end if;
 insert into pg_temp.qa_review_results values(label);end$$;
create function pg_temp.qa_denied(label text,statement text)returns void language plpgsql as $$
begin begin execute statement;exception when insufficient_privilege then perform pg_temp.qa_check(label,true);return;end;
 raise exception 'ASSERTION FAILED: accepted %',label;end$$;
-- Model GoTrue's initial INSERT before custom app metadata is finalized.
insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
 select uid,uid::text||'@review.invalid',now(),'{"provider":"email"}','{}',false from qa_review_context;
select pg_temp.qa_check('phone-empty Auth INSERT cannot create ordinary profile',not exists(select 1 from public.profiles where id=(select uid from qa_review_context)));
update auth.users set raw_app_meta_data='{"provider":"store_review","role":"driver"}' where id=(select uid from qa_review_context);
insert into auth.sessions(id,user_id,created_at,not_after)select sid,uid,now(),now()+interval '1 hour' from qa_review_context
 union all select other_sid,uid,now(),now()+interval '1 hour' from qa_review_context;
select pg_temp.qa_check('review provisioning creates no production profile',not exists(select 1 from public.profiles where id=(select uid from qa_review_context)));
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.qa_check('default review config fails closed',public.rpc_store_review_login_configuration()->>'active'='false');
select public.rpc_register_store_review_principal(uid,'QA review integration')from qa_review_context;
select public.rpc_configure_store_review(uid,2,true,now()-interval '1 minute',now()+interval '1 hour','mobio-marketplace-v1','QA window')from qa_review_context;
select pg_temp.qa_check('configured review is active',public.rpc_store_review_login_configuration()->>'active'='true');
select public.rpc_create_store_review_challenge(challenge,uid,2,'driver',repeat('a',64),repeat('b',64))from qa_review_context;
select pg_temp.qa_check('wrong context-bound review guess rejected',
 (select public.rpc_claim_store_review_challenge(challenge,uid,2,'driver',repeat('a',64),repeat('c',64))->>'claimed'='false'from qa_review_context));
select pg_temp.qa_check('correct challenge atomically claimed',
 (select public.rpc_claim_store_review_challenge(challenge,uid,2,'driver',repeat('a',64),repeat('b',64))->>'claimed'='true'from qa_review_context));
select pg_temp.qa_check('correct challenge replay rejected',
 (select public.rpc_claim_store_review_challenge(challenge,uid,2,'driver',repeat('a',64),repeat('b',64))->>'claimed'='false'from qa_review_context));
select pg_temp.qa_check('consumed review challenge issues exact active lease',
 (select public.rpc_register_store_review_challenge_session(challenge,uid,sid,2,'driver')->>'active'='true'from qa_review_context));
select pg_temp.qa_denied('one review challenge cannot bind second SID',
 'select public.rpc_register_store_review_challenge_session(challenge,uid,other_sid,2,''driver'')from qa_review_context');
select public.rpc_configure_store_review(uid,3,true,now()-interval '1 minute',now()+interval '1 hour','mobio-marketplace-v1','QA rotation')from qa_review_context;
select pg_temp.qa_check('generation rotation revokes issued review lease',
 (select public.rpc_store_review_session(uid,sid)->>'active'='false'from qa_review_context));
select pg_temp.qa_denied('old generation cannot create challenge',
 'select public.rpc_create_store_review_challenge(gen_random_uuid(),uid,2,''driver'',repeat(''a'',64),repeat(''b'',64))from qa_review_context');
reset role;
select set_config('request.jwt.claims',(select jsonb_build_object('sub',uid,'session_id',sid,'role','authenticated',
 'is_anonymous',false,'app_metadata',jsonb_build_object('provider','store_review'))::text from qa_review_context),true);
set local role authenticated;
select pg_temp.qa_denied('review bearer cannot read service-only configuration','select public.rpc_store_review_login_configuration()');
select pg_temp.qa_denied('review bearer cannot manufacture own challenge','select public.rpc_create_store_review_challenge(gen_random_uuid(),uid,3,''driver'',repeat(''a'',64),repeat(''b'',64))from qa_review_context');
select pg_temp.qa_check('review real Auth transport remains excluded from ordinary app',public.verified_app_user_id() is null);
select pg_temp.qa_check('review real Auth transport remains excluded from Admin',public.verified_admin_user_id() is null);
reset role;
select count(*)||' review-integration assertions passed' as result from qa_review_results;
rollback;
