-- Registered office-phone keys are public; private signing keys stay on device.
create table public.momobio_collectors (
  id uuid primary key,
  name text not null check (length(name) between 1 and 100),
  public_key_jwk jsonb not null,
  public_key_fingerprint text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  enrolled_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
)
;

create table public.momobio_collector_requests (
  collector_id uuid not null references public.momobio_collectors(id),
  nonce uuid not null,
  body_hash text not null check (body_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  primary key(collector_id,nonce)
)
;

create index momobio_collector_requests_rate_idx on public.momobio_collector_requests(collector_id,created_at)
;

create table public.momobio_collector_events (
  id bigint generated always as identity primary key,
  collector_id uuid not null references public.momobio_collectors(id),
  actor_id uuid references public.profiles(id),
  action text not null check(action in ('enrolled','revoked')),
  key_fingerprint text not null,
  created_at timestamptz not null default now()
)
;

alter table public.momobio_collectors enable row level security
;

alter table public.momobio_collector_requests enable row level security
;

alter table public.momobio_collector_events enable row level security
;

revoke all on public.momobio_collectors,public.momobio_collector_requests,public.momobio_collector_events from public,anon,authenticated
;

grant all on public.momobio_collectors,public.momobio_collector_requests,public.momobio_collector_events to service_role
;

grant usage,select on sequence public.momobio_collector_events_id_seq to service_role
;

create function public.rpc_register_momobio_collector(p_collector_id uuid,p_name text,p_public_key jsonb,p_expires_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_key jsonb; v_fingerprint text;
begin
  if not coalesce(public.is_platform_admin(), false) then raise exception 'ADMIN_REQUIRED'; end if;
  if p_collector_id is null or nullif(trim(p_name),'') is null or length(p_name)>100
    or p_expires_at is null or p_expires_at<=now() or p_expires_at>now()+interval '366 days'
    or coalesce(p_public_key->>'kty','')<>'RSA' or coalesce(p_public_key->>'e','')<>'AQAB'
    or length(coalesce(p_public_key->>'n','')) not between 342 and 683
    or coalesce(p_public_key->>'n','') !~ '^[A-Za-z0-9_-]+$' or p_public_key ? 'd' then
    raise exception 'INVALID_COLLECTOR_ENROLLMENT';
  end if;
  v_key := jsonb_build_object('kty','RSA','e','AQAB','n',p_public_key->>'n');
  v_fingerprint := encode(extensions.digest(E'RSA\n' || (v_key->>'n') || E'\nAQAB','sha256'),'hex');
  insert into public.momobio_collectors(id,name,public_key_jwk,public_key_fingerprint,expires_at,enrolled_by)
  values(p_collector_id,trim(p_name),v_key,v_fingerprint,p_expires_at,auth.uid())
  on conflict(id) do update set name=excluded.name,public_key_jwk=excluded.public_key_jwk,
    public_key_fingerprint=excluded.public_key_fingerprint,expires_at=excluded.expires_at,
    enrolled_by=auth.uid(),revoked_at=null,updated_at=now();
  insert into public.momobio_collector_events(collector_id,actor_id,action,key_fingerprint)
    values(p_collector_id,auth.uid(),'enrolled',v_fingerprint);
  return jsonb_build_object('collector_id',p_collector_id,'fingerprint',v_fingerprint,'expires_at',p_expires_at);
end $$
;

create function public.rpc_revoke_momobio_collector(p_collector_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_fingerprint text;
begin
  if not coalesce(public.is_platform_admin(), false) then raise exception 'ADMIN_REQUIRED'; end if;
  update public.momobio_collectors set revoked_at=now(),updated_at=now() where id=p_collector_id
    returning public_key_fingerprint into v_fingerprint;
  if v_fingerprint is null then raise exception 'COLLECTOR_NOT_FOUND'; end if;
  insert into public.momobio_collector_events(collector_id,actor_id,action,key_fingerprint)
    values(p_collector_id,auth.uid(),'revoked',v_fingerprint);
end $$
;

-- Called only after the Edge Function has verified the exact request bytes.
create function public.rpc_claim_momobio_collector_request(
  p_collector_id uuid,p_nonce uuid,p_timestamp_ms bigint,p_body_hash text,p_key_fingerprint text
) returns void language plpgsql security definer set search_path = '' as $$
declare v_collector public.momobio_collectors;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  select * into v_collector from public.momobio_collectors where id=p_collector_id for update;
  if v_collector.id is null or v_collector.revoked_at is not null or v_collector.expires_at<=now()
    or v_collector.public_key_fingerprint is distinct from p_key_fingerprint
    or p_timestamp_ms is null or abs(extract(epoch from clock_timestamp())*1000-p_timestamp_ms)>300000 then
    raise exception 'COLLECTOR_DENIED';
  end if;
  if exists(select 1 from public.momobio_collector_requests where collector_id=p_collector_id and nonce=p_nonce) then
    raise exception 'COLLECTOR_REPLAY';
  end if;
  if (select count(*) from public.momobio_collector_requests where collector_id=p_collector_id
    and created_at>now()-interval '1 minute') >= 20 then raise exception 'COLLECTOR_RATE_LIMIT'; end if;
  insert into public.momobio_collector_requests(collector_id,nonce,body_hash) values(p_collector_id,p_nonce,p_body_hash);
end $$
;

revoke all on function public.rpc_register_momobio_collector(uuid,text,jsonb,timestamptz) from public,anon
;

revoke all on function public.rpc_revoke_momobio_collector(uuid) from public,anon
;

revoke all on function public.rpc_claim_momobio_collector_request(uuid,uuid,bigint,text,text) from public,anon,authenticated
;

grant execute on function public.rpc_register_momobio_collector(uuid,text,jsonb,timestamptz) to authenticated
;

grant execute on function public.rpc_revoke_momobio_collector(uuid) to authenticated
;

grant execute on function public.rpc_claim_momobio_collector_request(uuid,uuid,bigint,text,text) to service_role
;
