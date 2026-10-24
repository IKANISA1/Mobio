-- Unique disposable full-schema fixture only. Real Auth/session rows, SQL roles,
-- actual RPC effects and RLS. Synthetic JWT settings do not verify signatures or
-- WhatsApp delivery. Jobs stay disabled; all fixture changes roll back.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create temp table qa_recent_actors(name text primary key,provider text not null,
  phone text not null,user_id uuid not null default gen_random_uuid(),
  session_id uuid not null default gen_random_uuid());
insert into qa_recent_actors(name,provider,phone) values
 ('admin','admin_whatsapp_otp','+250700009301'),
 ('delegated','admin_whatsapp_otp','+250700009302'),
 ('approver','admin_whatsapp_otp','+250700009305'),
 ('consumer','whatsapp_cloud_otp','+250700009303'),
 ('target','whatsapp_cloud_otp','+250700009304');
create temp table qa_recent_results(name text);
create temp table qa_recent_calls(signature text primary key,statement text not null);
create temp table qa_recent_context(transfer_id uuid default gen_random_uuid(),redemption_id uuid default gen_random_uuid(),
 subscription_id uuid default gen_random_uuid(),sms_subscription_id uuid default gen_random_uuid(),
 expiry_subscription_id uuid default gen_random_uuid(),sms_id uuid default gen_random_uuid(),
 trip_id uuid default gen_random_uuid(),
 report_id uuid default gen_random_uuid(),biopay_id uuid default gen_random_uuid(),
 plan_id uuid,agency_id uuid,charger_id uuid,campaign_id uuid,
 org_id uuid default gen_random_uuid(),route_id uuid default gen_random_uuid(),
 schedule_id uuid default gen_random_uuid(),booking_id uuid default gen_random_uuid(),
 service_booking_id uuid default gen_random_uuid());
insert into qa_recent_context default values;
grant select on qa_recent_actors,qa_recent_calls,qa_recent_context to authenticated,service_role;
grant select,insert on qa_recent_results to authenticated,service_role;

create function pg_temp.qa_recent_check(label text,value boolean) returns void language plpgsql as $$
begin
 if value is distinct from true then raise exception 'ASSERTION FAILED: %',label; end if;
 insert into pg_temp.qa_recent_results values(label);
end $$;
create function pg_temp.qa_recent_identity(actor text,overrides jsonb default '{}') returns void language plpgsql as $$
declare claims jsonb;
begin
 select jsonb_build_object('sub',user_id,'session_id',session_id,'role','authenticated',
  'is_anonymous',false,'app_metadata',jsonb_build_object('provider',provider))
 into strict claims from pg_temp.qa_recent_actors where name=actor;
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claim.role','',true);
 perform set_config('request.jwt.claims',(claims||overrides)::text,true);
end $$;
create function pg_temp.qa_recent_rejected(label text,statement text,exact_freshness boolean default true)
returns void language plpgsql as $$
declare state text;message text;rejected boolean:=false;
begin
 begin execute statement;
 exception when others then
  get stacked diagnostics state=returned_sqlstate,message=message_text;
  if exact_freshness and (state<>'42501' or message<>'ADMIN_REAUTHENTICATION_REQUIRED') then
   raise exception 'ASSERTION FAILED: % returned %/%',label,state,message;
  end if;
  if not exact_freshness and state not in ('42501','P0001') then
   raise exception 'ASSERTION FAILED: % returned unexpected %/%',label,state,message;
  end if;
  if not exact_freshness and state='P0001' and
     message !~* '(permission|auth|forbidden|denied|required|admin)' then
   raise exception 'ASSERTION FAILED: % returned non-authority rejection %/%',label,state,message;
  end if;
  rejected:=true;
 end;
 perform pg_temp.qa_recent_check(label,rejected);
end $$;
create function pg_temp.qa_recent_expected_error(label text,statement text,expected_message text)
returns void language plpgsql as $$
declare message text;rejected boolean:=false;
begin
 begin execute statement;
 exception when others then
  get stacked diagnostics message=message_text;
  if message<>expected_message then
   raise exception 'ASSERTION FAILED: % returned %, expected %',label,message,expected_message;
  end if;
  rejected:=true;
 end;
 perform pg_temp.qa_recent_check(label,rejected);
end $$;
create function pg_temp.qa_recent_reject_all(label text,exact_freshness boolean default true) returns void language plpgsql as $$
declare call record;
begin
 for call in select * from pg_temp.qa_recent_calls order by signature loop
  perform pg_temp.qa_recent_rejected(label||': '||call.signature,call.statement,exact_freshness);
 end loop;
end $$;
create function pg_temp.qa_recent_snapshot() returns jsonb language plpgsql as $$
declare relation record;rows_value jsonb;result jsonb:='{}';
begin
 for relation in select schemaname,tablename from pg_tables where schemaname='public' order by tablename loop
  execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r',
   relation.schemaname,relation.tablename) into rows_value;
  result:=result||jsonb_build_object(relation.tablename,rows_value);
 end loop;
 return result;
