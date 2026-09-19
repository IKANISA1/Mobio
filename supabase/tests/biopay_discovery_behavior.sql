-- Execute against an isolated PostgreSQL 17 fixture; never a linked database.
-- All accounts, phone numbers, evidence and routes below are synthetic.
begin;
create function pg_temp.expect(value boolean, message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end $$;
create function pg_temp.expect_rejected(statement text) returns void language plpgsql as $$
declare rejected boolean:=false;
begin begin execute statement; exception when others then rejected:=true; end;
  if not rejected then raise exception 'ASSERTION FAILED: unsafe action accepted: %',statement; end if;
end $$;
-- The fast fixture has no Auth table. The full-schema rehearsal creates genuine
-- synthetic Auth rows so profile foreign keys and signup triggers are exercised.
do $$ begin
  if to_regclass('auth.users') is not null then
    execute $seed$
      insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data)
      select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
             '+25078800000' || n::text, now(),
             '{"provider":"whatsapp_cloud_otp"}'::jsonb, '{}'::jsonb
      from generate_series(1,4) n
      on conflict(id) do nothing
    $seed$;
    execute $sessions$
      insert into auth.sessions(id,user_id,created_at,not_after)
      select md5('biopay-qa-session-' || id::text)::uuid, id, now(), now()+interval '1 hour'
      from auth.users where id in (
        select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
        from generate_series(1,4) n)
    $sessions$;
  end if;
end $$;
-- The same behavioral suite also runs in the reduced, Auth-free fast fixture.
-- Full-schema tests use real session rows and the same complete JWT shape that
-- PostgREST receives. The anonymous and Admin-purpose negatives remain explicit.
create function pg_temp.qa_identity(user_id uuid, anonymous boolean default false,
  provider text default 'whatsapp_cloud_otp') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', user_id, 'session_id', md5('biopay-qa-session-' || user_id::text)::uuid,
    'role', 'authenticated', 'is_anonymous', anonymous,
    'app_metadata', jsonb_build_object('provider', provider))::text, true);
