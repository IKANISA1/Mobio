begin;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'general',
  title text not null,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.notifications
  add column if not exists type text,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists metadata jsonb,
  add column if not exists is_read boolean,
  add column if not exists created_at timestamptz;

update public.notifications
set type = 'general'
where type is null;

update public.notifications
set title = ''
where title is null;

update public.notifications
set metadata = '{}'::jsonb
where metadata is null;

update public.notifications
set is_read = false
where is_read is null;

update public.notifications
set created_at = timezone('utc', now())
where created_at is null;

alter table public.notifications
  alter column user_id set not null,
  alter column type set default 'general',
  alter column type set not null,
  alter column title set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  alter column is_read set default false,
  alter column is_read set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null;

create index if not exists idx_notifications_user_created
  on public.notifications(user_id, created_at desc);

create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, is_read, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Users can view own notifications" on public.notifications;
create policy "Users can view own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
  on public.notifications for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.notifications from anon, authenticated;
grant select, update on public.notifications to authenticated;
grant all on public.notifications to service_role;

commit;
