-- Forward SOURCE body; not an applied migration. No data-erasure executor here.
-- Requires live verified Auth identity and the Increment05 administrative leases.
-- A request, an operator action, and verified deletion are separate facts.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $$ begin
  if to_regprocedure('public.verified_app_user_id()') is null or
     to_regprocedure('public.verified_admin_user_id()') is null or
     to_regprocedure('public._mobio_is_service_role()') is null then
    raise exception 'PRIVACY_PREREQUISITES_REQUIRED';
  end if;
end $$;
create table mobio_private.privacy_policy (
  singleton boolean primary key default true check(singleton),
  intake_enabled boolean not null default false,
  processing_enabled boolean not null default false,
  notice_version text check(notice_version ~ '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$'),
  inventory_sha256 text check(inventory_sha256 ~ '^[0-9a-f]{64}$'),
  approval_reference text check(approval_reference ~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$'),
  reauth_seconds integer not null default 300 check(reauth_seconds between 30 and 900),
  max_requests_per_day integer not null default 3 check(max_requests_per_day between 1 and 20),
  changed_at timestamptz not null default clock_timestamp(),
  check(not intake_enabled or (notice_version is not null and approval_reference is not null)),
  check(not processing_enabled or (intake_enabled and inventory_sha256 is not null))
);
insert into mobio_private.privacy_policy(singleton) values(true);
-- Intentionally not cascade-deleted with Auth. This is retained personal metadata
-- requiring approved retention and restore-tombstone handling before enablement.
create table mobio_private.privacy_requests (
  request_id uuid primary key,
  owner_id uuid not null,
  originating_session_id uuid not null,
  notice_version text not null,
  inventory_sha256 text,
  status text not null default 'requested' check(status in
    ('requested','processing','blocked','cancelled','completed','completed_with_retention')),
  revision integer not null default 0 check(revision>=0),
  requested_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  started_at timestamptz,
  completed_at timestamptz,
  plan_sha256 text check(plan_sha256 ~ '^[0-9a-f]{64}$'),
  completion_manifest_sha256 text check(completion_manifest_sha256 ~ '^[0-9a-f]{64}$'),
  blocked_code text check(blocked_code in ('inventory_incomplete','provider_unavailable','retention_review','identity_review','execution_failed')),
  check(status not in ('completed','completed_with_retention') or
    (completed_at is not null and started_at is not null and completion_manifest_sha256 is not null)),
  check(status<>'cancelled' or started_at is null)
);
create unique index privacy_one_active_per_owner on mobio_private.privacy_requests(owner_id)
  where status not in ('completed','completed_with_retention','cancelled');
create index privacy_owner_history on mobio_private.privacy_requests(owner_id,requested_at desc,request_id desc);
create index privacy_work_queue on mobio_private.privacy_requests(requested_at,request_id)
  where status in ('requested','processing','blocked');
create table mobio_private.privacy_evidence (
  request_id uuid not null references mobio_private.privacy_requests(request_id),
  category text not null check(category in ('sessions','auth','profile_and_activity','financial_records','delivery_journals','storage','face_vectors','processors','backups','privacy_case_records')),
  outcome text not null check(outcome in ('deleted','retained','not_applicable')),
  evidence_sha256 text not null check(evidence_sha256 ~ '^[0-9a-f]{64}$'),
  retention_until timestamptz,
  basis_reference text,
  recorded_at timestamptz not null default clock_timestamp(),
  request_revision integer not null check(request_revision>0),
  primary key(request_id,category,request_revision),
  check(outcome<>'retained' or (retention_until is not null and basis_reference is not null and basis_reference ~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$')),
  check(outcome='retained' or (retention_until is null and basis_reference is null)),
  check(category not in ('auth','sessions') or outcome='deleted'),
  check(category<>'privacy_case_records' or outcome='retained')
);
create table mobio_private.privacy_actions (
  event_id uuid primary key default gen_random_uuid(),
  request_id uuid references mobio_private.privacy_requests(request_id),
  action_id uuid unique,
  action text not null,
  actor_reference text not null,
  input_sha256 text,
  resulting_revision integer,
  happened_at timestamptz not null default clock_timestamp()
);
create index privacy_actions_request on mobio_private.privacy_actions(request_id,happened_at);
alter table mobio_private.privacy_policy enable row level security;
alter table mobio_private.privacy_requests enable row level security;
alter table mobio_private.privacy_evidence enable row level security;
alter table mobio_private.privacy_actions enable row level security;
revoke all on mobio_private.privacy_policy,mobio_private.privacy_requests,
  mobio_private.privacy_evidence,mobio_private.privacy_actions from public,anon,authenticated,service_role;


-- Evidence corrections append a new revision; earlier records remain auditable.
create function mobio_private.privacy_current_evidence(p_request_id uuid)
returns setof mobio_private.privacy_evidence language sql stable set search_path='' as $$
  select distinct on (e.category) e.* from mobio_private.privacy_evidence e
    where e.request_id=p_request_id order by e.category,e.request_revision desc
$$;
revoke all on function mobio_private.privacy_current_evidence(uuid) from public,anon,authenticated,service_role;

create function mobio_private.privacy_request_view(r mobio_private.privacy_requests)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('request_id',r.request_id,'notice_version',r.notice_version,
    'status',r.status,'revision',r.revision,'requested_at',r.requested_at,'updated_at',r.updated_at,
    'can_cancel',r.started_at is null and r.status in ('requested','blocked'),
    'completion_evidence_recorded',r.status in ('completed','completed_with_retention'),
    'retained_categories',coalesce((select jsonb_agg(e.category order by e.category)
      from mobio_private.privacy_current_evidence(r.request_id) e where e.outcome='retained'),'[]'::jsonb))
$$;
revoke all on function mobio_private.privacy_request_view(mobio_private.privacy_requests)
  from public,anon,authenticated,service_role;

-- Only own records. No user-supplied subject, table names, evidence or SQL.
create function public.rpc_privacy_user(p_action text,p_request_id uuid default null,
  p_notice_version text default null,p_confirmed boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=public.verified_app_user_id(); sid uuid;
  policy mobio_private.privacy_policy%rowtype;
  r mobio_private.privacy_requests%rowtype; payload jsonb; stamp timestamptz:=clock_timestamp();
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_action is null or p_action not in ('policy','list','status','request','cancel') then
    raise exception 'INVALID_PRIVACY_ACTION' using errcode='22023'; end if;
  if p_action in ('policy','list') and (p_request_id is not null or p_notice_version is not null or p_confirmed is distinct from false) then
    raise exception 'INVALID_PRIVACY_ARGUMENTS' using errcode='22023'; end if;
  if p_action in ('status','cancel') and (p_notice_version is not null or p_confirmed is distinct from false) then
    raise exception 'INVALID_PRIVACY_ARGUMENTS' using errcode='22023'; end if;
  select * into strict policy from mobio_private.privacy_policy where singleton;
  if p_action='policy' then
    return jsonb_build_object('protocol','mobio.privacy.v1','owner_id',actor,
      'enabled',policy.intake_enabled,'notice_version',policy.notice_version,
      'reauth_seconds',policy.reauth_seconds,'submission_means','request_received_not_data_deleted');
  elsif p_action='list' then
    select coalesce(jsonb_agg(mobio_private.privacy_request_view(x::mobio_private.privacy_requests) order by x.requested_at desc,x.request_id desc),'[]'::jsonb)
      into payload from (select * from mobio_private.privacy_requests where owner_id=actor
        order by requested_at desc,request_id desc limit 20) x;
    return jsonb_build_object('protocol','mobio.privacy.v1','owner_id',actor,'requests',payload);
  end if;
  if p_request_id is null then raise exception 'INVALID_PRIVACY_REQUEST' using errcode='22023'; end if;
  if p_action='status' then
    select * into r from mobio_private.privacy_requests where request_id=p_request_id and owner_id=actor;
    if not found then raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
  else
    -- One owner lock precedes a request row lock. A concurrent duplicate request
    -- or cancellation is linearized without a second erasure case.
    perform pg_advisory_xact_lock(hashtextextended('mobio.privacy:'||actor::text,0));
    select * into r from mobio_private.privacy_requests where request_id=p_request_id and owner_id=actor for update;
    if p_action='cancel' then
      if not found then raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
      if r.status<>'cancelled' then
        if r.started_at is not null or r.status not in ('requested','blocked') then
          raise exception 'PRIVACY_NOT_CANCELLABLE' using errcode='P0001'; end if;
        update mobio_private.privacy_requests set status='cancelled',revision=revision+1,updated_at=stamp
          where request_id=p_request_id returning * into r;
        insert into mobio_private.privacy_actions(request_id,action,actor_reference,resulting_revision)
          values(r.request_id,'cancel','subject',r.revision);
      end if;
    else
      if p_confirmed is distinct from true or p_notice_version is null or
        p_notice_version !~ '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$' then
        raise exception 'INVALID_PRIVACY_CONFIRMATION' using errcode='22023'; end if;
      if found then
        if r.notice_version<>p_notice_version then raise exception 'PRIVACY_REQUEST_CONFLICT' using errcode='P0001'; end if;
        -- A committed retry stays observable after a policy change/disablement.
      else
        if exists(select 1 from mobio_private.privacy_requests where request_id=p_request_id) then
          raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
        select * into strict policy from mobio_private.privacy_policy where singleton for share;
        if not policy.intake_enabled then raise exception 'PRIVACY_INTAKE_DISABLED' using errcode='P0001'; end if;
        if policy.notice_version is distinct from p_notice_version then raise exception 'PRIVACY_POLICY_CHANGED' using errcode='P0001'; end if;
        sid:=nullif(auth.jwt()->>'session_id','')::uuid;
        if not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=actor
          and s.created_at between stamp-make_interval(secs=>policy.reauth_seconds) and stamp
          and (s.not_after is null or s.not_after>stamp)) then
          raise exception 'PRIVACY_REAUTHENTICATION_REQUIRED' using errcode='42501'; end if;
        if exists(select 1 from mobio_private.privacy_requests where owner_id=actor
          and status not in ('completed','completed_with_retention','cancelled')) then
          raise exception 'PRIVACY_ACTIVE_REQUEST_EXISTS' using errcode='P0001'; end if;
        if (select count(*) from mobio_private.privacy_requests where owner_id=actor
          and requested_at>stamp-interval '24 hours')>=policy.max_requests_per_day then
          raise exception 'PRIVACY_RATE_LIMITED' using errcode='P0001'; end if;
        insert into mobio_private.privacy_requests(request_id,owner_id,originating_session_id,notice_version)
          values(p_request_id,actor,sid,p_notice_version) returning * into r;
        insert into mobio_private.privacy_actions(request_id,action,actor_reference,resulting_revision)
          values(r.request_id,'request','subject',r.revision);
      end if;
    end if;
  end if;
  return jsonb_build_object('protocol','mobio.privacy.v1','owner_id',actor,'request',mobio_private.privacy_request_view(r));
end $$;
revoke all on function public.rpc_privacy_user(text,uuid,text,boolean) from public,anon,service_role;
grant execute on function public.rpc_privacy_user(text,uuid,text,boolean) to authenticated;

-- Explicit service-owned enablement; no manufactured legal approvals or periods.
create function public.rpc_privacy_configure(p_intake_enabled boolean,p_processing_enabled boolean,
  p_notice_version text,p_inventory_sha256 text,p_approval_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_approval_reference is null or p_approval_reference !~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$' then
    raise exception 'APPROVAL_REFERENCE_REQUIRED' using errcode='22023'; end if;
  update mobio_private.privacy_policy set intake_enabled=p_intake_enabled,processing_enabled=p_processing_enabled,
    notice_version=p_notice_version,inventory_sha256=p_inventory_sha256,approval_reference=p_approval_reference,changed_at=clock_timestamp()
    where singleton;
  insert into mobio_private.privacy_actions(action,actor_reference)
    values('configure',p_approval_reference);
  return jsonb_build_object('intake_enabled',p_intake_enabled,'processing_enabled',p_processing_enabled);
end $$;
revoke all on function public.rpc_privacy_configure(boolean,boolean,text,text,text) from public,anon,authenticated;
grant execute on function public.rpc_privacy_configure(boolean,boolean,text,text,text) to service_role;

-- Fulfilment records evidence of separately executed erasure. This function DOES
-- NOT perform erasure and never claims that a case record caused provider deletion.
-- Each action has immutable idempotency identity and a compare-and-swap revision.
create function public.rpc_privacy_fulfil(p_request_id uuid,p_action_id uuid,p_expected_revision integer,
  p_action text,p_payload jsonb,p_actor_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  r mobio_private.privacy_requests%rowtype; policy mobio_private.privacy_policy%rowtype;
  prior mobio_private.privacy_actions%rowtype; input_hash text; stamp timestamptz:=clock_timestamp();
  category text; outcome text; retain_until timestamptz; basis text;
  required text[]:=array['sessions','auth','profile_and_activity','financial_records','delivery_journals','storage','face_vectors','processors','backups','privacy_case_records'];
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_request_id is null or p_action_id is null or p_expected_revision is null or p_expected_revision<0 or
    p_action is null or p_action not in ('start','block','evidence','complete') or jsonb_typeof(p_payload) is distinct from 'object' or
    p_actor_reference is null or p_actor_reference !~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$' then
    raise exception 'INVALID_PRIVACY_FULFILMENT' using errcode='22023'; end if;
  input_hash:=encode(sha256(convert_to(jsonb_build_object('request',p_request_id,'revision',p_expected_revision,
    'action',p_action,'payload',p_payload,'actor',p_actor_reference)::text,'UTF8')),'hex');
  -- Global action identity is locked before its target to reject cross-case reuse.
  perform pg_advisory_xact_lock(hashtextextended('mobio.privacy.action:'||p_action_id::text,0));
  select * into prior from mobio_private.privacy_actions where action_id=p_action_id;
  if found then
    if prior.input_sha256 is distinct from input_hash then raise exception 'PRIVACY_ACTION_CONFLICT' using errcode='22023'; end if;
    select * into strict r from mobio_private.privacy_requests where request_id=p_request_id;
    return jsonb_build_object('replayed',true,'applied_revision',prior.resulting_revision,'request',mobio_private.privacy_request_view(r));
  end if;
  select * into r from mobio_private.privacy_requests where request_id=p_request_id for update;
  if not found then raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
  if r.revision<>p_expected_revision then raise exception 'PRIVACY_REVISION_CONFLICT' using errcode='P0001'; end if;
  if r.status in ('cancelled','completed','completed_with_retention') then raise exception 'PRIVACY_CASE_CLOSED' using errcode='P0001'; end if;
  select * into strict policy from mobio_private.privacy_policy where singleton for share;
  if p_action='block' then
    if p_payload-array['code']<>'{}'::jsonb or p_payload->>'code' is null or p_payload->>'code' not in
      ('inventory_incomplete','provider_unavailable','retention_review','identity_review','execution_failed') then
      raise exception 'INVALID_BLOCK_CODE' using errcode='22023'; end if;
    r.status:='blocked'; r.blocked_code:=p_payload->>'code';
  else
    if not policy.processing_enabled then raise exception 'PRIVACY_PROCESSING_DISABLED' using errcode='P0001'; end if;
    if p_action='start' then
      if p_payload-array['plan_sha256','inventory_sha256']<>'{}'::jsonb or p_payload->>'plan_sha256' is null or
        p_payload->>'plan_sha256' !~ '^[0-9a-f]{64}$' or
        p_payload->>'inventory_sha256' is distinct from policy.inventory_sha256 then
        raise exception 'PRIVACY_APPROVED_PLAN_REQUIRED' using errcode='22023'; end if;
      if r.plan_sha256 is not null and (r.plan_sha256<>p_payload->>'plan_sha256' or r.inventory_sha256<>policy.inventory_sha256) then
        raise exception 'PRIVACY_PLAN_CONFLICT' using errcode='22023'; end if;
      r.status:='processing';r.started_at:=coalesce(r.started_at,stamp);r.plan_sha256:=p_payload->>'plan_sha256';
      r.inventory_sha256:=policy.inventory_sha256;r.blocked_code:=null;
    elsif p_action='evidence' then
      if r.status<>'processing' then raise exception 'PRIVACY_NOT_PROCESSING' using errcode='P0001'; end if;
      if p_payload-array['category','outcome','evidence_sha256','retention_until','basis_reference']<>'{}'::jsonb then
        raise exception 'INVALID_PRIVACY_EVIDENCE' using errcode='22023'; end if;
      category:=p_payload->>'category';outcome:=p_payload->>'outcome';
      if category is null or not(category=any(required)) or outcome is null or outcome not in ('deleted','retained','not_applicable') or
        p_payload->>'evidence_sha256' is null or p_payload->>'evidence_sha256' !~ '^[0-9a-f]{64}$' then
        raise exception 'INVALID_PRIVACY_EVIDENCE' using errcode='22023'; end if;
      retain_until:=null; basis:=null;
      if outcome='retained' then
        if category in ('auth','sessions') or p_payload->>'retention_until' is null or
          p_payload->>'retention_until' !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' then
          raise exception 'INVALID_RETENTION_EXCEPTION' using errcode='22023'; end if;
        retain_until:=(p_payload->>'retention_until')::timestamptz;basis:=p_payload->>'basis_reference';
        if not isfinite(retain_until) or retain_until<=stamp or basis is null or basis !~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$' then
          raise exception 'INVALID_RETENTION_EXCEPTION' using errcode='22023'; end if;
      elsif p_payload->>'retention_until' is not null or p_payload->>'basis_reference' is not null then
        raise exception 'UNEXPECTED_RETENTION_EXCEPTION' using errcode='22023';
      end if;
      if category in ('auth','sessions') and outcome<>'deleted' then raise exception 'AUTH_ERASURE_REQUIRED' using errcode='22023'; end if;
      if category='privacy_case_records' and outcome<>'retained' then
        raise exception 'PRIVACY_CASE_RETENTION_REQUIRED' using errcode='22023'; end if;
      -- Corrections append a revision without destroying prior attestations.
      insert into mobio_private.privacy_evidence(request_id,category,outcome,evidence_sha256,retention_until,basis_reference,request_revision)
        values(r.request_id,category,outcome,p_payload->>'evidence_sha256',retain_until,basis,r.revision+1);
    else
      if r.status<>'processing' or p_payload-array['manifest_sha256']<>'{}'::jsonb or
        p_payload->>'manifest_sha256' is null or p_payload->>'manifest_sha256' !~ '^[0-9a-f]{64}$' then
        raise exception 'PRIVACY_COMPLETION_MANIFEST_REQUIRED' using errcode='22023'; end if;
      if exists(select 1 from unnest(required) c where not exists(select 1 from mobio_private.privacy_current_evidence(r.request_id) e
        where e.category=c)) then raise exception 'PRIVACY_EVIDENCE_INCOMPLETE' using errcode='P0001'; end if;
      -- Live probes are independent of caller attestations for Auth/session state.
      if exists(select 1 from auth.users where id=r.owner_id) or exists(select 1 from auth.sessions where user_id=r.owner_id) then
        raise exception 'PRIVACY_AUTH_STILL_PRESENT' using errcode='P0001'; end if;
      if exists(select 1 from mobio_private.privacy_current_evidence(r.request_id) where outcome='retained' and retention_until<=stamp) then
        raise exception 'PRIVACY_RETENTION_REVIEW_DUE' using errcode='P0001'; end if;
      -- This implementation retains identifiable case/audit records. Their
      -- mandatory exception prevents a false claim that no personal data remains.
      r.status:=case when exists(select 1 from mobio_private.privacy_current_evidence(r.request_id) where outcome='retained')
        then 'completed_with_retention' else 'completed' end;
      r.completed_at:=stamp;r.completion_manifest_sha256:=p_payload->>'manifest_sha256';
    end if;
  end if;
  update mobio_private.privacy_requests set status=r.status,started_at=r.started_at,completed_at=r.completed_at,
    plan_sha256=r.plan_sha256,inventory_sha256=r.inventory_sha256,completion_manifest_sha256=r.completion_manifest_sha256,
    blocked_code=r.blocked_code,revision=revision+1,updated_at=stamp
    where request_id=r.request_id returning * into r;
  insert into mobio_private.privacy_actions(request_id,action_id,action,actor_reference,input_sha256,resulting_revision)
    values(r.request_id,p_action_id,p_action,p_actor_reference,input_hash,r.revision);
  return jsonb_build_object('replayed',false,'applied_revision',r.revision,'request',mobio_private.privacy_request_view(r));
end $$;
revoke all on function public.rpc_privacy_fulfil(uuid,uuid,integer,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.rpc_privacy_fulfil(uuid,uuid,integer,text,jsonb,text) to service_role;

-- Bounded service queue. The admin UI intentionally shows aggregates, not subject IDs.
create function public.rpc_privacy_worklist(p_after_time timestamptz default null,p_after_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if (p_after_time is null)<>(p_after_id is null) then raise exception 'INVALID_CURSOR' using errcode='22023'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.requested_at,x.request_id),'[]'::jsonb) into result
    from (select request_id,owner_id,status,revision,notice_version,requested_at,started_at,plan_sha256,inventory_sha256
      from mobio_private.privacy_requests where status in ('requested','processing','blocked') and
      (p_after_time is null or (requested_at,request_id)>(p_after_time,p_after_id))
      order by requested_at,request_id limit 50) x;
  return result;
end $$;
revoke all on function public.rpc_privacy_worklist(timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.rpc_privacy_worklist(timestamptz,uuid) to service_role;

create function public.rpc_privacy_health()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare policy mobio_private.privacy_policy%rowtype; counts jsonb;
begin
  if not public._mobio_is_service_role() and public.verified_admin_user_id() is null then
    raise exception 'ADMIN_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  select * into strict policy from mobio_private.privacy_policy where singleton;
  select coalesce(jsonb_object_agg(x.status,x.n),'{}'::jsonb) into counts from
    (select status,count(*) n from mobio_private.privacy_requests group by status) x;
  return jsonb_build_object('protocol','mobio.privacy.health.v1','intake_enabled',policy.intake_enabled,
    'processing_enabled',policy.processing_enabled,'counts',counts,
    'oldest_pending_seconds',coalesce((select greatest(0,extract(epoch from (statement_timestamp()-min(requested_at))))::bigint
      from mobio_private.privacy_requests where status in ('requested','processing','blocked')),0),
    'retention_reviews_due',(select count(*) from (select distinct on(request_id,category) outcome,retention_until
      from mobio_private.privacy_evidence order by request_id,category,request_revision desc) current_evidence
      where outcome='retained' and retention_until<=statement_timestamp()),
    'automatic_erasure_implemented',false);
end $$;
revoke all on function public.rpc_privacy_health() from public,anon;
grant execute on function public.rpc_privacy_health() to authenticated,service_role;
notify pgrst,'reload schema';
commit;