end $$;

insert into auth.users(id,phone,phone_confirmed_at,raw_app_meta_data,raw_user_meta_data,is_anonymous)
 select user_id,phone,now(),jsonb_build_object('provider',provider),'{"qa_fixture":true}',false from qa_recent_actors;
insert into auth.sessions(id,user_id,created_at,not_after)
 select session_id,user_id,now(),now()+interval '1 hour' from qa_recent_actors;
-- Explicit SQL-only positive OTP/session setup; no Admin lease or grant is added.
select pg_temp.qa_seed_interactive_authority(array(select user_id from qa_recent_actors));

update public.profiles set role='admin' where id in (select user_id from qa_recent_actors where name in ('admin','approver'));
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active)
 select phone,'+250',true from qa_recent_actors where provider='admin_whatsapp_otp';
insert into mobio_private.admin_session_leases
 (session_id,user_id,otp_id,authenticated_at,last_activity_at,idle_expires_at,absolute_expires_at)
 select session_id,user_id,'recent-admin-'||name,now(),now(),now()+interval '15 minutes',now()+interval '8 hours'
 from qa_recent_actors where provider='admin_whatsapp_otp';
insert into public.profile_platform_permissions(profile_id,permission_key,expires_at)
 select user_id,'admin.users.manage',now()+interval '10 minutes' from qa_recent_actors where name='delegated';
insert into public.trips(id,author_id,origin,destination,status,is_active)
 select trip_id,(select user_id from qa_recent_actors where name='target'),'Synthetic origin','Synthetic destination','active',true
 from qa_recent_context;
insert into public.user_reports(id,organization_id,reporter_id,reported_id,details)
 select report_id,public.default_organization_id(),
 (select user_id from qa_recent_actors where name='consumer'),(select user_id from qa_recent_actors where name='target'),
 'Synthetic recent-admin moderation report' from qa_recent_context;
insert into public.biopay_payment_requests(id,channel,payer_id,payee_id,payee_label,amount_minor,reference,ussd_code,status)
 select biopay_id,'qr',(select user_id from qa_recent_actors where name='consumer'),
 (select user_id from qa_recent_actors where name='target'),'Synthetic payee',100000,'QA-RECENT','*182*8*1*12345*1000#','user_marked_paid'
 from qa_recent_context;

-- Valid synthetic payment/receipt/seat inputs exercise only existing backend
-- contracts. They do not represent provider evidence or production settlement.
insert into public.notification_consents(organization_id,profile_id,consent_type,channel,status)
 select public.default_organization_id(),user_id,'promotional','in_app','granted'
 from qa_recent_actors where name='consumer';
insert into public.wallet_transfers(id,sender_profile_id,receiver_profile_id,amount_tokens,idempotency_key)
 select transfer_id,(select user_id from qa_recent_actors where name='consumer'),
 (select user_id from qa_recent_actors where name='target'),5,'qa-recent-transfer' from qa_recent_context;
insert into public.token_redemption_requests(id,requester_profile_id,admin_profile_id,wallet_transfer_id,
 amount_tokens,amount_rwf,momo_number,admin_member_id,idempotency_key)
 select redemption_id,(select user_id from qa_recent_actors where name='target'),
 (select user_id from qa_recent_actors where name='admin'),transfer_id,5000,5000,'+250700009304',
 (select member_id from public.profiles where id=(select user_id from qa_recent_actors where name='admin')),
 'qa-recent-redemption' from qa_recent_context;
insert into public.subscription_plans(vehicle_type_id,country_id,interval_days,price,currency,is_active)
 values('cab','RW',92,1000,'RWF',true);
update qa_recent_context set plan_id=(select id from public.subscription_plans where vehicle_type_id='cab' and country_id='RW' and interval_days=92),
 agency_id=gen_random_uuid();
insert into public.driver_subscription_payment_requests(id,profile_id,plan_id,vehicle_type_id,payment_method,
 amount_tokens,amount_rwf,reference_code,expires_at)
 select x.id,(select user_id from qa_recent_actors where name='target'),c.plan_id,'cab','momo_ussd',1000,1000,x.reference,
 case when x.reference='QA-RECENT-EXPIRED' then now()-interval '1 minute' else now()+interval '30 minutes' end
 from qa_recent_context c cross join lateral (values
  (c.subscription_id,'QA-RECENT-DIRECT'),(c.sms_subscription_id,'QA-RECENT-SMS'),(c.expiry_subscription_id,'QA-RECENT-EXPIRED')) x(id,reference);
insert into public.driver_subscription_momo_sms_receipts(id,raw_sms,sms_hash,amount_rwf,reference_code,provider_transaction_ref)
 select sms_id,'Synthetic QA SMS receipt','qa-recent-sms-hash',1000,'QA-RECENT-SMS','qa-recent-provider-ref' from qa_recent_context;
