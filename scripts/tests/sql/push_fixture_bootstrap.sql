-- ISOLATED COMPONENT FIXTURE ONLY. Never apply to a real Supabase project.
-- Synthetic Auth/identity/catalog tables intentionally replace the full schema.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create schema mobio_private;
revoke all on schema mobio_private from public;
create table auth.users (
  id uuid primary key, deleted_at timestamptz, banned_until timestamptz,
  is_anonymous boolean not null default false, phone_confirmed_at timestamptz,
  raw_app_meta_data jsonb not null default '{}'::jsonb
);
create table auth.sessions (id uuid primary key, user_id uuid references auth.users, not_after timestamptz);
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
create table public.profiles(id uuid primary key references auth.users, organization_id uuid);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles,
  type text not null, metadata jsonb not null default '{}'::jsonb, organization_id uuid,
  title text not null default 'Synthetic private title',body text not null default 'Synthetic private body',
  created_at timestamptz not null default clock_timestamp()
);
create table public.notification_type_catalog (
  type text primary key, requires_promotional_consent boolean not null default false,
  default_channels text[] not null default array['in_app','push']
);
create table public.notification_consents (
  profile_id uuid not null references public.profiles, organization_id uuid,
  consent_type text not null, channel text not null,
  status text not null check(status in('granted','denied','unknown','revoked')),
  primary key(profile_id,consent_type,channel)
);
create table public.fcm_tokens (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
  token text not null unique,platform text not null,last_seen_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),revoked_at timestamptz
);
alter table public.fcm_tokens enable row level security;
grant all on public.fcm_tokens to authenticated,service_role;
-- Deliberate historical column privilege: table REVOKE is not sufficient.
grant update(user_id) on public.fcm_tokens to authenticated;
create function public.verified_app_user_id() returns uuid language sql stable security definer set search_path='' as $$
  select u.id from auth.users u join auth.sessions s on s.user_id=u.id
  where u.id=(auth.jwt()->>'sub')::uuid and s.id=(auth.jwt()->>'session_id')::uuid
    and auth.jwt()->>'role'='authenticated' and not u.is_anonymous
    and u.phone_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=statement_timestamp())
    and (s.not_after is null or s.not_after>statement_timestamp())
$$;
create function public.verified_admin_user_id() returns uuid language sql stable security definer set search_path='' as $$
  select case when current_setting('fixture.admin',true)='true' then public.verified_app_user_id() else null end
$$;
create function public._mobio_is_service_role() returns boolean language sql stable as $$
  select current_setting('role',true)='service_role'
$$;
create function public.fn_send_push_on_notification() returns trigger language plpgsql as $$
begin return new; end $$;
create trigger push_for_new_notification after insert on public.notifications
  for each row execute function public.fn_send_push_on_notification();
insert into auth.users(id,phone_confirmed_at,raw_app_meta_data) values
 ('00000000-0000-4000-8000-000000000001',clock_timestamp(),'{"provider":"whatsapp_cloud_otp"}'),
 ('00000000-0000-4000-8000-000000000002',clock_timestamp(),'{"provider":"whatsapp_cloud_otp"}');
insert into auth.sessions(id,user_id) values
 ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000002');
insert into public.profiles select id,'00000000-0000-4000-8000-000000000900' from auth.users;
insert into public.notification_type_catalog(type,requires_promotional_consent) values
 ('chat_message',false),('promo',true);
