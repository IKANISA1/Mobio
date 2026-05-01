begin;

-- Security hardening follow-up:
-- - Prevent direct profile updates from escalating driver/admin-like flags.
-- - Restrict chat updates to read receipts only.
-- - Move dashboard stats authorization from role text to explicit permissions.
-- - Require verified WhatsApp sessions before driver-mode escalation.

insert into public.platform_permissions (permission_key, description)
values
  ('admin.dashboard.read', 'Read aggregate platform dashboard statistics.')
on conflict (permission_key) do update
set description = excluded.description;

insert into public.profile_platform_permissions (profile_id, permission_key, granted_by)
select p.id, 'admin.dashboard.read', p.id
from public.profiles p
where p.role = 'admin'
on conflict (profile_id, permission_key) do nothing;

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    and role is not distinct from (
      select existing.role
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and is_driver is not distinct from (
      select existing.is_driver
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and is_online is not distinct from (
      select existing.is_online
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and member_id is not distinct from (
      select existing.member_id
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and organization_id is not distinct from (
      select existing.organization_id
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and whatsapp_verified_at is not distinct from (
      select existing.whatsapp_verified_at
      from public.profiles as existing
      where existing.id = auth.uid()
    )
    and auth_provider is not distinct from (
      select existing.auth_provider
      from public.profiles as existing
      where existing.id = auth.uid()
    )
  );

drop policy if exists chat_conversations_update_participants on public.chat_conversations;
revoke update on public.chat_conversations from anon, authenticated;
grant select on public.chat_conversations to authenticated;

drop policy if exists chat_messages_update_participants on public.chat_messages;
drop policy if exists chat_messages_mark_peer_read on public.chat_messages;
create policy chat_messages_mark_peer_read
  on public.chat_messages
  for update
  to authenticated
  using (
    sender_id is distinct from auth.uid()
    and exists (
      select 1
      from public.chat_conversations as conversation
      where conversation.id = conversation_id
        and auth.uid() in (
          conversation.participant_low_id,
          conversation.participant_high_id
        )
    )
  )
  with check (
    sender_id is distinct from auth.uid()
    and exists (
      select 1
      from public.chat_conversations as conversation
      where conversation.id = conversation_id
        and auth.uid() in (
          conversation.participant_low_id,
          conversation.participant_high_id
        )
    )
  );

revoke update on public.chat_messages from anon, authenticated;
grant update (read_at) on public.chat_messages to authenticated;

create or replace function public.prevent_chat_message_content_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.conversation_id is distinct from new.conversation_id
    or old.sender_id is distinct from new.sender_id
    or old.message_type is distinct from new.message_type
    or old.body is distinct from new.body
    or old.metadata is distinct from new.metadata
    or old.created_at is distinct from new.created_at
    or old.organization_id is distinct from new.organization_id
  then
    raise exception using
      errcode = '42501',
      message = 'chat message content is immutable';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_chat_message_content_mutation
  on public.chat_messages;
create trigger prevent_chat_message_content_mutation
  before update on public.chat_messages
  for each row
  execute function public.prevent_chat_message_content_mutation();

revoke all on function public.prevent_chat_message_content_mutation()
  from public, anon, authenticated;

create or replace function public.get_dashboard_stats()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  result json;
begin
  if not public.has_platform_permission('admin.dashboard.read') then
    raise exception using
      errcode = '42501',
      message = 'Forbidden: admin.dashboard.read permission required';
  end if;

  select json_build_object(
    'total_users',       (select count(*) from public.profiles),
    'active_drivers',    (select count(*) from public.profiles where role = 'driver' or is_driver = true),
    'active_passengers', (select count(*) from public.profiles where role = 'passenger'),
    'total_trips',       (select count(*) from public.trips),
    'active_trips',      (select count(*) from public.trips where status = 'active' and is_active = true),
    'cancelled_trips',   (select count(*) from public.trips where status = 'cancelled'),
    'completed_trips',   (select count(*) from public.trips where status = 'completed')
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_dashboard_stats() from public, anon, authenticated;
grant execute on function public.get_dashboard_stats() to authenticated;

drop function if exists public.rpc_enable_driver_mode(text);
create or replace function public.rpc_enable_driver_mode(
  p_vehicle_type text default 'cab',
  p_vehicle_number_plate text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_anonymous boolean :=
    coalesce((auth.jwt()->>'is_anonymous')::boolean, false);
  v_profile public.profiles%rowtype;
begin
  if v_user_id is null or v_is_anonymous then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires WhatsApp Cloud API login.';
  end if;

  select *
  into v_profile
  from public.profiles
  where id = v_user_id;

  if not found
    or v_profile.whatsapp_verified_at is null
    or coalesce(v_profile.auth_provider, '') <> 'whatsapp_cloud_otp'
  then
    raise exception using
      errcode = '28000',
      message = 'WHATSAPP_LOGIN_REQUIRED',
      detail = 'Driver mode requires a verified WhatsApp account.';
  end if;

  update public.profiles
  set
    is_driver = true,
    vehicle_type = p_vehicle_type::vehicle_type_enum,
    vehicle_number_plate = coalesce(
      nullif(upper(trim(p_vehicle_number_plate)), ''),
      vehicle_number_plate
    ),
    role = 'driver'
  where id = v_user_id;
end;
$$;

revoke all on function public.rpc_enable_driver_mode(text, text)
  from public, anon, authenticated;
grant execute on function public.rpc_enable_driver_mode(text, text)
  to authenticated;

commit;