insert into public.organizations(id,slug,name,status)
 select org_id,'qa-recent-transport','Synthetic freshness transport','active' from qa_recent_context;
insert into public.transport_agencies(id,organization_id,name,slug,is_active)
 select agency_id,org_id,'Synthetic freshness booked agency','qa-recent-booked',false from qa_recent_context;
insert into public.transport_routes(id,agency_id,organization_id,route_code,origin_name,destination_name)
 select route_id,agency_id,org_id,'QA-RECENT','Synthetic origin','Synthetic destination' from qa_recent_context;
insert into public.bus_schedules(id,agency_id,route_id,organization_id,departure_at,fare_amount,currency,status)
 select schedule_id,agency_id,route_id,org_id,now()+interval '1 day',1000,'RWF','scheduled' from qa_recent_context;
insert into public.bus_seat_inventory(schedule_id,organization_id,total_seats,available_seats,held_seats,confirmed_seats)
 select schedule_id,org_id,10,8,2,0 from qa_recent_context;
insert into public.bus_bookings(id,schedule_id,agency_id,organization_id,passenger_id,seat_count,status,payment_status,
 amount,currency,hold_expires_at,ticket_reference)
 select b.id,c.schedule_id,c.agency_id,c.org_id,(select user_id from qa_recent_actors where name='target'),
 1,'held','pending',1000,'RWF',now()+interval '10 minutes',b.ticket
 from qa_recent_context c cross join lateral (values(c.booking_id,'QA-RECENT-ADMIN'),(c.service_booking_id,'QA-RECENT-SERVICE')) b(id,ticket);

-- Build calls from the exact installed signatures, including null-argument
-- failure paths. Stale login must be rejected before argument validation/write.
do $$
declare signature text;routine record;args text;
begin
 foreach signature in array array[
  'public.rpc_admin_update_user_role(uuid,text)',
  'public.rpc_admin_upsert_whatsapp_number(text,text,text,boolean)',
  'public.rpc_admin_set_whatsapp_number_active(uuid,boolean)',
  'public.rpc_admin_cancel_trip(uuid,text)',
  'public.rpc_admin_review_user_report(uuid,text,text)',
  'public.rpc_admin_request_campaign_approval(text,text,text,jsonb)',
  'public.rpc_admin_approve_campaign(uuid,boolean,text)',
  'public.rpc_admin_send_approved_campaign(uuid)',
  'public.rpc_admin_send_promo(text,text,jsonb)',
  'public.rpc_admin_send_announcement(text,text,jsonb)',
  'public.rpc_admin_upsert_platform_setting(text,text)',
  'public.rpc_admin_update_vehicle_type(text,text,text,text,integer,boolean)',
  'public.rpc_admin_set_vehicle_type_active(text,boolean)',
  'public.rpc_admin_set_vehicle_type_countries(text,text[])',
  'public.rpc_admin_upsert_subscription_plan(text,text,integer,numeric,text,boolean)',
  'public.rpc_admin_set_subscription_plan_active(uuid,boolean)',
  'public.rpc_admin_delete_subscription_plan(uuid)',
  'public.rpc_admin_upsert_transport_agency(uuid,text,text,text,text,text,boolean)',
  'public.rpc_admin_set_transport_agency_active(uuid,boolean)',
  'public.rpc_admin_remove_transport_agency(uuid)',
  'public.rpc_admin_upsert_ev_charger(uuid,text,text,double precision,double precision,text[],text,text,numeric,text,text,boolean)',
  'public.rpc_admin_set_ev_charger_active(uuid,boolean)',
  'public.rpc_admin_adjust_user_tokens(uuid,bigint,text)',
  'public.rpc_admin_update_token_redemption_status(uuid,text,text)',
  'public.rpc_admin_expire_driver_subscription_payment_requests()',
  'public.rpc_admin_confirm_momo_sms_receipt(uuid,text)',
  'public.rpc_admin_reverse_wallet_transfer(uuid,text)',
  'public.rpc_admin_biopay_confirm_external(uuid,text)',
  'public.rpc_admin_biopay_routes(text,jsonb)',
  'public.rpc_confirm_bus_booking(uuid,text,text,jsonb)',
  'public.rpc_confirm_driver_subscription_payment(text,text,text,jsonb)'
 ] loop
  select * into strict routine from pg_proc where oid=signature::regprocedure;
  select string_agg('null::'||format_type(arg,NULL),',' order by ord)
   into args from unnest(routine.proargtypes::oid[]) with ordinality as a(arg,ord);
  insert into qa_recent_calls values(signature,'select public.'||routine.proname||'('||coalesce(args,'')||')');
 end loop;
 update qa_recent_calls c set statement=$q$select public.rpc_admin_biopay_routes('save','{}')$q$
 where c.signature='public.rpc_admin_biopay_routes(text,jsonb)';
