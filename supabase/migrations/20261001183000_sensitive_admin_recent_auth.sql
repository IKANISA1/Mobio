-- Interactive sensitive writes require a fresh trusted Admin login. Keep
-- existing permission/receipt/audit checks and the five existing service paths.
-- No hosted rollout or operating-policy change is authorized by this migration.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local search_path = '';

create function public.admin_session_is_recent()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from mobio_private.admin_session_leases l
    cross join mobio_private.admin_session_policy p
    where p.singleton
      and l.user_id = public.verified_admin_user_id()
      and l.session_id::text = auth.jwt()->>'session_id'
      and l.authenticated_at <= statement_timestamp()
      and l.authenticated_at > statement_timestamp()
        - make_interval(secs => p.recent_auth_seconds)
  );
$$;
revoke all on function public.admin_session_is_recent() from public;
grant execute on function public.admin_session_is_recent() to anon,authenticated,service_role;

create or replace function public.require_recent_admin_session()
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid := public.verified_admin_user_id();
begin
  if actor is null or not public.admin_session_is_recent() then
    raise exception 'ADMIN_REAUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  return actor;
end;
$$;
revoke all on function public.require_recent_admin_session() from public,anon;
grant execute on function public.require_recent_admin_session() to authenticated,service_role;

-- Earlier identity hardening rewrites effective catalogue bodies. Upgrade those
-- bodies, not stale source copies, while preserving signatures/defaults, owners,
-- ACLs, SECURITY DEFINER and search paths. Invalid/revoked identities still meet
-- the original authority denial; valid but stale Admin identities get a precise
-- reauthentication rejection. Unexpected catalogue state fails closed.
do $rpc_gates$
declare
  target record; routine record; original_body text; next_body text;
  definition text; gate text; expected integer := 31; processed integer := 0;
