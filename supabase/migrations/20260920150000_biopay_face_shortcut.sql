-- Owner-approved single-capture face shortcut. Historical AWS records remain
-- historical; they cannot become OpenCV vectors. No monetary request is created.
begin;

alter table public.biopay_profiles
  drop constraint if exists biopay_profiles_status_check,
  add column receiving_method_id uuid references public.biopay_payment_methods(id) on delete set null,
  add column face_revision bigint not null default 0,
  add column pending_vector_id text,
  add column consent_version text,
  add constraint biopay_profiles_status_check check
    (status in ('active','paused','deleted','rejected','processing','reenrollment_required'));
update public.biopay_profiles set status='reenrollment_required', updated_at=now()
  where provider='aws_rekognition' and status not in ('deleted','rejected');
alter table public.biopay_profiles alter column provider set default 'opencv_sface_v1';

alter table public.biopay_provider_operations
  drop constraint if exists biopay_provider_operations_action_check,
  drop constraint if exists biopay_provider_operations_state_check,
  add column idempotency_key text,
  add column request_digest text,
  add column outcome text,
  add constraint biopay_provider_operations_action_check check
    (action in ('create_liveness_session','get_liveness_result','enroll_face','match_face','enroll','resolve')),
  add constraint biopay_provider_operations_state_check check
    (state in ('reserved','session_ready','enrolled','matched','processing','failed'));
create unique index biopay_face_operation_idempotency on public.biopay_provider_operations
  (user_id,auth_session_id,action,idempotency_key) where idempotency_key is not null;

create table public.biopay_face_revisions (
  vector_id text primary key,
  operation_id uuid not null unique references public.biopay_provider_operations(id),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  revision bigint not null,
  model_version text not null,
  state text not null default 'pending' check (state in ('pending','active','superseded','failed')),
  consent_version text not null,
  consent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '3 minutes',
  unique(owner_id,revision)
);
create table public.biopay_face_cleanup (
  vector_id text primary key,
  model_version text not null,
  not_before timestamptz not null default now(),
  attempts integer not null default 0,
  deleted_at timestamptz
);
-- Configuration is independent of measured acceptance. No uncalibrated default
-- threshold enables recognition; the operator supplies a versioned policy.
create table public.biopay_face_policy (
  model_version text primary key,
  dimensions integer not null check(dimensions>0),
  policy_version text not null,
  min_score double precision check(min_score between -1 and 1),
  min_margin double precision check(min_margin>0 and min_margin<=2),
  enabled boolean not null default false,
  acceptance_evidence text,
  accepted_at timestamptz,
  check(not enabled or (min_score is not null and min_margin is not null
    and acceptance_evidence ~ '^https://' and accepted_at is not null) is true)
);
insert into public.biopay_face_policy(model_version,dimensions,policy_version)
values ('yunet2023mar-sface2021dec-opencv4.11-v1',128,'sface-cosine-v1');
-- An amount-free instruction is an optional capability of the SAME registry.
-- It cannot turn a draft route into an amount-bearing composer route.
alter table public.biopay_provider_routes
  add column face_instruction_template text,
  add column face_enabled boolean not null default false,
  add column face_version integer not null default 1,
  add column face_tested_at timestamptz,
  add column face_evidence_url text,
  add constraint biopay_face_route_config check(not face_enabled or (
    destination_kind='mobileWallet' and source_provider=destination_provider
    and handoff_mode='dial' and recipient_format='rwandaNational'
    and face_instruction_template ~ '^\*[0-9*]+\{recipient\}#$'
    and face_tested_at is not null and face_evidence_url ~ '^https://'
    and valid_until is not null and valid_until>valid_from
  ) is true);
insert into public.biopay_provider_routes(source_provider,destination_provider,destination_kind,
  rail,purpose,handoff_mode,recipient_format,device_families,face_instruction_template)
values ('mtn_rw','mtn_rw','mobileWallet','ussd','transfer','dial','rwandaNational',
  array['android'],'*182*1*1*{recipient}#');

