-- Disposable isolated database only. Synthetic users and notifications are
-- rolled back. This checks publication membership and actual SQL-role access;
-- it does not connect a Realtime client or prove websocket delivery.
begin;

create temp table qa_notification_results (name text);
create temp table qa_notification_actors (name text primary key, user_id uuid, session_id uuid default gen_random_uuid());
create temp table qa_notification_rows (name text primary key, id uuid);
grant select, insert on qa_notification_results to authenticated;
grant select on qa_notification_actors, qa_notification_rows to authenticated;

create function pg_temp.qa_check(label text, value boolean) returns void
language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'ASSERTION FAILED: %', label;
  end if;
  insert into pg_temp.qa_notification_results values (label);
end;
$$;

select pg_temp.qa_check('notification inserts are published', exists (
  select 1 from pg_publication_tables t
  join pg_publication p on p.pubname = t.pubname
  where t.pubname = 'supabase_realtime' and t.schemaname = 'public'
    and t.tablename = 'notifications' and p.pubinsert
));
select pg_temp.qa_check('notifications retain row level security', (
  select relrowsecurity from pg_class where oid = 'public.notifications'::regclass
));
select pg_temp.qa_check('anonymous role cannot read notifications',
  not has_table_privilege('anon', 'public.notifications', 'SELECT'));
select pg_temp.qa_check('client role cannot create or delete notifications',
  not has_table_privilege('authenticated', 'public.notifications', 'INSERT')
  and not has_table_privilege('authenticated', 'public.notifications', 'DELETE'));

-- Actual Auth/profile foreign keys and signup triggers. No FCM token is added;
-- explicit in-app-only metadata also prevents a push request from being queued.
with inserted as (
  insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data)
  values (gen_random_uuid(), '+250700002001', now(), '{"provider":"whatsapp_cloud_otp"}', '{}') returning id
) insert into qa_notification_actors(name, user_id) select 'A', id from inserted;
with inserted as (
  insert into auth.users(id, phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data)
  values (gen_random_uuid(), '+250700002002', now(), '{"provider":"whatsapp_cloud_otp"}', '{}') returning id
) insert into qa_notification_actors(name, user_id) select 'B', id from inserted;
insert into auth.sessions(id, user_id, created_at, not_after)
select session_id, user_id, now(), now()+interval '1 hour' from qa_notification_actors;
with inserted as (
  insert into public.notifications(user_id, title, type, metadata)
  select user_id, 'Synthetic owner notification', 'system_announcement',
    '{"channels":["in_app"]}'::jsonb from qa_notification_actors
  returning id, user_id
) insert into qa_notification_rows
  select a.name, i.id from inserted i join qa_notification_actors a using(user_id);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  (select user_id::text from qa_notification_actors where name = 'A'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select user_id from qa_notification_actors where name = 'A'),
  'session_id', (select session_id from qa_notification_actors where name = 'A'),
  'role', 'authenticated', 'is_anonymous', false)::text, true);

select pg_temp.qa_check('actor A can read only its own fixture', (
  select count(*) = 1 and bool_and(user_id = auth.uid())
  from public.notifications where id in (select id from qa_notification_rows)
));
select pg_temp.qa_check('explicit foreign notification lookup returns no row',
  not exists (select 1 from public.notifications
    where id = (select id from qa_notification_rows where name = 'B')));

do $$
declare v_count integer;
begin
  update public.notifications set is_read = true
    where id = (select id from pg_temp.qa_notification_rows where name = 'A');
  get diagnostics v_count = row_count;
  perform pg_temp.qa_check('actor A can mark its notification read', v_count = 1);
  update public.notifications set is_read = true
    where id = (select id from pg_temp.qa_notification_rows where name = 'B');
  get diagnostics v_count = row_count;
  perform pg_temp.qa_check('actor A cannot update the other notification', v_count = 0);
  begin
    update public.notifications
      set user_id = (select user_id from pg_temp.qa_notification_actors where name = 'B')
      where id = (select id from pg_temp.qa_notification_rows where name = 'A');
    raise exception 'Ownership transfer unexpectedly succeeded';
  exception when insufficient_privilege then
    perform pg_temp.qa_check('owner cannot transfer a notification to another user', true);
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select pg_temp.qa_check('authenticated role without a user sees no fixture',
  not exists (select 1 from public.notifications
    where id in (select id from qa_notification_rows)));

select set_config('request.jwt.claim.sub',
  (select user_id::text from qa_notification_actors where name = 'B'), true);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select user_id from qa_notification_actors where name = 'B'),
  'session_id', (select session_id from qa_notification_actors where name = 'B'),
  'role', 'authenticated', 'is_anonymous', false)::text, true);
select pg_temp.qa_check('actor B can read only its own unchanged notification', (
  select count(*) = 1 and bool_and(user_id = auth.uid() and not is_read)
  from public.notifications where id in (select id from qa_notification_rows)
));

reset role;
select name as passed_assertion from qa_notification_results order by name;
select count(*) as passed_assertions from qa_notification_results;
rollback;
