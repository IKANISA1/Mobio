-- CR08/09: frozen global user queries and recoverable, exact-session role plans.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table mobio_private.admin_user_role_versions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  revision bigint not null default 0 check(revision >= 0)
);
insert into mobio_private.admin_user_role_versions(user_id) select id from public.profiles;
create function mobio_private.track_admin_user_role_version()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    insert into mobio_private.admin_user_role_versions(user_id) values(NEW.id);
  elsif NEW.role is distinct from OLD.role or NEW.is_driver is distinct from OLD.is_driver then
    update mobio_private.admin_user_role_versions set revision=revision+1 where user_id=NEW.id;
    if not found then raise exception 'ADMIN_ROLE_REVISION_UNAVAILABLE' using errcode='55000'; end if;
  end if;
  return NEW;
end $$;
create trigger admin_user_role_version_insert after insert on public.profiles
  for each row execute function mobio_private.track_admin_user_role_version();
create trigger admin_user_role_version_update after update of role,is_driver on public.profiles
  for each row execute function mobio_private.track_admin_user_role_version();

create table mobio_private.admin_user_snapshots (
  snapshot_id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null references auth.sessions(id) on delete cascade,
  role_filter text,
  search text,
  sort text not null check(sort in('online','name_asc','name_desc','role','newest')),
  page_size integer not null check(page_size between 1 and 100),
  as_of timestamptz not null,
  expires_at timestamptz not null,
  total_exact integer not null default 0 check(total_exact between 0 and 10000),
  check(expires_at=as_of+interval '10 minutes')
);
create index admin_user_snapshots_actor on mobio_private.admin_user_snapshots(actor_id,expires_at);
create table mobio_private.admin_user_snapshot_rows (
  snapshot_id uuid not null references mobio_private.admin_user_snapshots(snapshot_id) on delete cascade,
  ordinal integer not null check(ordinal between 0 and 10000),
  target_id uuid not null,
  row_payload jsonb not null check(jsonb_typeof(row_payload)='object'),
  primary key(snapshot_id,ordinal), unique(snapshot_id,target_id)
);

-- No cascading Auth/SID/target FK: replacement sessions and target deletion
-- must not erase an outstanding operation or its historical receipt.
create table mobio_private.admin_role_batches (
  batch_id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  reservation_id uuid unique not null,
  snapshot_id uuid not null,
  origin_session_id uuid not null,
  reserved_at timestamptz not null,
  execute_expires_at timestamptz not null,
  input_sha256 text not null check(input_sha256 ~ '^[0-9a-f]{64}$'),
  sealed_at timestamptz,
  check(execute_expires_at=reserved_at+interval '10 minutes')
);
create unique index admin_role_one_open_actor_batch on mobio_private.admin_role_batches(actor_id)
  where sealed_at is null;
create table mobio_private.admin_role_reservations (
  reservation_id uuid primary key,
  actor_id uuid not null,
  batch_id uuid unique references mobio_private.admin_role_batches(batch_id),
  sealed_at timestamptz,
  check(batch_id is not null or sealed_at is not null)
);
create table mobio_private.admin_role_operations (
  operation_id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references mobio_private.admin_role_batches(batch_id),
  ordinal integer not null check(ordinal between 1 and 100),
  target_id uuid not null,
  display_label text not null,
  member_id text,
  expected_role public.user_role_enum not null,
  expected_revision bigint not null check(expected_revision>=0),
  expected_is_driver boolean not null,
  requested_role public.user_role_enum not null,
  requested_is_driver boolean not null,
  status text not null check(status in('prepared','confirmed','known_rejected','skipped','not_started')),
  skip_reason text check(skip_reason in('self','same_role')),
  rejection_code text check(rejection_code in('target_not_found','target_changed')),
  decided_at timestamptz,
  receipt jsonb,
  audit_id uuid unique references public.admin_audit_log(id),
  unique(batch_id,ordinal), unique(batch_id,target_id),
  check((status='prepared' and decided_at is null and skip_reason is null and rejection_code is null and receipt is null and audit_id is null)
    or (status='confirmed' and decided_at is not null and skip_reason is null and rejection_code is null and receipt is not null and audit_id is not null)
    or (status='known_rejected' and decided_at is not null and skip_reason is null and rejection_code is not null and receipt is null and audit_id is null)
    or (status='skipped' and decided_at is not null and skip_reason is not null and rejection_code is null and receipt is null and audit_id is null)
    or (status='not_started' and decided_at is not null and skip_reason is null and rejection_code is null and receipt is null and audit_id is null))
);

