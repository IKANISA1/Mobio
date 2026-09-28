begin;

-- 20260614170000 redefined the chat conversation RPC for scheduled-trip
-- privacy and accidentally dropped the user_blocks guard from the earlier
-- report/block hardening migration. Restore the guard in a forward migration
-- because 20260614170000 is already applied on the linked project.

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
  v_driver_id uuid;
  v_passenger_id uuid;
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

  if not found then
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
      'Chat started in Mobio. Keep pickup and trip details here.',
      jsonb_build_object('seed', 'privacy_notice')
    );
  end if;

  if p_trip_id is not null and v_trip.role = 'driver' then
    v_driver_id := v_trip.author_id;
    v_passenger_id := case
      when v_self_id = v_driver_id then p_peer_id
      else v_self_id
    end;

    if v_self_id <> v_driver_id then
      perform public._record_driver_request_entitlement(
        v_driver_id,
        v_passenger_id,
        v_conversation.id,
        p_trip_id,
        'in_app_chat'
      );
    end if;
  elsif p_trip_id is not null and v_trip.role = 'passenger' then
    v_passenger_id := v_trip.author_id;
    v_driver_id := case
      when v_self_id = v_passenger_id then p_peer_id
      else v_self_id
    end;

    if v_self_id <> v_passenger_id then
      perform public._record_driver_request_entitlement(
        v_driver_id,
        v_passenger_id,
        v_conversation.id,
        p_trip_id,
        'in_app_chat'
      );
    end if;
  end if;

  return v_conversation;
end;
$$;

grant execute on function public.rpc_get_or_create_chat_conversation(uuid, uuid) to authenticated;

commit;
