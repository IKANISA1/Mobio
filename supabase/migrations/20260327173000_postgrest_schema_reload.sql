begin;

-- Force hosted PostgREST to refresh its schema/config cache after the
-- late-March profile and BioPay compatibility migrations.
select pg_notify('pgrst', 'reload schema');
select pg_notify('pgrst', 'reload config');

commit;
