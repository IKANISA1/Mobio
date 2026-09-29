-- Forward body, not an applied migration. Requires bodies 01-08 and the
-- original wallet/redemption schema. No settlement/payment engine is added.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create table mobio_private.wallet_operations (
  operation_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete restrict,
  kind text not null check (kind in ('transfer','redeem')),
  request jsonb not null,
  status text not null default 'prepared' check (status in ('prepared','committed','cancelled')),
  receipt jsonb,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  acknowledged_at timestamptz,
  check ((status='prepared' and receipt is null and completed_at is null and acknowledged_at is null)
    or (status='committed' and receipt is not null and completed_at is not null)
    or (status='cancelled' and receipt is null and completed_at is not null and acknowledged_at is not null))
);
-- The SERVER retains the unresolved slot. Loss/corruption of local storage or
-- racing browser tabs cannot silently manufacture a second unresolved operation.
create unique index wallet_one_unresolved_operation on mobio_private.wallet_operations(owner_id)
  where acknowledged_at is null;
create index wallet_operations_owner_history on mobio_private.wallet_operations(owner_id,created_at desc);
alter table mobio_private.wallet_operations enable row level security;
revoke all on mobio_private.wallet_operations from public,anon,authenticated,service_role;

create function mobio_private.wallet_operation_view(r mobio_private.wallet_operations)
returns jsonb language sql immutable set search_path='' as $$
  select jsonb_build_object('operation_id',r.operation_id,'owner_id',r.owner_id,
    'kind',r.kind,'status',r.status,'amount_tokens',r.request->'amount_tokens',
    'receiver_member_id',r.request->'receiver_member_id',
    'receipt',r.receipt,'created_at',r.created_at,'acknowledged',r.acknowledged_at is not null)
$$;
revoke all on function mobio_private.wallet_operation_view(mobio_private.wallet_operations) from public,anon,authenticated,service_role;

create function public.rpc_prepare_wallet_operation(p_operation_id uuid,p_kind text,
    p_amount_tokens bigint,p_receiver_member_id text default null,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid := public.verified_app_user_id();
  r mobio_private.wallet_operations%rowtype;
  canonical jsonb;
  receiver uuid;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_operation_id is null or p_kind is null or p_kind not in ('transfer','redeem')
    or p_amount_tokens is null or p_amount_tokens<=0 or p_amount_tokens>9007199254740991
    or length(coalesce(p_note,''))>280 then
    raise exception 'INVALID_WALLET_REQUEST' using errcode='22023'; end if;
  if p_kind='transfer' then
    if p_receiver_member_id is null or p_receiver_member_id !~ '^[0-9]{6}$' then
      raise exception 'INVALID_MEMBER_ID' using errcode='22023'; end if;
    -- Body04's unique canonical ID is required; do not pick a newest/first alias.
    select id into strict receiver from public.profiles where member_id=p_receiver_member_id;
    if receiver=actor then raise exception 'SELF_TRANSFER_NOT_ALLOWED' using errcode='22023'; end if;
  elsif p_receiver_member_id is not null or nullif(trim(coalesce(p_note,'')),'') is not null then
    raise exception 'INVALID_WALLET_REQUEST' using errcode='22023';
  end if;
  canonical:=jsonb_build_object('amount_tokens',p_amount_tokens,'receiver_member_id',p_receiver_member_id,
    'receiver_id',receiver,'note',nullif(trim(coalesce(p_note,'')),''));
  perform pg_advisory_xact_lock(hashtextextended(actor::text,90721));
  -- Idempotent request replay is checked before opening a new slot. An old
  -- acknowledged operation ID must never become a new financial instruction.
  select * into r from mobio_private.wallet_operations where operation_id=p_operation_id for update;
  if found then
    if r.owner_id<>actor or r.kind<>p_kind or r.request<>canonical then
      raise exception 'WALLET_OPERATION_CONFLICT' using errcode='22023'; end if;
    return mobio_private.wallet_operation_view(r);
  end if;
  select * into r from mobio_private.wallet_operations where owner_id=actor and acknowledged_at is null for update;
  if found then
    if r.kind<>p_kind or r.request<>canonical then
      raise exception 'WALLET_UNRESOLVED_OPERATION' using errcode='55000'; end if;
    return mobio_private.wallet_operation_view(r);
  end if;
  insert into mobio_private.wallet_operations(operation_id,owner_id,kind,request)
    values(p_operation_id,actor,p_kind,canonical) returning * into r;
  return mobio_private.wallet_operation_view(r);
exception when no_data_found then
  raise exception 'RECEIVER_NOT_FOUND' using errcode='22023';
when too_many_rows then
  raise exception 'AMBIGUOUS_RECEIVER' using errcode='22023';
end $$;

create function public.rpc_execute_wallet_operation(p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=public.verified_app_user_id();
  r mobio_private.wallet_operations%rowtype;
  result_receipt jsonb;
  key text:='mobio-v2:'||p_operation_id::text;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text,90721));
  select * into r from mobio_private.wallet_operations where operation_id=p_operation_id and owner_id=actor for update;
  if not found then raise exception 'WALLET_OPERATION_NOT_FOUND' using errcode='22023'; end if;
  if r.status='committed' then return mobio_private.wallet_operation_view(r); end if;
  if r.status<>'prepared' or r.acknowledged_at is not null then
    raise exception 'WALLET_OPERATION_CLOSED' using errcode='55000'; end if;
  if r.kind='transfer' then
    if not exists (select 1 from public.profiles where id=(r.request->>'receiver_id')::uuid
        and member_id=r.request->>'receiver_member_id') then
      raise exception 'RECEIVER_CHANGED' using errcode='22023'; end if;
    result_receipt:=public.rpc_transfer_tokens(r.request->>'receiver_member_id',
      (r.request->>'amount_tokens')::bigint,r.request->>'note',key)::jsonb;
    -- Legacy-key preplay or a concurrent direct legacy caller must not substitute
    -- another amount/recipient/note for this operation's reviewed request.
    if not exists (select 1 from public.wallet_transfers w
      where w.id=(result_receipt->>'transfer_id')::uuid and w.sender_profile_id=actor
        and w.receiver_profile_id=(r.request->>'receiver_id')::uuid
        and w.amount_tokens=(r.request->>'amount_tokens')::bigint and w.idempotency_key=key and w.status='completed'
        and nullif(trim(coalesce(w.note,'')),'') is not distinct from r.request->>'note') then
      raise exception 'WALLET_RECEIPT_BINDING_FAILED' using errcode='23514'; end if;
  else
    result_receipt:=public.rpc_redeem_wallet_tokens((r.request->>'amount_tokens')::bigint,key)::jsonb;
    if not exists (select 1 from public.token_redemption_requests x
      where x.id=(result_receipt->>'redemption_id')::uuid and x.requester_profile_id=actor
        and x.amount_tokens=(r.request->>'amount_tokens')::bigint and x.idempotency_key=key
        and x.wallet_transfer_id=(result_receipt->>'transfer_id')::uuid) then
      raise exception 'WALLET_RECEIPT_BINDING_FAILED' using errcode='23514'; end if;
  end if;
  if result_receipt is null or jsonb_typeof(result_receipt)<>'object' then
    raise exception 'INVALID_WALLET_RECEIPT' using errcode='23514'; end if;
  update mobio_private.wallet_operations set status='committed',receipt=result_receipt,
    completed_at=clock_timestamp() where operation_id=p_operation_id returning * into r;
  return mobio_private.wallet_operation_view(r);
