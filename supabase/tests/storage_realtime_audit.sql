-- Storage and realtime exposure audit.
-- Expected blocking result: zero rows with severity = 'failure'.

select
  'failure' as severity,
  'legacy_storage_policy' as check_name,
  policyname as object_name,
  'Legacy storage_% policy remains on storage.objects.' as detail
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname like 'storage_%'

union all

select
  'failure',
  'jwt_role_storage_policy',
  policyname,
  'Storage policy still depends on mutable JWT role strings instead of explicit permissions.'
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    coalesce(qual, '') like '%auth.jwt()%role%'
    or coalesce(with_check, '') like '%auth.jwt()%role%'
    or coalesce(qual, '') like '%role%admin%'
    or coalesce(with_check, '') like '%role%admin%'
  )

union all

select
  'failure',
  'sensitive_table_in_realtime',
  tablename,
  'Sensitive table is exposed through supabase_realtime.'
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in (
    'admin_access_attempts',
    'admin_audit_log',
    'admin_audit_logs',
    'app_auth_attempts',
    'campaign_approvals',
    'notification_consents',
    'otp_codes',
    'payment_events',
    'payment_intents',
    'profiles',
    'qr_payment_sessions',
    'nfc_payment_sessions',
    'risk_flags',
    'sms_raw_queue'
  )

union all

select
  'failure',
  'realtime_table_without_rls',
  pub.tablename,
  'Realtime table does not have RLS enabled.'
from pg_publication_tables pub
join pg_tables table_meta
  on table_meta.schemaname = pub.schemaname
 and table_meta.tablename = pub.tablename
where pub.pubname = 'supabase_realtime'
  and pub.schemaname = 'public'
  and table_meta.rowsecurity = false

union all

select
  'warning',
  'public_bucket_review',
  bucket.id,
  'Public bucket should have bounded MIME types and size limits unless intentionally unrestricted.'
from storage.buckets bucket
where bucket.public = true
  and bucket.id not in ('public-assets')
  and (
    bucket.file_size_limit is null
    or bucket.allowed_mime_types is null
  )

order by severity, check_name, object_name;
