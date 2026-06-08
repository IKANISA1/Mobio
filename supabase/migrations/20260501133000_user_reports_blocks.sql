begin;

insert into public.platform_permissions (permission_key, description)
values
  ('admin.reports.read', 'Read user reports and block moderation records.'),
  ('admin.reports.manage', 'Resolve user reports and moderation records.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key, granted_by)
select p.id, permission.permission_key, p.id
from public.profiles p
cross join (values ('admin.reports.read'), ('admin.reports.manage')) as permission(permission_key)
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

create table if not exists public.user_blocks (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_blocks_pkey primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id),
  constraint user_blocks_reason_length check (reason is null or char_length(reason) <= 500)
);

create index if not exists idx_user_blocks_blocked
  on public.user_blocks (organization_id, blocked_id, created_at desc);

drop trigger if exists set_user_blocks_updated_at on public.user_blocks;
create trigger set_user_blocks_updated_at
  before update on public.user_blocks
  for each row
  execute function public.handle_updated_at();

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid references public.chat_conversations(id) on delete set null,
  trip_id uuid references public.trips(id) on delete set null,
  category text not null default 'other'
    check (category in ('harassment', 'spam', 'unsafe_behavior', 'fraud', 'other')),
  details text not null default '',
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  resolution_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_reports_no_self_report check (reporter_id <> reported_id),
  constraint user_reports_details_length check (char_length(details) <= 2000),
  constraint user_reports_resolution_notes_length check (
    resolution_notes is null or char_length(resolution_notes) <= 2000
  )
);

create index if not exists idx_user_reports_status_created
  on public.user_reports (organization_id, status, created_at desc);

create index if not exists idx_user_reports_reported
  on public.user_reports (organization_id, reported_id, created_at desc);

create index if not exists idx_user_reports_reporter
  on public.user_reports (organization_id, reporter_id, created_at desc);

drop trigger if exists set_user_reports_updated_at on public.user_reports;
create trigger set_user_reports_updated_at
  before update on public.user_reports
  for each row
  execute function public.handle_updated_at();

alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

revoke all on public.user_blocks from anon, authenticated;
revoke all on public.user_reports from anon, authenticated;
grant select on public.user_blocks to authenticated;
grant select on public.user_reports to authenticated;

drop policy if exists user_blocks_select_self_or_admin on public.user_blocks;
create policy user_blocks_select_self_or_admin
  on public.user_blocks
  for select
  to authenticated
  using (
    blocker_id = auth.uid()
    or public.has_platform_permission('admin.reports.read')
  );

drop policy if exists user_reports_select_self_or_admin on public.user_reports;
create policy user_reports_select_self_or_admin
  on public.user_reports
  for select
  to authenticated
  using (
    reporter_id = auth.uid()
    or public.has_platform_permission('admin.reports.read')
  );