end $$;

create function public.rpc_wallet_operation_status(p_operation_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=public.verified_app_user_id();r mobio_private.wallet_operations%rowtype;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  select * into r from mobio_private.wallet_operations where owner_id=actor
    and ((p_operation_id is null and acknowledged_at is null) or operation_id=p_operation_id);
  if not found then return jsonb_build_object('status','not_observed'); end if;
  return mobio_private.wallet_operation_view(r);
end $$;

create function public.rpc_close_wallet_operation(p_operation_id uuid,p_action text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.verified_app_user_id();r mobio_private.wallet_operations%rowtype;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_action is null or p_action not in ('acknowledge','cancel') then
    raise exception 'INVALID_WALLET_ACTION' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text,90721));
  select * into r from mobio_private.wallet_operations where owner_id=actor and operation_id=p_operation_id for update;
  if not found then raise exception 'WALLET_OPERATION_NOT_FOUND' using errcode='22023'; end if;
  if p_action='acknowledge' and r.status='committed' then
    update mobio_private.wallet_operations set acknowledged_at=coalesce(acknowledged_at,clock_timestamp())
      where operation_id=p_operation_id returning * into r;
  elsif p_action='cancel' and r.status='prepared' then
    -- Cancel races serialize with execution. A committed operation cannot be
    -- cancelled here; refunds remain a separate authorized financial process.
    update mobio_private.wallet_operations set status='cancelled',completed_at=clock_timestamp(),
      acknowledged_at=clock_timestamp() where operation_id=p_operation_id returning * into r;
  elsif p_action='cancel' and r.status='cancelled' then null;
  else raise exception 'WALLET_OPERATION_STATE_CHANGED' using errcode='55000'; end if;
  return mobio_private.wallet_operation_view(r);
end $$;
revoke all on function public.rpc_prepare_wallet_operation(uuid,text,bigint,text,text),
  public.rpc_execute_wallet_operation(uuid),public.rpc_wallet_operation_status(uuid),
  public.rpc_close_wallet_operation(uuid,text) from public,anon;
grant execute on function public.rpc_prepare_wallet_operation(uuid,text,bigint,text,text),
  public.rpc_execute_wallet_operation(uuid),public.rpc_wallet_operation_status(uuid),
  public.rpc_close_wallet_operation(uuid,text) to authenticated;
-- All supported consumer mutation paths must use the journal. The owner-run
-- SECURITY DEFINER wrapper above retains EXECUTE on these legacy implementations.
-- Older clients will fail closed after this migration; coordinate the client
-- rollout/maintenance window rather than silently retaining a bypass.
revoke all on function public.rpc_transfer_tokens(text,bigint,text,text),
  public.rpc_redeem_wallet_tokens(bigint,text) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
