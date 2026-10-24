-- Privacy-case-bound Auth UUID authority fencing.
-- Service-only immutable activation receipts; guards ordinary admission and
-- materialization. No erasure executor, automation enablement or provider call.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path='';

do $dependencies$
begin
  if to_regclass('mobio_private.privacy_requests') is null
    or to_regclass('mobio_private.privacy_actions') is null
    or to_regprocedure('mobio_private.verified_interactive_account_is_eligible(uuid)') is null
    or to_regprocedure('mobio_private.require_verified_interactive_session(uuid,uuid,boolean)') is null
    or to_regprocedure('public.rpc_admin_role_execute(uuid,uuid)') is null
    or to_regprocedure('public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)') is null then
    raise exception 'PRIVACY_AUTHORITY_FENCE_PREREQUISITES_REQUIRED';
  end if;
end $dependencies$;

-- This minimal deny record intentionally has NO Auth/profile/session FK. The
-- existing privacy case/action ledger is its provenance; neither is cascaded.
-- No retention period/lifting power is invented. That remains a policy gate.
create table mobio_private.privacy_subject_authority_fences (
  subject_user_id uuid primary key,
  request_id uuid not null unique references mobio_private.privacy_requests(request_id),
  action_id uuid not null unique references mobio_private.privacy_actions(action_id),
  source_revision integer not null check(source_revision>=0),
  applied_revision integer not null check(applied_revision=source_revision+1),
  plan_sha256 text not null check(plan_sha256 ~ '^[0-9a-f]{64}$'),
  inventory_sha256 text not null check(inventory_sha256 ~ '^[0-9a-f]{64}$'),
  input_sha256 text not null check(input_sha256 ~ '^[0-9a-f]{64}$'),
  privacy_event_id uuid not null unique references mobio_private.privacy_actions(event_id),
  activated_at timestamptz not null,
  receipt jsonb not null check(jsonb_typeof(receipt)='object')
);
alter table mobio_private.privacy_subject_authority_fences enable row level security;
revoke all on mobio_private.privacy_subject_authority_fences from public,anon,authenticated,service_role;

create function mobio_private.privacy_subject_fence_is_active(p_subject uuid)
returns boolean language sql volatile security definer set search_path='' as $$
  select exists(select 1 from mobio_private.privacy_subject_authority_fences where subject_user_id=p_subject)
$$;
revoke all on function mobio_private.privacy_subject_fence_is_active(uuid)
  from public,anon,authenticated,service_role;

-- Mutating/locked paths only. Pure eligibility/RLS uses the boolean above.
-- Activation never requests an Auth/profile/resource row lock, so a trigger
-- entered after a row lock cannot form an inverse row-lock wait with it.
create function mobio_private.lock_privacy_subject(p_subject uuid,p_exclusive boolean)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  if p_subject is null or p_exclusive is null then
    raise exception 'INVALID_PRIVACY_SUBJECT_LOCK' using errcode='42501'; end if;
  if p_exclusive then
    perform pg_advisory_xact_lock(hashtextextended('mobio.privacy.subject:'||p_subject::text,0));
  else
    perform pg_advisory_xact_lock_shared(hashtextextended('mobio.privacy.subject:'||p_subject::text,0));
  end if;
end $$;
revoke all on function mobio_private.lock_privacy_subject(uuid,boolean)
  from public,anon,authenticated,service_role;

