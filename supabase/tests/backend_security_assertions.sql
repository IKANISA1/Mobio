-- Backend security assertions for production hardening.
-- Expected result: raises no exception and returns one ok row.
-- Run against a migrated database with:
--   supabase db query --linked --file supabase/tests/backend_security_assertions.sql --output table

do $$
declare
  v_failures text;
begin
  with failures(failure) as (
    select 'profiles broad authenticated select policy still exists'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_authenticated'

    union all

    select 'anon can still select trips directly'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'trips'
      and grantee in ('anon', 'PUBLIC')
      and privilege_type = 'SELECT'

    union all

    select 'out-of-scope legacy table still exists'
    from (values
      ('biopay_abuse_reports'),
      ('biopay_enrollment_audit'),
      ('biopay_face_embeddings'),
      ('biopay_match_audit'),
      ('biopay_match_rate_limits'),
      ('biopay_rate_limits'),
      ('biopay_transactions'),
      ('biopay_wallets'),
      ('face_templates'),
      ('nfc_payment_sessions'),
      ('payment_events'),
      ('payment_intents'),
      ('qr_payment_sessions'),
      ('ride_requests'),
      ('risk_flags'),
      ('sms_raw_queue'),
      ('transactions'),
      ('trip_requests')
    ) as legacy(table_name)
    where exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = legacy.table_name
    )

    union all

    select 'out-of-scope legacy routine still exists'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'biopay_delete_profile',
        'biopay_check_rate_limit',
        'biopay_cleanup_rate_limits',
        'biopay_reenroll_profile',
        'consume_biopay_match_rate_limit',
        'enforce_biopay_transaction_organization',
        'enforce_biopay_wallet_organization',
        'enforce_ride_request_organization',
        'enforce_trip_request_organization',
        'find_duplicate_biopay_profile',
        'fn_biopay_generate_qr',
        'fn_biopay_resolve_qr_payload',
        'fn_biopay_scan_and_charge',
        'generate_biopay_id',
        'match_biopay_embedding',
        'rpc_admin_list_risk_flags',
        'rpc_resolve_nfc_payment_session',
        'rpc_resolve_qr_payment_session',
        'rpc_get_biopay_wallet',
        'rpc_update_biopay_handle'
      )

    union all

    select 'out-of-scope profile BioPay column still exists'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name in (
        'biopay_handle_type',
        'biopay_handle_value',
        'has_face_id'
      )

    union all

    select 'out-of-scope country SMS sender column still exists'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'countries'
      and column_name = 'sender_id'

    union all

    select 'tenant foundation table missing'
    from (values
      ('organizations'),
      ('organization_members'),
      ('platform_permissions'),
      ('profile_platform_permissions'),
      ('otp_rate_limits'),
      ('operational_health_events')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = required.table_name
    )

    union all

    select 'public transport foundation table missing'
    from (values
      ('transport_agencies'),
      ('agency_buses'),
      ('transport_routes'),
      ('route_stops'),
      ('bus_schedules'),
      ('bus_seat_inventory'),
      ('bus_bookings'),
      ('bus_booking_payments'),
      ('bus_tracking_sources'),
      ('bus_location_events')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = required.table_name
    )

    union all

    select 'public transport RPC missing'
    from (values
      ('rpc_search_bus_schedules'),
      ('rpc_hold_bus_seats'),
      ('rpc_confirm_bus_booking'),
      ('rpc_cancel_bus_booking'),
      ('rpc_get_bus_payment_status'),
      ('rpc_ingest_bus_location')
    ) as required(routine_name)
    where not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = required.routine_name
    )

    union all

    select 'public transport payment confirmation allows passenger self-confirmation'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rpc_confirm_bus_booking'
      and pg_get_functiondef(p.oid) like '%passenger_id = v_user_id%'

    union all

    select 'profiles organization_id missing'
    where not exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'profiles'
        and c.column_name = 'organization_id'
    )

    union all

    select 'admin rpc still contains direct role admin check'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'rpc_admin_%'
      and pg_get_functiondef(p.oid) like '%role = ''admin''%'

    union all

    select 'storage avatar update lacks WITH CHECK'
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'avatars_update_own'
      and with_check is null

    union all

    select 'out-of-scope legacy table still in realtime publication'
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
        'transactions',
        'sms_raw_queue',
        'payment_intents',
        'payment_events',
        'qr_payment_sessions',
        'nfc_payment_sessions'
      )

    union all

    select 'profile self-update policy does not preserve driver flag'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_own'
      and with_check not like '%is_driver%'

    union all

    select 'chat conversation client update grant still exists'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'chat_conversations'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type = 'UPDATE'

    union all

    select 'chat message content update grant still exists'
    from information_schema.column_privileges
    where table_schema = 'public'
      and table_name = 'chat_messages'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type = 'UPDATE'
      and column_name <> 'read_at'

    union all

    select 'broad chat update policy still exists'
    from pg_policies
    where schemaname = 'public'
      and tablename in ('chat_conversations', 'chat_messages')
      and policyname in (
        'chat_conversations_update_participants',
        'chat_messages_update_participants'
      )

    union all

    select 'dashboard stats still contains direct role admin check'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_dashboard_stats'
      and pg_get_functiondef(p.oid) like '%role = ''admin''%'

    union all

    select 'legacy storage policy still exists'
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'storage_%'

    union all

    select 'direct admin role check still exists in RLS policy'
    from pg_policies
    where schemaname in ('public', 'storage')
      and (
        coalesce(qual, '') like '%role%admin%'
        or coalesce(with_check, '') like '%role%admin%'
      )

    union all

    select 'tenant organization_id column still nullable'
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'organization_id'
      and is_nullable = 'YES'

    union all

    select 'required storage bucket missing'
    from (values
      ('avatars'),
      ('media'),
      ('promo-media'),
      ('tickets')
    ) as required(bucket_id)
    where not exists (
      select 1
      from storage.buckets b
      where b.id = required.bucket_id
    )

    union all

    select 'OTP rate limit RPC executable by clients'
    from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'consume_otp_rate_limit'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type = 'EXECUTE'

    union all

    select 'operational health RPC executable by anon/public'
    from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'rpc_admin_list_operational_health_events'
      and grantee in ('anon', 'PUBLIC')
      and privilege_type = 'EXECUTE'

    union all

    select 'legacy tenant table missing organization_id'
    from (values
      ('admin_whatsapp_numbers'),
      ('app_auth_attempts'),
      ('otp_codes'),
      ('promo_video_jobs'),
      ('saved_places')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = required.table_name
        and c.column_name = 'organization_id'
    )

    union all

    select 'campaign approval foundation missing'
    from (values
      ('campaign_approvals'),
      ('notification_consents')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = required.table_name
    )

    union all

    select 'report/block foundation table missing'
    from (values
      ('user_blocks'),
      ('user_reports')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = required.table_name
    )

    union all

    select 'report/block client direct write grant still exists'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in ('user_blocks', 'user_reports')
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')

    union all

    select 'report/block RPC missing'
    from (values
      ('rpc_is_user_blocked'),
      ('rpc_block_user'),
      ('rpc_unblock_user'),
      ('rpc_report_user'),
      ('rpc_admin_list_user_reports'),
      ('rpc_admin_review_user_report')
    ) as required(routine_name)
    where not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = required.routine_name
    )

    union all

    select 'chat conversation RPC does not enforce user blocks'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rpc_get_or_create_chat_conversation'
      and pg_get_functiondef(p.oid) not like '%user_blocks%'

    union all

    select 'chat insert policy does not enforce user blocks'
    from pg_policies
    where schemaname = 'public'
      and tablename = 'chat_messages'
      and policyname = 'chat_messages_insert_sender'
      and coalesce(with_check, '') not like '%user_blocks%'

    union all

    select 'admin report permission missing'
    from (values
      ('admin.reports.read'),
      ('admin.reports.manage')
    ) as required(permission_key)
    where not exists (
      select 1
      from public.platform_permissions permission
      where permission.permission_key = required.permission_key
    )

    union all

    select 'promo RPC still bypasses approval workflow'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rpc_admin_send_promo'
      and pg_get_functiondef(p.oid) not like '%rpc_admin_request_campaign_approval%'

    union all

    select 'promo campaign send does not require notification consent'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rpc_admin_send_approved_campaign'
      and pg_get_functiondef(p.oid) not like '%notification_consents%'

    union all

    select 'campaign approval list RPC missing'
    where not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'rpc_admin_list_campaign_approvals'
    )

    union all

    select 'searchable campaign approval list RPC missing'
    where not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'rpc_admin_list_campaign_approvals'
        and pg_get_function_arguments(p.oid) like '%p_search text%'
    )

    union all

	    select 'notification consent summary RPC missing'
	    where not exists (
	      select 1
	      from pg_proc p
	      join pg_namespace n on n.oid = p.pronamespace
	      where n.nspname = 'public'
	        and p.proname = 'rpc_admin_get_notification_consent_summary'
	    )

	    union all

	    select 'campaign audience preview RPC missing'
	    where not exists (
	      select 1
	      from pg_proc p
	      join pg_namespace n on n.oid = p.pronamespace
	      where n.nspname = 'public'
	        and p.proname = 'rpc_admin_get_campaign_audience_preview'
	    )

	    union all

	    select 'campaign audit timeline RPC missing'
	    where not exists (
	      select 1
	      from pg_proc p
	      join pg_namespace n on n.oid = p.pronamespace
	      where n.nspname = 'public'
	        and p.proname = 'rpc_admin_get_campaign_audit_timeline'
	    )

	    union all

	    select 'notification consent trend RPC missing'
	    where not exists (
	      select 1
	      from pg_proc p
	      join pg_namespace n on n.oid = p.pronamespace
	      where n.nspname = 'public'
	        and p.proname = 'rpc_admin_get_notification_consent_trend'
	    )

	    union all

	    select 'promo campaign send lacks zero-consent guard'
	    from pg_proc p
	    join pg_namespace n on n.oid = p.pronamespace
	    where n.nspname = 'public'
	      and p.proname = 'rpc_admin_send_approved_campaign'
	      and pg_get_functiondef(p.oid) not like '%No consenting recipients%'
	  )
  select string_agg(failure, E'\n')
  into v_failures
  from failures;

  if v_failures is not null then
    raise exception 'Backend security assertions failed:%', E'\n' || v_failures;
  end if;
end $$;

select 'backend security assertions passed' as ok;
