-- Forward SQL body. Use the existing guarded Supabase-CLI preparer for migration
-- names. Requires bodies 01-06 and the original collector/receipt migrations.
-- NOT applied here. Defaults are engineering limits, not provider/legal rules.
begin;
do $$ begin
  if to_regprocedure('public._mobio_is_service_role()') is null
    or to_regprocedure('public.rpc_ingest_driver_subscription_momo_sms(text,text,timestamptz,jsonb)') is null
    or to_regclass('public.momobio_allocation_policies') is null then
    raise exception 'Install and verify the original schema and hardening bodies 01-06 first';
  end if;
end $$;

create table public.momobio_sms_intake_config (
  singleton boolean primary key default true check (singleton),
  processing_enabled boolean not null default false,
  max_total_rows integer not null default 50000 check (max_total_rows between 1 and 1000000),
  max_collector_rows integer not null default 10000 check (max_collector_rows between 1 and 100000),
  max_payload_bytes bigint not null default 134217728 check (max_payload_bytes between 10000 and 1073741824),
  max_concurrency integer not null default 2 check (max_concurrency between 1 and 10),
  max_attempts integer not null default 5 check (max_attempts between 1 and 20),
  max_attempts_per_hour integer not null default 120 check (max_attempts_per_hour between 1 and 10000),
  lease_seconds integer not null default 120 check (lease_seconds between 60 and 600),
  last_worker_at timestamptz,
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.momobio_sms_intake_config(singleton) values (true);

create table public.momobio_sms_intake (
  id uuid primary key default gen_random_uuid(),
  collector_id uuid not null references public.momobio_collectors(id) on delete restrict,
  message_hash text not null check (message_hash ~ '^[0-9a-f]{64}$'),
  raw_sms text not null check (length(raw_sms) between 1 and 10000),
  sender text not null check (length(sender) between 1 and 100),
  received_at timestamptz not null check (isfinite(received_at)),
  payload_bytes integer not null check (payload_bytes > 0),
  status text not null check (status in ('queued','processing','retry','processed','review')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default clock_timestamp(),
  lease_token uuid,
  lease_expires_at timestamptz,
  receipt_id uuid,
  review_reasons text[] not null default '{}',
  last_error_code text,
  admitted_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  unique (collector_id,message_hash),
  check ((status='processing' and lease_token is not null and lease_expires_at is not null)
    or (status<>'processing' and lease_token is null and lease_expires_at is null))
);
create index momobio_sms_intake_due_idx on public.momobio_sms_intake(next_attempt_at,admitted_at,id)
  where status in ('queued','retry');
create index momobio_sms_intake_expired_idx on public.momobio_sms_intake(lease_expires_at)
  where status='processing';
create index momobio_sms_intake_collector_idx on public.momobio_sms_intake(collector_id,status,admitted_at);

-- Fixed UTC-hour accounting, including failed parser attempts. No SMS/PII here.
create table public.momobio_sms_intake_budget (
  hour_start timestamptz primary key,
  attempts integer not null check (attempts >= 0)
);

alter table public.momobio_sms_intake_config enable row level security;
alter table public.momobio_sms_intake enable row level security;
alter table public.momobio_sms_intake_budget enable row level security;
revoke all on public.momobio_sms_intake_config,public.momobio_sms_intake,public.momobio_sms_intake_budget from public,anon,authenticated;
-- Configuration is explicitly operator-controlled; raw intake mutations go via RPCs.
grant select,update on public.momobio_sms_intake_config to service_role;
grant select on public.momobio_sms_intake,public.momobio_sms_intake_budget to service_role;

create function public.rpc_admit_momobio_sms_batch(p_collector_id uuid,p_messages jsonb,p_edge_processing_enabled boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  cfg public.momobio_sms_intake_config%rowtype;
  pol public.momobio_allocation_policies%rowtype;
  old public.momobio_sms_intake%rowtype;
  row_json jsonb; results jsonb := '[]'::jsonb;
  raw text; sender_name text; msg_hash text; received timestamptz;
  bytes integer; total_count bigint; collector_count bigint; total_bytes bigint;
  reasons text[]; duplicate boolean;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
  if p_messages is null or jsonb_typeof(p_messages)<>'array' then raise exception 'INVALID_INTAKE'; end if;
  if jsonb_array_length(p_messages) not between 1 and 50 then raise exception 'INVALID_INTAKE'; end if;
  -- One bounded transaction; also serializes capacity checks across collectors.
  perform pg_advisory_xact_lock(hashtextextended('mobio-intake-state-v1',0));
  select * into strict cfg from public.momobio_sms_intake_config where singleton for share;
  perform 1 from public.momobio_collectors where id=p_collector_id
    and revoked_at is null and expires_at>clock_timestamp() for share;
  if not found then raise exception 'COLLECTOR_DENIED' using errcode='42501'; end if;
  select * into pol from public.momobio_allocation_policies where collector_id=p_collector_id for share;
  select count(*),coalesce(sum(payload_bytes),0),count(*) filter(where collector_id=p_collector_id)
    into total_count,total_bytes,collector_count from public.momobio_sms_intake;
  for row_json in select value from jsonb_array_elements(p_messages) loop
    if jsonb_typeof(row_json)<>'object' or jsonb_typeof(row_json->'raw_sms') is distinct from 'string'
      or jsonb_typeof(row_json->'sender') is distinct from 'string'
      or jsonb_typeof(row_json->'message_hash') is distinct from 'string'
      or jsonb_typeof(row_json->'received_at') is distinct from 'string' then raise exception 'INVALID_INTAKE'; end if;
    raw := btrim(row_json->>'raw_sms'); sender_name := btrim(row_json->>'sender'); msg_hash := row_json->>'message_hash';
    if length(raw) not between 1 and 10000 or length(sender_name) not between 1 and 100
      or msg_hash !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_INTAKE'; end if;
    begin received := (row_json->>'received_at')::timestamptz;
    exception when invalid_datetime_format or datetime_field_overflow then raise exception 'INVALID_INTAKE'; end;
    if received is null or not isfinite(received) or received<=to_timestamp(0)
      or received>clock_timestamp()+interval '5 minutes' then raise exception 'INVALID_INTAKE'; end if;
    select * into old from public.momobio_sms_intake where collector_id=p_collector_id and message_hash=msg_hash for update;
    duplicate := found;
    if duplicate then
      if old.raw_sms<>raw or old.sender<>sender_name or old.received_at<>received then raise exception 'INTAKE_HASH_CONFLICT' using errcode='23505'; end if;
      -- Immutable admission identity/payload: never turn a retry into a new credit.
    else
      bytes := octet_length(raw)+octet_length(sender_name);
      if total_count+1>cfg.max_total_rows or collector_count+1>cfg.max_collector_rows
        or total_bytes+bytes>cfg.max_payload_bytes then raise exception 'INTAKE_CAPACITY' using errcode='54000'; end if;
      reasons := '{}';
      if p_edge_processing_enabled is not true then reasons := array_append(reasons,'edge_processing_disabled'); end if;
      if not cfg.processing_enabled then reasons := array_append(reasons,'processing_disabled'); end if;
      if pol.enabled is not true or coalesce(cardinality(pol.merchant_codes),0)=0
        or coalesce(cardinality(pol.allowed_senders),0)=0 then reasons := array_append(reasons,'policy_not_approved'); end if;
      if not exists(select 1 from unnest(pol.allowed_senders) s where lower(s)=lower(sender_name))
        then reasons := array_append(reasons,'sender_not_approved'); end if;
      insert into public.momobio_sms_intake(collector_id,message_hash,raw_sms,sender,received_at,payload_bytes,status,review_reasons)
        values(p_collector_id,msg_hash,raw,sender_name,received,bytes,case when cardinality(reasons)=0 then 'queued' else 'review' end,reasons)
        returning * into old;
      total_count:=total_count+1; collector_count:=collector_count+1; total_bytes:=total_bytes+bytes;
    end if;
    results := results || jsonb_build_array(jsonb_build_object('message_hash',msg_hash,
      'status',case when duplicate then 'duplicate' else 'accepted' end,
      'admission_id',old.id,'admission_status',old.status,'review_required',old.status='review'));
  end loop;
  return jsonb_build_object('version','momobio-intake-v1','results',results);
end $$;

create function public.rpc_claim_momobio_sms_intake()
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg public.momobio_sms_intake_config%rowtype; job public.momobio_sms_intake%rowtype;
  pol public.momobio_allocation_policies%rowtype; current_hour timestamptz; used integer; token uuid;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mobio-intake-state-v1',0));
  select * into strict cfg from public.momobio_sms_intake_config where singleton for update;
  update public.momobio_sms_intake_config set last_worker_at=clock_timestamp() where singleton;
  if not cfg.processing_enabled then return null; end if;
  -- Expired leases recover after process death. Tokens are cleared BEFORE re-claim.
  update public.momobio_sms_intake set status=case when attempt_count>=cfg.max_attempts then 'review' else 'retry' end,
    review_reasons=case when attempt_count>=cfg.max_attempts then array['attempts_exhausted'] else review_reasons end,
    last_error_code='lease_expired',lease_token=null,lease_expires_at=null,
    next_attempt_at=clock_timestamp()+interval '60 seconds',updated_at=clock_timestamp()
    where status='processing' and lease_expires_at<=clock_timestamp();
  update public.momobio_sms_intake set status='review',review_reasons=array['policy_or_collector_not_active'],updated_at=clock_timestamp()
    where status in ('queued','retry') and not exists(
      select 1 from public.momobio_collectors c join public.momobio_allocation_policies p on p.collector_id=c.id
      where c.id=momobio_sms_intake.collector_id and c.revoked_at is null and c.expires_at>clock_timestamp()
        and p.enabled and cardinality(p.merchant_codes)>0
        and exists(select 1 from unnest(p.allowed_senders) s where lower(s)=lower(momobio_sms_intake.sender)));
  update public.momobio_sms_intake set status='review',review_reasons=array['attempts_exhausted'],updated_at=clock_timestamp()
    where status in ('queued','retry') and attempt_count>=cfg.max_attempts;
  if (select count(*) from public.momobio_sms_intake where status='processing')>=cfg.max_concurrency then return null; end if;
  current_hour := date_trunc('hour',clock_timestamp(),'UTC');
  insert into public.momobio_sms_intake_budget(hour_start,attempts) values(current_hour,0) on conflict do nothing;
  select attempts into used from public.momobio_sms_intake_budget where hour_start=current_hour for update;
  if used>=cfg.max_attempts_per_hour then return null; end if;
  select * into job from public.momobio_sms_intake where status in ('queued','retry') and next_attempt_at<=clock_timestamp()
    order by next_attempt_at,admitted_at,id limit 1 for update skip locked;
  if not found then return null; end if;
  -- Hold approval and enrollment locks through the claim transaction.
  perform 1 from public.momobio_collectors where id=job.collector_id and revoked_at is null and expires_at>clock_timestamp() for share;
  if not found then return null; end if;
  select * into pol from public.momobio_allocation_policies where collector_id=job.collector_id and enabled for share;
  if not found then return null; end if;
  token := gen_random_uuid();
  update public.momobio_sms_intake set status='processing',attempt_count=attempt_count+1,
    lease_token=token,lease_expires_at=clock_timestamp()+make_interval(secs=>cfg.lease_seconds),updated_at=clock_timestamp()
    where id=job.id returning * into job;
  update public.momobio_sms_intake_budget set attempts=attempts+1 where hour_start=current_hour;
  -- Non-sensitive budget rows only; retained payloads are NEVER purged here.
  delete from public.momobio_sms_intake_budget where hour_start<current_hour-interval '48 hours';
  return jsonb_build_object('id',job.id,'lease_token',job.lease_token,'collector_id',job.collector_id,
    'raw_sms',job.raw_sms,'sender',job.sender,'received_at',job.received_at,'attempt_count',job.attempt_count,
    'policy',jsonb_build_object('enabled',true,'allowedSenders',pol.allowed_senders,'merchantCodes',pol.merchant_codes,'minConfidence',pol.min_confidence));
end $$;

create function public.rpc_complete_momobio_sms_intake(p_id uuid,p_lease_token uuid,p_parsed jsonb,p_review_reasons text[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare job public.momobio_sms_intake%rowtype; cfg public.momobio_sms_intake_config%rowtype;
  result jsonb; parsed jsonb; next_status text; reasons text[];
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
  if p_parsed is null or jsonb_typeof(p_parsed)<>'object' or octet_length(p_parsed::text)>20000
    or coalesce(cardinality(p_review_reasons),0)>30 then raise exception 'INVALID_INTAKE_RESULT'; end if;
  if exists(select 1 from unnest(p_review_reasons) r where r is null or r !~ '^[a-z_]{1,80}$') then raise exception 'INVALID_INTAKE_RESULT'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mobio-intake-state-v1',0));
  select * into strict cfg from public.momobio_sms_intake_config where singleton for share;
  select * into job from public.momobio_sms_intake where id=p_id for update;
  if not found or job.status<>'processing' or job.lease_token is distinct from p_lease_token
    or job.lease_expires_at<=clock_timestamp() then return jsonb_build_object('status','stale'); end if;
  reasons := coalesce(p_review_reasons,'{}');
  if not cfg.processing_enabled then reasons := array_append(reasons,'processing_disabled'); end if;
  parsed := case when cardinality(reasons)=0 then p_parsed else '{}'::jsonb end;
  -- Bind to the actual queued collector, never to a provider- or caller-selected identity.
  parsed := parsed || jsonb_build_object('verified_collector_id',job.collector_id);
  if cardinality(reasons)>0 then parsed := parsed || jsonb_build_object('allocation_eligible',false); end if;
  -- The EXISTING strict allocator independently rechecks current collector/policy,
  -- receipt evidence and invoice idempotency. Its credit and this queue completion
  -- commit in ONE database transaction. No direct receipt upsert is introduced.
  result := public.rpc_ingest_driver_subscription_momo_sms(job.raw_sms,job.sender,job.received_at,parsed)::jsonb;
  if result is null or result->>'status' is null or result->>'id' is null then raise exception 'INVALID_ALLOCATION_RESULT'; end if;
  next_status := case when result->>'status' in ('matched','duplicate') then 'processed' else 'review' end;
  if next_status='review' and cardinality(reasons)=0 then reasons := array['strict_allocation_review']; end if;
  update public.momobio_sms_intake set status=next_status,receipt_id=(result->>'id')::uuid,
    review_reasons=reasons,lease_token=null,lease_expires_at=null,completed_at=clock_timestamp(),updated_at=clock_timestamp(),last_error_code=null
    where id=job.id;
  return jsonb_build_object('status',next_status);
end $$;

create function public.rpc_retry_momobio_sms_intake(p_id uuid,p_lease_token uuid,p_error_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare job public.momobio_sms_intake%rowtype; cfg public.momobio_sms_intake_config%rowtype; next_status text; delay_seconds integer;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
  if p_error_code is null or p_error_code not in ('parser_configuration_missing','parser_rate_limited','parser_unavailable','parser_request_rejected','parser_timeout','parser_failed') then raise exception 'INVALID_INTAKE_ERROR'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mobio-intake-state-v1',0));
  select * into strict cfg from public.momobio_sms_intake_config where singleton for share;
  select * into job from public.momobio_sms_intake where id=p_id for update;
  if not found or job.status<>'processing' or job.lease_token is distinct from p_lease_token
    or job.lease_expires_at<=clock_timestamp() then return jsonb_build_object('status','stale'); end if;
  next_status := case when job.attempt_count>=cfg.max_attempts or not cfg.processing_enabled
    or p_error_code in ('parser_configuration_missing','parser_request_rejected') then 'review' else 'retry' end;
  delay_seconds := least(3600,(60*power(2,least(job.attempt_count-1,6)))::integer);
  if p_error_code='parser_rate_limited' then delay_seconds:=greatest(delay_seconds,300); end if;
  update public.momobio_sms_intake set status=next_status,last_error_code=p_error_code,
    review_reasons=case when next_status='review' then array[p_error_code] else review_reasons end,
    next_attempt_at=clock_timestamp()+make_interval(secs=>delay_seconds),lease_token=null,lease_expires_at=null,updated_at=clock_timestamp()
    where id=job.id;
  return jsonb_build_object('status',next_status);
end $$;

create function public.rpc_momobio_sms_intake_health(p_collector_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg public.momobio_sms_intake_config%rowtype; pol public.momobio_allocation_policies%rowtype; counts jsonb;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501'; end if;
  perform 1 from public.momobio_collectors where id=p_collector_id and revoked_at is null and expires_at>clock_timestamp();
  if not found then raise exception 'COLLECTOR_DENIED' using errcode='42501'; end if;
  select * into strict cfg from public.momobio_sms_intake_config where singleton;
  select * into pol from public.momobio_allocation_policies where collector_id=p_collector_id;
  select jsonb_build_object('queued_count',count(*) filter(where status in ('queued','retry','processing')),
    'review_count',count(*) filter(where status='review'),
    'oldest_queued_at',min(admitted_at) filter(where status in ('queued','retry','processing')),
    'last_admitted_at',max(admitted_at)) into counts from public.momobio_sms_intake where collector_id=p_collector_id;
  return counts || jsonb_build_object('version','momobio-intake-v1',
    'automatic_allocation_enabled',cfg.processing_enabled and coalesce(pol.enabled,false)
      and coalesce(cardinality(pol.allowed_senders),0)>0 and coalesce(cardinality(pol.merchant_codes),0)>0,
    'worker_recent',coalesce(cfg.last_worker_at>clock_timestamp()-interval '5 minutes',false));
end $$;

revoke all on function public.rpc_admit_momobio_sms_batch(uuid,jsonb,boolean),public.rpc_claim_momobio_sms_intake(),
  public.rpc_complete_momobio_sms_intake(uuid,uuid,jsonb,text[]),public.rpc_retry_momobio_sms_intake(uuid,uuid,text),
  public.rpc_momobio_sms_intake_health(uuid) from public,anon,authenticated;
grant execute on function public.rpc_admit_momobio_sms_batch(uuid,jsonb,boolean),public.rpc_claim_momobio_sms_intake(),
  public.rpc_complete_momobio_sms_intake(uuid,uuid,jsonb,text[]),public.rpc_retry_momobio_sms_intake(uuid,uuid,text),
  public.rpc_momobio_sms_intake_health(uuid) to service_role;
notify pgrst, 'reload schema';
commit;
