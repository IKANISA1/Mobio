\set ON_ERROR_STOP on
set request.jwt.claims='{"role":"service_role"}';
create function pg_temp.check_intake(value boolean,message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'ASSERTION: %',message; end if; end $$;
create function pg_temp.envelope(hash text,body text default 'synthetic receipt') returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('raw_sms',body,'sender','MTN','message_hash',hash,'received_at','2026-09-01T00:00:00Z'))
$$;
insert into public.momobio_collectors values('11111111-1111-4111-8111-111111111111',clock_timestamp()+interval '1 day',null);
insert into public.momobio_allocation_policies values('11111111-1111-4111-8111-111111111111',true,array['MTN'],array['12345'],0.95);
DO $$
declare collector uuid:='11111111-1111-4111-8111-111111111111'; a jsonb; b jsonb; job jsonb; new_job jsonb; result jsonb; denied boolean; before_count bigint;
begin
  a:=public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('a',64)),true);
  perform pg_temp.check_intake(a->'results'->0->>'admission_status'='review','default processing must be OFF');
  b:=public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('a',64)),true);
  perform pg_temp.check_intake(a->'results'->0->>'admission_id'=b->'results'->0->>'admission_id','duplicate admission identity');
  perform pg_temp.check_intake(b->'results'->0->>'status'='duplicate','duplicate acknowledgement');
  denied:=false;
  begin perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('a',64),'different payload'),true);
  exception when unique_violation then denied:=true; end;
  perform pg_temp.check_intake(denied,'different content with same client hash rejected');
  select count(*) into before_count from public.momobio_sms_intake;
  denied:=false;
  begin perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('b',64))||jsonb_build_array(jsonb_build_object('raw_sms','invalid')),true);
  exception when raise_exception then denied:=true; end;
  perform pg_temp.check_intake(denied and (select count(*) from public.momobio_sms_intake)=before_count,'invalid final row rolls back entire batch');

  update public.momobio_sms_intake_config set processing_enabled=true,max_concurrency=1,max_attempts_per_hour=2;
  perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('c',64),'queued one'),true);
  perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('d',64),'queued two'),true);
  job:=public.rpc_claim_momobio_sms_intake();
  perform pg_temp.check_intake(job->>'id' is not null,'claim one queued row');
  perform pg_temp.check_intake(public.rpc_claim_momobio_sms_intake() is null,'concurrency ceiling');
  result:=public.rpc_complete_momobio_sms_intake((job->>'id')::uuid,gen_random_uuid(),'{"allocation_eligible":true}','{}');
  perform pg_temp.check_intake(result->>'status'='stale' and (select count(*) from public.fixture_allocations)=0,'wrong lease has no allocator effects');
  update public.momobio_sms_intake set lease_expires_at=clock_timestamp()-interval '1 second' where id=(job->>'id')::uuid;
  result:=public.rpc_complete_momobio_sms_intake((job->>'id')::uuid,(job->>'lease_token')::uuid,'{"allocation_eligible":true}','{}');
  perform pg_temp.check_intake(result->>'status'='stale' and (select count(*) from public.fixture_allocations)=0,'expired lease has no allocator effects');
  -- Exhaust recovery and budget deterministically; suppress the other row's due time.
  update public.momobio_sms_intake set next_attempt_at=clock_timestamp()+interval '1 day' where message_hash=repeat('d',64);
  perform public.rpc_claim_momobio_sms_intake();
  update public.momobio_sms_intake set next_attempt_at=clock_timestamp()-interval '1 second' where id=(job->>'id')::uuid;
  new_job:=public.rpc_claim_momobio_sms_intake();
  perform pg_temp.check_intake(new_job->>'id'=job->>'id' and new_job->>'lease_token'<>job->>'lease_token','reclaim rotates fencing token');
  result:=public.rpc_retry_momobio_sms_intake((job->>'id')::uuid,(job->>'lease_token')::uuid,'parser_timeout');
  perform pg_temp.check_intake(result->>'status'='stale','old retry callback cannot reset a new lease');
  result:=public.rpc_complete_momobio_sms_intake((new_job->>'id')::uuid,(new_job->>'lease_token')::uuid,
    '{"allocation_eligible":true,"verified_collector_id":"22222222-2222-4222-8222-222222222222"}','{}');
  perform pg_temp.check_intake(result->>'status'='processed','current completion');
  perform pg_temp.check_intake((select parsed->>'verified_collector_id'=collector::text from public.fixture_allocations limit 1),'collector identity rebound in SQL');
  result:=public.rpc_complete_momobio_sms_intake((new_job->>'id')::uuid,(new_job->>'lease_token')::uuid,'{"allocation_eligible":true}','{}');
  perform pg_temp.check_intake(result->>'status'='stale' and (select count(*) from public.fixture_allocations)=1,'duplicate callback cannot run allocator');
  update public.momobio_sms_intake set next_attempt_at=clock_timestamp()-interval '1 second' where message_hash=repeat('d',64);
  perform pg_temp.check_intake(public.rpc_claim_momobio_sms_intake() is null,'hourly attempt budget');
  update public.momobio_sms_intake_budget set attempts=0;
  job:=public.rpc_claim_momobio_sms_intake();
  result:=public.rpc_retry_momobio_sms_intake((job->>'id')::uuid,(job->>'lease_token')::uuid,'parser_rate_limited');
  perform pg_temp.check_intake(result->>'status'='retry','provider retry persisted');
  perform pg_temp.check_intake((select next_attempt_at>clock_timestamp()+interval '4 minutes' from public.momobio_sms_intake where id=(job->>'id')::uuid),'rate-limit delay');
  update public.momobio_collectors set revoked_at=clock_timestamp() where id=collector;
  perform public.rpc_claim_momobio_sms_intake();
  perform pg_temp.check_intake((select status='review' from public.momobio_sms_intake where id=(job->>'id')::uuid),'revocation prevents further claims');
  denied:=false;
  begin perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('e',64)),true);
  exception when insufficient_privilege then denied:=true; end;
  perform pg_temp.check_intake(denied,'revoked admission rejected');
  update public.momobio_collectors set revoked_at=null where id=collector;
  update public.momobio_sms_intake_config set max_total_rows=(select count(*)::integer from public.momobio_sms_intake);
  perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('a',64)),true);
  denied:=false;
  begin perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('e',64)),true);
  exception when program_limit_exceeded then denied:=true; end;
  perform pg_temp.check_intake(denied,'capacity rejects new data but permits safe retransmission');
  update public.momobio_sms_intake_config set max_total_rows=50000;
  perform public.rpc_admit_momobio_sms_batch(collector,pg_temp.envelope(repeat('f',64),'kill switch race'),true);
  job:=public.rpc_claim_momobio_sms_intake();
  update public.momobio_sms_intake_config set processing_enabled=false;
  result:=public.rpc_complete_momobio_sms_intake((job->>'id')::uuid,(job->>'lease_token')::uuid,'{"allocation_eligible":true}','{}');
  perform pg_temp.check_intake(result->>'status'='review','database kill switch wins before completion');
  perform pg_temp.check_intake((select status='unmatched' from public.fixture_allocations where raw_sms='kill switch race'),'kill switch strips eligibility');