do $$ declare t text; begin
  foreach t in array array['admin_user_role_versions','admin_user_snapshots','admin_user_snapshot_rows',
    'admin_role_batches','admin_role_reservations','admin_role_operations'] loop
    execute format('alter table mobio_private.%I enable row level security',t);
    execute format('revoke all on mobio_private.%I from public,anon,authenticated,service_role',t);
  end loop;
end $$;

revoke all on function mobio_private.track_admin_user_role_version() from public,anon,authenticated,service_role;

create function mobio_private.admin_role_actor(p_requires_recent boolean)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid;
begin
  -- This purpose check grants no identity, including when the lease is invalid.
  if p_requires_recent and mobio_private.is_live_admin_purpose_transport() then
    perform public.require_recent_admin_session();
  end if;
  actor:=public.verified_admin_user_id();
  if actor is null or not public.has_platform_permission('admin.users.manage') then
    raise exception 'ADMIN_ROLE_MANAGE_REQUIRED' using errcode='42501';
  end if;
  return actor;
end $$;
create function mobio_private.lock_admin_role_actor(p_actor uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_actor is null then raise exception 'ADMIN_ROLE_MANAGE_REQUIRED' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mobio.admin.role.actor:'||p_actor::text,0));
end $$;

create function mobio_private.admin_role_envelope(p_actor uuid,p_session uuid,p_reservation uuid,p_batch uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b mobio_private.admin_role_batches%rowtype; r mobio_private.admin_role_reservations%rowtype;
  operations jsonb:='[]'::jsonb; batch jsonb; reservation_state text:='absent';
begin
  if p_batch is not null then
    select * into b from mobio_private.admin_role_batches where batch_id=p_batch and actor_id=p_actor;
    if found then p_reservation:=b.reservation_id; end if;
  elsif p_reservation is not null then
    select * into r from mobio_private.admin_role_reservations where reservation_id=p_reservation and actor_id=p_actor;
    if found and r.batch_id is not null then
      select * into b from mobio_private.admin_role_batches where batch_id=r.batch_id and actor_id=p_actor;
    elsif found then reservation_state:='sealed_before_reserve'; end if;
  end if;
  if b.batch_id is not null then
    reservation_state:=case when b.sealed_at is null then 'reserved' else 'sealed' end;
    batch:=jsonb_build_object('batch_id',b.batch_id,'reservation_id',b.reservation_id,'snapshot_id',b.snapshot_id,
      'origin_session_id',b.origin_session_id,'reserved_at',b.reserved_at,'execute_expires_at',b.execute_expires_at,
      'input_sha256',b.input_sha256,'state',case when b.sealed_at is null then 'open' else 'sealed' end,'sealed_at',b.sealed_at);
    select coalesce(jsonb_agg(jsonb_build_object('operation_id',o.operation_id,'ordinal',o.ordinal,
      'target_id',o.target_id,'display_label',o.display_label,'member_id',o.member_id,
      'expected_role',o.expected_role,'expected_revision',o.expected_revision,'expected_is_driver',o.expected_is_driver,
      'requested_role',o.requested_role,'requested_is_driver',o.requested_is_driver,'status',o.status,
      'skip_reason',o.skip_reason,'rejection_code',o.rejection_code,'decided_at',o.decided_at,'receipt',o.receipt)
      order by o.ordinal),'[]'::jsonb) into operations from mobio_private.admin_role_operations o where o.batch_id=b.batch_id;
  end if;
  return jsonb_build_object('protocol','mobio.admin-users.v1','actor_id',p_actor,'session_id',p_session,
    'server_now',clock_timestamp(),'reservation_id',p_reservation,'reservation_state',reservation_state,
    'batch',batch,'operations',operations);
end $$;
revoke all on function mobio_private.admin_role_actor(boolean),mobio_private.lock_admin_role_actor(uuid),
  mobio_private.admin_role_envelope(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.rpc_admin_users_page(p_role text default null,p_search text default null,
  p_sort text default 'online',p_page_size integer default 25,p_snapshot_id uuid default null,p_offset integer default 0)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid; sid uuid; normal_role text; normal_search text;
  s mobio_private.admin_user_snapshots%rowtype; stamp timestamptz; rows jsonb; count_rows integer;
begin
  actor:=public.verified_admin_user_id();
  if actor is null or not public.has_platform_permission('admin.users.read') then
    raise exception 'ADMIN_USERS_READ_REQUIRED' using errcode='42501'; end if;
  sid:=(auth.jwt()->>'session_id')::uuid;
  normal_role:=nullif(btrim(p_role),''); normal_search:=nullif(btrim(p_search),'');
  if (normal_role is not null and normal_role not in('passenger','driver','admin'))
    or length(coalesce(normal_search,''))>120 or p_sort is null
    or p_sort not in('online','name_asc','name_desc','role','newest')
    or p_page_size is null or p_page_size not between 1 and 100
    or p_offset is null or p_offset<0 or p_offset>10000 or mod(p_offset,p_page_size)<>0
    or (p_snapshot_id is null and p_offset<>0) then
    raise exception 'ADMIN_USERS_QUERY_INVALID' using errcode='22023'; end if;
  -- The same actor lock makes the per-owner bound meaningful across tabs.
  perform mobio_private.lock_admin_role_actor(actor);
  if public.verified_admin_user_id() is distinct from actor or not public.has_platform_permission('admin.users.read') then
    raise exception 'ADMIN_USERS_READ_REQUIRED' using errcode='42501'; end if;
  stamp:=clock_timestamp();
  if p_snapshot_id is null then
    delete from mobio_private.admin_user_snapshots where actor_id=actor and expires_at<=stamp;
    if (select count(*) from mobio_private.admin_user_snapshots where actor_id=actor)>=3 then
      raise exception 'ADMIN_USERS_SNAPSHOT_LIMIT' using errcode='P0001'; end if;
    insert into mobio_private.admin_user_snapshots(actor_id,session_id,role_filter,search,sort,page_size,as_of,expires_at)
      values(actor,sid,normal_role,normal_search,p_sort,p_page_size,stamp,stamp+interval '10 minutes') returning * into s;
    with candidates as (
      select p.*,v.revision,
        case when btrim(coalesce(p.display_name,''))<>'' then p.display_name
          when btrim(coalesce(p.name,''))<>'' then p.name else 'Unnamed member' end as display_label
      from public.profiles p join mobio_private.admin_user_role_versions v on v.user_id=p.id
      where (normal_role is null or p.role::text=normal_role)
        and (normal_search is null or strpos(lower(p.name),lower(normal_search))>0
          or strpos(lower(coalesce(p.display_name,'')),lower(normal_search))>0
          or strpos(lower(p.phone),lower(normal_search))>0
          or strpos(lower(coalesce(p.member_id,'')),lower(normal_search))>0)
      limit 10001
    ), ranked as (
      select c.*,row_number() over(order by
        case when p_sort='online' then c.is_online end desc nulls last,
        case when p_sort in('online','role') then c.role::text end collate "C" asc,
        case when p_sort='newest' then c.created_at end desc nulls last,
        case when p_sort='name_desc' then lower(c.display_label) end collate "C" desc,
        case when p_sort<>'name_desc' then lower(c.display_label) end collate "C" asc,
        c.id asc)-1 as ordinal
      from candidates c
    )
    insert into mobio_private.admin_user_snapshot_rows(snapshot_id,ordinal,target_id,row_payload)
      select s.snapshot_id,r.ordinal::integer,r.id,jsonb_build_object('id',r.id,'name',r.name,
        'display_name',r.display_name,'phone',r.phone,'role',r.role,'is_driver',r.is_driver,
        'vehicle_type',r.vehicle_type,'member_id',r.member_id,'has_face_id',false,
        'is_online',r.is_online,'created_at',r.created_at,'role_revision',r.revision)
      from ranked r order by r.ordinal limit 10001;
    get diagnostics count_rows=row_count;
    if count_rows>10000 then raise exception 'ADMIN_USERS_QUERY_TOO_BROAD' using errcode='P0001'; end if;
    update mobio_private.admin_user_snapshots set total_exact=count_rows where snapshot_id=s.snapshot_id returning * into s;
  else
    select * into s from mobio_private.admin_user_snapshots where snapshot_id=p_snapshot_id and actor_id=actor for share;
    if not found then raise exception 'ADMIN_USERS_SNAPSHOT_NOT_FOUND' using errcode='P0001'; end if;
    if s.session_id<>sid or s.role_filter is distinct from normal_role or s.search is distinct from normal_search
      or s.sort<>p_sort or s.page_size<>p_page_size then
      raise exception 'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH' using errcode='P0001'; end if;
    if s.expires_at<=clock_timestamp() then raise exception 'ADMIN_USERS_SNAPSHOT_EXPIRED' using errcode='P0001'; end if;
  end if;
  select coalesce(jsonb_agg(r.row_payload order by r.ordinal),'[]'::jsonb) into rows
    from mobio_private.admin_user_snapshot_rows r where r.snapshot_id=s.snapshot_id
      and r.ordinal>=p_offset and r.ordinal<p_offset+p_page_size;
  return jsonb_build_object('protocol','mobio.admin-users.v1','actor_id',actor,'session_id',sid,'server_now',clock_timestamp(),
    'snapshot_id',s.snapshot_id,'as_of',s.as_of,'expires_at',s.expires_at,'role_filter',s.role_filter,'search',s.search,
    'sort',s.sort,'page_size',s.page_size,'offset',p_offset,'total_exact',s.total_exact,
    'has_next_page',p_offset+p_page_size<s.total_exact,'rows',rows);
end $$;

-- Superseded query handles can be discarded without waiting for their TTL.
-- Immutable batch tuples and receipts retain UUID provenance without a cache FK.
create function public.rpc_admin_users_release_snapshot(p_snapshot_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid; sid uuid; s mobio_private.admin_user_snapshots%rowtype; removed boolean:=false;
begin
  actor:=public.verified_admin_user_id();
  if actor is null or not public.has_platform_permission('admin.users.read') then
    raise exception 'ADMIN_USERS_READ_REQUIRED' using errcode='42501'; end if;
  sid:=(auth.jwt()->>'session_id')::uuid;
  if p_snapshot_id is null then raise exception 'ADMIN_USERS_QUERY_INVALID' using errcode='22023'; end if;
  perform mobio_private.lock_admin_role_actor(actor);
  if public.verified_admin_user_id() is distinct from actor or not public.has_platform_permission('admin.users.read') then
    raise exception 'ADMIN_USERS_READ_REQUIRED' using errcode='42501'; end if;
  select * into s from mobio_private.admin_user_snapshots where snapshot_id=p_snapshot_id for update;
  if found then
    if s.actor_id<>actor or s.session_id<>sid then
      raise exception 'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH' using errcode='42501'; end if;
    -- Recheck after a possible expiry-worker row-lock wait as well.
    if public.verified_admin_user_id() is distinct from actor or not public.has_platform_permission('admin.users.read') then
      raise exception 'ADMIN_USERS_READ_REQUIRED' using errcode='42501'; end if;
    delete from mobio_private.admin_user_snapshots where snapshot_id=s.snapshot_id;
    removed:=true;
  end if;
  return jsonb_build_object('protocol','mobio.admin-users.v1','actor_id',actor,'session_id',sid,
    'server_now',clock_timestamp(),'snapshot_id',p_snapshot_id,'released',removed,'already_absent',not removed);
end $$;

create function public.rpc_admin_role_reserve(p_reservation_id uuid,p_snapshot_id uuid,p_targets jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=mobio_private.admin_role_actor(true); sid uuid:=(auth.jwt()->>'session_id')::uuid;
  s mobio_private.admin_user_snapshots%rowtype; b mobio_private.admin_role_batches%rowtype;
  fence mobio_private.admin_role_reservations%rowtype; target record; payload jsonb; hash text;
  stamp timestamptz; requested_target_id uuid; status text; reason text;
begin
  -- The declaration above applies current purpose freshness before body validation.
  if p_reservation_id is null or p_snapshot_id is null or jsonb_typeof(p_targets) is distinct from 'array'
    then
    raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
  if jsonb_array_length(p_targets) not between 1 and 100 then raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
  hash:=encode(sha256(convert_to(jsonb_build_object('snapshot_id',p_snapshot_id,'targets',p_targets)::text,'UTF8')),'hex');
  perform mobio_private.lock_admin_role_actor(actor);
  perform mobio_private.admin_role_actor(true);
  select * into fence from mobio_private.admin_role_reservations where reservation_id=p_reservation_id for update;
  if found then
    if fence.actor_id<>actor then raise exception 'ADMIN_ROLE_RESERVATION_CONFLICT' using errcode='22023'; end if;
    if fence.sealed_at is not null then raise exception 'ADMIN_ROLE_RESERVATION_SEALED' using errcode='P0001'; end if;
    select * into strict b from mobio_private.admin_role_batches where batch_id=fence.batch_id;
    if b.origin_session_id<>sid then raise exception 'ADMIN_ROLE_SESSION_CHANGED' using errcode='42501'; end if;
    if b.input_sha256<>hash then raise exception 'ADMIN_ROLE_RESERVATION_CONFLICT' using errcode='22023'; end if;
    return mobio_private.admin_role_envelope(actor,sid,p_reservation_id,b.batch_id);
  end if;
  if exists(select 1 from mobio_private.admin_role_batches where actor_id=actor and sealed_at is null) then
    raise exception 'ADMIN_ROLE_BATCH_OPEN' using errcode='P0001'; end if;
  select * into s from mobio_private.admin_user_snapshots where snapshot_id=p_snapshot_id and actor_id=actor for share;
  if not found then raise exception 'ADMIN_USERS_SNAPSHOT_NOT_FOUND' using errcode='P0001'; end if;
  if s.session_id<>sid then raise exception 'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH' using errcode='P0001'; end if;
  if s.expires_at<=clock_timestamp() then raise exception 'ADMIN_USERS_SNAPSHOT_EXPIRED' using errcode='P0001'; end if;
  stamp:=clock_timestamp();
  insert into mobio_private.admin_role_batches(actor_id,reservation_id,snapshot_id,origin_session_id,reserved_at,execute_expires_at,input_sha256)
    values(actor,p_reservation_id,p_snapshot_id,sid,stamp,stamp+interval '10 minutes',hash) returning * into b;
  insert into mobio_private.admin_role_reservations(reservation_id,actor_id,batch_id)
    values(p_reservation_id,actor,b.batch_id);
  for target in select value,ordinality from jsonb_array_elements(p_targets) with ordinality loop
    if jsonb_typeof(target.value) is distinct from 'object'
      or target.value-array['target_id','expected_role','expected_revision','requested_role']<>'{}'::jsonb
      or jsonb_typeof(target.value->'target_id') is distinct from 'string'
      or target.value->>'target_id' !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
      or jsonb_typeof(target.value->'expected_revision') is distinct from 'number'
      or target.value->>'expected_revision' !~ '^[0-9]{1,19}$'
            or target.value->>'expected_role' is null or target.value->>'expected_role' not in('passenger','driver','admin')
      or target.value->>'requested_role' is null or target.value->>'requested_role' not in('passenger','driver','admin') then
      raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
    if (target.value->>'expected_revision')::numeric>9223372036854775807 then raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
    requested_target_id:=(target.value->>'target_id')::uuid;
    select r.row_payload into payload from mobio_private.admin_user_snapshot_rows r
      where r.snapshot_id=s.snapshot_id and r.target_id=requested_target_id;
    if not found or payload->>'role' is distinct from target.value->>'expected_role'
      or (payload->>'role_revision')::bigint is distinct from (target.value->>'expected_revision')::bigint then
      raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
    if exists(select 1 from mobio_private.admin_role_operations where batch_id=b.batch_id and admin_role_operations.target_id=requested_target_id) then
      raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
    status:='prepared';reason:=null;
    if requested_target_id=actor then status:='skipped';reason:='self';
    elsif target.value->>'expected_role'=target.value->>'requested_role' then status:='skipped';reason:='same_role'; end if;
    insert into mobio_private.admin_role_operations(batch_id,ordinal,target_id,display_label,member_id,
      expected_role,expected_revision,expected_is_driver,requested_role,requested_is_driver,status,skip_reason,decided_at)
      values(b.batch_id,target.ordinality::integer,requested_target_id,
        case when btrim(coalesce(payload->>'display_name',''))<>'' then payload->>'display_name'
          when btrim(coalesce(payload->>'name',''))<>'' then payload->>'name' else 'Unnamed member' end,
        payload->>'member_id',(target.value->>'expected_role')::public.user_role_enum,
        (target.value->>'expected_revision')::bigint,(payload->>'is_driver')::boolean,
        (target.value->>'requested_role')::public.user_role_enum,target.value->>'requested_role'='driver',
        status,reason,case when status='skipped' then stamp else null end);
  end loop;
  return mobio_private.admin_role_envelope(actor,sid,p_reservation_id,b.batch_id);
exception when unique_violation then
  raise exception 'ADMIN_ROLE_RESERVATION_CONFLICT' using errcode='22023';
end $$;

create function public.rpc_admin_role_execute(p_batch_id uuid,p_operation_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=mobio_private.admin_role_actor(true); sid uuid:=(auth.jwt()->>'session_id')::uuid;
  b mobio_private.admin_role_batches%rowtype; o mobio_private.admin_role_operations%rowtype;
  target public.profiles%rowtype; before_revision bigint; after_revision bigint;
  audit uuid; stamp timestamptz; result_receipt jsonb;
begin
  if p_batch_id is null or p_operation_id is null then raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
  perform mobio_private.lock_admin_role_actor(actor);
  perform mobio_private.admin_role_actor(true);
  select * into b from mobio_private.admin_role_batches where batch_id=p_batch_id and actor_id=actor for update;
  if not found then raise exception 'ADMIN_ROLE_BATCH_NOT_FOUND' using errcode='P0001'; end if;
  if b.origin_session_id<>sid then raise exception 'ADMIN_ROLE_SESSION_CHANGED' using errcode='42501'; end if;
  if b.sealed_at is not null then raise exception 'ADMIN_ROLE_BATCH_SEALED' using errcode='P0001'; end if;
  if b.execute_expires_at<=clock_timestamp() then raise exception 'ADMIN_ROLE_BATCH_EXPIRED' using errcode='P0001'; end if;
  select * into o from mobio_private.admin_role_operations where batch_id=b.batch_id and operation_id=p_operation_id for update;
  if not found then raise exception 'ADMIN_ROLE_OPERATION_NOT_FOUND' using errcode='P0001'; end if;
  if o.status<>'prepared' then return mobio_private.admin_role_envelope(actor,sid,b.reservation_id,b.batch_id); end if;
  select * into target from public.profiles where id=o.target_id for update;
  stamp:=clock_timestamp();
  if not found then
    update mobio_private.admin_role_operations set status='known_rejected',rejection_code='target_not_found',decided_at=stamp where operation_id=o.operation_id;
  else
    select revision into before_revision from mobio_private.admin_user_role_versions where user_id=o.target_id for share;
    if not found then raise exception 'ADMIN_ROLE_REVISION_UNAVAILABLE' using errcode='55000'; end if;
    if target.role<>o.expected_role or target.is_driver<>o.expected_is_driver or before_revision<>o.expected_revision then
      update mobio_private.admin_role_operations set status='known_rejected',rejection_code='target_changed',decided_at=stamp where operation_id=o.operation_id;
    else
      -- Re-read authority after the possibly blocked target lock. No lease touch.
      perform mobio_private.admin_role_actor(true);
      if b.execute_expires_at<=clock_timestamp() then raise exception 'ADMIN_ROLE_BATCH_EXPIRED' using errcode='P0001'; end if;
      update public.profiles set role=o.requested_role,is_driver=o.requested_is_driver
        where id=o.target_id and role=o.expected_role and is_driver=o.expected_is_driver;
      if not found then raise exception 'ADMIN_ROLE_TARGET_CAS_FAILED' using errcode='55000'; end if;
      select revision into strict after_revision from mobio_private.admin_user_role_versions where user_id=o.target_id;
      stamp:=clock_timestamp();
      insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
        values(actor,'update_role','profile',o.target_id,jsonb_build_object('old_role',o.expected_role,'new_role',o.requested_role,
          'batch_id',b.batch_id,'operation_id',o.operation_id,'reservation_id',b.reservation_id,
          'before_revision',before_revision,'after_revision',after_revision)) returning id into audit;
      result_receipt:=jsonb_build_object('actor_id',actor,'session_id',sid,'batch_id',b.batch_id,'operation_id',o.operation_id,
        'target_id',o.target_id,'before_role',o.expected_role,'after_role',o.requested_role,
        'before_revision',before_revision,'after_revision',after_revision,'before_is_driver',o.expected_is_driver,
        'after_is_driver',o.requested_is_driver,'audit_id',audit,'committed_at',stamp);
      update mobio_private.admin_role_operations set status='confirmed',decided_at=stamp,receipt=result_receipt,audit_id=audit
        where operation_id=o.operation_id;
    end if;
  end if;
  return mobio_private.admin_role_envelope(actor,sid,b.reservation_id,b.batch_id);
end $$;

create function public.rpc_admin_role_status(p_batch_id uuid default null,p_reservation_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=mobio_private.admin_role_actor(false); sid uuid:=(auth.jwt()->>'session_id')::uuid; batch uuid;
begin
  if p_batch_id is not null and p_reservation_id is not null then raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
  perform mobio_private.lock_admin_role_actor(actor);
  perform mobio_private.admin_role_actor(false);
  batch:=p_batch_id;
  if batch is null and p_reservation_id is null then
    select batch_id into batch from mobio_private.admin_role_batches where actor_id=actor and sealed_at is null;
  end if;
  return mobio_private.admin_role_envelope(actor,sid,p_reservation_id,batch);
end $$;

create function public.rpc_admin_role_seal(p_batch_id uuid default null,p_reservation_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare actor uuid:=mobio_private.admin_role_actor(false); sid uuid:=(auth.jwt()->>'session_id')::uuid;
  b mobio_private.admin_role_batches%rowtype; fence mobio_private.admin_role_reservations%rowtype; stamp timestamptz;
begin
  if (p_batch_id is null)=(p_reservation_id is null) then raise exception 'ADMIN_ROLE_ARGUMENT_INVALID' using errcode='22023'; end if;
  perform mobio_private.lock_admin_role_actor(actor);
  perform mobio_private.admin_role_actor(false);
  if p_batch_id is not null then
    select * into b from mobio_private.admin_role_batches where batch_id=p_batch_id and actor_id=actor for update;
    if not found then raise exception 'ADMIN_ROLE_BATCH_NOT_FOUND' using errcode='P0001'; end if;
    p_reservation_id:=b.reservation_id;
  else
    select * into fence from mobio_private.admin_role_reservations where reservation_id=p_reservation_id for update;
    if found then
      if fence.actor_id<>actor then raise exception 'ADMIN_ROLE_BATCH_NOT_FOUND' using errcode='P0001'; end if;
      if fence.batch_id is not null then
        select * into strict b from mobio_private.admin_role_batches where batch_id=fence.batch_id and actor_id=actor for update;
      end if;
    end if;
  end if;
  stamp:=clock_timestamp();
  if b.batch_id is null then
    insert into mobio_private.admin_role_reservations(reservation_id,actor_id,sealed_at)
      values(p_reservation_id,actor,stamp) on conflict(reservation_id) do nothing;
    select * into strict fence from mobio_private.admin_role_reservations where reservation_id=p_reservation_id;
    if fence.actor_id<>actor then raise exception 'ADMIN_ROLE_BATCH_NOT_FOUND' using errcode='P0001'; end if;
  else
    -- An executor owns this actor/batch fence until its target/audit/receipt commit.
    -- A later executor observes sealed_at before it can reach any target row.
    update mobio_private.admin_role_operations set status='not_started',decided_at=stamp
      where batch_id=b.batch_id and status='prepared';
    update mobio_private.admin_role_batches set sealed_at=coalesce(sealed_at,stamp) where batch_id=b.batch_id;
    update mobio_private.admin_role_reservations set sealed_at=coalesce(sealed_at,stamp) where reservation_id=p_reservation_id;
  end if;
  return mobio_private.admin_role_envelope(actor,sid,p_reservation_id,b.batch_id);
end $$;

create function mobio_private.expire_admin_user_snapshots(p_limit integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare removed integer;
begin
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception 'ADMIN_USERS_QUERY_INVALID' using errcode='22023'; end if;
  with due as (select snapshot_id from mobio_private.admin_user_snapshots
    where expires_at<=clock_timestamp() order by expires_at,snapshot_id
    limit p_limit for update skip locked)
  delete from mobio_private.admin_user_snapshots s using due where s.snapshot_id=due.snapshot_id;
  get diagnostics removed=row_count;
  return jsonb_build_object('protocol','mobio.admin-users.v1','server_now',clock_timestamp(),
    'expired_snapshots',removed,'has_more_due',exists(select 1 from mobio_private.admin_user_snapshots where expires_at<=clock_timestamp()));
end $$;
create function public.rpc_admin_users_expire_snapshots(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public._mobio_is_service_role() then raise exception 'SERVICE_AUTHORITY_REQUIRED' using errcode='42501'; end if;
  return mobio_private.expire_admin_user_snapshots(p_limit);
end $$;
revoke all on function mobio_private.expire_admin_user_snapshots(integer),
  public.rpc_admin_users_expire_snapshots(integer) from public,anon,authenticated,service_role;
grant execute on function public.rpc_admin_users_expire_snapshots(integer) to service_role;
-- Database-owner cron executes only the private bounded SQL cleanup. It does
-- not dispatch HTTP, require a customer SID, or erase durable role receipts.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('admin-user-snapshot-expiry','* * * * *',
  'select mobio_private.expire_admin_user_snapshots(100);');

-- Old list signature/semantics remain untouched. Legacy role callers share the
-- actor fence so they cannot bypass an outstanding server-owned review plan.
do $$ declare routine record; body text; definition text; anchor text;
begin
  select p.* into strict routine from pg_proc p where p.oid='public.rpc_admin_update_user_role(uuid,text)'::regprocedure;
  anchor:=E'if not public.has_platform_permission(''admin.users.manage'') then\n    raise exception ''Unauthorized: admin.users.manage permission required'';\n  end if;';
  if not routine.prosecdef or routine.prosrc not like '%mobio_private.is_live_admin_purpose_transport()%'
    or (length(routine.prosrc)-length(replace(routine.prosrc,anchor,'')))<>length(anchor) then
    raise exception 'Unexpected legacy Admin role function'; end if;
  body:=replace(routine.prosrc,anchor,anchor||E'\n  perform mobio_private.lock_admin_role_actor(public.verified_admin_user_id());\n  perform mobio_private.admin_role_actor(true);\n  if exists(select 1 from mobio_private.admin_role_batches where actor_id=public.verified_admin_user_id() and sealed_at is null) then\n    raise exception ''ADMIN_ROLE_BATCH_OPEN'' using errcode=''P0001'';\n  end if;');
  definition:=pg_get_functiondef(routine.oid);
  execute replace(definition,routine.prosrc,body);
  if exists(select 1 from pg_proc where oid=routine.oid and (proowner<>routine.proowner
    or proacl is distinct from routine.proacl or proconfig is distinct from routine.proconfig
    or proargtypes<>routine.proargtypes or proargdefaults is distinct from routine.proargdefaults)) then
    raise exception 'Legacy Admin role catalogue authority changed'; end if;
end $$;

revoke all on function public.rpc_admin_users_page(text,text,text,integer,uuid,integer),
  public.rpc_admin_users_release_snapshot(uuid),
  public.rpc_admin_role_reserve(uuid,uuid,jsonb),public.rpc_admin_role_execute(uuid,uuid),
  public.rpc_admin_role_status(uuid,uuid),public.rpc_admin_role_seal(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.rpc_admin_users_page(text,text,text,integer,uuid,integer),
  public.rpc_admin_users_release_snapshot(uuid),
  public.rpc_admin_role_reserve(uuid,uuid,jsonb),public.rpc_admin_role_execute(uuid,uuid),
  public.rpc_admin_role_status(uuid,uuid),public.rpc_admin_role_seal(uuid,uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
