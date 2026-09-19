-- Execute after a fresh migration replay in a disposable database only.
-- The transaction rolls back the update to the migration-seeded charger.
begin;

do $$
declare
  v_updated_at timestamptz;
begin
  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgrelid = 'public.ev_chargers'::regclass
      and tgname = 'set_ev_chargers_updated_at'
      and tgfoid = 'public.handle_updated_at()'::regprocedure
      and not tgisinternal
  ) then
    raise exception 'EV charger updates must use the timestamp helper from the migration chain';
  end if;

  update public.ev_chargers
  set name = name, updated_at = '2000-01-01T00:00:00Z'
  where id = (select id from public.ev_chargers order by id limit 1)
  returning updated_at into v_updated_at;

  if v_updated_at is distinct from now() then
    raise exception 'EV charger update did not refresh updated_at';
  end if;
end $$;

select 'Fresh schema replay and EV charger timestamp behavior passed' as ok;
rollback;