create function mobio_private.require_subject_authority_unfenced(p_subject uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  if p_subject is null then
    raise exception 'SUBJECT_AUTHORITY_FENCED' using errcode='42501';
  end if;
  perform mobio_private.lock_privacy_subject(p_subject,false);
  if mobio_private.privacy_subject_fence_is_active(p_subject) then
    raise exception 'SUBJECT_AUTHORITY_FENCED' using errcode='42501';
  end if;
end $$;
revoke all on function mobio_private.require_subject_authority_unfenced(uuid)
  from public,anon,authenticated,service_role;

create function mobio_private.guard_subject_authority_materialization()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare subject uuid; previous_subject uuid;
begin
  subject:=(to_jsonb(new)->>tg_argv[0])::uuid;
  if tg_op='UPDATE' then
    previous_subject:=(to_jsonb(old)->>tg_argv[0])::uuid;
    if previous_subject is distinct from subject then
      perform mobio_private.require_subject_authority_unfenced(previous_subject);
    end if;
  end if;
  -- Revocation updates may reduce authority after the fence. They cannot revive
  -- proof/lease rows. Auth/profile writes have no such maintenance exemption.
  if tg_nargs=2 and (to_jsonb(new)->>tg_argv[1]) is not null then return new; end if;
  perform mobio_private.require_subject_authority_unfenced(subject);
  return new;
end $$;
revoke all on function mobio_private.guard_subject_authority_materialization()
  from public,anon,authenticated,service_role;

create trigger privacy_authority_materialization before insert or update on auth.users
  for each row execute function mobio_private.guard_subject_authority_materialization('id');
create trigger privacy_authority_materialization before insert or update on public.profiles
  for each row execute function mobio_private.guard_subject_authority_materialization('id');
create trigger privacy_authority_materialization before insert or update on auth.sessions
  for each row execute function mobio_private.guard_subject_authority_materialization('user_id');
create trigger privacy_authority_materialization before insert or update on mobio_private.whatsapp_identity_bindings
  for each row execute function mobio_private.guard_subject_authority_materialization('user_id');
create trigger privacy_authority_materialization before insert or update on mobio_private.consumer_session_proofs
  for each row execute function mobio_private.guard_subject_authority_materialization('user_id','revoked_at');
create trigger privacy_authority_materialization before insert or update on mobio_private.admin_session_leases
  for each row execute function mobio_private.guard_subject_authority_materialization('user_id','revoked_at');

create function mobio_private.guard_immutable_privacy_subject_fence()
returns trigger language plpgsql security definer set search_path='' as $$
begin raise exception 'PRIVACY_AUTHORITY_FENCE_IMMUTABLE' using errcode='42501'; end $$;
revoke all on function mobio_private.guard_immutable_privacy_subject_fence()
  from public,anon,authenticated,service_role;
create trigger immutable_privacy_subject_fence before update or delete
  on mobio_private.privacy_subject_authority_fences for each row
  execute function mobio_private.guard_immutable_privacy_subject_fence();

create function public.rpc_privacy_activate_subject_fence(
  p_request_id uuid,p_action_id uuid,p_expected_revision integer,
  p_plan_sha256 text,p_inventory_sha256 text,p_actor_reference text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare r mobio_private.privacy_requests%rowtype;
  policy mobio_private.privacy_policy%rowtype;
  prior mobio_private.privacy_actions%rowtype;
  fence mobio_private.privacy_subject_authority_fences%rowtype;
  input_hash text; event uuid; stamp timestamptz; immutable_receipt jsonb;
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  if p_request_id is null or p_action_id is null or p_expected_revision is null
    or p_expected_revision<0 or p_expected_revision=2147483647
    or p_plan_sha256 is null or p_plan_sha256 !~ '^[0-9a-f]{64}$'
    or p_inventory_sha256 is null or p_inventory_sha256 !~ '^[0-9a-f]{64}$'
    or p_actor_reference is null or p_actor_reference !~ '^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$' then
    raise exception 'INVALID_PRIVACY_FENCE_ARGUMENTS' using errcode='22023'; end if;
  input_hash:=encode(sha256(convert_to(jsonb_build_object('request',p_request_id,'revision',p_expected_revision,
    'action','authority_fence','plan_sha256',p_plan_sha256,'inventory_sha256',p_inventory_sha256,
    'actor',p_actor_reference)::text,'UTF8')),'hex');
  -- Existing global action namespace remains first for service mutations.
  perform pg_advisory_xact_lock(hashtextextended('mobio.privacy.action:'||p_action_id::text,0));
  select * into prior from mobio_private.privacy_actions where action_id=p_action_id;
  if found then
    if prior.action<>'authority_fence' or prior.request_id is distinct from p_request_id
      or prior.input_sha256 is distinct from input_hash then
      raise exception 'PRIVACY_ACTION_CONFLICT' using errcode='22023'; end if;
    select * into fence from mobio_private.privacy_subject_authority_fences
      where action_id=p_action_id and request_id=p_request_id;
    if not found or fence.input_sha256<>input_hash or fence.privacy_event_id<>prior.event_id then
      raise exception 'PRIVACY_FENCE_RECEIPT_UNAVAILABLE' using errcode='55000'; end if;
    return jsonb_build_object('replayed',true,'receipt',fence.receipt);
  end if;
  -- Optimistic case-derived owner only; NO case row lock before subject X.
  select * into r from mobio_private.privacy_requests where request_id=p_request_id;
  if not found then raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
  perform mobio_private.lock_privacy_subject(r.owner_id,true);
  perform pg_advisory_xact_lock(hashtextextended('mobio.privacy:'||r.owner_id::text,0));
  -- Revalidate the same owner under the case lock. A changed/missing case does
  -- not move activation to a different subject after its lock was selected.
  select * into r from mobio_private.privacy_requests
    where request_id=p_request_id and owner_id=r.owner_id for update;
  if not found then raise exception 'PRIVACY_REQUEST_NOT_FOUND' using errcode='P0001'; end if;
  if r.revision<>p_expected_revision then raise exception 'PRIVACY_REVISION_CONFLICT' using errcode='P0001'; end if;
  if r.status<>'processing' or r.started_at is null then
    raise exception 'PRIVACY_NOT_PROCESSING' using errcode='P0001'; end if;
  -- Subject -> owner -> case -> policy is shared by mutating owner/fulfil paths.
  select * into strict policy from mobio_private.privacy_policy where singleton for share;
  if not policy.processing_enabled then raise exception 'PRIVACY_PROCESSING_DISABLED' using errcode='P0001'; end if;
  if r.plan_sha256 is distinct from p_plan_sha256 or r.inventory_sha256 is distinct from p_inventory_sha256
    or policy.inventory_sha256 is distinct from p_inventory_sha256 then
    raise exception 'PRIVACY_APPROVED_PLAN_REQUIRED' using errcode='22023'; end if;
  -- Subject comes solely from the locked existing case. No Auth/profile rows are
  -- locked/read/deleted; missing Auth rows cannot remove this technical denial.
  -- Retention/lifting remains subject to a separately approved future policy.
  if exists(select 1 from mobio_private.privacy_subject_authority_fences where subject_user_id=r.owner_id) then
    raise exception 'PRIVACY_SUBJECT_ALREADY_FENCED' using errcode='P0001'; end if;
  stamp:=clock_timestamp();
  update mobio_private.privacy_requests set revision=revision+1,updated_at=stamp
    where request_id=r.request_id returning * into r;
  insert into mobio_private.privacy_actions(request_id,action_id,action,actor_reference,input_sha256,resulting_revision,happened_at)
    values(r.request_id,p_action_id,'authority_fence',p_actor_reference,input_hash,r.revision,stamp)
    returning event_id into event;
  immutable_receipt:=jsonb_build_object('protocol','mobio.privacy-authority-fence.v1','request_id',r.request_id,
    'subject_user_id',r.owner_id,'action_id',p_action_id,'source_revision',p_expected_revision,'applied_revision',r.revision,
    'plan_sha256',r.plan_sha256,'inventory_sha256',r.inventory_sha256,'input_sha256',input_hash,
    'privacy_event_id',event,'activated_at',stamp);
  insert into mobio_private.privacy_subject_authority_fences(subject_user_id,request_id,action_id,source_revision,
    applied_revision,plan_sha256,inventory_sha256,input_sha256,privacy_event_id,activated_at,receipt)
    values(r.owner_id,r.request_id,p_action_id,p_expected_revision,r.revision,r.plan_sha256,r.inventory_sha256,
      input_hash,event,stamp,immutable_receipt);
  return jsonb_build_object('replayed',false,'receipt',immutable_receipt);
end $$;
revoke all on function public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)
  from public,anon,authenticated;
grant execute on function public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text) to service_role;

