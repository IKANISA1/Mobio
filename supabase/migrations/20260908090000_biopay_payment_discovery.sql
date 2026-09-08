-- A01-A24: external-payment discovery. No balances or settlement are added.
begin;

create table public.biopay_payment_methods (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider ~ '^[a-z0-9_]{2,32}$'),
  kind text not null check (kind in ('mobileWallet','merchantCode','bankAccount','bankAlias')),
  identifier text not null check (length(identifier) between 3 and 40),
  label text not null check (length(trim(label)) between 1 and 60),
  login_phone text check (login_phone ~ '^\+2507[0-9]{8}$'),
  sim_label text check (length(sim_label) <= 40),
  can_send boolean not null default false,
  can_receive boolean not null default true,
  phone_discoverable boolean not null default false,
  preferred boolean not null default false,
  active boolean not null default true,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (can_send or can_receive),
  check (kind<>'merchantCode' or not can_send),
  check (not preferred or can_send),
  check (not phone_discoverable or can_receive),
  check (kind <> 'mobileWallet' or identifier ~ '^\+2507[0-9]{8}$'),
  check (kind <> 'merchantCode' or identifier ~ '^[0-9]{3,20}$'),
  check (kind not in ('bankAccount','bankAlias') or identifier ~ '^[A-Za-z0-9 -]{3,40}$')
);
create unique index biopay_method_active_endpoint on public.biopay_payment_methods
  (owner_id,provider,kind,identifier) where active;
create index biopay_method_owner on public.biopay_payment_methods(owner_id);

create table public.biopay_method_grants (
  method_id uuid not null references public.biopay_payment_methods(id) on delete cascade,
  grantee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(method_id,grantee_id)
);

create table public.biopay_provider_routes (
  id uuid primary key default gen_random_uuid(),
  source_provider text not null,
  source_kind text not null default 'mobileWallet' check (source_kind in ('mobileWallet','bankAccount','bankAlias')),
  requires_login_phone boolean not null default false,
  destination_provider text not null,
  destination_kind text not null check (destination_kind in ('mobileWallet','merchantCode','bankAccount','bankAlias')),
  rail text not null check (length(rail) between 1 and 40),
  purpose text not null check (purpose in ('transfer','merchant')),
  currency text not null default 'RWF' check (currency = 'RWF'),
  min_rwf integer not null default 1 check (min_rwf > 0),
  max_rwf integer not null default 10000000 check (max_rwf <= 10000000 and max_rwf >= min_rwf),
  fee_certainty text not null default 'unknown' check (fee_certainty in ('exact','capped','unknown')),
  fee_rwf integer check (fee_rwf >= 0),
  fee_all_in boolean not null default false,
  steps integer check (steps > 0),
  handoff_mode text not null default 'instructions' check (handoff_mode in ('dial','instructions')),
  instruction_template text,
  recipient_format text not null default 'raw' check (recipient_format in ('raw','e164Digits','rwandaNational')),
  device_families text[] not null default '{}',
  requires_sim boolean not null default true,
  adapter_version integer not null default 1,
  tariff_version integer not null default 1,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  evidence_url text,
  tariff_evidence_url text,
  test_evidence_url text,
  tested_at timestamptz,
  tested_by uuid references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  state text not null default 'draft' check (state in ('draft','tested','approved','disabled')),
  updated_at timestamptz not null default now(),
  check (fee_certainty = 'unknown' or fee_rwf is not null),
  check (state <> 'approved' or (
    tested_at is not null and tested_by is not null and reviewed_by is not null
    and tested_by <> reviewed_by and reviewed_at is not null
    and position('{recipient}' in instruction_template)>0
    and position('{amount}' in instruction_template)>0 and cardinality(device_families)>0
    and valid_until is not null and valid_until>valid_from
    and evidence_url ~ '^https://' and tariff_evidence_url ~ '^https://'
    and test_evidence_url ~ '^https://'
  ) is true),
  check (device_families <@ array['android','ios','web','desktop']),
  check (recipient_format='raw' or destination_kind='mobileWallet')
);

