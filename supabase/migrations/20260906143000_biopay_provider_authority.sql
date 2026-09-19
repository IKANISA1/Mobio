-- Provider results are server authority. Legacy client assertions are never
-- backfilled as verified. A legacy identity is reverified on an actual capture.
alter table public.biopay_profiles add column if not exists server_verified_at timestamptz
;

create unique index if not exists biopay_verified_provider_subject_uidx
  on public.biopay_profiles(provider_collection_id, provider_subject_id)
  where server_verified_at is not null
;

revoke insert, update, delete on public.biopay_profiles from anon, authenticated
;

grant select on public.biopay_profiles to service_role
;

create table public.biopay_provider_operations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  auth_session_id uuid not null,
  action text not null check (action in ('create_liveness_session','get_liveness_result','enroll_face','match_face')),
  state text not null default 'reserved' check (state in ('reserved','session_ready','enrolled','matched')),
  provider_session_id text unique,
  provider_face_id text,
  provider_collection_id text,
  confidence numeric check (confidence between 0 and 1),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '3 minutes',
  consumed_at timestamptz,
  payment_request_id uuid references public.biopay_payment_requests(id)
)
;

create index biopay_provider_operations_rate_idx
  on public.biopay_provider_operations(user_id, action, created_at)
;

alter table public.biopay_provider_operations enable row level security
;

revoke all on public.biopay_provider_operations from public, anon, authenticated
;

grant all on public.biopay_provider_operations to service_role
;

create function public.rpc_reserve_biopay_provider_operation(p_user_id uuid, p_action text, p_auth_session_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_limit integer; v_window interval;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if not exists (select 1 from auth.users u where u.id=p_user_id
    and not coalesce(u.is_anonymous,false) and u.phone_confirmed_at is not null
    and u.raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp','admin_whatsapp_otp')) then
    raise exception 'VERIFIED_USER_REQUIRED';
  end if;
  if not exists(select 1 from auth.sessions where id=p_auth_session_id and user_id=p_user_id
    and (not_after is null or not_after>now())) then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  if p_action not in ('create_liveness_session','get_liveness_result','enroll_face','match_face') then
    raise exception 'UNSUPPORTED_PROVIDER_ACTION';
  end if;
  v_limit := case when p_action in ('create_liveness_session','enroll_face') then 5 else 30 end;
  v_window := case when p_action in ('create_liveness_session','enroll_face') then interval '15 minutes' else interval '5 minutes' end;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':' || p_action, 0));
  if (select count(*) from public.biopay_provider_operations
      where user_id=p_user_id and action=p_action and created_at > now()-v_window) >= v_limit then
    raise exception 'BIOPAY_RATE_LIMIT';
  end if;
  insert into public.biopay_provider_operations(user_id,action,auth_session_id) values(p_user_id,p_action,p_auth_session_id) returning id into v_id;
  return v_id;
end $$
;

