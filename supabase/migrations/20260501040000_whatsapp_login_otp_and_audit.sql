begin;

-- Separate app login OTPs from admin-login OTPs so a code requested from one
-- surface cannot be replayed on another surface.
alter table public.otp_codes
  add column if not exists purpose text;

update public.otp_codes
set purpose = 'admin_login'
where purpose is null;

alter table public.otp_codes
  alter column purpose set default 'admin_login',
  alter column purpose set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'otp_codes_purpose_check'
      and conrelid = 'public.otp_codes'::regclass
  ) then
    alter table public.otp_codes
      add constraint otp_codes_purpose_check
      check (purpose in ('admin_login', 'app_login'));
  end if;
end $$;

create index if not exists idx_otp_phone_purpose_created
  on public.otp_codes(phone, purpose, created_at desc);

create table if not exists public.app_auth_attempts (
  id uuid primary key default gen_random_uuid(),
  phone_e164 text not null,
  requested_role text not null default 'passenger',
  user_id uuid references public.profiles(id) on delete set null,
  status text not null,
  reason text,
  source_app text not null default 'unknown',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint app_auth_attempts_phone_e164_check
    check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  constraint app_auth_attempts_requested_role_check
    check (requested_role in ('passenger', 'driver'))
);

alter table public.app_auth_attempts
  add column if not exists requested_role text,
  add column if not exists user_id uuid references public.profiles(id) on delete set null,
  add column if not exists status text,
  add column if not exists reason text,
  add column if not exists source_app text,
  add column if not exists metadata jsonb,
  add column if not exists created_at timestamptz;

update public.app_auth_attempts
set requested_role = 'passenger'
where requested_role is null;

update public.app_auth_attempts
set source_app = 'unknown'
where source_app is null;

update public.app_auth_attempts
set metadata = '{}'::jsonb
where metadata is null;

update public.app_auth_attempts
set created_at = timezone('utc', now())
where created_at is null;

alter table public.app_auth_attempts
  alter column phone_e164 set not null,
  alter column requested_role set default 'passenger',
  alter column requested_role set not null,
  alter column status set not null,
  alter column source_app set default 'unknown',
  alter column source_app set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

create index if not exists idx_app_auth_attempts_created
  on public.app_auth_attempts(created_at desc);

create index if not exists idx_app_auth_attempts_phone_created
  on public.app_auth_attempts(phone_e164, created_at desc);

create index if not exists idx_app_auth_attempts_user_created
  on public.app_auth_attempts(user_id, created_at desc);

alter table public.app_auth_attempts enable row level security;

revoke all on public.app_auth_attempts from anon, authenticated;
grant all on public.app_auth_attempts to service_role;

commit;