end $$;
insert into public.profiles(id,phone,member_id,whatsapp_verified_at) values
 ('00000000-0000-4000-8000-000000000001','+250788000001','100001',now()),
 ('00000000-0000-4000-8000-000000000002','+250788000002','100002',now()),
 ('00000000-0000-4000-8000-000000000003','+250788000003','100003',now()),
 ('00000000-0000-4000-8000-000000000004','+250788000004','100004',now())
 on conflict(id) do update set phone=excluded.phone,member_id=excluded.member_id,
   whatsapp_verified_at=excluded.whatsapp_verified_at;
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000001');
select pg_temp.expect_rejected($q$select public.rpc_biopay_discovery('save_method','{"provider":"mtn_rw","kind":"mobileWallet","identifier":"not-a-phone","label":"bad"}')$q$);
select public.rpc_biopay_discovery('save_method','{"provider":"mtn_rw","kind":"mobileWallet","identifier":"+250788000001","label":"My source","can_send":true,"can_receive":true,"sim_label":"SIM 1"}');
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000002');
select public.rpc_biopay_discovery('save_method','{"provider":"mtn_rw","kind":"merchantCode","identifier":"001234","label":"Shop","can_receive":true}');
select pg_temp.expect((select count(*)=1 from public.biopay_payment_methods where identifier='001234'),'leading zeros retained');
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000001');
select pg_temp.expect(public.rpc_biopay_discovery('resolve','{"lookup":"+250788000002"}')->'methods'='[]','private recipient not disclosed');
select pg_temp.expect(public.rpc_biopay_discovery('resolve','{"lookup":"+250788000099"}')->'methods'='[]','nonexistent recipient uses same shape');
select pg_temp.expect_rejected(format('select public.rpc_biopay_discovery(''save_method'',%L::jsonb)',
  (select (to_jsonb(m)||'{"label":"Takeover"}')::text from public.biopay_payment_methods m where identifier='001234')));
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000002');
select public.rpc_biopay_discovery('grant',(select jsonb_build_object('method_id',id,'version',version,'member_id','100001') from public.biopay_payment_methods where identifier='001234'));
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000001');
select pg_temp.expect(jsonb_array_length(public.rpc_biopay_discovery('resolve','{"lookup":"+250788000002"}')->'methods')=1,'explicit recipient grant works');
select pg_temp.expect(not(public.rpc_biopay_discovery('resolve','{"lookup":"+250788000002"}')->'methods'->0 ? 'login_phone'),'private banking login omitted');
select public.rpc_biopay_discovery('save_draft','{"id":"00000000-0000-4000-8000-000000000011","owner_id":"00000000-0000-4000-8000-000000000001","revision":1,"lookup":"+250788000002","amount":"1000","purpose":"merchant"}');
select pg_temp.expect(public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","revision":1,"device":"android"}')->'options'='[]','unapproved provider routes are absent');
insert into public.biopay_provider_routes(id,source_provider,destination_provider,destination_kind,rail,purpose,fee_certainty,fee_rwf,fee_all_in,device_families,instruction_template,handoff_mode,evidence_url,tariff_evidence_url,test_evidence_url,tested_by,tested_at,reviewed_by,reviewed_at,state,valid_until)
values('00000000-0000-4000-8000-000000000021','mtn_rw','mtn_rw','merchantCode','test rail','merchant','capped',20,true,array['android'],'*182*8*1*{recipient}*{amount}#','dial','https://example.invalid/test','https://example.invalid/tariff','https://example.invalid/device-test','00000000-0000-4000-8000-000000000003',now(),'00000000-0000-4000-8000-000000000004',now(),'approved',now()+interval '1 day');
do $$
declare quote jsonb; prepared jsonb; snapshot jsonb;
begin
  quote:=public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","revision":1,"device":"android"}');
  perform pg_temp.expect(jsonb_array_length(quote->'options')=1,'eligible route available');
  perform pg_temp.expect(quote->'options'->0->'destination'->>'identifier'='001234','route retains receiving identifier');
  prepared:=public.rpc_biopay_discovery('prepare',jsonb_build_object('quote_id',quote->>'quote_id','option_id',quote->'options'->0->>'id','device','android'));
  perform pg_temp.expect(prepared->>'instruction'='*182*8*1*001234*1000#','prepared approved instruction');
  perform pg_temp.expect((select amount_minor=100000 from public.biopay_payment_requests where id=(prepared->>'attempt_id')::uuid),'legacy unit bridge exact');
  perform pg_temp.expect_rejected(format('select public.rpc_biopay_discovery(''prepare'',%L::jsonb)',jsonb_build_object('quote_id',quote->>'quote_id','option_id',quote->'options'->0->>'id','device','android')::text));
  perform public.rpc_biopay_discovery('record_attempt',jsonb_build_object('id',prepared->>'attempt_id','evidence','handoffOpened'));
  perform pg_temp.expect_rejected(format('select public.rpc_biopay_discovery(''record_attempt'',%L::jsonb)',jsonb_build_object('id',prepared->>'attempt_id','evidence','providerConfirmed')::text));
  perform pg_temp.expect((select status<>'confirmed' from public.biopay_payment_requests where id=(prepared->>'attempt_id')::uuid),'handoff cannot confirm payment');
end $$;
select pg_temp.qa_identity(auth.uid(), true);
select pg_temp.expect_rejected($q$select public.rpc_biopay_discovery('workspace','{}')$q$);
select pg_temp.qa_identity(auth.uid());
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000002');
select pg_temp.expect_rejected($q$select public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","revision":1,"device":"android"}')$q$);
do $$
declare link jsonb; methods jsonb;
begin
 select jsonb_agg(id) into methods from public.biopay_payment_methods where owner_id=auth.uid();
 link:=public.rpc_biopay_discovery('create_link',jsonb_build_object('scope','request','method_ids',methods,'label','Fixture request','amount_rwf',1000,'purpose','merchant','expires_at',now()+interval '1 day'));
 perform pg_temp.expect(public.rpc_biopay_link_preview(link->>'token')->>'available'='true','public minimal preview available');
 perform pg_temp.expect(not(public.rpc_biopay_link_preview(link->>'token') ? 'methods'),'public preview omits receiving endpoints');
 perform pg_temp.expect((select count(*)=1 from public.biopay_payment_requests),'preview creates no payment attempt');
 perform public.rpc_biopay_discovery('revoke_link',jsonb_build_object('id',link->>'id','version',link->'version'));
 perform pg_temp.expect(public.rpc_biopay_link_preview(link->>'token')->>'available'='false','revoked preview unavailable');
end $$;

select pg_temp.qa_identity('00000000-0000-4000-8000-000000000001');
create function pg_temp.fresh_quote() returns jsonb language sql as $$
 select public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","revision":1,"device":"android"}')
$$;
create function pg_temp.reject_prepare(q jsonb) returns void language sql as $$
 select pg_temp.expect_rejected(format('select public.rpc_biopay_discovery(''prepare'',%L::jsonb)',
   jsonb_build_object('quote_id',q->>'quote_id','option_id',q->'options'->0->>'id','device','android')::text))
$$;
select pg_temp.expect_rejected($q$select public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","device":"android"}')$q$);
select pg_temp.expect_rejected($q$select public.rpc_biopay_discovery('save_draft','{"id":"00000000-0000-4000-8000-000000000011","owner_id":"00000000-0000-4000-8000-000000000001","revision":1,"amount":"2000"}')$q$);
select pg_temp.expect(public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000011","revision":1,"device":"ios"}')->'options'='[]','untested device has no route');
select pg_temp.expect(public.fn_biopay_quote_options(auth.uid(),'{"lookup":"+250788000002","amount":"1000","purpose":"transfer","device":"android"}')->'options'='[]','wrong purpose has no route');
select pg_temp.expect(public.fn_biopay_quote_options(auth.uid(),jsonb_build_object('lookup','+250788000002','amount','1000','purpose','merchant','device','android','source_id',
 (select id from public.biopay_payment_methods where identifier='001234')))->'options'='[]','another users method cannot be a source');
do $$ declare q jsonb; again jsonb; begin
 q:=pg_temp.fresh_quote();
 update public.biopay_provider_routes set tariff_version=tariff_version+1,fee_rwf=25;
 perform pg_temp.reject_prepare(q);
 q:=pg_temp.fresh_quote();
 update public.biopay_provider_routes set state='disabled';
 perform pg_temp.reject_prepare(q);
 update public.biopay_provider_routes set state='approved';
 q:=pg_temp.fresh_quote();
 update public.biopay_provider_routes set valid_until=now()-interval '1 minute',valid_from=now()-interval '1 day';
 perform pg_temp.reject_prepare(q);
 update public.biopay_provider_routes set valid_until=now()+interval '1 day';
 q:=pg_temp.fresh_quote();
 update public.biopay_payment_methods set version=version+1 where identifier='001234';
 perform pg_temp.reject_prepare(q);
 q:=pg_temp.fresh_quote();
 delete from public.biopay_method_grants;
 perform pg_temp.reject_prepare(q);
 insert into public.biopay_method_grants(method_id,grantee_id)
   select id,auth.uid() from public.biopay_payment_methods where identifier='001234';
 q:=pg_temp.fresh_quote();
 update public.biopay_route_quotes set expires_at=now()-interval '1 second' where id=(q->>'quote_id')::uuid;
 perform pg_temp.reject_prepare(q);
 update public.biopay_payment_methods set sim_label=null where owner_id=auth.uid();
 perform pg_temp.expect(pg_temp.fresh_quote()->'options'='[]','missing required SIM blocks route');
 update public.biopay_payment_methods set sim_label='SIM 1' where owner_id=auth.uid();
 perform pg_temp.expect(not exists(select 1 from public.biopay_payment_requests where reviewed_snapshot->'source' ? 'login_phone' or reviewed_snapshot->'source' ? 'sim_label'),'activity snapshot omits private source details');
 again:=public.rpc_biopay_discovery('pay_again',jsonb_build_object('id',(select id from public.biopay_payment_requests where payer_id=auth.uid() limit 1)));
 perform pg_temp.expect(again->>'evidence'='draft' and not(again ? 'attempt_id') and not(again ? 'instruction'),'pay again is a fresh draft with no executable instruction');
 perform pg_temp.expect(again->>'id'<>'00000000-0000-4000-8000-000000000011','pay again uses a new draft ID');
 perform pg_temp.expect((select count(*)=1 from public.biopay_recipient_shortcuts where owner_id=auth.uid()),'explicit choices create one private recent');
end $$;
-- Administrator authentication and independent evidence review.
update public.profiles set role='admin' where member_id in ('100003','100004');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 values('+250788000003','+250',true),('+250788000004','+250',true);
-- Full-schema Admin fixtures also carry the server-owned provider marker.
-- The old consumer JWT below must still be rejected until its claim context
-- changes to the separately verified Admin login. The reduced fixture has no
-- Auth table; actual Auth password rotation/revocation is tested over HTTP.
do $$ begin
  if to_regclass('auth.users') is not null then
    execute $admins$
      update auth.users set raw_app_meta_data = '{"provider":"admin_whatsapp_otp"}'
      where id in ('00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000004')
    $admins$;
  end if;
end $$;
select pg_temp.expect_rejected($q$select public.rpc_admin_biopay_routes('list','{}')$q$);
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000003');
select pg_temp.expect_rejected($q$select public.rpc_admin_biopay_routes('list','{}')$q$);
select pg_temp.qa_identity(auth.uid(), false, 'admin_whatsapp_otp');
do $$ declare r jsonb; bad jsonb; q jsonb; prepared jsonb; begin
 r:=public.rpc_admin_biopay_routes('save',jsonb_build_object('source_provider','mtn_rw','source_kind','mobileWallet',
   'destination_provider','mtn_rw','destination_kind','mobileWallet','rail','Synthetic transfer','purpose','transfer',
   'min_rwf',1,'max_rwf',10000000,'fee_certainty','unknown','handoff_mode','dial','recipient_format','rwandaNational',
   'instruction_template','*182#','valid_from',now(),'valid_until',now()+interval '1 day','device_families',jsonb_build_array('android'),
   'evidence_url','https://example.invalid/provider','tariff_evidence_url','https://example.invalid/tariff','test_evidence_url','https://example.invalid/handset'));
 perform pg_temp.expect_rejected(format('select public.rpc_admin_biopay_routes(''tested'',%L::jsonb)',r::text));
 r:=public.rpc_admin_biopay_routes('save',r||jsonb_build_object('instruction_template','*182*1*1*{recipient}*{amount}#'));
 r:=public.rpc_admin_biopay_routes('tested',r);
 perform pg_temp.expect_rejected(format('select public.rpc_admin_biopay_routes(''approve'',%L::jsonb)',r::text));
 perform pg_temp.qa_identity('00000000-0000-4000-8000-000000000004', false, 'admin_whatsapp_otp');
 r:=public.rpc_admin_biopay_routes('approve',r);
 perform pg_temp.expect(r->>'state'='approved','independent tested route approval succeeds');
 perform pg_temp.qa_identity('00000000-0000-4000-8000-000000000001');
 perform pg_temp.qa_identity(auth.uid());
 perform public.rpc_biopay_discovery('save_draft','{"id":"00000000-0000-4000-8000-000000000012","owner_id":"00000000-0000-4000-8000-000000000001","revision":1,"manual_method":{"provider":"mtn_rw","kind":"mobileWallet","identifier":"+250788000002"},"amount":"1500","purpose":"transfer"}');
 q:=public.rpc_biopay_discovery('quote','{"id":"00000000-0000-4000-8000-000000000012","revision":1,"device":"android"}');
 prepared:=public.rpc_biopay_discovery('prepare',jsonb_build_object('quote_id',q->>'quote_id','option_id',q->'options'->0->>'id','device','android'));
 perform pg_temp.expect(prepared->>'instruction'='*182*1*1*0788000002*1500#','adapter explicitly formats E164 phone for dialer');
end $$;
-- Receiver and operator statements stay distinct from provider confirmation.
select pg_temp.expect_rejected(format('select public.rpc_biopay_discovery(''acknowledge'',%L::jsonb)',
  jsonb_build_object('id',(select id from public.biopay_payment_requests where payee_id='00000000-0000-4000-8000-000000000002' limit 1))::text));
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000002');
select public.rpc_biopay_discovery('acknowledge',jsonb_build_object('id',(select id from public.biopay_payment_requests where payee_id=auth.uid() limit 1)));
select pg_temp.expect((select evidence_kind='receiverAcknowledged' and status<>'confirmed' from public.biopay_payment_requests where payee_id=auth.uid() limit 1),'receiver acknowledgement is not provider confirmation');
select pg_temp.qa_identity('00000000-0000-4000-8000-000000000003');
select pg_temp.qa_identity(auth.uid(), false, 'admin_whatsapp_otp');
select pg_temp.expect_rejected($q$update public.biopay_payment_requests set status='confirmed',confirmation_source='admin_external_reference' where payee_id='00000000-0000-4000-8000-000000000002'$q$);
update public.biopay_payment_requests set status='confirmed',confirmation_source='operator_review:synthetic-ref-123' where payee_id='00000000-0000-4000-8000-000000000002';
select pg_temp.expect((select evidence_kind='operatorReviewed' and status<>'confirmed' and confirmed_at is null from public.biopay_payment_requests where payee_id='00000000-0000-4000-8000-000000000002' limit 1),'operator reference is labelled as review, not provider confirmation');
select pg_temp.expect_rejected($q$update public.biopay_payment_requests set evidence_kind='providerConfirmed' where payee_id='00000000-0000-4000-8000-000000000002'$q$);
-- No direct access to another account's new private tables or helper RPCs.
set local role authenticated;
select pg_temp.expect_rejected('select * from public.biopay_payment_methods');
select pg_temp.expect_rejected($q$select public.fn_biopay_discover('00000000-0000-4000-8000-000000000002','{}')$q$);
reset role;
select 'BioPay discovery authorization, stale-state, privacy and adapter checks passed' as result;
rollback;
