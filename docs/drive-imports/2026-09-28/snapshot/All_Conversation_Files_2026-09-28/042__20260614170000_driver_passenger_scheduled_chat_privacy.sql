begin;

-- Drivers discover passengers only through scheduled passenger trip posts.
-- Opening or messaging a passenger-authored scheduled trip requires Mobio Plus
-- or the configured free daily driver request allowance. Passenger live
-- location remains outside the product model.

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

create or replace function public.handle_chat_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_preview text;
  v_driver_id uuid;
begin
  v_preview := left(new.body, 160);

  select *
  into v_conversation
  from public.chat_conversations
  where id = new.conversation_id;

  if found and v_conversation.trip_id is not null and new.sender_id is not null then
    select *
    into v_trip
    from public.trips
    where id = v_conversation.trip_id;

    if found and v_trip.role = 'driver' then
      v_driver_id := v_trip.author_id;
      if new.sender_id is distinct from v_driver_id
        and not public._driver_can_reply_to_conversation(v_driver_id, v_conversation.id) then
        v_preview := 'Mobio Plus required to read this passenger message.';
      end if;
    elsif found and v_trip.role = 'passenger' then
      v_driver_id := case
        when v_conversation.participant_low_id = v_trip.author_id then v_conversation.participant_high_id
        else v_conversation.participant_low_id
      end;
      if new.sender_id is distinct from v_driver_id
        and not public._driver_can_reply_to_conversation(v_driver_id, v_conversation.id) then
        v_preview := 'Mobio Plus required to read this passenger message.';
      end if;
    end if;
  end if;

  update public.chat_conversations
  set
    last_message_at = new.created_at,
    last_message_preview = v_preview,
    updated_at = now()
  where id = new.conversation_id;

  return new;
end;
$$;

create or replace function public.rpc_send_chat_message(
  p_conversation_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_message_id uuid;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  if v_body is null then
    raise exception using message = 'EMPTY_MESSAGE';
  end if;

  select *
  into v_conversation
  from public.chat_conversations
  where id = p_conversation_id
    and v_user_id in (participant_low_id, participant_high_id);

  if not found then
    raise exception using message = 'CONVERSATION_NOT_FOUND';
  end if;

  if v_conversation.trip_id is not null then
    select *
    into v_trip
    from public.trips
    where id = v_conversation.trip_id;

    if found and v_trip.role = 'driver' and v_trip.author_id = v_user_id then
      if not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id) then
        raise exception using
          message = 'MOBIO_PLUS_REQUIRED',
          detail = 'Upgrade to Mobio Plus to read and respond to passenger requests.';
      end if;
    elsif found and v_trip.role = 'passenger' and v_trip.author_id <> v_user_id then
      if not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id) then
        raise exception using
          message = 'MOBIO_PLUS_REQUIRED',
          detail = 'Upgrade to Mobio Plus to message passenger scheduled trips.';
      end if;
    end if;
  end if;

  insert into public.chat_messages (
    conversation_id,
    sender_id,
    message_type,
    body,
    metadata
  )
  values (
    p_conversation_id,
    v_user_id,
    'text',
    v_body,
    '{}'::jsonb
  )
  returning id into v_message_id;

  return v_message_id;
end;
$$;

create or replace function public.rpc_list_chat_messages(
  p_conversation_id uuid,
  p_limit integer default 100
)
returns table (
  id uuid,
  conversation_id uuid,
  sender_id uuid,
  message_type text,
  body text,
  metadata jsonb,
  created_at timestamptz,
  read_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_conversation public.chat_conversations%rowtype;
  v_trip public.trips%rowtype;
  v_redact boolean := false;
begin
  if v_user_id is null then
    raise exception using message = 'AUTHENTICATION_REQUIRED';
  end if;

  select *
  into v_conversation
  from public.chat_conversations c
  where c.id = p_conversation_id
    and v_user_id in (c.participant_low_id, c.participant_high_id);

  if not found then
    raise exception using message = 'CONVERSATION_NOT_FOUND';
  end if;

  if v_conversation.trip_id is not null then
    select *
    into v_trip
    from public.trips
    where trips.id = v_conversation.trip_id;

    if found and v_trip.role = 'driver' and v_trip.author_id = v_user_id then
      v_redact := not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id);
    elsif found and v_trip.role = 'passenger' and v_trip.author_id <> v_user_id then
      v_redact := not public._driver_can_reply_to_conversation(v_user_id, v_conversation.id);
    end if;
  end if;

  return query
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    m.message_type,
    case
      when v_redact
        and m.message_type = 'text'
        and m.sender_id is distinct from v_user_id
      then 'Mobio Plus required to read this passenger message.'
      else m.body
    end as body,
    case
      when v_redact
        and m.message_type = 'text'
        and m.sender_id is distinct from v_user_id
      then m.metadata || jsonb_build_object('redacted', true, 'redaction_reason', 'mobio_plus_required')
      else m.metadata
    end as metadata,
    m.created_at,
    m.read_at
  from public.chat_messages m
  where m.conversation_id = p_conversation_id
  order by m.created_at asc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
end;
$$;

grant execute on function public.rpc_get_or_create_chat_conversation(uuid, uuid) to authenticated;
grant execute on function public.rpc_send_chat_message(uuid, text) to authenticated;
grant execute on function public.rpc_list_chat_messages(uuid, integer) to authenticated;

commit;