end $$;
select pg_temp.qa_recent_check('all 31 sensitive RPC signatures are installed',(select count(*)=31 from qa_recent_calls));
select pg_temp.qa_recent_check('90 restrictive write gates cover 30 relations',(
 select count(*)=90 and count(distinct polrelid)=30 and bool_and(not polpermissive and polcmd in ('a','w','d'))
 from pg_policy where polname in ('sensitive_admin_recent_insert','sensitive_admin_recent_update','sensitive_admin_recent_delete')));
select pg_temp.qa_recent_check('recent write gates never affect SELECT',not exists(
 select 1 from pg_policy where polname like 'sensitive_admin_recent_%' and polcmd in ('r','*')));
select pg_temp.qa_recent_check('Admin purpose helper grants no client or service execution',
 not has_function_privilege('anon','mobio_private.is_live_admin_purpose_transport()','execute')
 and not has_function_privilege('authenticated','mobio_private.is_live_admin_purpose_transport()','execute')
 and not has_function_privilege('service_role','mobio_private.is_live_admin_purpose_transport()','execute'));

select pg_temp.qa_recent_identity('admin');
select pg_temp.qa_recent_check('Admin purpose is recognized independently of its lease',
 mobio_private.is_live_admin_purpose_transport());
select pg_temp.qa_recent_identity('admin','{"app_metadata":{"provider":"whatsapp_cloud_otp"}}');
select pg_temp.qa_recent_check('wrong JWT purpose cannot borrow Admin freshness recognition',
 not mobio_private.is_live_admin_purpose_transport());
select pg_temp.qa_recent_identity('admin','{"is_anonymous":true}');
select pg_temp.qa_recent_check('anonymous JWT cannot borrow Admin freshness recognition',
 not mobio_private.is_live_admin_purpose_transport());
select pg_temp.qa_recent_identity('consumer');
select pg_temp.qa_recent_check('ordinary consumer is outside Admin freshness recognition',
 not mobio_private.is_live_admin_purpose_transport());
select pg_temp.qa_recent_identity('admin');
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp()-interval '6 minutes'
 where user_id=(select user_id from qa_recent_actors where name='admin');
select pg_temp.qa_recent_check('stale authentication retains live Admin lease',public.verified_admin_user_id()=auth.uid());
create temp table qa_recent_initial as select pg_temp.qa_recent_snapshot() as state;
set local role authenticated;
select pg_temp.qa_recent_reject_all('stale Admin denied');
select pg_temp.qa_recent_check('stale live Admin retains ordinary read RPC',
 (select count(*)>0 from public.rpc_admin_list_users(p_limit=>10)));
select public.rpc_admin_session('touch');
select pg_temp.qa_recent_rejected('touch never renews authentication age',
 $q$select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'driver')$q$);
-- All non-list provider route actions are gated, even before route validation.
select pg_temp.qa_recent_rejected('stale route tested',$q$select public.rpc_admin_biopay_routes('tested','{}')$q$);
select pg_temp.qa_recent_rejected('stale route approve',$q$select public.rpc_admin_biopay_routes('approve','{}')$q$);
select pg_temp.qa_recent_rejected('stale route disable',$q$select public.rpc_admin_biopay_routes('disable','{}')$q$);
select pg_temp.qa_recent_check('stale route list remains readable',
 jsonb_typeof(public.rpc_admin_biopay_routes('list','{}')->'routes')='array');
-- Direct permission insertion must raise RLS denial. Stale updates/deletes may
-- correctly return zero affected rows, so inspect authoritative targets below.
select pg_temp.qa_recent_rejected('stale direct privilege escalation denied',
 $q$insert into public.profile_platform_permissions(profile_id,permission_key)
 select user_id,'platform.admin' from qa_recent_actors where name='consumer'$q$,false);
update public.vehicle_types set label='STALE-ADMIN-WRITE' where id='cab';
delete from public.profile_platform_permissions where profile_id=(select user_id from qa_recent_actors where name='delegated');
reset role;
select pg_temp.qa_recent_check('all stale RPC and direct denials preserve exact public rows',
 pg_temp.qa_recent_snapshot()=(select state from qa_recent_initial));

-- Future authentication times cannot supply freshness. Boundary uses server
-- statement time; the exact five-minute age is rejected, just inside is allowed.
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp()+interval '1 minute',
 last_activity_at=statement_timestamp()+interval '1 minute'
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
-- CR23 denies identity; the forward purpose guard still rejects all sensitive
-- RPCs with exact freshness failure before argument validation or any write.
select pg_temp.qa_recent_check('future authentication has no Admin identity',public.verified_admin_user_id() is null);
select pg_temp.qa_recent_check('future authentication has no application identity',public.verified_app_user_id() is null);
select pg_temp.qa_recent_reject_all('future authentication denied');
reset role;
select pg_temp.qa_recent_check('future authentication denials preserve exact public rows',
 pg_temp.qa_recent_snapshot()=(select state from qa_recent_initial));
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp()-interval '5 minutes'
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select pg_temp.qa_recent_rejected('exact freshness limit denied',
 $q$select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'driver')$q$);
