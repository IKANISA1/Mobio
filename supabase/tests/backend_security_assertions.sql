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

    select 'public/anon QR session table read still granted'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in ('qr_payment_sessions', 'nfc_payment_sessions')
      and grantee in ('anon', 'PUBLIC')
      and privilege_type = 'SELECT'

    union all

    select 'client payment intent write grant still exists'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'payment_intents'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')

    union all

    select 'client payment event write grant still exists'
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'payment_events'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')

    union all

    select 'client payment insert policy still exists'
    from pg_policies
    where schemaname = 'public'
      and tablename in ('payment_intents', 'payment_events')
      and policyname in ('Users insert own intents', 'Users insert own events')

    union all

    select 'payment_events provenance column missing'
    from (values
      ('amount'),
      ('currency'),
      ('payment_method'),
      ('source'),
      ('metadata')
    ) as required(column_name)
    where not exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'payment_events'
        and c.column_name = required.column_name
    )

    union all

    select 'legacy BioPay transfer RPC still executable by clients'
    from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in (
        'fn_biopay_generate_qr',
        'fn_biopay_resolve_qr_payload',
        'fn_biopay_scan_and_charge',
        'rpc_get_biopay_wallet',
        'rpc_update_biopay_handle'
      )
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type = 'EXECUTE'

    union all

    select 'tenant foundation table missing'
    from (values
      ('organizations'),
      ('organization_members'),
      ('platform_permissions'),
      ('profile_platform_permissions')
    ) as required(table_name)
    where not exists (
      select 1
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_name = required.table_name
    )

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

    select 'sensitive payment table still in realtime publication'
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
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

    select 'legacy tenant table missing organization_id'
    from (values
      ('admin_whatsapp_numbers'),
      ('app_auth_attempts'),
      ('biopay_abuse_reports'),
      ('biopay_enrollment_audit'),
      ('biopay_face_embeddings'),
      ('biopay_match_audit'),
      ('biopay_match_rate_limits'),
      ('biopay_profiles'),
      ('biopay_rate_limits'),
      ('biopay_transactions'),
      ('biopay_wallets'),
      ('otp_codes'),
      ('promo_video_jobs'),
      ('ride_requests'),
      ('saved_places'),
      ('trip_requests')
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
  )
  select string_agg(failure, E'\n')
  into v_failures
  from failures;

  if v_failures is not null then
    raise exception 'Backend security assertions failed:%', E'\n' || v_failures;
  end if;
end $$;

select 'backend security assertions passed' as ok;