create or replace function public.rpc_is_user_blocked(p_peer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and p_peer_id is not null
    and exists (
      select 1
      from public.user_blocks block_row
      where (
        block_row.blocker_id = auth.uid()
        and block_row.blocked_id = p_peer_id
      ) or (
        block_row.blocker_id = p_peer_id
        and block_row.blocked_id = auth.uid()
      )
    );
$$;

create or replace function public.rpc_block_user(
  p_blocked_id uuid,
  p_reason text default null
)
returns public.user_blocks
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
  v_organization_id uuid;
  v_block public.user_blocks%rowtype;
begin
  if v_self_id is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;

  if p_blocked_id is null or p_blocked_id = v_self_id then
    raise exception using errcode = '22023', message = 'INVALID_BLOCK_TARGET';
  end if;

  select profile.organization_id
  into v_organization_id
  from public.profiles profile
  where profile.id = v_self_id;

  if v_organization_id is null then
    raise exception using errcode = '28000', message = 'PROFILE_REQUIRED';
  end if;

  if not exists (select 1 from public.profiles profile where profile.id = p_blocked_id) then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;

  insert into public.user_blocks (
    organization_id,
    blocker_id,
    blocked_id,
    reason
  )
  values (
    v_organization_id,
    v_self_id,
    p_blocked_id,
    nullif(left(trim(coalesce(p_reason, '')), 500), '')
  )
  on conflict (blocker_id, blocked_id) do update
  set
    organization_id = excluded.organization_id,
    reason = excluded.reason,
    updated_at = now()
  returning *
  into v_block;

  update public.chat_conversations conversation
  set status = 'closed',
      updated_at = now()
  where status = 'active'
    and v_self_id in (conversation.participant_low_id, conversation.participant_high_id)
    and p_blocked_id in (conversation.participant_low_id, conversation.participant_high_id);

  return v_block;
end;
$$;

create or replace function public.rpc_unblock_user(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
begin
  if v_self_id is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;

  delete from public.user_blocks
  where blocker_id = v_self_id
    and blocked_id = p_blocked_id;
end;
$$;

create or replace function public.rpc_report_user(
  p_reported_id uuid,
  p_conversation_id uuid default null,
  p_trip_id uuid default null,
  p_category text default 'other',
  p_details text default ''
)
returns public.user_reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
  v_organization_id uuid;
  v_category text := lower(coalesce(nullif(trim(p_category), ''), 'other'));
  v_report public.user_reports%rowtype;
begin
  if v_self_id is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;

  if p_reported_id is null or p_reported_id = v_self_id then
    raise exception using errcode = '22023', message = 'INVALID_REPORT_TARGET';
  end if;

  if v_category not in ('harassment', 'spam', 'unsafe_behavior', 'fraud', 'other') then
    v_category := 'other';
  end if;

  select profile.organization_id
  into v_organization_id
  from public.profiles profile
  where profile.id = v_self_id;

  if v_organization_id is null then
    raise exception using errcode = '28000', message = 'PROFILE_REQUIRED';
  end if;

  if not exists (select 1 from public.profiles profile where profile.id = p_reported_id) then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;

  if p_conversation_id is not null and not exists (
    select 1
    from public.chat_conversations conversation
    where conversation.id = p_conversation_id
      and v_self_id in (conversation.participant_low_id, conversation.participant_high_id)
      and p_reported_id in (conversation.participant_low_id, conversation.participant_high_id)
  ) then
    raise exception using errcode = '42501', message = 'REPORT_CONVERSATION_FORBIDDEN';
  end if;

  insert into public.user_reports (
    organization_id,
    reporter_id,
    reported_id,
    conversation_id,
    trip_id,
    category,
    details
  )
  values (
    v_organization_id,
    v_self_id,
    p_reported_id,
    p_conversation_id,
    p_trip_id,
    v_category,
    left(trim(coalesce(p_details, '')), 2000)
  )
  returning *
  into v_report;

  return v_report;
end;
$$;

create or replace function public.rpc_admin_list_user_reports(
  p_status text default 'open',
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  reporter_id uuid,
  reporter_name text,
  reporter_phone text,
  reported_id uuid,
  reported_name text,
  reported_phone text,
  conversation_id uuid,
  trip_id uuid,
  category text,
  details text,
  status text,
  resolution_notes text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status text := lower(coalesce(nullif(trim(p_status), ''), 'open'));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not public.has_platform_permission('admin.reports.read') then
    raise exception using
      errcode = '42501',
      message = 'Forbidden: admin.reports.read permission required';
  end if;

  return query
  select
    report.id,
    report.reporter_id,
    coalesce(reporter.display_name, reporter.name, reporter.phone, reporter.id::text) as reporter_name,
    reporter.phone as reporter_phone,
    report.reported_id,
    coalesce(reported.display_name, reported.name, reported.phone, reported.id::text) as reported_name,
    reported.phone as reported_phone,
    report.conversation_id,
    report.trip_id,
    report.category,
    report.details,
    report.status,
    report.resolution_notes,
    report.reviewed_by,
    report.reviewed_at,
    report.created_at
  from public.user_reports report
  left join public.profiles reporter on reporter.id = report.reporter_id
  left join public.profiles reported on reported.id = report.reported_id
  where (
      v_status = 'all'
      or report.status = v_status
    )
    and (
      v_search is null
      or report.category ilike '%' || v_search || '%'
      or report.details ilike '%' || v_search || '%'
      or coalesce(reporter.display_name, reporter.name, reporter.phone, '') ilike '%' || v_search || '%'
      or coalesce(reported.display_name, reported.name, reported.phone, '') ilike '%' || v_search || '%'
    )
  order by
    case report.status when 'open' then 0 when 'reviewing' then 1 else 2 end,
    report.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

create or replace function public.rpc_admin_review_user_report(
  p_report_id uuid,
  p_status text,
  p_resolution_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := lower(coalesce(nullif(trim(p_status), ''), ''));
begin
  if not public.has_platform_permission('admin.reports.manage') then
    raise exception using
      errcode = '42501',
      message = 'Forbidden: admin.reports.manage permission required';
  end if;

  if v_status not in ('open', 'reviewing', 'resolved', 'dismissed') then
    raise exception using errcode = '22023', message = 'INVALID_REPORT_STATUS';
  end if;

  update public.user_reports
  set status = v_status,
      resolution_notes = nullif(left(trim(coalesce(p_resolution_notes, '')), 2000), ''),
      reviewed_by = auth.uid(),
      reviewed_at = case
        when v_status in ('resolved', 'dismissed') then now()
        else reviewed_at
      end,
      updated_at = now()
  where id = p_report_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'REPORT_NOT_FOUND';
  end if;
end;
$$;

create or replace function public.rpc_get_or_create_chat_conversation(
  p_peer_id uuid,
  p_trip_id uuid default null
)
returns public.chat_conversations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_self_id uuid := auth.uid();
  v_trip public.trips%rowtype;
  v_conversation public.chat_conversations%rowtype;
  v_low_id uuid;
  v_high_id uuid;
  v_context_type text := case when p_trip_id is null then 'direct' else 'trip' end;
begin
  if v_self_id is null then
    raise exception 'Authentication required';
  end if;

  if p_peer_id is null or p_peer_id = v_self_id then
    raise exception 'A different peer is required';
  end if;

  if exists (
    select 1
    from public.user_blocks block_row
    where (
      block_row.blocker_id = v_self_id
      and block_row.blocked_id = p_peer_id
    ) or (
      block_row.blocker_id = p_peer_id
      and block_row.blocked_id = v_self_id
    )
  ) then
    raise exception using errcode = '42501', message = 'USER_BLOCKED';
  end if;

  if p_trip_id is not null then
    select *
    into v_trip
    from public.trips
    where id = p_trip_id;

    if not found then
      raise exception 'Trip not found';
    end if;

    if v_self_id <> v_trip.author_id and p_peer_id <> v_trip.author_id then
      raise exception 'Trip chat must include the trip author';
    end if;
  end if;

  v_low_id := least(v_self_id, p_peer_id);
  v_high_id := greatest(v_self_id, p_peer_id);

  select *
  into v_conversation
  from public.chat_conversations
  where participant_low_id = v_low_id
    and participant_high_id = v_high_id
    and (
      (p_trip_id is null and trip_id is null and context_type = 'direct')
      or trip_id = p_trip_id
    )
  limit 1;

  if found then
    return v_conversation;
  end if;

  insert into public.chat_conversations (
    trip_id,
    participant_low_id,
    participant_high_id,
    created_by,
    context_type
  )
  values (
    p_trip_id,
    v_low_id,
    v_high_id,
    v_self_id,
    v_context_type
  )
  returning *
  into v_conversation;

  insert into public.chat_messages (
    conversation_id,
    sender_id,
    message_type,
    body,
    metadata
  )
  values (
    v_conversation.id,
    null,
    'system',
    'Chat started in MOBI. Keep trip planning, pricing, and pickup details here without sharing personal contact details.',
    jsonb_build_object('seed', 'privacy_notice')
  );

  return v_conversation;
end;
$$;

drop policy if exists chat_messages_insert_sender on public.chat_messages;
create policy chat_messages_insert_sender
  on public.chat_messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.chat_conversations as conversation
      where conversation.id = conversation_id
        and auth.uid() in (
          conversation.participant_low_id,
          conversation.participant_high_id
        )
        and not exists (
          select 1
          from public.user_blocks block_row
          where (
            block_row.blocker_id = conversation.participant_low_id
            and block_row.blocked_id = conversation.participant_high_id
          ) or (
            block_row.blocker_id = conversation.participant_high_id
            and block_row.blocked_id = conversation.participant_low_id
          )
        )
    )
  );

revoke all on function public.rpc_is_user_blocked(uuid) from public, anon, authenticated;
revoke all on function public.rpc_block_user(uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_unblock_user(uuid) from public, anon, authenticated;
revoke all on function public.rpc_report_user(uuid, uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.rpc_admin_list_user_reports(text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.rpc_admin_review_user_report(uuid, text, text) from public, anon, authenticated;

grant execute on function public.rpc_is_user_blocked(uuid) to authenticated;
grant execute on function public.rpc_block_user(uuid, text) to authenticated;
grant execute on function public.rpc_unblock_user(uuid) to authenticated;
grant execute on function public.rpc_report_user(uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.rpc_admin_list_user_reports(text, text, integer, integer) to authenticated;
grant execute on function public.rpc_admin_review_user_report(uuid, text, text) to authenticated;

commit;
