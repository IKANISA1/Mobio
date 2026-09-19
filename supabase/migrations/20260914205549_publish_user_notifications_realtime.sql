-- The existing native notification listener subscribes to inserts on this
-- table. Its owner-scoped SELECT/UPDATE policies and client grants stay intact.
begin;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

commit;