begin
  for target in select * from (values
      ('public.rpc_admin_update_user_role(uuid,text)', 'admin'),
      ('public.rpc_admin_upsert_whatsapp_number(text,text,text,boolean)', 'admin'),
      ('public.rpc_admin_set_whatsapp_number_active(uuid,boolean)', 'admin'),
      ('public.rpc_admin_cancel_trip(uuid,text)', 'admin'),
      ('public.rpc_admin_review_user_report(uuid,text,text)', 'admin'),
      ('public.rpc_admin_request_campaign_approval(text,text,text,jsonb)', 'admin'),
      ('public.rpc_admin_approve_campaign(uuid,boolean,text)', 'admin'),
      ('public.rpc_admin_send_approved_campaign(uuid)', 'admin'),
      ('public.rpc_admin_send_promo(text,text,jsonb)', 'admin'),
      ('public.rpc_admin_send_announcement(text,text,jsonb)', 'admin'),
      ('public.rpc_admin_upsert_platform_setting(text,text)', 'admin'),
      ('public.rpc_admin_update_vehicle_type(text,text,text,text,integer,boolean)', 'admin'),
      ('public.rpc_admin_set_vehicle_type_active(text,boolean)', 'admin'),
      ('public.rpc_admin_set_vehicle_type_countries(text,text[])', 'admin'),
      ('public.rpc_admin_upsert_subscription_plan(text,text,integer,numeric,text,boolean)', 'admin'),
      ('public.rpc_admin_set_subscription_plan_active(uuid,boolean)', 'admin'),
      ('public.rpc_admin_delete_subscription_plan(uuid)', 'admin'),
      ('public.rpc_admin_upsert_transport_agency(uuid,text,text,text,text,text,boolean)', 'admin'),
      ('public.rpc_admin_set_transport_agency_active(uuid,boolean)', 'admin'),
      ('public.rpc_admin_remove_transport_agency(uuid)', 'admin'),
      ('public.rpc_admin_upsert_ev_charger(uuid,text,text,double precision,double precision,text[],text,text,numeric,text,text,boolean)', 'admin'),
      ('public.rpc_admin_set_ev_charger_active(uuid,boolean)', 'admin'),
      ('public.rpc_admin_adjust_user_tokens(uuid,bigint,text)', 'admin'),
      ('public.rpc_admin_update_token_redemption_status(uuid,text,text)', 'admin'),
      ('public.rpc_admin_expire_driver_subscription_payment_requests()', 'service'),
      ('public.rpc_admin_confirm_momo_sms_receipt(uuid,text)', 'service'),
      ('public.rpc_admin_reverse_wallet_transfer(uuid,text)', 'service'),
      ('public.rpc_admin_biopay_confirm_external(uuid,text)', 'admin'),
      ('public.rpc_admin_biopay_routes(text,jsonb)', 'routes'),
      ('public.rpc_confirm_bus_booking(uuid,text,text,jsonb)', 'service'),
      ('public.rpc_confirm_driver_subscription_payment(text,text,text,jsonb)', 'service')
    ) as mutations(signature,mode)
  loop
    if pg_catalog.to_regprocedure(target.signature) is null then
      raise exception 'Missing sensitive Admin RPC: %', target.signature;
    end if;
    select p.*, l.lanname into strict routine
      from pg_catalog.pg_proc p join pg_catalog.pg_language l on l.oid=p.prolang
      where p.oid=pg_catalog.to_regprocedure(target.signature);
    if routine.lanname <> 'plpgsql' or not routine.prosecdef
      or not ('search_path=""' = any(coalesce(routine.proconfig,array[]::text[])))
      or routine.prosrc !~* '\mBEGIN\M'
      or position('require_recent_admin_session' in routine.prosrc)>0 then
      raise exception 'Unexpected sensitive Admin RPC body or security settings: %',target.signature;
    end if;
    if target.mode='service' and position('public._mobio_is_service_role()' in routine.prosrc)=0 then
      raise exception 'Missing original trusted service branch: %',target.signature;
    end if;
    gate := case target.mode
      when 'service' then 'if not public._mobio_is_service_role() and public.verified_admin_user_id() is not null then perform public.require_recent_admin_session(); end if;'
      when 'routes' then 'if p_action is distinct from ''list'' and public.verified_admin_user_id() is not null then perform public.require_recent_admin_session(); end if;'
      else 'if public.verified_admin_user_id() is not null then perform public.require_recent_admin_session(); end if;'
    end;
    if target.mode='routes' and position('if p_action=''list'' then' in routine.prosrc)=0 then
      raise exception 'Missing provider-route read branch: %',target.signature;
    end if;
    original_body := routine.prosrc;
    next_body := pg_catalog.regexp_replace(original_body,'\mBEGIN\M',
      E'BEGIN\n  -- CR03: immutable authenticated-at freshness, in addition to original authority.\n  '||gate,'i');
    if next_body=original_body then raise exception 'Admin gate insertion failed: %',target.signature; end if;
    definition := pg_catalog.pg_get_functiondef(routine.oid);
    if position(original_body in definition)=0 then
      raise exception 'Admin body is not present verbatim in catalogue definition: %',target.signature;
    end if;
    execute replace(definition,original_body,next_body);
    if not exists(select 1 from pg_catalog.pg_proc p where p.oid=routine.oid
      and p.prosrc=next_body and p.proowner=routine.proowner
      and p.proacl is not distinct from routine.proacl
      and p.proconfig is not distinct from routine.proconfig
      and p.prosecdef=routine.prosecdef) then
      raise exception 'Admin gate changed catalogue authority: %',target.signature;
    end if;
    processed := processed+1;
  end loop;
  if processed<>expected then raise exception 'Incomplete sensitive Admin RPC catalogue'; end if;
end;
$rpc_gates$;

-- Restrictive write policies are additive: all original permissions, ownership,
-- tenant checks and public/owner reads survive. Ordinary verified consumers do
-- not acquire Admin identity, so their owner writes retain their original rules.
-- An expired/revoked Admin identity cannot use the original privileged branches:
-- those branches must resolve verified Admin permission, as checked below.
do $policy_gates$
declare
  relation text; table_oid oid; policy record; expr text;
  targets text[] := array[
'public.organizations',
    'public.organization_members',
    'public.platform_permissions',
    'public.profile_platform_permissions',
    'public.profiles',
    'public.vehicle_types',
    'public.vehicle_type_countries',
    'public.subscription_plans',
    'public.app_platform_settings',
    'public.ev_chargers',
    'public.transport_agencies',
    'public.agency_buses',
    'public.transport_routes',
    'public.route_stops',
    'public.bus_schedules',
    'public.bus_seat_inventory',
    'public.bus_tracking_sources',
    'public.trips',
    'public.campaign_approvals',
    'public.notification_consents',
    'public.admin_audit_logs',
    'public.driver_entitlement_rules',
    'public.driver_plus_rules',
    'public.driver_subscriptions',
    'public.driver_trip_entitlement_usage',
    'public.driver_locations',
    'public.mobility_events',
    'public.vehicles',
    'public.favorite_addresses',
    'storage.objects'
  ];
  privileged_policies integer := 0; relation_policies integer;