create function public.rpc_bind_biopay_liveness_session(p_operation_id uuid,p_user_id uuid,p_provider_session_id text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if nullif(trim(p_provider_session_id),'') is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  update public.biopay_provider_operations set provider_session_id=p_provider_session_id,state='session_ready'
    where id=p_operation_id and user_id=p_user_id and action='create_liveness_session'
      and state='reserved' and expires_at>now() and consumed_at is null;
  if not found then raise exception 'BIOPAY_SESSION_INVALID'; end if;
end $$
;

create function public.rpc_authorize_biopay_liveness_session(p_user_id uuid,p_provider_session_id text,p_consume boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  select id into v_id from public.biopay_provider_operations o
    where user_id=p_user_id and provider_session_id=p_provider_session_id
      and action='create_liveness_session' and state='session_ready'
      and expires_at>now() and consumed_at is null
      and exists(select 1 from auth.sessions s where s.id=o.auth_session_id and s.user_id=p_user_id
        and (s.not_after is null or s.not_after>now())) for update;
  if v_id is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  if p_consume then update public.biopay_provider_operations set consumed_at=now() where id=v_id; end if;
end $$
;

create function public.rpc_record_verified_biopay_face_enrollment(
  p_user_id uuid,p_operation_id uuid,p_provider_face_id text,p_provider_collection_id text,
  p_liveness_status text,p_quality_score numeric,p_provider_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_operation public.biopay_provider_operations; v_profile public.biopay_profiles;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if nullif(trim(p_provider_face_id),'') is null or nullif(trim(p_provider_collection_id),'') is null
    or p_liveness_status is null or p_liveness_status not in ('provider_liveness_verified','provider_liveness_not_required')
    or p_quality_score is null or p_quality_score<0 or p_quality_score>1 then
    raise exception 'INVALID_PROVIDER_RESULT';
  end if;
  select * into v_operation from public.biopay_provider_operations o where id=p_operation_id
    and user_id=p_user_id and action='enroll_face' and state='reserved'
    and consumed_at is null and expires_at>now()
    and exists(select 1 from auth.sessions s where s.id=o.auth_session_id and s.user_id=p_user_id
      and (s.not_after is null or s.not_after>now())) for update;
  if v_operation.id is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_provider_collection_id || ':' || p_provider_face_id,1));
  if exists(select 1 from public.biopay_profiles where provider_subject_id=p_provider_face_id
      and provider_collection_id=p_provider_collection_id and server_verified_at is not null and user_id<>p_user_id) then
    raise exception 'BIOPAY_DUPLICATE_IDENTITY';
  end if;
  insert into public.biopay_profiles(user_id,handle,provider,provider_subject_id,provider_collection_id,
    liveness_status,status,consent_granted_at,server_verified_at,provider_metadata)
  values(p_user_id,'bio-' || substr(replace(p_user_id::text,'-',''),1,12),'aws_rekognition',p_provider_face_id,
    p_provider_collection_id,p_liveness_status,'active',now(),now(),coalesce(p_provider_metadata,'{}'::jsonb))
  on conflict(user_id) do update set provider='aws_rekognition',provider_subject_id=excluded.provider_subject_id,
    provider_collection_id=excluded.provider_collection_id,liveness_status=excluded.liveness_status,
    status='active',consent_granted_at=now(),server_verified_at=now(),provider_metadata=excluded.provider_metadata,
    matching_paused_at=null,deleted_at=null,updated_at=now() returning * into v_profile;
  update public.biopay_provider_operations set state='enrolled',consumed_at=now(),
    provider_face_id=p_provider_face_id,provider_collection_id=p_provider_collection_id where id=p_operation_id;
  insert into public.biopay_face_sessions(user_id,purpose,provider_session_id,provider_face_id,provider_collection_id,
    liveness_status,match_status,confidence,raw_asset_deleted_at,provider_metadata)
  values(p_user_id,'enrollment',p_operation_id::text,p_provider_face_id,p_provider_collection_id,
    p_liveness_status,'matched',p_quality_score,now(),jsonb_build_object('server_verified',true));
  insert into public.biopay_audit_events(actor_user_id,action,metadata)
    values(p_user_id,'biopay.face.enrolled',jsonb_build_object('operation_id',p_operation_id,'server_verified',true));
  return jsonb_build_object('profile',to_jsonb(v_profile));
end $$
;

-- Compatibility for installed clients: acknowledge a server-committed result;
-- never insert/update a profile from caller-supplied data.
create or replace function public.rpc_record_biopay_face_enrollment(
  p_provider_session_id text default null,p_provider_face_id text default null,
  p_provider_collection_id text default null,p_liveness_status text default 'provider_liveness_not_required',
  p_quality_score numeric default null,p_provider_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_profile public.biopay_profiles;
begin
  select * into v_profile from public.biopay_profiles where user_id=auth.uid()
    and provider_subject_id=p_provider_face_id and provider_collection_id=p_provider_collection_id
    and server_verified_at is not null and status='active' and deleted_at is null;
  if v_profile.id is null then raise exception 'SERVER_VERIFIED_ENROLLMENT_REQUIRED'; end if;
  return jsonb_build_object('profile',to_jsonb(v_profile));
end $$
;

create function public.rpc_record_verified_biopay_face_match(
  p_user_id uuid,p_operation_id uuid,p_provider_face_id text,p_provider_collection_id text,p_confidence numeric
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if p_confidence is null or p_confidence<0.99 or p_confidence>1 then raise exception 'INVALID_PROVIDER_RESULT'; end if;
  if not exists(select 1 from public.biopay_profiles where provider_subject_id=p_provider_face_id
    and provider_collection_id=p_provider_collection_id and server_verified_at is not null
    and consent_granted_at is not null and status='active' and deleted_at is null) then
    raise exception 'BIOPAY_IDENTITY_UNAVAILABLE';
  end if;
  update public.biopay_provider_operations o set state='matched',provider_face_id=p_provider_face_id,
    provider_collection_id=p_provider_collection_id,confidence=p_confidence
    where id=p_operation_id and user_id=p_user_id and action='match_face' and state='reserved'
      and expires_at>now() and consumed_at is null
      and exists(select 1 from auth.sessions s where s.id=o.auth_session_id and s.user_id=p_user_id
        and (s.not_after is null or s.not_after>now()));
  if not found then raise exception 'BIOPAY_SESSION_INVALID'; end if;
end $$
;

create function public.rpc_create_verified_biopay_face_match_request(
  p_match_session_id uuid,p_amount_minor integer,p_provider_code text default 'mtn_rw'
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid(); v_operation public.biopay_provider_operations;
  v_biopay_profile public.biopay_profiles; v_payee_profile public.profiles;
  v_row public.biopay_payment_requests;
  v_reference text := 'BP-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  v_provider text := coalesce(nullif(trim(p_provider_code),''),'mtn_rw');
begin
  if v_user_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Authentication required'; end if;
  if p_amount_minor is null or p_amount_minor<=0 then raise exception 'Invalid amount'; end if;
  select * into v_operation from public.biopay_provider_operations where id=p_match_session_id
    and user_id=v_user_id and auth_session_id=(auth.jwt()->>'session_id')::uuid
    and exists(select 1 from auth.sessions s where s.id=auth_session_id and s.user_id=v_user_id and (s.not_after is null or s.not_after>now()))
    and action='match_face' and state='matched'
    and consumed_at is null and expires_at>now() for update;
  if v_operation.id is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  select * into v_biopay_profile from public.biopay_profiles
    where provider_subject_id=v_operation.provider_face_id and provider_collection_id=v_operation.provider_collection_id
      and server_verified_at is not null and consent_granted_at is not null and status='active' and deleted_at is null for update;
  if v_biopay_profile.id is null then raise exception 'BIOPAY_IDENTITY_UNAVAILABLE'; end if;
  select * into strict v_payee_profile from public.profiles where id=v_biopay_profile.user_id;
  insert into public.biopay_payment_requests(channel,payer_id,payee_id,payee_label,provider_code,amount_minor,reference,ussd_code)
  values('face',v_user_id,v_biopay_profile.user_id,
    coalesce(nullif(trim(v_payee_profile.display_name),''),nullif(trim(v_payee_profile.name),''),'BioPay merchant'),
    v_provider,p_amount_minor,v_reference,
    public.fn_biopay_ussd_code(v_provider,coalesce(v_payee_profile.phone,v_payee_profile.whatsapp),p_amount_minor,v_reference))
    returning * into v_row;
  update public.biopay_provider_operations set consumed_at=now(),payment_request_id=v_row.id where id=v_operation.id;
  insert into public.biopay_face_sessions(user_id,payment_request_id,purpose,provider_face_id,provider_collection_id,
    liveness_status,match_status,confidence,raw_asset_deleted_at,provider_metadata)
  values(v_user_id,v_row.id,'scan',v_operation.provider_face_id,v_operation.provider_collection_id,
    'provider_liveness_not_required','matched',v_operation.confidence,now(),jsonb_build_object('operation_id',v_operation.id));
  insert into public.biopay_audit_events(actor_user_id,request_id,action,metadata)
  values(v_user_id,v_row.id,'biopay.face_match.ussd_request.created',jsonb_build_object('operation_id',v_operation.id));
  return to_jsonb(v_row);
end $$
;

-- Older clients submit a face ID after provider matching. Require and consume
-- the same server-owned, unexpired proof; arbitrary face IDs alone confer nothing.
create or replace function public.rpc_create_biopay_face_match_request(
  p_provider_face_id text,p_amount_minor integer,p_provider_code text default 'mtn_rw'
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_session uuid;
begin
  select id into v_session from public.biopay_provider_operations where user_id=auth.uid()
    and provider_face_id=p_provider_face_id and action='match_face' and state='matched'
    and expires_at>now() and consumed_at is null order by created_at desc limit 1;
  if v_session is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  return public.rpc_create_verified_biopay_face_match_request(v_session,p_amount_minor,p_provider_code);
end $$
;

revoke all on function public.rpc_reserve_biopay_provider_operation(uuid,text,uuid) from public,anon,authenticated
;

revoke all on function public.rpc_bind_biopay_liveness_session(uuid,uuid,text) from public,anon,authenticated
;

revoke all on function public.rpc_authorize_biopay_liveness_session(uuid,text,boolean) from public,anon,authenticated
;

revoke all on function public.rpc_record_verified_biopay_face_enrollment(uuid,uuid,text,text,text,numeric,jsonb) from public,anon,authenticated
;

revoke all on function public.rpc_record_verified_biopay_face_match(uuid,uuid,text,text,numeric) from public,anon,authenticated
;

grant execute on function public.rpc_reserve_biopay_provider_operation(uuid,text,uuid) to service_role
;

grant execute on function public.rpc_bind_biopay_liveness_session(uuid,uuid,text) to service_role
;

grant execute on function public.rpc_authorize_biopay_liveness_session(uuid,text,boolean) to service_role
;

grant execute on function public.rpc_record_verified_biopay_face_enrollment(uuid,uuid,text,text,text,numeric,jsonb) to service_role
;

grant execute on function public.rpc_record_verified_biopay_face_match(uuid,uuid,text,text,numeric) to service_role
;

revoke all on function public.rpc_create_verified_biopay_face_match_request(uuid,integer,text) from public,anon
;

grant execute on function public.rpc_create_verified_biopay_face_match_request(uuid,integer,text) to authenticated
;

revoke all on function public.rpc_record_biopay_face_enrollment(text,text,text,text,numeric,jsonb) from public,anon
;

grant execute on function public.rpc_record_biopay_face_enrollment(text,text,text,text,numeric,jsonb) to authenticated
;

revoke all on function public.rpc_create_biopay_face_match_request(text,integer,text) from public,anon
;

grant execute on function public.rpc_create_biopay_face_match_request(text,integer,text) to authenticated
;

-- Admin readiness counts the same verified, consenting identities used by matching.
CREATE OR REPLACE FUNCTION public.rpc_admin_biopay_list_payees(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_search text := lower(nullif(trim(coalesce(p_search, '')), ''));
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_rows jsonb;
begin
  perform public.fn_biopay_require_admin();

  select coalesce(jsonb_agg(row_payload order by sort_created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select
      bp.created_at as sort_created_at,
      jsonb_build_object(
        'user_id', bp.user_id,
        'handle', bp.handle,
        'display_name', coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.name), ''), bp.handle),
        'provider', bp.provider,
        'provider_subject_id', bp.provider_subject_id,
        'provider_collection_id', bp.provider_collection_id,
        'liveness_status', bp.liveness_status,
        'status', bp.status,
        'request_count', (
          select count(*)::integer
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
        ),
        'confirmed_count', (
          select count(*)::integer
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
            and request.status = 'confirmed'
        ),
        'last_request_at', (
          select max(request.created_at)
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
        ),
        'enrolled_at', bp.consent_granted_at,
        'server_verified_at', bp.server_verified_at
      ) as row_payload
    from public.biopay_profiles bp
    left join public.profiles p on p.id = bp.user_id
    where v_search is null
       or lower(bp.handle) like '%' || v_search || '%'
       or lower(coalesce(p.display_name, '')) like '%' || v_search || '%'
       or lower(coalesce(p.name, '')) like '%' || v_search || '%'
       or lower(coalesce(bp.provider_subject_id, '')) like '%' || v_search || '%'
    order by bp.created_at desc
    limit v_limit
  ) payees;

  return coalesce(v_rows, '[]'::jsonb);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_admin_biopay_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_total_payees integer;
  v_enrolled_payees integer;
  v_total_requests integer;
  v_pending_confirmations integer;
  v_confirmed_requests integer;
  v_match_attempts integer;
  v_matched_attempts integer;
begin
  perform public.fn_biopay_require_admin();

  select count(*)::integer,
         count(*) filter (
           where provider_subject_id is not null and status = 'active' and server_verified_at is not null and consent_granted_at is not null and deleted_at is null
         )::integer
    into v_total_payees, v_enrolled_payees
  from public.biopay_profiles;

  select count(*)::integer,
         count(*) filter (where status = 'user_marked_paid')::integer,
         count(*) filter (where status = 'confirmed')::integer
    into v_total_requests, v_pending_confirmations, v_confirmed_requests
  from public.biopay_payment_requests;

  select count(*)::integer,
         count(*) filter (where match_status = 'matched')::integer
    into v_match_attempts, v_matched_attempts
  from public.biopay_face_sessions
  where purpose = 'scan';

  return jsonb_build_object(
    'total_payees', coalesce(v_total_payees, 0),
    'enrolled_payees', coalesce(v_enrolled_payees, 0),
    'total_requests', coalesce(v_total_requests, 0),
    'pending_confirmations', coalesce(v_pending_confirmations, 0),
    'confirmed_requests', coalesce(v_confirmed_requests, 0),
    'match_rate', case
      when coalesce(v_match_attempts, 0) = 0 then 0
      else round((v_matched_attempts::numeric / v_match_attempts::numeric), 4)
    end
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_admin_biopay_system_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_collection_id text;
  v_has_enrolled_face boolean;
  v_pending_confirmations integer;
  v_last_audit_at timestamptz;
begin
  perform public.fn_biopay_require_admin();

  select max(provider_collection_id),
         bool_or(provider_subject_id is not null and status = 'active' and server_verified_at is not null and consent_granted_at is not null and deleted_at is null)
    into v_collection_id, v_has_enrolled_face
  from public.biopay_profiles;

  select count(*)::integer
    into v_pending_confirmations
  from public.biopay_payment_requests
  where status = 'user_marked_paid';

  select max(created_at)
    into v_last_audit_at
  from public.biopay_audit_events;

  return jsonb_build_object(
    'overall_status', case
      when coalesce(v_has_enrolled_face, false) then 'operational'
      else 'configuration_required'
    end,
    'face_provider', 'aws_rekognition',
    'face_provider_ready', coalesce(v_has_enrolled_face, false),
    'collection_id', coalesce(v_collection_id, ''),
    'database_status', 'available',
    'ussd_handoff_status', 'external_ussd_only',
    'pending_confirmations', coalesce(v_pending_confirmations, 0),
    'last_audit_at', v_last_audit_at
  );
end;
$function$
;
