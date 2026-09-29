-- Forward source body. Generate a timestamped migration with the existing CLI
-- preparer after full-schema rehearsal. Requires the current chat/Plus schema
-- and public.verified_app_user_id(). Not applied to a linked project here.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$ begin
  if to_regprocedure('public.verified_app_user_id()') is null or
     to_regprocedure('public._driver_can_reply_to_conversation(uuid,uuid)') is null or
     to_regclass('public.user_blocks') is null then
    raise exception 'CHAT_PREREQUISITES_REQUIRED';
  end if;
end $$;

create table mobio_private.chat_delivery_policy (
  singleton boolean primary key default true check(singleton),
  sends_enabled boolean not null default false,
  min_send_interval_ms integer not null default 1000 check(min_send_interval_ms between 0 and 60000),
  max_retained_operations integer not null default 10000 check(max_retained_operations between 100 and 1000000),
  changed_at timestamptz not null default clock_timestamp()
);
-- Deliberately OFF for coordinated old-client/new-client cutover.
insert into mobio_private.chat_delivery_policy(singleton) values(true);
create table mobio_private.chat_send_clock (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  last_sent_at timestamptz not null
);
create table mobio_private.chat_delivery_operations (
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_message_id uuid not null,
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  body_sha256 text not null check(body_sha256 ~ '^[0-9a-f]{64}$'),
  state text not null check(state in ('sent','cancelled')),
  message_id uuid references public.chat_messages(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  acknowledged_at timestamptz,
  primary key(owner_id, client_message_id),
  check(state <> 'cancelled' or (message_id is null and acknowledged_at is not null))
);
create unique index chat_one_unresolved_send_per_conversation
  on mobio_private.chat_delivery_operations(owner_id,conversation_id)
  where acknowledged_at is null;
create index chat_delivery_history on mobio_private.chat_delivery_operations(owner_id,created_at desc);
create index chat_history_cursor on public.chat_messages(conversation_id,created_at desc,id desc);
alter table mobio_private.chat_delivery_policy enable row level security;
alter table mobio_private.chat_send_clock enable row level security;
alter table mobio_private.chat_delivery_operations enable row level security;
revoke all on mobio_private.chat_delivery_policy,mobio_private.chat_send_clock,
  mobio_private.chat_delivery_operations from public,anon,authenticated,service_role;

create function mobio_private.chat_delivery_view(r mobio_private.chat_delivery_operations)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('owner_id',r.owner_id,'client_message_id',r.client_message_id,
    'conversation_id',r.conversation_id,'body_sha256',r.body_sha256,'state',r.state,
    'message_id',r.message_id,'acknowledged',r.acknowledged_at is not null)
$$;
revoke all on function mobio_private.chat_delivery_view(mobio_private.chat_delivery_operations)
  from public,anon,authenticated,service_role;

-- One checked authority boundary for new reads/writes. No caller-supplied owner.
create function mobio_private.chat_member(p_conversation_id uuid)
returns public.chat_conversations language plpgsql security definer set search_path = '' as $$
declare actor uuid := public.verified_app_user_id(); c public.chat_conversations%rowtype;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  select * into c from public.chat_conversations
    where id=p_conversation_id and actor in(participant_low_id,participant_high_id);
  if not found then raise exception 'CONVERSATION_NOT_FOUND' using errcode='42501'; end if;
  return c;
end $$;
revoke all on function mobio_private.chat_member(uuid) from public,anon,authenticated,service_role;

create function public.rpc_chat_delivery_status(p_conversation_id uuid,p_client_message_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := public.verified_app_user_id(); r mobio_private.chat_delivery_operations%rowtype;
begin
  perform mobio_private.chat_member(p_conversation_id);
  select * into r from mobio_private.chat_delivery_operations o where o.owner_id=actor
    and o.conversation_id=p_conversation_id and
    ((p_client_message_id is not null and o.client_message_id=p_client_message_id) or
     (p_client_message_id is null and o.acknowledged_at is null));
  if not found then return jsonb_build_object('state','not_observed','owner_id',actor,
    'conversation_id',p_conversation_id,'client_message_id',p_client_message_id); end if;
  return mobio_private.chat_delivery_view(r);
end $$;

create function public.rpc_send_chat_message_v2(p_conversation_id uuid,p_client_message_id uuid,p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := public.verified_app_user_id(); c public.chat_conversations%rowtype;
  t public.trips%rowtype; r mobio_private.chat_delivery_operations%rowtype;
  policy mobio_private.chat_delivery_policy%rowtype; msg uuid; h text; last_sent timestamptz;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_client_message_id is null or p_body is null or char_length(p_body)=0 or
     p_body !~ '[^[:space:]]' or char_length(p_body)>2000 or octet_length(p_body)>8000 then
    raise exception 'INVALID_CHAT_MESSAGE' using errcode='22023'; end if;
  -- Hash EXACT UTF-8 bytes. Flutter trims before calling; SQL never normalizes.
  h := encode(sha256(convert_to(p_body,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('mobio.chat.owner:'||actor::text,0));
  c := mobio_private.chat_member(p_conversation_id);
  select * into r from mobio_private.chat_delivery_operations
    where owner_id=actor and client_message_id=p_client_message_id;
  if found then
    if r.conversation_id<>p_conversation_id or r.body_sha256<>h then
      raise exception 'CHAT_OPERATION_CONFLICT' using errcode='22023'; end if;
    return mobio_private.chat_delivery_view(r); -- retry does not send or trigger again
  end if;
  if exists(select 1 from mobio_private.chat_delivery_operations where owner_id=actor
      and conversation_id=p_conversation_id and acknowledged_at is null) then
    raise exception 'CHAT_UNRESOLVED_SEND' using errcode='55000'; end if;
  select * into strict policy from mobio_private.chat_delivery_policy where singleton for share;
  if (select count(*) from mobio_private.chat_delivery_operations where owner_id=actor)>=policy.max_retained_operations then
    raise sqlstate 'PT429' using message='CHAT_OPERATION_CAPACITY'; end if;
  if not policy.sends_enabled then raise sqlstate 'PT503' using message='CHAT_SENDS_PAUSED'; end if;
  -- Exclusive per-conversation lock avoids trigger lock-upgrade deadlocks for
  -- two participants sending concurrently. All paths order owner then conversation.
  select * into strict c from public.chat_conversations where id=p_conversation_id for update;
  if actor not in(c.participant_low_id,c.participant_high_id) or c.status<>'active' then
    raise exception 'CONVERSATION_UNAVAILABLE' using errcode='42501'; end if;
  if exists(select 1 from public.user_blocks b where
    (b.blocker_id=c.participant_low_id and b.blocked_id=c.participant_high_id) or
    (b.blocker_id=c.participant_high_id and b.blocked_id=c.participant_low_id)) then
    raise exception 'USER_BLOCKED' using errcode='42501'; end if;
  if c.trip_id is not null then
    select * into t from public.trips where id=c.trip_id;
    if found and ((t.role='driver' and t.author_id=actor) or
                  (t.role='passenger' and t.author_id<>actor)) and
       not coalesce(public._driver_can_reply_to_conversation(actor,c.id),false) then
      raise exception 'MOBIO_PLUS_REQUIRED' using errcode='42501'; end if;
  end if;
  select last_sent_at into last_sent from mobio_private.chat_send_clock where owner_id=actor;
  if last_sent is not null and clock_timestamp()<last_sent+make_interval(secs=>policy.min_send_interval_ms/1000.0) then
    raise sqlstate 'PT429' using message='CHAT_RATE_LIMITED'; end if;
  insert into public.chat_messages(conversation_id,sender_id,message_type,body,metadata,created_at)
    values(c.id,actor,'text',p_body,jsonb_build_object('client_message_id',p_client_message_id),clock_timestamp())
    returning id into msg;
  insert into mobio_private.chat_delivery_operations(owner_id,client_message_id,conversation_id,
      body_sha256,state,message_id) values(actor,p_client_message_id,c.id,h,'sent',msg) returning * into r;
  insert into mobio_private.chat_send_clock(owner_id,last_sent_at) values(actor,clock_timestamp())
    on conflict(owner_id) do update set last_sent_at=excluded.last_sent_at;
  return mobio_private.chat_delivery_view(r);
end $$;

create function public.rpc_close_chat_delivery(p_conversation_id uuid,p_client_message_id uuid,
    p_body_sha256 text,p_cancel_if_unobserved boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := public.verified_app_user_id(); r mobio_private.chat_delivery_operations%rowtype;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_client_message_id is null or p_body_sha256 is null or p_body_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'INVALID_CHAT_OPERATION' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mobio.chat.owner:'||actor::text,0));
  perform mobio_private.chat_member(p_conversation_id);
  select * into r from mobio_private.chat_delivery_operations
    where owner_id=actor and client_message_id=p_client_message_id;
  if found then
    if r.conversation_id<>p_conversation_id or r.body_sha256<>p_body_sha256 then
      raise exception 'CHAT_OPERATION_CONFLICT' using errcode='22023'; end if;
    update mobio_private.chat_delivery_operations set acknowledged_at=coalesce(acknowledged_at,clock_timestamp())
      where owner_id=actor and client_message_id=p_client_message_id returning * into r;
  elsif p_cancel_if_unobserved is true then
    if (select count(*) from mobio_private.chat_delivery_operations where owner_id=actor)>=
      (select max_retained_operations from mobio_private.chat_delivery_policy where singleton) then
      raise sqlstate 'PT429' using message='CHAT_OPERATION_CAPACITY'; end if;
    -- Cancellation tombstone fences a late send with the same id. Never assume
    -- a timeout meant failure and simply manufacture a replacement id.
    insert into mobio_private.chat_delivery_operations(owner_id,client_message_id,conversation_id,
        body_sha256,state,acknowledged_at) values(actor,p_client_message_id,p_conversation_id,
        p_body_sha256,'cancelled',clock_timestamp()) returning * into r;
  else
    raise exception 'CHAT_OUTCOME_NOT_OBSERVED' using errcode='55000';
  end if;
  return mobio_private.chat_delivery_view(r);
end $$;

create function public.rpc_chat_runtime_status()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if public.verified_app_user_id() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  return (select jsonb_build_object('sends_enabled',sends_enabled,'changed_at',changed_at)
    from mobio_private.chat_delivery_policy where singleton);
end $$;
create function public.rpc_set_chat_sends_enabled(p_enabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_enabled is null then raise exception 'INVALID_CHAT_POLICY' using errcode='22023'; end if;
  update mobio_private.chat_delivery_policy set sends_enabled=p_enabled,changed_at=clock_timestamp() where singleton;
end $$;
revoke all on function public.rpc_set_chat_sends_enabled(boolean) from public,anon,authenticated;
grant execute on function public.rpc_set_chat_sends_enabled(boolean) to service_role;

create function public.rpc_list_chat_messages_page(p_conversation_id uuid,p_limit integer default 50,
    p_before_created_at timestamptz default null,p_before_id uuid default null)
returns table(id uuid,conversation_id uuid,sender_id uuid,message_type text,body text,
    metadata jsonb,created_at timestamptz,read_at timestamptz,access_redacted boolean)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := public.verified_app_user_id(); c public.chat_conversations%rowtype;
  t public.trips%rowtype; redact boolean := false;
begin
  c := mobio_private.chat_member(p_conversation_id);
  if (p_before_created_at is null)<>(p_before_id is null) or
      (p_before_created_at is not null and not isfinite(p_before_created_at)) or
      p_limit is null or p_limit<1 or p_limit>100 then
    raise exception 'INVALID_CHAT_CURSOR' using errcode='22023'; end if;
  if c.trip_id is not null then
    select * into t from public.trips where trips.id=c.trip_id;
    if found and ((t.role='driver' and t.author_id=actor) or
                  (t.role='passenger' and t.author_id<>actor)) then
      redact := not coalesce(public._driver_can_reply_to_conversation(actor,c.id),false);
    end if;
  end if;
  return query select m.id,m.conversation_id,m.sender_id,m.message_type,
    case when redact and m.message_type='text' and m.sender_id is distinct from actor
      then 'Mobio Plus required to read this passenger message.' else m.body end,
    case when redact and m.message_type='text' and m.sender_id is distinct from actor
      then jsonb_build_object('redacted',true,'redaction_reason','mobio_plus_required') else m.metadata end,
    m.created_at,m.read_at,redact from public.chat_messages m
    where m.conversation_id=p_conversation_id and (p_before_created_at is null or
      (m.created_at,m.id)<(p_before_created_at,p_before_id))
    order by m.created_at desc,m.id desc limit p_limit;
end $$;

create function public.rpc_mark_chat_read(p_conversation_id uuid,p_through_created_at timestamptz,p_through_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare actor uuid := public.verified_app_user_id(); n integer; c public.chat_conversations%rowtype; t public.trips%rowtype;
begin
  c := mobio_private.chat_member(p_conversation_id);
  if c.trip_id is not null then
    select * into t from public.trips where id=c.trip_id;
    if found and ((t.role='driver' and t.author_id=actor) or
      (t.role='passenger' and t.author_id<>actor)) and
      not coalesce(public._driver_can_reply_to_conversation(actor,c.id),false) then return 0; end if;
  end if;
  if p_through_id is null or p_through_created_at is null or not isfinite(p_through_created_at) then
    raise exception 'INVALID_CHAT_CURSOR' using errcode='22023'; end if;
  -- The watermark must refer to an actual row in this conversation, not a
  -- client timestamp in the future. Only read_at changes; never body/owner.
  if not exists(select 1 from public.chat_messages where id=p_through_id and
      conversation_id=p_conversation_id and created_at=p_through_created_at) then
    raise exception 'INVALID_CHAT_CURSOR' using errcode='22023'; end if;
  update public.chat_messages m set read_at=clock_timestamp()
    where m.conversation_id=p_conversation_id and m.sender_id is not null and m.sender_id<>actor
      and m.read_at is null and (m.created_at,m.id)<=(p_through_created_at,p_through_id);
  get diagnostics n = row_count;
  return n;
end $$;

-- Compatibility reads now return the latest bounded window chronologically.
create or replace function public.rpc_list_chat_messages(p_conversation_id uuid,p_limit integer default 100)
returns table(id uuid,conversation_id uuid,sender_id uuid,message_type text,body text,
  metadata jsonb,created_at timestamptz,read_at timestamptz)
language sql stable security definer set search_path='' as $$
  select m.id,m.conversation_id,m.sender_id,m.message_type,m.body,m.metadata,m.created_at,m.read_at
  from public.rpc_list_chat_messages_page(p_conversation_id,least(greatest(coalesce(p_limit,100),1),100),null,null) m
  order by m.created_at asc,m.id asc
$$;
revoke all on function public.rpc_list_chat_messages(uuid,integer) from public,anon;
grant execute on function public.rpc_list_chat_messages(uuid,integer) to authenticated;

-- Old clients cannot bypass the new authority/idempotency boundaries. Existing
-- read RPC stays available for compatibility; new UI uses the cursor RPC.
create or replace function public.rpc_send_chat_message(p_conversation_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
begin raise sqlstate 'PT410' using message='CHAT_CLIENT_UPDATE_REQUIRED'; end $$;
revoke select,insert,update,delete on public.chat_messages from public,anon,authenticated;
revoke insert,update,delete on public.chat_conversations from public,anon,authenticated;
-- Also revoke any historical column-level mutation grants (table revoke alone
-- is insufficient). Restrict this to this known table and these roles only.
do $$ declare a record; begin
  for a in select attname from pg_attribute where attrelid='public.chat_messages'::regclass
    and attnum>0 and not attisdropped loop
    execute format('revoke select(%I),insert(%I),update(%I) on public.chat_messages from public,anon,authenticated',a.attname,a.attname,a.attname);
  end loop;
  for a in select attname from pg_attribute where attrelid='public.chat_conversations'::regclass
    and attnum>0 and not attisdropped loop
    execute format('revoke insert(%I),update(%I) on public.chat_conversations from public,anon,authenticated',a.attname,a.attname);
  end loop;
end $$;
revoke all on function public.rpc_send_chat_message_v2(uuid,uuid,text),
 public.rpc_chat_delivery_status(uuid,uuid),public.rpc_close_chat_delivery(uuid,uuid,text,boolean),
 public.rpc_list_chat_messages_page(uuid,integer,timestamptz,uuid),public.rpc_chat_runtime_status(),
 public.rpc_mark_chat_read(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.rpc_send_chat_message_v2(uuid,uuid,text),
 public.rpc_chat_delivery_status(uuid,uuid),public.rpc_close_chat_delivery(uuid,uuid,text,boolean),
 public.rpc_list_chat_messages_page(uuid,integer,timestamptz,uuid),public.rpc_chat_runtime_status(),
 public.rpc_mark_chat_read(uuid,timestamptz,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
