-- Face caller/recipient admission and account-wide Maps quota. Preserve the
-- approved amount-free receiving shortcut and all existing cleanup exclusions.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local search_path = '';

do $dependencies$
declare existing record;
begin
  if pg_catalog.to_regprocedure('mobio_private.require_verified_interactive_session(uuid,uuid,boolean)') is null
    or pg_catalog.to_regprocedure('mobio_private.verified_interactive_account_is_eligible(uuid)') is null then
    raise exception 'Missing canonical interactive authority contracts';
  end if;
  select p.*,l.lanname into strict existing from pg_catalog.pg_proc p
    join pg_catalog.pg_language l on l.oid=p.prolang
    where p.oid=pg_catalog.to_regprocedure('public.fn_biopay_face_session(uuid,uuid)');
  if existing.lanname <> 'plpgsql' or not existing.prosecdef
    or not ('search_path=""' = any(coalesce(existing.proconfig,array[]::text[])))
    or position('SERVICE_ROLE_REQUIRED' in existing.prosrc)=0
    or position('BIOPAY_SESSION_INVALID' in existing.prosrc)=0
    or position('auth.sessions' in existing.prosrc)=0
    or position('require_verified_interactive_session' in existing.prosrc)>0
    or pg_catalog.has_function_privilege('authenticated',existing.oid,'EXECUTE')
    or pg_catalog.has_function_privilege('anon',existing.oid,'EXECUTE') then
    raise exception 'Unexpected existing Face session helper contract';
  end if;
end;
$dependencies$;

-- Only server callers may transport the exact Auth-validated owner/session pair.
-- This wrapper retains the established Face expired-session error contract.
create or replace function public.fn_biopay_face_session(p_user_id uuid,p_session_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode = '42501';
  end if;
  begin
    perform mobio_private.require_verified_interactive_session(p_user_id,p_session_id,false);
  exception when insufficient_privilege then
    raise exception 'BIOPAY_SESSION_INVALID' using errcode = '42501';
  end;
end;
$$;
revoke all on function public.fn_biopay_face_session(uuid,uuid) from public,anon,authenticated;

-- Preserve installed bodies, signatures, defaults, grants and service-only
-- boundaries. Unknown catalogue/body state fails the forward migration.
do $face_gates$
declare target record; routine record; previous text; next_body text; anchor text; replacement text;
begin
  for target in select * from (values
    ('public.rpc_reserve_biopay_provider_operation(uuid,text,uuid,text,text)',
      '  perform public.fn_biopay_face_session(p_user_id,p_auth_session_id);',
      $reservation$  begin
    perform mobio_private.require_verified_interactive_session(p_user_id,p_auth_session_id,true);
  exception when insufficient_privilege then
    if sqlerrm='ADMIN_REAUTHENTICATION_REQUIRED' then raise; end if;
    raise exception 'BIOPAY_SESSION_INVALID' using errcode='42501';
  end;$reservation$),
    ('public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)',
      '  perform public.fn_biopay_face_session(p_user_id,p_session_id);',
      $action$  if p_action in ('begin_enroll','activate','pause','remove','resume','change_method','fail_enroll','resolve','prepare_handoff','handoff') then
    begin
      perform mobio_private.require_verified_interactive_session(p_user_id,p_session_id,true);
    exception when insufficient_privilege then
      if sqlerrm='ADMIN_REAUTHENTICATION_REQUIRED' then raise; end if;
      raise exception 'BIOPAY_SESSION_INVALID' using errcode='42501';
    end;
  end if;$action$)
  ) as paths(signature,session_anchor,fresh_gate)
  loop
    if pg_catalog.to_regprocedure(target.signature) is null then
      raise exception 'Missing Face service RPC: %',target.signature;
    end if;
    select p.*,l.lanname into strict routine from pg_catalog.pg_proc p
      join pg_catalog.pg_language l on l.oid=p.prolang
      where p.oid=pg_catalog.to_regprocedure(target.signature);
    if routine.lanname <> 'plpgsql' or not routine.prosecdef
      or not ('search_path=""' = any(coalesce(routine.proconfig,array[]::text[])))
      or position('require_verified_interactive_session' in routine.prosrc)>0
      or (length(routine.prosrc)-length(replace(routine.prosrc,target.session_anchor,''))) / length(target.session_anchor) <> 1
      or pg_catalog.has_function_privilege('authenticated',routine.oid,'EXECUTE')
      or pg_catalog.has_function_privilege('anon',routine.oid,'EXECUTE')
      or not pg_catalog.has_function_privilege('service_role',routine.oid,'EXECUTE') then
      raise exception 'Unexpected Face service RPC security/body: %',target.signature;
    end if;
    previous := routine.prosrc;
    -- Service admission remains first. Sensitive purpose/freshness must then
    -- precede the generic wrapper, which deliberately hides ordinary denials.
    next_body := replace(previous,target.session_anchor,
      $service$  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;$service$ || E'\n' || target.fresh_gate || E'\n' || target.session_anchor);
    if target.signature = 'public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)' then
      anchor := $anchor$    select * into bp from public.biopay_profiles where provider_subject_id=v and provider='opencv_sface_v1'
      and provider_collection_id=policy.model_version and status='active' and deleted_at is null
      and consent_version='face-discovery-v1' and server_verified_at is not null for share;$anchor$;
      replacement := $replacement$    select p.* into bp from public.biopay_profiles p
      join auth.users u on u.id=p.user_id
      where p.provider_subject_id=v and p.provider='opencv_sface_v1'
      and p.provider_collection_id=policy.model_version and p.status='active' and p.deleted_at is null
      and p.consent_version='face-discovery-v1' and p.server_verified_at is not null
      and mobio_private.verified_interactive_account_is_eligible(p.user_id)
      for share of p,u;
    -- Check again after row-lock acquisition, including a concurrent moderation
    -- change. Recipients need durable verified identity, never a live session.
    if bp.id is not null and not mobio_private.verified_interactive_account_is_eligible(bp.user_id) then
      bp := null;
    end if;$replacement$;
      if (length(next_body)-length(replace(next_body,anchor,''))) / length(anchor) <> 1 then
        raise exception 'Unexpected Face recipient admission body';
      end if;
      next_body := replace(next_body,anchor,replacement);
      anchor := $resolve$  elsif p_action='resolve' and o.action='resolve' then$resolve$;
      if (length(next_body)-length(replace(next_body,anchor,''))) / length(anchor) <> 1 then
        raise exception 'Unexpected Face resolution authority body';
      end if;
      next_body := replace(next_body,anchor,$prepare$  elsif p_action in ('resolve','prepare_handoff') and o.action='resolve' then
    if p_action='prepare_handoff' and o.state<>'matched' then
      raise exception 'BIOPAY_SESSION_INVALID' using errcode='42501';
    end if;$prepare$);
      anchor := $handoff$  elsif p_action='handoff' and o.action='resolve' and o.state='matched' then$handoff$;
      if (length(next_body)-length(replace(next_body,anchor,''))) / length(anchor) <> 1 then
        raise exception 'Unexpected Face handoff authority body';
      end if;
      next_body := replace(next_body,anchor,anchor||$recheck$
    p_data := public.rpc_biopay_face_authority(p_user_id,p_session_id,'resolve',jsonb_build_object('operation_id',o.id));
    if p_data->>'status' is distinct from 'dial_ready' then return p_data; end if;$recheck$);
    end if;
    execute replace(pg_catalog.pg_get_functiondef(routine.oid),previous,next_body);
  end loop;
end;
$face_gates$;

-- Private durable buckets. Only the caller-bound definer RPC can consume one;
-- service keys, user-selected accounts and process restarts grant no extra quota.
create table mobio_private.maps_account_quota (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count between 1 and 100)
);
alter table mobio_private.maps_account_quota enable row level security;
revoke all on mobio_private.maps_account_quota from public,anon,authenticated,service_role;