reset role;
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp()-interval '299 seconds'
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'driver');
reset role;
select pg_temp.qa_recent_check('inside freshness window permits real role mutation',
 (select role='driver' and is_driver from public.profiles where id=(select user_id from qa_recent_actors where name='target')));

-- Keep the fresh success rows synthetic and verify real family effects. The
-- additional gates must not replace permission checks with freshness alone.
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp(),last_activity_at=statement_timestamp()
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select public.rpc_admin_cancel_trip((select trip_id from qa_recent_context),'Synthetic moderation');
select public.rpc_admin_review_user_report((select report_id from qa_recent_context),'resolved','Synthetic resolution');
select public.rpc_admin_adjust_user_tokens((select user_id from qa_recent_actors where name='target'),10,'Synthetic QA credit');
select public.rpc_admin_upsert_platform_setting('insurance_agent_whatsapp_e164','+250700009399');
select public.rpc_admin_update_token_redemption_status((select redemption_id from qa_recent_context),'cancelled','Synthetic cancellation');
select public.rpc_admin_reverse_wallet_transfer((select transfer_id from qa_recent_context),'Synthetic reversal');
select public.rpc_confirm_driver_subscription_payment('QA-RECENT-DIRECT','Synthetic authority','qa-recent-direct-reference','{"qa_fixture":true}');
select public.rpc_admin_confirm_momo_sms_receipt((select sms_id from qa_recent_context),'Synthetic SMS review');
select public.rpc_confirm_bus_booking((select booking_id from qa_recent_context),'qa-recent','qa-recent-admin-booking','{"qa_fixture":true}');
select public.rpc_admin_update_vehicle_type('cab','Synthetic recent-admin cab',null,null,null,null);
select public.rpc_admin_set_vehicle_type_active('cab',true);
select public.rpc_admin_set_vehicle_type_countries('cab',array['RW']);
reset role;
select pg_temp.qa_recent_check('fresh moderation cancels exact trip',
 (select status='cancelled' and not is_active from public.trips where id=(select trip_id from qa_recent_context)));
select pg_temp.qa_recent_check('fresh report resolution records exact reviewer',
 (select status='resolved' and reviewed_by=(select user_id from qa_recent_actors where name='admin')
 from public.user_reports where id=(select report_id from qa_recent_context)));
select pg_temp.qa_recent_check('fresh finance credit creates real ledger entry',exists(
 select 1 from public.token_ledger_entries where profile_id=(select user_id from qa_recent_actors where name='target')
 and amount_tokens=10 and reason='admin_adjustment'));
select pg_temp.qa_recent_check('fresh configuration stores server audit actor',
 (select value='+250700009399' and updated_by=(select user_id from qa_recent_actors where name='admin')
 from public.app_platform_settings where key='insurance_agent_whatsapp_e164'));
select pg_temp.qa_recent_check('fresh redemption review applies existing cancelled transition',
 (select status='cancelled' and admin_note='Synthetic cancellation' from public.token_redemption_requests where id=(select redemption_id from qa_recent_context)));
select pg_temp.qa_recent_check('fresh wallet reversal persists paired debit and credit',
 (select status='reversed' from public.wallet_transfers where id=(select transfer_id from qa_recent_context))
 and (select count(*)=2 and sum(case when direction='credit' then amount_tokens else -amount_tokens end)=0
 from public.token_ledger_entries where reference_id=(select transfer_id from qa_recent_context)));
select pg_temp.qa_recent_check('fresh direct subscription confirmation creates exact entitlement',exists(
 select 1 from public.driver_subscriptions where external_subscription_id='QA-RECENT-DIRECT'
 and profile_id=(select user_id from qa_recent_actors where name='target') and status='active'));
select pg_temp.qa_recent_check('fresh SMS review binds exact receipt to entitlement request',
 (select status='matched' and matched_payment_request_id=(select sms_subscription_id from qa_recent_context)
 from public.driver_subscription_momo_sms_receipts where id=(select sms_id from qa_recent_context))
 and exists(select 1 from public.driver_subscriptions where external_subscription_id='QA-RECENT-SMS'));
select pg_temp.qa_recent_check('fresh Admin bus confirmation preserves bound paid receipt',exists(
 select 1 from public.bus_booking_payments where booking_id=(select booking_id from qa_recent_context)
 and provider_reference='qa-recent-admin-booking' and status='paid' and amount=1000 and currency='RWF'));
select pg_temp.qa_recent_check('fresh vehicle changes persist through existing catalog RPCs',
 (select label='Synthetic recent-admin cab' and is_active from public.vehicle_types where id='cab'));

