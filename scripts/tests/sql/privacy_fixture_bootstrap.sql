-- ISOLATED SYNTHETIC PREREQUISITES ONLY. NEVER APPLY TO A USER PROJECT.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create schema mobio_private;
revoke all on schema mobio_private from public;
create table auth.users(id uuid primary key,is_anonymous boolean not null default false,deleted_at timestamptz);
create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id),created_at timestamptz not null default clock_timestamp(),not_after timestamptz);
create function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
create function public.verified_app_user_id() returns uuid language sql stable security definer set search_path='' as $$
 select u.id from auth.users u join auth.sessions s on s.user_id=u.id
 where u.id=(auth.jwt()->>'sub')::uuid and s.id=(auth.jwt()->>'session_id')::uuid
 and auth.jwt()->>'role'='authenticated' and not u.is_anonymous and u.deleted_at is null
 and (s.not_after is null or s.not_after>statement_timestamp())
$$;
create function public.verified_admin_user_id() returns uuid language sql stable as $$
 select case when current_setting('fixture.admin',true)='true' then public.verified_app_user_id() else null end
$$;
create function public.require_recent_admin_session() returns uuid language sql as $$ select public.verified_admin_user_id() $$;
create function public._mobio_is_service_role() returns boolean language sql stable as $$ select current_setting('role',true)='service_role' $$;
insert into auth.users(id) values('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
insert into auth.sessions(id,user_id) values
 ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000002');