begin
  if position('public.verified_admin_user_id()' in pg_catalog.pg_get_functiondef(
    'public.has_platform_permission(text)'::regprocedure))=0
    or position('public.has_platform_permission(' in pg_catalog.pg_get_functiondef(
      'public.is_platform_admin()'::regprocedure))=0
    or pg_catalog.pg_get_functiondef('public.can_access_organization(uuid,text)'::regprocedure)
      !~* 'p_permission[[:space:]]+is[[:space:]]+null' then
    raise exception 'Recent Admin policies require verified permission and read-only membership authority';
  end if;
  for policy in select n.nspname,c.relname,p.polname,p.polcmd,
      pg_catalog.pg_get_expr(p.polqual,p.polrelid) as qual,
      pg_catalog.pg_get_expr(p.polwithcheck,p.polrelid) as with_check
    from pg_catalog.pg_policy p join pg_catalog.pg_class c on c.oid=p.polrelid
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','storage') and p.polcmd<>'r'
  loop
    expr:=coalesce(policy.qual,'')||' '||coalesce(policy.with_check,'');
    if expr ~ '(has_platform_permission|is_platform_admin|can_access_organization)\(' then
      relation:=pg_catalog.format('%I.%I',policy.nspname,policy.relname);
      if not (relation=any(targets)) then
        raise exception 'Uninventoried privileged write policy: %.%',relation,policy.polname;
      end if;
      if expr ~ 'can_access_organization\(' and
        expr !~ 'can_access_organization\([^,]+,[[:space:]]*''[^'']+''::text\)' then
        raise exception 'Privileged organization write must request a named permission: %.%',relation,policy.polname;
      end if;
      privileged_policies:=privileged_policies+1;
    end if;
  end loop;
  if privileged_policies<>41 then
    raise exception 'Expected 41 inventoried privileged write policies, found %',privileged_policies;
  end if;
  foreach relation in array targets loop
    table_oid:=pg_catalog.to_regclass(relation);
    if table_oid is null or not exists(select 1 from pg_catalog.pg_class c where c.oid=table_oid and c.relrowsecurity) then
      raise exception 'Missing RLS relation for recent Admin writes: %',relation;
    end if;
    select count(*) into relation_policies from pg_catalog.pg_policy p where p.polrelid=table_oid
      and p.polcmd<>'r' and (coalesce(pg_catalog.pg_get_expr(p.polqual,p.polrelid),'')||' '||
        coalesce(pg_catalog.pg_get_expr(p.polwithcheck,p.polrelid),''))
          ~ '(has_platform_permission|is_platform_admin|can_access_organization)\(';
    if relation_policies=0 then raise exception 'Missing inventoried privileged writes: %',relation; end if;
    execute pg_catalog.format('create policy sensitive_admin_recent_insert on %s as restrictive for insert to authenticated with check (public.verified_admin_user_id() is null or public.admin_session_is_recent())',relation);
    execute pg_catalog.format('create policy sensitive_admin_recent_update on %s as restrictive for update to authenticated using (public.verified_admin_user_id() is null or public.admin_session_is_recent()) with check (public.verified_admin_user_id() is null or public.admin_session_is_recent())',relation);
    execute pg_catalog.format('create policy sensitive_admin_recent_delete on %s as restrictive for delete to authenticated using (public.verified_admin_user_id() is null or public.admin_session_is_recent())',relation);
  end loop;
end;
$policy_gates$;
notify pgrst,'reload schema';
commit;
