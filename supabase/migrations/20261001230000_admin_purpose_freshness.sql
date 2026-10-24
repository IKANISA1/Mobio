-- CR03/CR23 composition: an invalid Admin lease must be denied before a
-- sensitive RPC validates arguments. Recognizing its purpose grants no identity.
-- Keep the existing service bypasses and provider-route read branch unchanged.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local search_path = '';

create function mobio_private.is_live_admin_purpose_transport()
returns boolean language sql volatile security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u
    where u.id = public.live_auth_user_id()
      and auth.jwt()->'is_anonymous' = 'false'::jsonb
      and auth.jwt()->'app_metadata'->>'provider' = 'admin_whatsapp_otp'
      and u.raw_app_meta_data->>'provider' = 'admin_whatsapp_otp'
      and mobio_private.verified_interactive_account_is_eligible(u.id)
  );
$$;
revoke all on function mobio_private.is_live_admin_purpose_transport()
  from public, anon, authenticated, service_role;

-- Rewrite only the exact earlier freshness predicate. The recent-session
-- requirement, original permissions, receipts, RLS and audit rules survive.
do $purpose_gates$
declare
  target record; routine record; next_body text; definition text;
  anchor text := 'public.verified_admin_user_id() is not null then perform public.require_recent_admin_session();';
  replacement text := 'mobio_private.is_live_admin_purpose_transport() then perform public.require_recent_admin_session();';
  processed integer := 0;
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
  ) as mutations(signature,mode) loop
    if pg_catalog.to_regprocedure(target.signature) is null then
      raise exception 'Missing Admin purpose RPC: %', target.signature;
    end if;
    select p.*, l.lanname into strict routine
    from pg_catalog.pg_proc p join pg_catalog.pg_language l on l.oid = p.prolang
    where p.oid = pg_catalog.to_regprocedure(target.signature);
    if routine.lanname <> 'plpgsql' or not routine.prosecdef
      or not ('search_path=""' = any(coalesce(routine.proconfig,array[]::text[])))
      or (length(routine.prosrc)-length(replace(routine.prosrc,anchor,''))) <> length(anchor)
      or position(replacement in routine.prosrc) > 0 then
      raise exception 'Unexpected Admin freshness body or security settings: %', target.signature;
    end if;
    if target.mode = 'service' and position('if not public._mobio_is_service_role() and ' || anchor in routine.prosrc) = 0 then
      raise exception 'Missing original service freshness bypass: %', target.signature;
    end if;
    if target.mode = 'routes' and position('if p_action is distinct from ''list'' and ' || anchor in routine.prosrc) = 0 then
      raise exception 'Missing original provider-route read exclusion: %', target.signature;
    end if;
    next_body := replace(routine.prosrc,anchor,replacement);
    definition := pg_catalog.pg_get_functiondef(routine.oid);
    if position(routine.prosrc in definition) = 0 then
      raise exception 'Admin freshness body missing from catalogue definition: %', target.signature;
    end if;
    execute replace(definition,routine.prosrc,next_body);
    if not exists(select 1 from pg_catalog.pg_proc p where p.oid = routine.oid
      and p.prosrc = next_body and p.proowner = routine.proowner
      and p.proacl is not distinct from routine.proacl
      and p.proconfig is not distinct from routine.proconfig
      and p.prosecdef = routine.prosecdef
      and p.proargtypes = routine.proargtypes
      and p.proargdefaults is not distinct from routine.proargdefaults) then
      raise exception 'Admin purpose guard changed catalogue authority: %', target.signature;
    end if;
    processed := processed + 1;
  end loop;
  if processed <> 31 then raise exception 'Incomplete Admin purpose RPC catalogue'; end if;
end;
$purpose_gates$;
notify pgrst, 'reload schema';
commit;
