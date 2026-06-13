-- BioPay reactivation: USSD-assisted external payment and AWS face provider.
-- Payment remains outside Mobio. The app creates/opens tel: USSD requests and
-- stores attempt/confirmation state only.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.biopay_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  handle text not null,
  provider text not null default 'aws_rekognition',
  provider_subject_id text,
  provider_collection_id text,
  liveness_status text not null default 'not_started',
  status text not null default 'active' check (
    status in ('active', 'paused', 'deleted', 'rejected')
  ),
  consent_granted_at timestamptz,
  matching_paused_at timestamptz,
  deleted_at timestamptz,
  provider_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.biopay_payment_requests (
  id uuid primary key default gen_random_uuid(),
  token text not null unique default replace(
    replace(rtrim(encode(extensions.gen_random_bytes(18), 'base64'), '='), '+', '-'),
    '/',
    '_'
  ),
  channel text not null check (channel in ('qr', 'nfc', 'face')),
  payer_id uuid references public.profiles(id) on delete set null,
  payee_id uuid references public.profiles(id) on delete set null,
  payee_label text not null,
  provider_code text not null default 'mtn_rw',
  amount_minor integer not null check (amount_minor > 0),
  currency text not null default 'RWF',
  reference text not null,
  ussd_code text not null,
  status text not null default 'ready_to_dial' check (
    status in (
      'draft',
      'ready_to_dial',
      'dialer_opened',
      'user_marked_paid',
      'confirmed',
      'expired',
      'cancelled',
      'failed'
    )
  ),
  expires_at timestamptz not null default now() + interval '15 minutes',
  confirmed_at timestamptz,
  confirmation_source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.biopay_ussd_attempts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.biopay_payment_requests(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  action text not null check (
    action in ('dialer_opened', 'user_marked_paid', 'cancelled')
  ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.biopay_face_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  payment_request_id uuid references public.biopay_payment_requests(id) on delete set null,
  purpose text not null check (purpose in ('enrollment', 'scan')),
  provider text not null default 'aws_rekognition',
  provider_session_id text,
  provider_face_id text,
  provider_collection_id text,
  liveness_status text not null default 'not_started',
  match_status text not null default 'pending' check (
    match_status in ('pending', 'matched', 'needs_review', 'rejected')
  ),
  confidence numeric(7,6) check (confidence is null or confidence between 0 and 1),
  raw_asset_deleted_at timestamptz,
  provider_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.biopay_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  request_id uuid references public.biopay_payment_requests(id) on delete set null,
  action text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.biopay_profiles enable row level security;
alter table public.biopay_payment_requests enable row level security;
alter table public.biopay_ussd_attempts enable row level security;
alter table public.biopay_face_sessions enable row level security;
alter table public.biopay_audit_events enable row level security;

drop policy if exists biopay_profiles_self_read on public.biopay_profiles;
create policy biopay_profiles_self_read
  on public.biopay_profiles
  for select using (user_id = auth.uid());

drop policy if exists biopay_requests_self_read on public.biopay_payment_requests;
create policy biopay_requests_self_read
  on public.biopay_payment_requests
  for select using (payer_id = auth.uid() or payee_id = auth.uid());

drop policy if exists biopay_attempts_self_read on public.biopay_ussd_attempts;
create policy biopay_attempts_self_read
  on public.biopay_ussd_attempts
  for select using (user_id = auth.uid());

drop policy if exists biopay_face_sessions_self_read on public.biopay_face_sessions;
create policy biopay_face_sessions_self_read
  on public.biopay_face_sessions
  for select using (user_id = auth.uid());

drop policy if exists biopay_audit_self_read on public.biopay_audit_events;
create policy biopay_audit_self_read
  on public.biopay_audit_events
  for select using (actor_user_id = auth.uid());

create or replace function public.fn_biopay_ussd_code(
  p_provider_code text,
  p_payee_phone text,
  p_amount_minor integer,
  p_reference text
) returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  amount_major integer := greatest(1, ceil(p_amount_minor::numeric / 100)::integer);
  normalized_phone text := regexp_replace(coalesce(p_payee_phone, ''), '[^0-9+]', '', 'g');
begin
  if p_provider_code = 'mtn_rw' then
    return '*182*8*1*' || coalesce(nullif(normalized_phone, ''), p_reference) || '*' || amount_major::text || '#';
  end if;

  return '*' || p_provider_code || '*' || coalesce(nullif(normalized_phone, ''), p_reference) || '*' || amount_major::text || '#';
end;
$$;

create or replace function public.rpc_create_biopay_ussd_request(
  p_channel text,
  p_amount_minor integer,
  p_payee_label text,
  p_provider_code text default 'mtn_rw',
  p_payee_phone text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_reference text := 'BP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  v_phone text;
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_channel not in ('qr', 'nfc', 'face') then
    raise exception 'Invalid BioPay channel';
  end if;

  select coalesce(p_payee_phone, phone, whatsapp)
    into v_phone
  from public.profiles
  where id = v_user_id;

  insert into public.biopay_payment_requests (
    channel,
    payee_id,
    payee_label,
    provider_code,
    amount_minor,
    reference,
    ussd_code
  ) values (
    p_channel,
    v_user_id,
    coalesce(nullif(trim(p_payee_label), ''), 'BioPay merchant'),
    coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
    p_amount_minor,
    v_reference,
    public.fn_biopay_ussd_code(
      coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
      v_phone,
      p_amount_minor,
      v_reference
    )
  )
  returning * into v_row;

  insert into public.biopay_audit_events(actor_user_id, request_id, action)
  values (v_user_id, v_row.id, 'biopay.ussd_request.created');

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_create_biopay_face_match_request(
  p_provider_face_id text,
  p_amount_minor integer,
  p_provider_code text default 'mtn_rw'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_provider_face_id text := nullif(trim(coalesce(p_provider_face_id, '')), '');
  v_reference text := 'BP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  v_payee_profile public.profiles;
  v_biopay_profile public.biopay_profiles;
  v_phone text;
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if v_provider_face_id is null then
    raise exception 'Matched provider face id required';
  end if;

  select bp.*
    into v_biopay_profile
  from public.biopay_profiles bp
  where bp.provider_subject_id = v_provider_face_id
    and bp.status = 'active'
    and bp.deleted_at is null
  limit 1;

  if v_biopay_profile.id is null then
    raise exception 'Matched BioPay profile not found';
  end if;

  select *
    into v_payee_profile
  from public.profiles
  where id = v_biopay_profile.user_id;

  v_phone := coalesce(v_payee_profile.phone, v_payee_profile.whatsapp);

  insert into public.biopay_payment_requests (
    channel,
    payer_id,
    payee_id,
    payee_label,
    provider_code,
    amount_minor,
    reference,
    ussd_code
  ) values (
    'face',
    v_user_id,
    v_biopay_profile.user_id,
    coalesce(
      nullif(trim(v_payee_profile.display_name), ''),
      nullif(trim(v_payee_profile.name), ''),
      'BioPay merchant'
    ),
    coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
    p_amount_minor,
    v_reference,
    public.fn_biopay_ussd_code(
      coalesce(nullif(trim(p_provider_code), ''), 'mtn_rw'),
      v_phone,
      p_amount_minor,
      v_reference
    )
  )
  returning * into v_row;

  insert into public.biopay_face_sessions (
    user_id,
    payment_request_id,
    purpose,
    provider_face_id,
    provider_collection_id,
    liveness_status,
    match_status,
    raw_asset_deleted_at,
    provider_metadata
  ) values (
    v_user_id,
    v_row.id,
    'scan',
    v_provider_face_id,
    v_biopay_profile.provider_collection_id,
    'provider_liveness_not_required',
    'matched',
    now(),
    jsonb_build_object('matched_payee_id', v_biopay_profile.user_id)
  );

  insert into public.biopay_audit_events(actor_user_id, request_id, action, metadata)
  values (
    v_user_id,
    v_row.id,
    'biopay.face_match.ussd_request.created',
    jsonb_build_object('provider_face_id', v_provider_face_id)
  );

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_resolve_biopay_ussd_request(
  p_token text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.biopay_payment_requests;
begin
  select *
    into v_row
  from public.biopay_payment_requests
  where token = p_token
    and status in ('ready_to_dial', 'dialer_opened', 'user_marked_paid')
    and expires_at > now();

  if v_row.id is null then
    raise exception 'BioPay request not found or expired';
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'token', v_row.token,
    'channel', v_row.channel,
    'provider_code', v_row.provider_code,
    'payee_label', v_row.payee_label,
    'amount_minor', v_row.amount_minor,
    'currency', v_row.currency,
    'reference', v_row.reference,
    'ussd_code', v_row.ussd_code,
    'status', v_row.status,
    'expires_at', v_row.expires_at
  );
end;
$$;

create or replace function public.rpc_record_biopay_ussd_dialer_opened(
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  update public.biopay_payment_requests
  set status = 'dialer_opened',
      payer_id = coalesce(payer_id, v_user_id),
      updated_at = now()
  where id = p_request_id
    and status in ('ready_to_dial', 'dialer_opened')
    and expires_at > now()
  returning * into v_row;

  if v_row.id is null then
    raise exception 'BioPay request is not ready for USSD dialer handoff';
  end if;

  insert into public.biopay_ussd_attempts(request_id, user_id, action)
  values (p_request_id, v_user_id, 'dialer_opened');

  insert into public.biopay_audit_events(actor_user_id, request_id, action)
  values (v_user_id, p_request_id, 'biopay.ussd_dialer.opened');

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_mark_biopay_ussd_user_paid(
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  update public.biopay_payment_requests
  set status = 'user_marked_paid',
      payer_id = coalesce(payer_id, v_user_id),
      updated_at = now()
  where id = p_request_id
    and status in ('dialer_opened', 'user_marked_paid')
    and expires_at > now()
  returning * into v_row;

  if v_row.id is null then
    raise exception 'BioPay request is not ready for user payment marking';
  end if;

  insert into public.biopay_ussd_attempts(request_id, user_id, action)
  values (p_request_id, v_user_id, 'user_marked_paid');

  insert into public.biopay_audit_events(actor_user_id, request_id, action)
  values (v_user_id, p_request_id, 'biopay.ussd.user_marked_paid');

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_list_biopay_ussd_requests(
  p_limit integer default 20
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  return coalesce(
    (
      select jsonb_agg(to_jsonb(rows) order by rows.created_at desc)
      from (
        select
          id,
          token,
          channel,
          provider_code,
          payee_label,
          amount_minor,
          currency,
          reference,
          ussd_code,
          status,
          expires_at,
          confirmed_at,
          confirmation_source,
          created_at,
          updated_at
        from public.biopay_payment_requests
        where payer_id = v_user_id
           or payee_id = v_user_id
        order by created_at desc
        limit greatest(1, least(50, coalesce(p_limit, 20)))
      ) rows
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.rpc_confirm_biopay_ussd_external(
  p_request_id uuid,
  p_confirmation_source text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_source text := nullif(trim(coalesce(p_confirmation_source, '')), '');
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if v_source is null then
    raise exception 'External confirmation source required';
  end if;

  update public.biopay_payment_requests
  set status = 'confirmed',
      confirmed_at = now(),
      confirmation_source = v_source,
      updated_at = now()
  where id = p_request_id
    and payee_id = v_user_id
    and status = 'user_marked_paid'
  returning * into v_row;

  if v_row.id is null then
    raise exception 'BioPay request is not externally confirmable';
  end if;

  insert into public.biopay_audit_events(actor_user_id, request_id, action, metadata)
  values (
    v_user_id,
    p_request_id,
    'biopay.ussd.externally_confirmed',
    jsonb_build_object('confirmation_source', v_source)
  );

  return to_jsonb(v_row);
end;
$$;

create or replace function public.rpc_record_biopay_face_enrollment(
  p_provider_session_id text default null,
  p_provider_face_id text default null,
  p_provider_collection_id text default null,
  p_liveness_status text default 'provider_liveness_not_required',
  p_quality_score numeric default null,
  p_provider_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.biopay_profiles;
  v_session public.biopay_face_sessions;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if coalesce(nullif(trim(p_provider_face_id), ''), '') = '' then
    raise exception 'Provider face id required';
  end if;

  insert into public.biopay_profiles (
    user_id,
    handle,
    provider_subject_id,
    provider_collection_id,
    liveness_status,
    consent_granted_at,
    provider_metadata
  ) values (
    v_user_id,
    'bio-' || substr(replace(v_user_id::text, '-', ''), 1, 12),
    p_provider_face_id,
    p_provider_collection_id,
    coalesce(nullif(trim(p_liveness_status), ''), 'provider_liveness_not_required'),
    now(),
    coalesce(p_provider_metadata, '{}'::jsonb)
  )
  on conflict (user_id) do update
  set provider_subject_id = excluded.provider_subject_id,
      provider_collection_id = excluded.provider_collection_id,
      liveness_status = excluded.liveness_status,
      status = 'active',
      consent_granted_at = coalesce(public.biopay_profiles.consent_granted_at, now()),
      provider_metadata = excluded.provider_metadata,
      matching_paused_at = null,
      deleted_at = null,
      updated_at = now()
  returning * into v_profile;

  insert into public.biopay_face_sessions (
    user_id,
    purpose,
    provider_session_id,
    provider_face_id,
    provider_collection_id,
    liveness_status,
    match_status,
    confidence,
    raw_asset_deleted_at,
    provider_metadata
  ) values (
    v_user_id,
    'enrollment',
    nullif(trim(coalesce(p_provider_session_id, '')), ''),
    p_provider_face_id,
    p_provider_collection_id,
    v_profile.liveness_status,
    'matched',
    case
      when p_quality_score is null then null
      else greatest(0, least(1, p_quality_score))
    end,
    now(),
    coalesce(p_provider_metadata, '{}'::jsonb)
  )
  returning * into v_session;

  insert into public.biopay_audit_events(actor_user_id, action, metadata)
  values (
    v_user_id,
    'biopay.face.enrolled',
    jsonb_build_object(
      'face_session_id', v_session.id,
      'provider', v_profile.provider,
      'provider_collection_id', v_profile.provider_collection_id
    )
  );

  return jsonb_build_object(
    'profile', to_jsonb(v_profile),
    'session', to_jsonb(v_session)
  );
end;
$$;

create or replace function public.fn_biopay_require_admin()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role = 'admin'
  ) then
    raise exception 'Admin access required';
  end if;
end;
$$;

create or replace function public.rpc_admin_biopay_summary()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total_payees integer;
  v_enrolled_payees integer;
  v_total_requests integer;
  v_pending_confirmations integer;
  v_confirmed_requests integer;
  v_match_attempts integer;
  v_matched_attempts integer;
begin
  perform public.fn_biopay_require_admin();

  select count(*)::integer,
         count(*) filter (
           where provider_subject_id is not null and status = 'active'
         )::integer
    into v_total_payees, v_enrolled_payees
  from public.biopay_profiles;

  select count(*)::integer,
         count(*) filter (where status = 'user_marked_paid')::integer,
         count(*) filter (where status = 'confirmed')::integer
    into v_total_requests, v_pending_confirmations, v_confirmed_requests
  from public.biopay_payment_requests;

  select count(*)::integer,
         count(*) filter (where match_status = 'matched')::integer
    into v_match_attempts, v_matched_attempts
  from public.biopay_face_sessions
  where purpose = 'scan';

  return jsonb_build_object(
    'total_payees', coalesce(v_total_payees, 0),
    'enrolled_payees', coalesce(v_enrolled_payees, 0),
    'total_requests', coalesce(v_total_requests, 0),
    'pending_confirmations', coalesce(v_pending_confirmations, 0),
    'confirmed_requests', coalesce(v_confirmed_requests, 0),
    'match_rate', case
      when coalesce(v_match_attempts, 0) = 0 then 0
      else round((v_matched_attempts::numeric / v_match_attempts::numeric), 4)
    end
  );
end;
$$;

create or replace function public.rpc_admin_biopay_list_payees(
  p_search text default null,
  p_limit integer default 50
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_search text := lower(nullif(trim(coalesce(p_search, '')), ''));
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_rows jsonb;
begin
  perform public.fn_biopay_require_admin();

  select coalesce(jsonb_agg(row_payload order by sort_created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select
      bp.created_at as sort_created_at,
      jsonb_build_object(
        'user_id', bp.user_id,
        'handle', bp.handle,
        'display_name', coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.name), ''), bp.handle),
        'provider', bp.provider,
        'provider_subject_id', bp.provider_subject_id,
        'provider_collection_id', bp.provider_collection_id,
        'liveness_status', bp.liveness_status,
        'status', bp.status,
        'request_count', (
          select count(*)::integer
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
        ),
        'confirmed_count', (
          select count(*)::integer
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
            and request.status = 'confirmed'
        ),
        'last_request_at', (
          select max(request.created_at)
          from public.biopay_payment_requests request
          where request.payee_id = bp.user_id
        ),
        'enrolled_at', bp.consent_granted_at
      ) as row_payload
    from public.biopay_profiles bp
    left join public.profiles p on p.id = bp.user_id
    where v_search is null
       or lower(bp.handle) like '%' || v_search || '%'
       or lower(coalesce(p.display_name, '')) like '%' || v_search || '%'
       or lower(coalesce(p.name, '')) like '%' || v_search || '%'
       or lower(coalesce(bp.provider_subject_id, '')) like '%' || v_search || '%'
    order by bp.created_at desc
    limit v_limit
  ) payees;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

create or replace function public.rpc_admin_biopay_list_requests(
  p_limit integer default 50
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_rows jsonb;
begin
  perform public.fn_biopay_require_admin();

  select coalesce(jsonb_agg(row_payload order by sort_created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select
      request.created_at as sort_created_at,
      jsonb_build_object(
        'id', request.id,
        'token', request.token,
        'channel', request.channel,
        'provider_code', request.provider_code,
        'payee_label', request.payee_label,
        'amount_minor', request.amount_minor,
        'currency', request.currency,
        'reference', request.reference,
        'ussd_code', request.ussd_code,
        'status', request.status,
        'expires_at', request.expires_at,
        'confirmed_at', request.confirmed_at,
        'confirmation_source', request.confirmation_source,
        'created_at', request.created_at
      ) as row_payload
    from public.biopay_payment_requests request
    order by request.created_at desc
    limit v_limit
  ) requests;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

create or replace function public.rpc_admin_biopay_system_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_collection_id text;
  v_has_enrolled_face boolean;
  v_pending_confirmations integer;
  v_last_audit_at timestamptz;
begin
  perform public.fn_biopay_require_admin();

  select max(provider_collection_id),
         bool_or(provider_subject_id is not null and status = 'active')
    into v_collection_id, v_has_enrolled_face
  from public.biopay_profiles;

  select count(*)::integer
    into v_pending_confirmations
  from public.biopay_payment_requests
  where status = 'user_marked_paid';

  select max(created_at)
    into v_last_audit_at
  from public.biopay_audit_events;

  return jsonb_build_object(
    'overall_status', case
      when coalesce(v_has_enrolled_face, false) then 'operational'
      else 'configuration_required'
    end,
    'face_provider', 'aws_rekognition',
    'face_provider_ready', coalesce(v_has_enrolled_face, false),
    'collection_id', coalesce(v_collection_id, ''),
    'database_status', 'available',
    'ussd_handoff_status', 'external_ussd_only',
    'pending_confirmations', coalesce(v_pending_confirmations, 0),
    'last_audit_at', v_last_audit_at
  );
end;
$$;

create or replace function public.rpc_admin_biopay_confirm_external(
  p_request_id uuid,
  p_confirmation_source text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_source text := nullif(trim(coalesce(p_confirmation_source, '')), '');
  v_row public.biopay_payment_requests;
begin
  perform public.fn_biopay_require_admin();

  if v_source is null then
    raise exception 'External confirmation source required';
  end if;

  update public.biopay_payment_requests
  set status = 'confirmed',
      confirmed_at = now(),
      confirmation_source = v_source,
      updated_at = now()
  where id = p_request_id
    and status = 'user_marked_paid'
  returning * into v_row;

  if v_row.id is null then
    raise exception 'BioPay request is not externally confirmable';
  end if;

  insert into public.biopay_audit_events(actor_user_id, request_id, action, metadata)
  values (
    v_user_id,
    p_request_id,
    'biopay.admin.externally_confirmed',
    jsonb_build_object('confirmation_source', v_source)
  );

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.fn_biopay_ussd_code(text, text, integer, text) from public;
grant execute on function public.fn_biopay_ussd_code(text, text, integer, text) to authenticated;
grant execute on function public.rpc_create_biopay_ussd_request(text, integer, text, text, text) to authenticated;
grant execute on function public.rpc_create_biopay_face_match_request(text, integer, text) to authenticated;
grant execute on function public.rpc_resolve_biopay_ussd_request(text) to authenticated;
grant execute on function public.rpc_record_biopay_ussd_dialer_opened(uuid) to authenticated;
grant execute on function public.rpc_mark_biopay_ussd_user_paid(uuid) to authenticated;
grant execute on function public.rpc_list_biopay_ussd_requests(integer) to authenticated;
grant execute on function public.rpc_confirm_biopay_ussd_external(uuid, text) to authenticated;
grant execute on function public.rpc_record_biopay_face_enrollment(text, text, text, text, numeric, jsonb) to authenticated;
grant execute on function public.rpc_admin_biopay_summary() to authenticated;
grant execute on function public.rpc_admin_biopay_list_payees(text, integer) to authenticated;
grant execute on function public.rpc_admin_biopay_list_requests(integer) to authenticated;
grant execute on function public.rpc_admin_biopay_system_status() to authenticated;
grant execute on function public.rpc_admin_biopay_confirm_external(uuid, text) to authenticated;

create index if not exists biopay_payment_requests_token_idx
  on public.biopay_payment_requests(token);
create index if not exists biopay_payment_requests_payee_status_idx
  on public.biopay_payment_requests(payee_id, status, created_at desc);
create index if not exists biopay_face_sessions_provider_idx
  on public.biopay_face_sessions(provider, provider_session_id);
