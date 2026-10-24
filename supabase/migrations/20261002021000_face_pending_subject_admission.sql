-- Forward per-dispatch pending Face subject/session admission.
-- No policy enablement, provider call, vector deletion or case-ledger rewrite.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local search_path='';

do $dependencies$
begin
  if to_regprocedure('mobio_private.require_verified_interactive_session(uuid,uuid,boolean)') is null
    or to_regprocedure('mobio_private.require_subject_authority_unfenced(uuid)') is null
    or to_regclass('public.biopay_face_revisions') is null
    or to_regclass('public.biopay_provider_operations') is null then
    raise exception 'FACE_PENDING_ADMISSION_PREREQUISITES_REQUIRED';
  end if;
end $dependencies$;

create function public.rpc_biopay_face_pending_admission(p_vector_id text,p_operation_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' set lock_timeout='4s' as $$
declare subject uuid; sid uuid; bp public.biopay_profiles%rowtype;
  rv public.biopay_face_revisions%rowtype; op public.biopay_provider_operations%rowtype;
  stamp timestamptz; denied jsonb;
begin
  -- Service transport is checked before parsing any target. No subject/SID is
  -- supplied by the worker: derive them from the existing immutable operation.
  if coalesce(auth.role(),'')<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_vector_id is null or p_vector_id !~ '^f_[0-9a-f]{32}$' or p_operation_id is null then
    raise exception 'INVALID_FACE_PENDING_ADMISSION' using errcode='22023';
  end if;
  denied:=jsonb_build_object('protocol','mobio.face-pending-admission.v1','admitted',false,
    'code','PENDING_UNAVAILABLE','server_now',clock_timestamp());
  select r.owner_id,o.auth_session_id into subject,sid
    from public.biopay_face_revisions r join public.biopay_provider_operations o on o.id=r.operation_id
    where r.vector_id=p_vector_id and r.operation_id=p_operation_id and o.user_id=r.owner_id;
  if not found then return denied; end if;
  -- The canonical locked helper now takes subject S BEFORE any Auth row lock.
  -- Fence/identity/SID/purpose and Admin freshness must hold before provider use.
  begin
    perform mobio_private.require_verified_interactive_session(subject,sid,true);
  exception when insufficient_privilege then return denied;
  end;
  perform pg_advisory_xact_lock(hashtextextended('face:'||subject::text,0));
  select * into bp from public.biopay_profiles where user_id=subject for share;
  if not found then return denied; end if;
  select * into op from public.biopay_provider_operations
    where id=p_operation_id and user_id=subject and auth_session_id=sid for share;
  if not found then return denied; end if;
  select * into rv from public.biopay_face_revisions
    where vector_id=p_vector_id and operation_id=op.id and owner_id=subject for share;
  if not found then return denied; end if;
  stamp:=clock_timestamp();
  if rv.state<>'pending' or rv.expires_at<=stamp or op.expires_at<=stamp
    or op.action<>'enroll' or op.state<>'processing' or op.consumed_at is not null
    or rv.vector_id<>'f_'||replace(op.id::text,'-','')
    or rv.model_version<>'yunet2023mar-sface2021dec-opencv4.11-v1'
    or rv.consent_version<>'face-discovery-v1' or rv.consent_at is null
    or bp.pending_vector_id is distinct from rv.vector_id or bp.status not in('processing','active')
    or rv.revision<=bp.face_revision then return denied; end if;
  perform 1 from public.biopay_payment_methods where id=bp.receiving_method_id
    and owner_id=subject and active and can_receive and kind='mobileWallet' for share;
  if not found then return denied; end if;
  -- Enrollment retains the existing disabled-recognition policy semantics. The
  -- current model row must exist; this check never enables recognition policy.
  perform 1 from public.biopay_face_policy where model_version=rv.model_version for share;
  if not found then return denied; end if;
  -- Lock waits may cross an expiry. The same exact session is checked again and
  -- both operation deadlines use current database time, not transaction start.
  begin
    perform mobio_private.require_verified_interactive_session(subject,sid,true);
  exception when insufficient_privilege then return denied;
  end;
  stamp:=clock_timestamp();
  if least(rv.expires_at,op.expires_at)<=stamp then return denied; end if;
  return jsonb_build_object('protocol','mobio.face-pending-admission.v1','admitted',true,
    'user_id',subject,'session_id',sid,'vector_id',rv.vector_id,'operation_id',op.id,
    'revision',rv.revision,'model_version',rv.model_version,'server_now',stamp,
    'expires_at',least(rv.expires_at,op.expires_at));
end $$;
revoke all on function public.rpc_biopay_face_pending_admission(text,uuid) from public,anon,authenticated;
grant execute on function public.rpc_biopay_face_pending_admission(text,uuid) to service_role;
comment on function public.rpc_biopay_face_pending_admission(text,uuid) is
  'Service-only current exact pending vector/operation/session admission before provider searchable. Per-dispatch check; no remote fence/retraction, mutation, cleanup or case-evidence authority.';
commit;
