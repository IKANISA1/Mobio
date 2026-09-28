-- SYNTHETIC prerequisites only. The runner supplies an empty, network-isolated
-- PostgreSQL 17 container. These are explicit Auth/Plus/trigger doubles, not
-- the actual Supabase schema or authorization implementation.
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create schema mobio_private;
create table auth.users(id uuid primary key);
create table public.trips(id uuid primary key,author_id uuid,role text);
create table public.chat_conversations(
 id uuid primary key,trip_id uuid references public.trips,
 participant_low_id uuid not null,participant_high_id uuid not null,status text not null default 'active'
);
create table public.chat_messages(
 id uuid primary key default gen_random_uuid(),conversation_id uuid references public.chat_conversations on delete cascade,
 sender_id uuid,message_type text,body text,metadata jsonb default '{}',created_at timestamptz not null,read_at timestamptz
);
create table public.user_blocks(blocker_id uuid,blocked_id uuid,primary key(blocker_id,blocked_id));
create table public.fixture_plus(owner_id uuid primary key,allowed boolean not null);
create table public.fixture_insert_events(message_id uuid);
create function public.fixture_insert_event() returns trigger language plpgsql as $$
begin insert into public.fixture_insert_events values(new.id); return new; end $$;
create trigger fixture_message_event after insert on public.chat_messages for each row execute function public.fixture_insert_event();
create function public.verified_app_user_id() returns uuid language sql stable as $$
 select case when current_setting('fixture.verified',true)='false' then null else
   nullif(current_setting('fixture.actor',true),'')::uuid end
$$;
create function public._driver_can_reply_to_conversation(uuid,uuid) returns boolean language sql stable as $$
 select coalesce((select allowed from public.fixture_plus where owner_id=$1),false)
$$;
-- Required legacy signatures exercise CREATE OR REPLACE compatibility.
create function public.rpc_send_chat_message(p_conversation_id uuid,p_body text)
 returns uuid language sql as $$select null::uuid$$;
create function public.rpc_list_chat_messages(p_conversation_id uuid,p_limit integer default 100)
 returns table(id uuid,conversation_id uuid,sender_id uuid,message_type text,body text,metadata jsonb,created_at timestamptz,read_at timestamptz)
 language sql as $$select * from public.chat_messages where false$$;
grant usage on schema public to authenticated,anon,service_role;
grant select,insert,update,delete on public.chat_messages,public.chat_conversations to authenticated;
grant update(body) on public.chat_messages to authenticated;
grant update(participant_low_id) on public.chat_conversations to authenticated;
insert into auth.users values
 ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002'),('00000000-0000-4000-8000-000000000003');
insert into public.chat_conversations values
 ('00000000-0000-4000-8000-000000000010',null,'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','active'),
 ('00000000-0000-4000-8000-000000000011',null,'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','active');