create table public.biopay_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique default encode(extensions.gen_random_bytes(24),'hex'),
  scope text not null check (scope in ('profile','method','request')),
  method_ids uuid[] not null check (cardinality(method_ids) > 0),
  method_versions jsonb not null,
  label text not null check (length(label) between 1 and 60),
  amount_rwf integer check (amount_rwf > 0 and amount_rwf <= 10000000),
  purpose text not null default 'transfer' check (purpose in ('transfer','merchant')),
  reference text not null default '' check (length(reference) <= 80),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  check (scope <> 'method' or cardinality(method_ids) = 1),
  check (scope = 'request' or amount_rwf is null)
);
create index biopay_link_owner on public.biopay_links(owner_id,created_at desc);

create table public.biopay_payment_drafts (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  revision integer not null check (revision >= 0),
  data jsonb not null check (octet_length(data::text) <= 8000),
  updated_at timestamptz not null default now()
);

create table public.biopay_route_quotes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  draft_id uuid not null references public.biopay_payment_drafts(id) on delete cascade,
  revision integer not null,
  input jsonb not null,
  options jsonb not null,
  expires_at timestamptz not null default now() + interval '2 minutes',
  request_id uuid references public.biopay_payment_requests(id),
  prepared_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.biopay_discovery_rate_limits (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  window_at timestamptz not null,
  attempts integer not null default 0
);

create table public.biopay_recipient_shortcuts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  lookup text not null check (length(lookup) between 1 and 100),
  nickname text not null check (length(nickname) between 1 and 60),
  favorite boolean not null default false,
  updated_at timestamptz not null default now(),
  unique(owner_id,lookup)
);

create table public.biopay_request_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  label text not null check (length(label) between 1 and 60),
  data jsonb not null check (octet_length(data::text) <= 4000),
  created_at timestamptz not null default now()
);

-- Existing request/attempt records remain the only external interaction history.
alter table public.biopay_payment_requests add column discovery_quote_id uuid references public.biopay_route_quotes(id);
alter table public.biopay_payment_requests add column evidence_kind text not null default 'unclassified';
alter table public.biopay_payment_requests add column reviewed_snapshot jsonb;

do $$
declare t text;
begin
  foreach t in array array['biopay_payment_methods','biopay_method_grants',
    'biopay_provider_routes','biopay_links','biopay_payment_drafts',
    'biopay_route_quotes','biopay_discovery_rate_limits','biopay_recipient_shortcuts','biopay_request_templates'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;

create or replace function public.fn_biopay_discovery_user() returns uuid
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true)
    or not exists(select 1 from public.profiles where id=u and whatsapp_verified_at is not null)
  then raise exception 'Verified sign-in required' using errcode='42501'; end if;
  return u;
end $$;

-- Recipient output explicitly omits login phone, SIM, preferences and send role.
create or replace function public.fn_biopay_receiving_method(m public.biopay_payment_methods)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('id',m.id,'owner_id',m.owner_id,'provider',m.provider,
    'kind',m.kind,'identifier',m.identifier,'label',m.label,'can_receive',m.can_receive,
    'version',m.version,'active',m.active)
$$;

