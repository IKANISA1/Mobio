-- Forward migration BODY. Generate a timestamp using the Supabase CLI installer.
-- No historical migration is changed. Rehearse legitimate RPCs before deployment.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
alter table public.bus_bookings enable row level security;
revoke insert, update, delete, truncate on table public.bus_bookings from public, anon, authenticated;
do $guard$
declare columns_sql text; role_name text;
begin
  select string_agg(quote_ident(attname), ', ' order by attnum) into columns_sql
  from pg_catalog.pg_attribute
  where attrelid='public.bus_bookings'::regclass and attnum>0 and not attisdropped;
  if columns_sql is null then raise exception 'BOOKING_SCHEMA_MISSING'; end if;
  execute format('revoke insert (%s), update (%s) on table public.bus_bookings from public, anon, authenticated',columns_sql,columns_sql);
  foreach role_name in array array['anon','authenticated'] loop
    if pg_catalog.has_table_privilege(role_name,'public.bus_bookings','INSERT,UPDATE,DELETE,TRUNCATE')
       or pg_catalog.has_any_column_privilege(role_name,'public.bus_bookings','INSERT')
       or pg_catalog.has_any_column_privilege(role_name,'public.bus_bookings','UPDATE') then
      raise exception 'BOOKING_WRITE_GRANT_REMAINS: %',role_name;
    end if;
  end loop;
end;
$guard$;
drop policy if exists bus_bookings_update_owner_hold_or_agency on public.bus_bookings;
-- SELECT policies/grants and authorized server RPCs are retained.
notify pgrst, 'reload schema';
commit;