-- Exercise direct authorization boundaries as actual writes, including the
-- precise permission table that the stale session could not mutate.
set local role authenticated;
do $$
declare previous_order integer;
begin
 insert into public.profile_platform_permissions(profile_id,permission_key)
 select user_id,'admin.users.read' from qa_recent_actors where name='consumer';
 perform pg_temp.qa_recent_check('fresh direct permission insertion retains authorized Admin path',exists(
  select 1 from public.profile_platform_permissions where profile_id=(select user_id from qa_recent_actors where name='consumer')
  and permission_key='admin.users.read'));
 delete from public.profile_platform_permissions where profile_id=(select user_id from qa_recent_actors where name='consumer')
  and permission_key='admin.users.read';
 perform pg_temp.qa_recent_check('fresh direct permission deletion retains authorized Admin path',not exists(
  select 1 from public.profile_platform_permissions where profile_id=(select user_id from qa_recent_actors where name='consumer')
  and permission_key='admin.users.read'));
 select sort_order into previous_order from public.vehicle_types where id='cab';
 update public.vehicle_types set sort_order=previous_order+1 where id='cab';
 perform pg_temp.qa_recent_check('fresh direct catalog update survives restrictive guard',
  (select sort_order=previous_order+1 from public.vehicle_types where id='cab'));
end $$;
reset role;

-- Valid effects through the remaining ordinary Admin families. No external
-- delivery runs: the fixture's cron launch is disabled and the push trigger
-- writes only the existing outbox. Synthetic evidence URLs are fixture data.
set local role authenticated;
do $$
declare row_value record;plan uuid;agency uuid;charger uuid;campaign uuid;provider_route jsonb;count_value integer;
begin
 select * into row_value from public.rpc_admin_upsert_whatsapp_number('+250700009398','+250','Synthetic QA allowlist',true);
 perform pg_temp.qa_recent_check('fresh allowlist upsert returns the server record',row_value.phone_e164='+250700009398' and row_value.is_active);
 select * into row_value from public.rpc_admin_set_whatsapp_number_active(row_value.id,false);
 perform pg_temp.qa_recent_check('fresh allowlist deactivate applies exact requested state',not row_value.is_active);
 plan:=public.rpc_admin_upsert_subscription_plan('cab','RW',91,1000,'RWF',true);
 perform pg_temp.qa_recent_check('fresh subscription catalog upsert persists valid plan',exists(
  select 1 from public.subscription_plans where id=plan and interval_days=91 and price=1000));
 perform public.rpc_admin_set_subscription_plan_active(plan,false);
 perform pg_temp.qa_recent_check('fresh subscription catalog deactivate persists state',exists(
  select 1 from public.subscription_plans where id=plan and not is_active));
 perform public.rpc_admin_delete_subscription_plan(plan);
 perform pg_temp.qa_recent_check('fresh subscription catalog delete removes exact unused plan',not exists(
  select 1 from public.subscription_plans where id=plan));
 agency:=public.rpc_admin_upsert_transport_agency(null,'Synthetic freshness agency',null,null,null,'rwanda',false);
 perform pg_temp.qa_recent_check('fresh transport catalog upsert persists exact agency',exists(
  select 1 from public.transport_agencies where id=agency and name='Synthetic freshness agency'));
 perform public.rpc_admin_set_transport_agency_active(agency,true);
 perform pg_temp.qa_recent_check('fresh transport catalog activation persists state',exists(
  select 1 from public.transport_agencies where id=agency and is_active));
 perform public.rpc_admin_remove_transport_agency(agency);
 perform pg_temp.qa_recent_check('fresh public remove wrapper preserves soft deactivation',exists(
  select 1 from public.transport_agencies where id=agency and not is_active));
 charger:=public.rpc_admin_upsert_ev_charger(null,'Synthetic freshness charger','Synthetic address',-1.95,30.05,
  array['Type 2'],'Synthetic operator',null,22,null,null,true);
 perform pg_temp.qa_recent_check('fresh EV catalog upsert persists exact charger',exists(
  select 1 from public.ev_chargers where id=charger and name='Synthetic freshness charger'));
 perform public.rpc_admin_set_ev_charger_active(charger,false);
 perform pg_temp.qa_recent_check('fresh EV catalog deactivate persists state',exists(
  select 1 from public.ev_chargers where id=charger and not is_active));
 campaign:=public.rpc_admin_request_campaign_approval('promo','Synthetic freshness promo','QA only','{"qa_fixture":true}');
 perform pg_temp.qa_recent_check('fresh campaign request persists pending approval',exists(
  select 1 from public.campaign_approvals where id=campaign and status='pending_approval'));
 perform public.rpc_admin_approve_campaign(campaign,true,'Synthetic QA approval');
 perform pg_temp.qa_recent_check('fresh campaign approval preserves permission checks and state',exists(
  select 1 from public.campaign_approvals where id=campaign and status='approved'));
 count_value:=public.rpc_admin_send_approved_campaign(campaign);
 perform pg_temp.qa_recent_check('fresh approved campaign send persists sent state',exists(
  select 1 from public.campaign_approvals where id=campaign and status='sent') and count_value>=0);
 count_value:=public.rpc_admin_send_promo('Synthetic wrapper promo','QA only','{"qa_fixture":true}');
 perform pg_temp.qa_recent_check('fresh promo wrapper creates approval rather than unapproved send',count_value=0 and exists(
  select 1 from public.campaign_approvals where title='Synthetic wrapper promo' and status='pending_approval'));
 count_value:=public.rpc_admin_send_announcement('Synthetic freshness announcement','QA only','{"qa_fixture":true}');
 perform pg_temp.qa_recent_check('fresh announcement retains exact synthetic content',exists(
  select 1 from public.campaign_approvals where title='Synthetic freshness announcement' and status='sent') and count_value>=0);
 provider_route:=public.rpc_admin_biopay_confirm_external((select biopay_id from qa_recent_context),'Synthetic QA reference');
 perform pg_temp.qa_recent_check('fresh BioPay external confirmation retains existing exact request',
  provider_route->>'status'='confirmed' and provider_route->>'confirmation_source'='Synthetic QA reference');
 provider_route:=public.rpc_admin_biopay_routes('save',jsonb_build_object(
  'source_provider','mtn_rw','source_kind','mobileWallet','destination_provider','mtn_rw',
  'destination_kind','merchantCode','rail','Synthetic QA rail','purpose','merchant','min_rwf',1,'max_rwf',10000,
  'fee_certainty','unknown','fee_all_in',false,'steps',1,'handoff_mode','dial',
  'instruction_template','*182*8*1*{recipient}*{amount}#','device_families',jsonb_build_array('android'),
  'valid_from',now()-interval '1 minute','valid_until',now()+interval '1 day',
  'evidence_url','https://example.invalid/qa-provider','tariff_evidence_url','https://example.invalid/qa-tariff',
  'test_evidence_url','https://example.invalid/qa-test'));
 perform pg_temp.qa_recent_check('fresh provider route save preserves draft boundary',provider_route->>'state'='draft');
 provider_route:=public.rpc_admin_biopay_routes('tested',provider_route);
 perform pg_temp.qa_recent_check('fresh provider route test records current tester',provider_route->>'state'='tested'
  and provider_route->>'tested_by'=(select user_id::text from qa_recent_actors where name='admin'));
 perform pg_temp.qa_recent_rejected('fresh route cannot bypass independent approval',
  format('select public.rpc_admin_biopay_routes(''approve'',%L::jsonb)',provider_route::text),false);
 perform pg_temp.qa_recent_identity('approver');
 provider_route:=public.rpc_admin_biopay_routes('approve',provider_route);
 perform pg_temp.qa_recent_check('fresh independent route approval preserves reviewer separation',
  provider_route->>'state'='approved' and provider_route->>'reviewed_by'=(select user_id::text from qa_recent_actors where name='approver'));
 provider_route:=public.rpc_admin_biopay_routes('disable',provider_route);
 perform pg_temp.qa_recent_check('fresh provider disable persists exact disabled state',provider_route->>'state'='disabled');
 perform pg_temp.qa_recent_identity('admin');