alter table public.biopay_face_revisions enable row level security;
alter table public.biopay_face_cleanup enable row level security;
alter table public.biopay_face_policy enable row level security;
revoke all on public.biopay_face_revisions,public.biopay_face_cleanup,public.biopay_face_policy from public,anon,authenticated;
grant all on public.biopay_face_revisions,public.biopay_face_cleanup,public.biopay_face_policy to service_role;

create function public.fn_biopay_face_session(p_user_id uuid,p_session_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if not exists(select 1 from auth.users where id=p_user_id and not coalesce(is_anonymous,false)
    and phone_confirmed_at is not null and raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp','admin_whatsapp_otp'))
    or not exists(select 1 from auth.sessions where id=p_session_id and user_id=p_user_id
      and (not_after is null or not_after>now())) then raise exception 'BIOPAY_SESSION_INVALID'; end if;
end $$;

drop function public.rpc_reserve_biopay_provider_operation(uuid,text,uuid);
create function public.rpc_reserve_biopay_provider_operation(p_user_id uuid,p_action text,p_auth_session_id uuid,
  p_idempotency_key text default null,p_request_digest text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare o public.biopay_provider_operations; n integer; w interval;
begin
  perform public.fn_biopay_face_session(p_user_id,p_auth_session_id);
  if p_action not in ('enroll','resolve') then raise exception 'UNSUPPORTED_PROVIDER_ACTION'; end if;
  if p_idempotency_key is null or p_idempotency_key !~ '^[A-Za-z0-9_-]{16,64}$'
    or p_request_digest is null or p_request_digest !~ '^[a-f0-9]{64}$' then raise exception 'INVALID_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text||':'||p_action,0));
  select * into o from public.biopay_provider_operations where user_id=p_user_id and auth_session_id=p_auth_session_id
    and action=p_action and idempotency_key=p_idempotency_key;
  if found then
    if o.request_digest<>p_request_digest then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    if o.expires_at<=now() then raise exception 'OPERATION_EXPIRED'; end if;
    return o.id;
  end if;
  n:=case when p_action='enroll' then 5 else 30 end;
  w:=case when p_action='enroll' then interval '15 minutes' else interval '5 minutes' end;
  if (select count(*) from public.biopay_provider_operations where user_id=p_user_id and action=p_action
    and created_at>now()-w)>=n then raise exception 'BIOPAY_RATE_LIMIT'; end if;
  insert into public.biopay_provider_operations(user_id,action,auth_session_id,idempotency_key,request_digest)
    values(p_user_id,p_action,p_auth_session_id,p_idempotency_key,p_request_digest) returning * into o;
  return o.id;
end $$;

-- Common canonical-number formatting. The existing composer uses this too.
create function public.fn_biopay_route_recipient(p_identifier text,p_format text)
returns text language plpgsql immutable set search_path='' as $$
begin
  if p_format='raw' then return p_identifier; end if;
  if p_identifier is null or p_identifier !~ '^\+2507[0-9]{8}$' then raise exception 'INVALID_RECEIVING_NUMBER'; end if;
  if p_format='e164Digits' then return substring(p_identifier from 2); end if;
  if p_format='rwandaNational' then return '0'||substring(p_identifier from 5); end if;
  raise exception 'INVALID_RECIPIENT_FORMAT';
end $$;

create function public.rpc_biopay_face_authority(p_user_id uuid,p_session_id uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare bp public.biopay_profiles; o public.biopay_provider_operations; rv public.biopay_face_revisions;
  m public.biopay_payment_methods; r public.biopay_provider_routes; policy public.biopay_face_policy;
  v text; old_vector text; score double precision; second_score double precision; candidate jsonb;
  best_owner uuid; next_owner uuid; code text;
begin
  perform public.fn_biopay_face_session(p_user_id,p_session_id);
  perform pg_advisory_xact_lock(hashtextextended('face:'||p_user_id::text,0));
  select * into bp from public.biopay_profiles where user_id=p_user_id for update;
  select * into policy from public.biopay_face_policy where model_version='yunet2023mar-sface2021dec-opencv4.11-v1';
  if p_action='status' then
    if bp.pending_vector_id is not null and exists(select 1 from public.biopay_face_revisions
      where vector_id=bp.pending_vector_id and (expires_at<=now() or state='failed')) then
      update public.biopay_face_revisions set state='failed' where vector_id=bp.pending_vector_id and state='pending';
      update public.biopay_profiles set pending_vector_id=null,status=case when status='processing' then 'rejected' else status end
        where id=bp.id returning * into bp;
    end if;
    return jsonb_build_object('status',case when bp.status='active' and not exists(
        select 1 from public.biopay_payment_methods where id=bp.receiving_method_id and owner_id=p_user_id
          and active and can_receive and kind='mobileWallet') then 'receiving_method_required'
        else coalesce(bp.status,'not_started') end,'receiving_method_id',bp.receiving_method_id,
      'pending_vector_id',bp.pending_vector_id,'revision',bp.face_revision,'model_version',bp.provider_collection_id,
      'enrolled_at',bp.consent_granted_at,'has_face',bp.provider='opencv_sface_v1' and bp.provider_subject_id is not null,
      'consent_version',bp.consent_version);
  elsif p_action in ('pause','remove','resume','change_method') then
    if bp.id is null then raise exception 'RECIPIENT_UNAVAILABLE'; end if;
    if p_action='change_method' then
      select * into m from public.biopay_payment_methods where id=(p_data->>'method_id')::uuid
        and owner_id=p_user_id and active and can_receive and kind='mobileWallet';
      if m.id is null then raise exception 'RECEIVING_METHOD_REQUIRED'; end if;
      update public.biopay_profiles set receiving_method_id=m.id,updated_at=now() where id=bp.id;
    elsif p_action='resume' then
      if bp.status<>'paused' or bp.provider<>'opencv_sface_v1' or bp.provider_subject_id is null
        or bp.consent_version is null then raise exception 'REENROLLMENT_REQUIRED'; end if;
      update public.biopay_profiles set status='active',matching_paused_at=null,updated_at=now() where id=bp.id;
    else
      -- In-flight replacement can never reactivate after pause/remove.
      update public.biopay_face_revisions set state='failed' where owner_id=p_user_id and state='pending';
      update public.biopay_profiles set status=case when p_action='remove' then 'deleted' else 'paused' end,
        pending_vector_id=null,matching_paused_at=now(),updated_at=now(),
        deleted_at=case when p_action='remove' then now() else deleted_at end,
        provider_subject_id=case when p_action='remove' then null else provider_subject_id end,
        receiving_method_id=case when p_action='remove' then null else receiving_method_id end
        where id=bp.id;
      if p_action='remove' then
        update public.biopay_face_revisions set state='superseded' where owner_id=p_user_id and state='active';
      end if;
      insert into public.biopay_face_cleanup(vector_id,model_version,not_before)
        select vector_id,model_version,greatest(expires_at+interval '30 seconds',now())
        from public.biopay_face_revisions where owner_id=p_user_id and state in ('failed','superseded')
        on conflict(vector_id) do update set deleted_at=null;
    end if;
    insert into public.biopay_audit_events(actor_user_id,action) values(p_user_id,'biopay.face.'||p_action);
    return jsonb_build_object('status','updated');
  elsif p_action='activate' then
    select * into rv from public.biopay_face_revisions where vector_id=p_data->>'vector_id'
      and owner_id=p_user_id and model_version=policy.model_version for update;
    if rv.state='active' then return jsonb_build_object('status','active'); end if;
    if rv.state is distinct from 'pending' or rv.expires_at<=now() or bp.pending_vector_id is distinct from rv.vector_id
      then return jsonb_build_object('status','cancelled'); end if;
    if not exists(select 1 from public.biopay_payment_methods where id=bp.receiving_method_id
      and owner_id=p_user_id and active and can_receive and kind='mobileWallet') then raise exception 'RECEIVING_METHOD_REQUIRED'; end if;
    old_vector:=bp.provider_subject_id;
    update public.biopay_profiles set provider='opencv_sface_v1',provider_subject_id=rv.vector_id,
      provider_collection_id=rv.model_version,pending_vector_id=null,face_revision=rv.revision,status='active',
      consent_granted_at=rv.consent_at,consent_version=rv.consent_version,server_verified_at=now(),
      matching_paused_at=null,deleted_at=null,liveness_status='not_applicable',provider_metadata='{}',updated_at=now() where id=bp.id;
    update public.biopay_face_revisions set state='superseded' where owner_id=p_user_id and state='active';
    update public.biopay_face_revisions set state='active' where vector_id=rv.vector_id;
    update public.biopay_provider_operations set state='enrolled',consumed_at=now() where id=rv.operation_id;
    if old_vector is not null and old_vector<>rv.vector_id and bp.provider='opencv_sface_v1' then
      insert into public.biopay_face_cleanup(vector_id,model_version) values(old_vector,bp.provider_collection_id)
        on conflict(vector_id) do nothing;
    end if;
    return jsonb_build_object('status','active','revision',rv.revision);
  end if;
  select * into o from public.biopay_provider_operations where id=(p_data->>'operation_id')::uuid
    and user_id=p_user_id and auth_session_id=p_session_id and expires_at>now() for update;
  if o.id is null then raise exception 'BIOPAY_SESSION_INVALID'; end if;
  if p_action='begin_enroll' and o.action='enroll' then
    select * into rv from public.biopay_face_revisions where operation_id=o.id;
    if found then return to_jsonb(rv); end if;
    if (p_data->>'consent_version') is distinct from 'face-discovery-v1' or (p_data->>'consent')::boolean is not true
      then raise exception 'CONSENT_REQUIRED'; end if;
    select * into m from public.biopay_payment_methods where id=(p_data->>'method_id')::uuid
      and owner_id=p_user_id and active and can_receive and kind='mobileWallet';
    if m.id is null then raise exception 'RECEIVING_METHOD_REQUIRED'; end if;
    update public.biopay_face_revisions set state='failed' where owner_id=p_user_id and state='pending';
    v:='f_'||replace(o.id::text,'-','');
    insert into public.biopay_face_revisions(vector_id,operation_id,owner_id,revision,model_version,consent_version,expires_at)
      values(v,o.id,p_user_id,coalesce((select max(revision) from public.biopay_face_revisions where owner_id=p_user_id),0)+1,
        policy.model_version,p_data->>'consent_version',o.expires_at) returning * into rv;
    -- Intent before index write. Reconciler only deletes non-current IDs after expiry.
    insert into public.biopay_face_cleanup(vector_id,model_version,not_before)
      values(v,policy.model_version,o.expires_at+interval '30 seconds');
    insert into public.biopay_profiles(user_id,handle,provider,status,receiving_method_id,pending_vector_id)
      values(p_user_id,'bio-'||substr(replace(p_user_id::text,'-',''),1,12),'opencv_sface_v1','processing',m.id,v)
      on conflict(user_id) do update set receiving_method_id=m.id,pending_vector_id=v,
        status=case when biopay_profiles.status='active' and biopay_profiles.provider='opencv_sface_v1' then 'active' else 'processing' end;
    update public.biopay_provider_operations set state='processing' where id=o.id;
    return to_jsonb(rv);
  elsif p_action='fail_enroll' and o.action='enroll' then
    update public.biopay_face_revisions set state='failed' where operation_id=o.id and state='pending';
    update public.biopay_profiles set pending_vector_id=null,
      status=case when status='processing' then 'rejected' else status end
      where user_id=p_user_id and pending_vector_id=(select vector_id from public.biopay_face_revisions where operation_id=o.id);
    return jsonb_build_object('status','failed');
  elsif p_action='operation' then
    return jsonb_build_object('state',o.state,'outcome',o.outcome,'vector_id',o.provider_face_id);
  elsif p_action='resolve' and o.action='resolve' then
    if policy.enabled is not true then return jsonb_build_object('status','unavailable','code','POLICY_NOT_ACCEPTED'); end if;
    if o.state='matched' then v:=o.provider_face_id;
    elsif o.outcome is not null then return jsonb_build_object('status',o.outcome); else
      if p_data->>'model_version' is distinct from policy.model_version then raise exception 'MODEL_MISMATCH'; end if;
      -- Never skip a stale or inactive top hit to choose a lower unrelated person.
      candidate:=p_data->'candidates'->0;
      score:=(candidate->>'score')::double precision; v:=candidate->>'id';
      if score is null or score<policy.min_score or score>1 or score='NaN'::float8 then
        update public.biopay_provider_operations set outcome='no_match' where id=o.id;
        return jsonb_build_object('status','no_match','code','NO_MATCH');
      end if;
      select owner_id into best_owner from public.biopay_face_revisions where vector_id=v and model_version=policy.model_version;
      for candidate in select value from jsonb_array_elements(p_data->'candidates') with ordinality as c(value,ord) where ord>1 loop
        second_score:=(candidate->>'score')::double precision;
        if second_score is null or second_score>score or second_score<'-1'::float8 or second_score='NaN'::float8 then raise exception 'INVALID_PROVIDER_RESULT'; end if;
        select owner_id into next_owner from public.biopay_face_revisions where vector_id=candidate->>'id' and model_version=policy.model_version;
        if next_owner is distinct from best_owner or next_owner is null then
          if score-second_score<policy.min_margin then
            update public.biopay_provider_operations set outcome='ambiguous' where id=o.id;
            return jsonb_build_object('status','ambiguous','code','AMBIGUOUS_MATCH');
          end if;
        end if;
      end loop;
      update public.biopay_provider_operations set state='matched',provider_face_id=v,provider_collection_id=policy.model_version where id=o.id;
    end if;
    select * into bp from public.biopay_profiles where provider_subject_id=v and provider='opencv_sface_v1'
      and provider_collection_id=policy.model_version and status='active' and deleted_at is null
      and consent_version='face-discovery-v1' and server_verified_at is not null for share;
    if bp.id is null then
      update public.biopay_provider_operations set outcome='recipient_unavailable' where id=o.id;
      return jsonb_build_object('status','recipient_unavailable','code','RECIPIENT_UNAVAILABLE');
    end if;
    select * into m from public.biopay_payment_methods where id=bp.receiving_method_id and owner_id=bp.user_id
      and active and can_receive and kind='mobileWallet' for share;
    if m.id is null then
      update public.biopay_provider_operations set outcome='recipient_unavailable' where id=o.id;
      return jsonb_build_object('status','recipient_unavailable','code','RECEIVING_METHOD_REQUIRED');
    end if;
    select * into r from public.biopay_provider_routes where destination_provider=m.provider and destination_kind=m.kind
      and face_enabled and state<>'disabled' and valid_from<=now() and valid_until>now()
      order by face_version desc,id limit 1 for share;
    if r.id is null then
      update public.biopay_provider_operations set outcome='route_unavailable' where id=o.id;
      return jsonb_build_object('status','unavailable','code','ROUTE_NOT_CONFIGURED');
    end if;
    code:=replace(r.face_instruction_template,'{recipient}',public.fn_biopay_route_recipient(m.identifier,r.recipient_format));
    if code !~ '^\*[0-9*]+#$' then raise exception 'INVALID_ROUTE'; end if;
    update public.biopay_provider_operations set outcome='dial_ready' where id=o.id;
    return jsonb_build_object('status','dial_ready','request_id',o.id,'payee_id',bp.user_id,
      'display_name',(select coalesce(nullif(display_name,''),nullif(name,'')) from public.profiles where id=bp.user_id),
      'receiving_method_id',m.id,'receiving_method_version',m.version,'provider',m.provider,
      'route_id',r.id,'route_version',r.face_version,'ussd_code',code,'expires_at',least(o.expires_at,now()+interval '30 seconds'));
  elsif p_action='handoff' and o.action='resolve' and o.state='matched' then
    if o.consumed_at is null then
      update public.biopay_provider_operations set consumed_at=now() where id=o.id;
      insert into public.biopay_audit_events(actor_user_id,action,metadata)
        values(p_user_id,'biopay.face.dialer_opened',jsonb_build_object('operation_id',o.id));
    end if;
    return jsonb_build_object('status','recorded');
  end if;
  raise exception 'UNSUPPORTED_PROVIDER_ACTION';
end $$;

-- Small retry queue; raw captures are never retained for a background retry.
create function public.rpc_biopay_face_maintenance(p_deleted_ids text[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  update public.biopay_face_cleanup c set deleted_at=now() where vector_id=any(p_deleted_ids) and not_before<=now()
    and not exists(select 1 from public.biopay_profiles p where p.provider='opencv_sface_v1'
      and (p.provider_subject_id=c.vector_id or p.pending_vector_id=c.vector_id));
  update public.biopay_face_revisions set state='failed' where state='pending' and expires_at<=now();
  update public.biopay_profiles p set pending_vector_id=null,status=case when status='processing' then 'rejected' else status end
    where exists(select 1 from public.biopay_face_revisions r where r.vector_id=p.pending_vector_id and r.state='failed');
  update public.biopay_face_cleanup c set attempts=attempts+1 where vector_id in (
    -- Recheck observed-absent tombstones daily: a very late asynchronous insert
    -- after a timed-out write must not become a permanently forgotten orphan.
    select vector_id from public.biopay_face_cleanup q where (deleted_at is null or deleted_at<now()-interval '1 day') and not_before<=now()
      and not exists(select 1 from public.biopay_profiles p where p.provider='opencv_sface_v1'
        and (p.provider_subject_id=q.vector_id or p.pending_vector_id=q.vector_id)) order by not_before limit 50);
  return coalesce((select jsonb_agg(jsonb_build_object('vector_id',vector_id,'model_version',model_version))
    from (select c.* from public.biopay_face_cleanup c where (deleted_at is null or deleted_at<now()-interval '1 day') and not_before<=now()
      and not exists(select 1 from public.biopay_profiles p where p.provider='opencv_sface_v1'
        and (p.provider_subject_id=c.vector_id or p.pending_vector_id=c.vector_id)) order by not_before limit 50) q),'[]'::jsonb);
end $$;

-- Installed legacy clients fail closed instead of producing login-number routes.
revoke all on function public.rpc_bind_biopay_liveness_session(uuid,uuid,text),
  public.rpc_authorize_biopay_liveness_session(uuid,text,boolean),
  public.rpc_record_verified_biopay_face_enrollment(uuid,uuid,text,text,text,numeric,jsonb),
  public.rpc_record_verified_biopay_face_match(uuid,uuid,text,text,numeric),
  public.rpc_create_verified_biopay_face_match_request(uuid,integer,text),
  public.rpc_create_biopay_face_match_request(text,integer,text),
  public.rpc_record_biopay_face_enrollment(text,text,text,text,numeric,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.fn_biopay_face_session(uuid,uuid),
  public.rpc_reserve_biopay_provider_operation(uuid,text,uuid,text,text),
  public.rpc_biopay_face_authority(uuid,uuid,text,jsonb),public.rpc_biopay_face_maintenance(text[]) from public,anon,authenticated;
grant execute on function public.rpc_reserve_biopay_provider_operation(uuid,text,uuid,text,text),
  public.rpc_biopay_face_authority(uuid,uuid,text,jsonb),public.rpc_biopay_face_maintenance(text[]) to service_role;
commit;