create or replace function public.fn_biopay_discover(p_user uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l public.biopay_links; result jsonb; v_phone text; manual jsonb; legacy public.biopay_payment_requests; legacy_match text[];
begin
  if coalesce(p_input->>'link_token','') <> '' then
    select * into l from public.biopay_links where token=p_input->>'link_token'
      and revoked_at is null and expires_at > now();
    if not found then raise exception 'Link unavailable. Ask for a new link.'; end if;
    select coalesce(jsonb_agg(public.fn_biopay_receiving_method(m) order by m.id),'[]') into result
      from public.biopay_payment_methods m where m.id=any(l.method_ids)
      and m.owner_id=l.owner_id and m.active and m.can_receive
      and m.version=(l.method_versions->>m.id::text)::integer;
    if jsonb_array_length(result) <> cardinality(l.method_ids) then
      raise exception 'Receiving details changed. Ask for a new link.';
    end if;
    return jsonb_build_object('label',l.label,'methods',result,'assurance','sharedLink',
      'link_token',l.token,'fixed_amount',l.amount_rwf,'purpose',l.purpose,'reference',l.reference,'link_version',l.version);
  end if;
  if coalesce(p_input->>'lookup','') like 'legacy:%' then
    select * into legacy from public.biopay_payment_requests
      where token=substring(p_input->>'lookup' from 8) and discovery_quote_id is null
      and expires_at>now() and status not in ('expired','cancelled','failed','confirmed');
    if not found then raise exception 'Legacy request unavailable. Ask for a new link.'; end if;
    legacy_match:=regexp_match(legacy.ussd_code,'^\*182\*(1\*1|8\*1)\*([0-9+]+)(?:\*([0-9]+))?#$');
    if legacy_match is null then raise exception 'Enter receiving details for this legacy request.'; end if;
    manual:=jsonb_build_object('provider','mtn_rw','kind',case when legacy_match[1]='8*1' then 'merchantCode' else 'mobileWallet' end,
      'identifier',case when legacy_match[1]='8*1' then legacy_match[2]
      when legacy_match[2] ~ '^07[0-9]{8}$' then '+250'||substring(legacy_match[2] from 2)
      when legacy_match[2] ~ '^2507[0-9]{8}$' then '+'||legacy_match[2] else legacy_match[2] end);
    result:=public.fn_biopay_discover(p_user,jsonb_build_object('manual_method',manual));
    if legacy.amount_minor>0 and legacy.amount_minor%100<>0 then raise exception 'Unsupported legacy amount.'; end if;
    return result||jsonb_build_object('fixed_amount',nullif(legacy.amount_minor/100,0),
      'purpose',case when legacy_match[1]='8*1' then 'merchant' else 'transfer' end);
  end if;
  manual := p_input->'manual_method';
  if jsonb_typeof(manual)='object' then
    if coalesce(manual->>'provider','') !~ '^[a-z0-9_]{2,32}$'
      or coalesce(manual->>'kind','') not in ('mobileWallet','merchantCode','bankAccount','bankAlias')
      or length(coalesce(manual->>'identifier','')) not between 3 and 40
      or (manual->>'kind'='mobileWallet' and manual->>'identifier' !~ '^\+2507[0-9]{8}$')
      or (manual->>'kind'='merchantCode' and manual->>'identifier' !~ '^[0-9]{3,20}$')
      or (manual->>'kind' in ('bankAccount','bankAlias') and manual->>'identifier' !~ '^[A-Za-z0-9 -]{3,40}$')
    then raise exception 'Check the receiving details.'; end if;
    -- Never accept supplied owner, assurance, send role or destination version.
    return jsonb_build_object('label','Entered receiving details','assurance','manual',
      'methods',jsonb_build_array(jsonb_build_object('id','manual','owner_id','',
        'provider',manual->>'provider','kind',manual->>'kind','identifier',manual->>'identifier',
        'label','Entered receiving details','can_receive',true,'active',true,'version',0)));
  end if;
  v_phone := p_input->>'lookup';
  -- Identical no-results response for private and nonexistent profiles.
  select coalesce(jsonb_agg(public.fn_biopay_receiving_method(m) order by m.id),'[]') into result
    from public.biopay_payment_methods m join public.profiles p on p.id=m.owner_id
    where m.active and m.can_receive and p.phone=v_phone
    and (m.owner_id=p_user or m.phone_discoverable or exists(
      select 1 from public.biopay_method_grants g where g.method_id=m.id and g.grantee_id=p_user));
  return jsonb_build_object('label','Shared receiving details','assurance','shared',
    'lookup',v_phone,'methods',result);
end $$;

create or replace function public.fn_biopay_quote_options(p_user uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare recipient jsonb; result jsonb; availability jsonb; amount integer; v_purpose text; device text;
begin
  if coalesce(p_input->>'amount','') !~ '^[0-9]{1,8}$' then raise exception 'Enter whole RWF.'; end if;
  amount := (p_input->>'amount')::integer;
  v_purpose := p_input->>'purpose';
  device := p_input->>'device';
  if amount not between 1 and 10000000 or coalesce(v_purpose,'') not in ('transfer','merchant')
    or coalesce(device,'') not in ('android','ios','web','desktop') then raise exception 'Payment details invalid.'; end if;
  recipient := public.fn_biopay_discover(p_user,p_input);
  if recipient->>'fixed_amount' is not null and (recipient->>'fixed_amount')::integer <> amount
    or recipient->>'purpose' is not null and recipient->>'purpose' <> v_purpose then
    raise exception 'Request amount or purpose changed.';
  end if;
  if nullif(recipient->>'reference','') is not null and recipient->>'reference' is distinct from p_input->>'reference' then
    raise exception 'Request reference changed. Review again.';
  end if;
  select coalesce(jsonb_agg(option order by option->>'id'),'[]') into result from (
    select distinct on (s.provider,s.kind,s.identifier,d->>'provider',d->>'kind',d->>'identifier',r.rail)
      jsonb_build_object('id',r.id::text||':'||s.id::text||':'||(d->>'id'),
      'adapter_id',r.id,'source',to_jsonb(s),'destination',d,'rail',r.rail,
      'fee',jsonb_build_object('certainty',r.fee_certainty,'francs',r.fee_rwf,'all_in',r.fee_all_in),
      'adapter_version',r.adapter_version,'tariff_version',r.tariff_version,'steps',r.steps,
      'handoff_mode',r.handoff_mode,'sim_required',r.requires_sim,
      'supports_reference',position('{reference}' in r.instruction_template)>0) as option
    from public.biopay_payment_methods s cross join jsonb_array_elements(recipient->'methods') d
    join public.biopay_provider_routes r on r.destination_provider=d->>'provider'
      and r.destination_kind=d->>'kind'
    where s.owner_id=p_user and s.active and s.can_send
      and r.source_provider=s.provider and r.source_kind=s.kind
      and (not r.requires_login_phone or s.login_phone is not null) and r.state='approved' and r.valid_from<=now() and r.valid_until>now() and r.purpose=v_purpose
      and amount between r.min_rwf and r.max_rwf and device=any(r.device_families)
      and (not r.requires_sim or nullif(s.sim_label,'') is not null)
    order by s.provider,s.kind,s.identifier,d->>'provider',d->>'kind',d->>'identifier',r.rail,
      case when r.fee_all_in and r.fee_certainty<>'unknown' then r.fee_rwf end nulls last,r.id
  ) candidates;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'reason',case
    when not s.can_send then 'notSending'
    when exists(select 1 from jsonb_array_elements(result) o where o->'source'->>'id'=s.id::text) then null
    when s.sim_label is null and exists(select 1 from public.biopay_provider_routes r
      where r.source_provider=s.provider and r.source_kind=s.kind and r.requires_sim and r.state='approved'
      and r.valid_from<=now() and r.valid_until>now() and r.purpose=v_purpose and device=any(r.device_families)
      and amount between r.min_rwf and r.max_rwf) then 'missingSim'
    when s.login_phone is null and exists(select 1 from public.biopay_provider_routes r
      where r.source_provider=s.provider and r.source_kind=s.kind and r.requires_login_phone and r.state='approved'
      and r.valid_from<=now() and r.valid_until>now() and r.purpose=v_purpose and device=any(r.device_families)
      and amount between r.min_rwf and r.max_rwf) then 'missingLogin'
    else 'noReviewedRoute' end)),'[]') into availability from public.biopay_payment_methods s where s.owner_id=p_user and s.active;
  if nullif(p_input->>'source_id','') is not null then
    select coalesce(jsonb_agg(o),'[]') into result from jsonb_array_elements(result) o where o->'source'->>'id'=p_input->>'source_id';
  end if;
  return jsonb_build_object('recipient',recipient,'options',result,'source_availability',availability);
end $$;

revoke all on function public.fn_biopay_discovery_user() from public,anon,authenticated;
revoke all on function public.fn_biopay_receiving_method(public.biopay_payment_methods) from public,anon,authenticated;
revoke all on function public.fn_biopay_discover(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.fn_biopay_quote_options(uuid,jsonb) from public,anon,authenticated;

commit;
