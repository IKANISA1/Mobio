-- Final Mobio production-scope cleanup after linked/local migration history.
-- Some local and linked environments include later operational migrations that
-- reintroduce PayLedger SMS tables and role-based parser policies. This
-- forward migration keeps the final schema aligned to Mobio's limited
-- discovery, scheduled-post, and communication scope.

do $$
declare
  legacy_table text;
begin
  foreach legacy_table in array array[
    'transactions',
    'sms_raw_queue'
  ]
  loop
    if exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = legacy_table
    ) then
      execute format(
        'alter publication supabase_realtime drop table public.%I',
        legacy_table
      );
    end if;
  end loop;
end $$;

drop table if exists public.transactions cascade;
drop table if exists public.sms_raw_queue cascade;

alter table public.countries
  drop column if exists sender_id;

do $$
begin
  if to_regclass('public.parser_alert_thresholds') is not null then
    drop policy if exists parser_alert_thresholds_admin_select
      on public.parser_alert_thresholds;

    create policy parser_alert_thresholds_admin_select
      on public.parser_alert_thresholds
      for select
      to authenticated
      using (public.has_platform_permission('admin.operations.read'));
  end if;
end $$;

do $$
begin
  if to_regclass('public.admin_audit_logs') is not null then
    update public.admin_audit_logs
    set organization_id = public.default_organization_id()
    where organization_id is null;

    alter table public.admin_audit_logs
      alter column organization_id set default public.default_organization_id(),
      alter column organization_id set not null;
  end if;
end $$;