end $$;
reset role;

select pg_temp.qa_recent_identity('delegated');
set local role authenticated;
select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'passenger');
select pg_temp.qa_recent_rejected('fresh delegated grant cannot manage configuration',
 $q$select public.rpc_admin_upsert_platform_setting('insurance_agent_whatsapp_e164','+250700009399')$q$,false);
reset role;
select pg_temp.qa_recent_check('fresh delegated exact grant preserves real allowed effect',
 (select role='passenger' from public.profiles where id=(select user_id from qa_recent_actors where name='target')));
update public.profile_platform_permissions set expires_at=now()-interval '1 second'
 where profile_id=(select user_id from qa_recent_actors where name='delegated');
set local role authenticated;
select pg_temp.qa_recent_rejected('fresh delegated expired permission remains denied',
 $q$select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'driver')$q$,false);
reset role;

select pg_temp.qa_recent_identity('consumer');
set local role authenticated;
select pg_temp.qa_recent_check('verified consumer remains outside Admin identity',public.verified_admin_user_id() is null);
select pg_temp.qa_recent_expected_error('authenticated consumer cannot borrow service expiry',
 $q$select public.rpc_admin_expire_driver_subscription_payment_requests()$q$,'ADMIN_OR_SERVICE_ROLE_REQUIRED');
update public.profiles set display_name='Synthetic consumer retained owner edit'
 where id=(select user_id from qa_recent_actors where name='consumer');
select pg_temp.qa_recent_rejected('consumer role escalation remains denied',
 $q$select public.rpc_admin_update_user_role((select user_id from qa_recent_actors where name='target'),'driver')$q$,false);