-- Preserve installed owners, ACLs, defaults, signatures and wire errors. Require
-- exactly one understood anchor per change; unknown catalogue state aborts.
do $authority_guards$
declare path record; routine record; previous text; replacement text;
begin
  for path in select * from (values
    ('mobio_private.verified_interactive_account_is_eligible(uuid)',
      E'begin\n  select * into account from auth.users where id=p_user_id;',
      E'begin\n  if mobio_private.privacy_subject_fence_is_active(p_user_id) then return false; end if;\n  select * into account from auth.users where id=p_user_id;'),
    ('mobio_private.require_verified_interactive_session(uuid,uuid,boolean)',
      '  perform 1 from auth.users where id=p_user_id for share;',
      E'  begin\n    perform mobio_private.require_subject_authority_unfenced(p_user_id);\n  exception when insufficient_privilege then\n    raise exception ''INTERACTIVE_SESSION_REQUIRED'' using errcode=''42501'';\n  end;\n  perform 1 from auth.users where id=p_user_id for share;'),
    ('mobio_private.bind_whatsapp_otp_account(uuid,text,text)',
      '  select * into account from auth.users where id=p_user_id for share;',
      E'  begin\n    perform mobio_private.require_subject_authority_unfenced(p_user_id);\n  exception when insufficient_privilege then\n    raise exception ''WHATSAPP_BINDING_REJECTED'' using errcode=''42501'';\n  end;\n  select * into account from auth.users where id=p_user_id for share;'),
    ('public.rpc_lookup_whatsapp_otp_phone_owner(text,text,text)',
      '  select * into strict candidate from auth.users where phone in(p_phone,substring(p_phone from 2)) for share;',
      E'  select id into candidate.id from auth.users where phone in(p_phone,substring(p_phone from 2));\n  begin\n    perform mobio_private.require_subject_authority_unfenced(candidate.id);\n  exception when insufficient_privilege then\n    raise exception ''PHONE_IDENTITY_UNAVAILABLE'' using errcode=''42501'';\n  end;\n  select * into candidate from auth.users where id=candidate.id and phone in(p_phone,substring(p_phone from 2)) for share;\n  if not found then raise exception ''PHONE_IDENTITY_UNAVAILABLE'' using errcode=''42501''; end if;'),
    ('public._mobio_verified_phone_owner(text)',
      '  return candidate.id;',
      E'  begin\n    perform mobio_private.require_subject_authority_unfenced(candidate.id);\n  exception when insufficient_privilege then\n    raise exception ''PHONE_IDENTITY_UNAVAILABLE'' using errcode=''42501'';\n  end;\n  return candidate.id;'),
    ('public.require_recent_admin_session()',
      E'begin\n  if actor is null or not public.admin_session_is_recent() then',
      E'begin\n  if actor is not null then\n    begin\n      perform mobio_private.require_subject_authority_unfenced(actor);\n    exception when insufficient_privilege then\n      raise exception ''INTERACTIVE_SESSION_REQUIRED'' using errcode=''42501'';\n    end;\n  elsif mobio_private.privacy_subject_fence_is_active(public.live_auth_user_id()) then\n    raise exception ''INTERACTIVE_SESSION_REQUIRED'' using errcode=''42501'';\n  end if;\n  if actor is null or not public.admin_session_is_recent() then'),
    ('public.rpc_privacy_user(text,uuid,text,boolean)',
      E'    perform pg_advisory_xact_lock(hashtextextended(''mobio.privacy:''||actor::text,0));',
      E'    perform mobio_private.require_verified_interactive_session(actor,(auth.jwt()->>''session_id'')::uuid,false);\n    perform pg_advisory_xact_lock(hashtextextended(''mobio.privacy:''||actor::text,0));'),
    ('public.rpc_privacy_fulfil(uuid,uuid,integer,text,jsonb,text)',
      '  select * into r from mobio_private.privacy_requests where request_id=p_request_id for update;',
      E'  select * into r from mobio_private.privacy_requests where request_id=p_request_id;\n  if not found then raise exception ''PRIVACY_REQUEST_NOT_FOUND'' using errcode=''P0001''; end if;\n  -- Case evidence/completion remains permitted after fencing: lock without granting ordinary identity.\n  perform mobio_private.lock_privacy_subject(r.owner_id,false);\n  perform pg_advisory_xact_lock(hashtextextended(''mobio.privacy:''||r.owner_id::text,0));\n  select * into r from mobio_private.privacy_requests where request_id=p_request_id and owner_id=r.owner_id for update;'),
    ('public.rpc_push_authorize(uuid,uuid)',
      E'  if reason is not null then\n    update mobio_private.push_jobs set state=case when reason=''ttl_expired'' then ''expired'' else ''skipped'' end,',
      E'  if reason is null then\n    begin\n      perform mobio_private.require_subject_authority_unfenced(j.owner_id);\n    exception when insufficient_privilege then reason:=''binding_inactive''; end;\n  end if;\n  if reason is not null then\n    update mobio_private.push_jobs set state=case when reason=''ttl_expired'' then ''expired'' else ''skipped'' end,'),
    ('public.rpc_admin_role_execute(uuid,uuid)',
      '  select * into target from public.profiles where id=o.target_id for update;',
      E'  begin\n    perform mobio_private.require_subject_authority_unfenced(o.target_id);\n  exception when insufficient_privilege then\n    update mobio_private.admin_role_operations set status=''known_rejected'',rejection_code=''target_changed'',decided_at=clock_timestamp() where operation_id=o.operation_id;\n    return mobio_private.admin_role_envelope(actor,sid,b.reservation_id,b.batch_id);\n  end;\n  select * into target from public.profiles where id=o.target_id for update;'),
    ('public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)',
      E'    if bp.id is not null and not mobio_private.verified_interactive_account_is_eligible(bp.user_id) then\n      bp := null;\n    end if;',
      E'    if bp.id is not null then\n      begin\n        perform mobio_private.require_subject_authority_unfenced(bp.user_id);\n      exception when insufficient_privilege then bp:=null; end;\n    end if;\n    if bp.id is not null and not mobio_private.verified_interactive_account_is_eligible(bp.user_id) then\n      bp := null;\n    end if;')
  ) as entries(signature,anchor,new_body)
  loop
    select p.*,l.lanname into strict routine from pg_catalog.pg_proc p
      join pg_catalog.pg_language l on l.oid=p.prolang where p.oid=to_regprocedure(path.signature);
    if routine.lanname<>'plpgsql' or not routine.prosecdef
      or not ('search_path=""'=any(coalesce(routine.proconfig,array[]::text[])))
      or position('privacy_subject_fence_is_active' in routine.prosrc)>0
      or position('require_subject_authority_unfenced' in routine.prosrc)>0
      or (length(routine.prosrc)-length(replace(routine.prosrc,path.anchor,'')))/length(path.anchor)<>1 then
      raise exception 'Unexpected authority-fence routine contract: %',path.signature; end if;
    previous:=routine.prosrc;
    replacement:=replace(previous,path.anchor,path.new_body);
    execute replace(pg_catalog.pg_get_functiondef(routine.oid),previous,replacement);
  end loop;
end $authority_guards$;

comment on function public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text) is
  'Service-only authority fence derived from a processing privacy case. Immutable receipt replay; no erasure, legal retention approval, policy enablement, worker or provider call.';
comment on table mobio_private.privacy_subject_authority_fences is
  'Minimal case-bound Auth UUID denial surviving Auth/profile deletion. No phone ban or subject re-registration policy. Retention/lifting and case recovery remain separately approved gates.';
commit;