create function public.rpc_consume_maps_quota(p_action text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid; session_id uuid; bucket mobio_private.maps_account_quota;
  at_time timestamptz := statement_timestamp(); allowed boolean;
begin
  if coalesce(auth.role(),'') <> 'authenticated' then
    raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode = '42501';
  end if;
  begin
    session_id := (auth.jwt()->>'session_id')::uuid;
  exception when invalid_text_representation then
    raise exception 'INTERACTIVE_SESSION_REQUIRED' using errcode = '42501';
  end;
  actor := mobio_private.require_verified_interactive_session(public.verified_app_user_id(),session_id,false);
  if p_action is null or p_action not in ('autocomplete','geocode','text_search','place_details','reverse_geocode') then
    raise exception 'UNSUPPORTED_MAPS_ACTION' using errcode = '22023';
  end if;
  insert into mobio_private.maps_account_quota as current_bucket(user_id,window_started_at,request_count)
    values(actor,at_time,1)
    on conflict(user_id) do update set
      window_started_at = case when current_bucket.window_started_at <= at_time - interval '5 minutes'
        then at_time else current_bucket.window_started_at end,
      request_count = case when current_bucket.window_started_at <= at_time - interval '5 minutes'
        then 1 else current_bucket.request_count+1 end
    where current_bucket.window_started_at <= at_time - interval '5 minutes'
      or (current_bucket.window_started_at <= clock_timestamp() and current_bucket.request_count < 100)
    returning * into bucket;
  allowed := found;
  at_time := clock_timestamp();
  if not allowed then
    select * into strict bucket from mobio_private.maps_account_quota where user_id=actor for share;
  end if;
  return jsonb_build_object('allowed',allowed,'remaining',case when allowed then 100-bucket.request_count else 0 end,
    'retry_after_seconds',case when allowed then 0 else greatest(1,least(300,
      ceil(extract(epoch from bucket.window_started_at + interval '5 minutes' - at_time))::integer)) end,
    'window_ends_at',bucket.window_started_at + interval '5 minutes');
end;
$$;
revoke all on function public.rpc_consume_maps_quota(text) from public,anon,service_role;
grant execute on function public.rpc_consume_maps_quota(text) to authenticated;

comment on function public.rpc_consume_maps_quota(text) is
  'Caller-bound verified interactive session; atomic account limit 100 requests/5 minutes across all five Places/Geocoding actions. No service bypass or compute_route.';
commit;