reset role;
select pg_temp.qa_recent_check('new write guards retain consumer profile owner edit',
 (select display_name='Synthetic consumer retained owner edit' from public.profiles
 where id=(select user_id from qa_recent_actors where name='consumer')));

select pg_temp.qa_recent_identity('admin');
create temp table qa_recent_final_authority_snapshot as select pg_temp.qa_recent_snapshot() as state;
update mobio_private.admin_session_leases set revoked_at=now()
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select pg_temp.qa_recent_reject_all('revoked Admin denied before sensitive validation');
update public.vehicle_types set label='REVOKED-ADMIN-WRITE' where id='cab';
reset role;
select pg_temp.qa_recent_check('null revoked resolver does not bypass original privileged RLS',
 (select label='Synthetic recent-admin cab' from public.vehicle_types where id='cab'));
update mobio_private.admin_session_leases set revoked_at=null,idle_expires_at=now()-interval '1 second'
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select pg_temp.qa_recent_reject_all('expired idle Admin denied before sensitive validation');
reset role;
update mobio_private.admin_session_leases set idle_expires_at=now()-interval '1 second',absolute_expires_at=now()-interval '1 second'
 where user_id=(select user_id from qa_recent_actors where name='admin');
set local role authenticated;
select pg_temp.qa_recent_reject_all('expired absolute Admin denied before sensitive validation');
reset role;
select pg_temp.qa_recent_check('revoked and expired denials preserve exact public rows',
 pg_temp.qa_recent_snapshot()=(select state from qa_recent_final_authority_snapshot));

-- An authenticated caller cannot borrow the service-only branch. The five
-- existing true service paths retain freshness admission and original validation.
select pg_temp.qa_recent_identity('consumer');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.qa_recent_check('existing service expiry path executes without interactive lease',
 public.rpc_admin_expire_driver_subscription_payment_requests()->>'expired_count' is not null);
select public.rpc_confirm_bus_booking((select service_booking_id from qa_recent_context),'qa-recent','qa-recent-service-booking','{"qa_fixture":true}');
select pg_temp.qa_recent_expected_error('service reverse retains target-not-found validation',
 $q$select public.rpc_admin_reverse_wallet_transfer('00000000-0000-4000-8000-000000000000','QA')$q$,'WALLET_TRANSFER_NOT_FOUND');
select pg_temp.qa_recent_expected_error('service SMS review retains target-not-found validation',
 $q$select public.rpc_admin_confirm_momo_sms_receipt('00000000-0000-4000-8000-000000000000','QA')$q$,'MOMO_SMS_RECEIPT_NOT_FOUND');
select pg_temp.qa_recent_expected_error('service subscription retains target-not-found validation',
 $q$select public.rpc_confirm_driver_subscription_payment('QA-NOT-FOUND','QA',null,'{}')$q$,'SUBSCRIPTION_PAYMENT_NOT_FOUND');
select pg_temp.qa_recent_expected_error('service bus confirmation retains target-not-found validation',
 $q$select public.rpc_confirm_bus_booking('00000000-0000-4000-8000-000000000000','QA','QA-NOT-FOUND','{}')$q$,'Booking is not available for confirmation.');
reset role;
-- A fresh interactive Admin also retains the expiry RPC's authorized,
-- idempotent success after the true service expiry has already consumed targets.
update mobio_private.admin_session_leases set authenticated_at=statement_timestamp(),last_activity_at=statement_timestamp(),
 idle_expires_at=statement_timestamp()+interval '15 minutes',absolute_expires_at=statement_timestamp()+interval '8 hours',revoked_at=null
 where user_id=(select user_id from qa_recent_actors where name='admin');
select pg_temp.qa_recent_identity('admin');
set local role authenticated;
select pg_temp.qa_recent_check('fresh Admin expiry retains authorized idempotent success',
 (public.rpc_admin_expire_driver_subscription_payment_requests()->>'expired_count')::integer=0);
reset role;
select pg_temp.qa_recent_check('existing service expiry commits actual expired request',
 (select status='expired' from public.driver_subscription_payment_requests where id=(select expiry_subscription_id from qa_recent_context)));
select pg_temp.qa_recent_check('existing service bus branch commits exact paid receipt',exists(
 select 1 from public.bus_booking_payments where booking_id=(select service_booking_id from qa_recent_context)
 and provider_reference='qa-recent-service-booking' and status='paid'));
select pg_temp.qa_recent_check('two allowed bus confirmations conserve exact seat inventory',
 (select available_seats=8 and held_seats=0 and confirmed_seats=2
 and available_seats+held_seats+confirmed_seats=total_seats from public.bus_seat_inventory
 where schedule_id=(select schedule_id from qa_recent_context)));
select name as passed_assertion from qa_recent_results order by name;
select count(*) as passed_assertions from qa_recent_results;
rollback;