end $$;
-- Real PostgreSQL grants/RLS checks, still using synthetic schema prerequisites.
select pg_temp.check_intake(not has_function_privilege('anon','public.rpc_claim_momobio_sms_intake()','EXECUTE'),'anon cannot claim');
select pg_temp.check_intake(not has_function_privilege('authenticated','public.rpc_complete_momobio_sms_intake(uuid,uuid,jsonb,text[])','EXECUTE'),'authenticated cannot complete');
select pg_temp.check_intake(not has_table_privilege('authenticated','public.momobio_sms_intake','SELECT'),'authenticated cannot read SMS');
select pg_temp.check_intake(not has_table_privilege('service_role','public.momobio_sms_intake','UPDATE'),'service must use fenced queue mutations');
select pg_temp.check_intake((select relrowsecurity from pg_class where oid='public.momobio_sms_intake'::regclass),'RLS enabled');
-- Prepare eight synthetic jobs for separate-session concurrency verification.
update public.momobio_sms_intake_config set processing_enabled=true,max_concurrency=2,max_attempts_per_hour=120;
update public.momobio_sms_intake_budget set attempts=0;
select public.rpc_admit_momobio_sms_batch('11111111-1111-4111-8111-111111111111',
  jsonb_agg(jsonb_build_object('raw_sms','concurrency fixture '||n,'sender','MTN','message_hash',lpad(n::text,64,'0'),'received_at','2026-09-01T00:00:00Z')),true)
  from generate_series(1,8) n;
select 'COMPONENT_ASSERTIONS_COMPLETED';
