begin;

create extension if not exists vector;

create or replace function public.biopay_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.biopay_profiles (
  id uuid primary key default gen_random_uuid(),
  biopay_id text not null unique
    check (biopay_id ~ '^[0-9]{6}$'),
  display_name text not null
    check (char_length(btrim(display_name)) between 2 and 80),
  ussd_string text not null,
  ussd_normalized text not null,
  recipient_phone_e164 text
    check (
      recipient_phone_e164 is null
      or recipient_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
  status text not null default 'active'
    check (status in ('pending', 'active', 'suspended', 'deleted')),
  consent_version integer not null
    check (consent_version > 0),
  consent_at timestamptz not null default timezone('utc', now()),
  owner_token_version integer not null default 1
    check (owner_token_version > 0),
  management_code_hash text not null,
  management_code_hint text
    check (
      management_code_hint is null
      or management_code_hint ~ '^[0-9]{2}$'
    ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.biopay_profiles is
  'Service-role-managed BioPay identity registry for MOBI.';

comment on column public.biopay_profiles.ussd_normalized is
  'Canonical settlement string used for duplicate detection and updates.';

comment on column public.biopay_profiles.owner_token_version is
  'Rotated whenever BioPay ownership credentials are re-issued or invalidated.';

drop trigger if exists set_biopay_profiles_updated_at
  on public.biopay_profiles;
create trigger set_biopay_profiles_updated_at
before update on public.biopay_profiles
for each row
execute function public.biopay_set_updated_at();

create unique index if not exists uq_biopay_profiles_ussd_normalized_active
  on public.biopay_profiles (ussd_normalized)
  where status in ('pending', 'active', 'suspended');

create unique index if not exists uq_biopay_profiles_phone_active
  on public.biopay_profiles (recipient_phone_e164)
  where recipient_phone_e164 is not null
    and status in ('pending', 'active', 'suspended');

create index if not exists idx_biopay_profiles_status_created_at
  on public.biopay_profiles (status, created_at desc);

create table if not exists public.biopay_face_embeddings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.biopay_profiles(id) on delete cascade,
  embedding vector(192) not null,
  model_version text not null,
  quality_score double precision
    check (
      quality_score is null
      or (quality_score >= 0 and quality_score <= 1)
    ),
  source text not null default 'enrollment'
    check (source in ('enrollment', 're_enrollment')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.biopay_face_embeddings is
  'Normalized face embeddings for BioPay. Raw face images must never be persisted.';

create unique index if not exists uq_biopay_face_embeddings_profile_active
  on public.biopay_face_embeddings (profile_id)
  where is_active;

create index if not exists idx_biopay_face_embeddings_profile_created_at
  on public.biopay_face_embeddings (profile_id, created_at desc);

create index if not exists idx_biopay_face_embeddings_model_version
  on public.biopay_face_embeddings (model_version);

create index if not exists idx_biopay_face_embeddings_embedding_cosine
  on public.biopay_face_embeddings
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 64);

create table if not exists public.biopay_match_audit (
  id uuid primary key default gen_random_uuid(),
  matched_profile_id uuid
    references public.biopay_profiles(id) on delete set null,
  similarity double precision,
  result text not null
    check (result in ('matched', 'no_match', 'rate_limited', 'rejected', 'error')),
  client_install_id text,
  ip_hash text,
  device_label text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_biopay_match_audit_created_at
  on public.biopay_match_audit (created_at desc);

create index if not exists idx_biopay_match_audit_profile_created_at
  on public.biopay_match_audit (matched_profile_id, created_at desc);

create table if not exists public.biopay_enrollment_audit (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid
    references public.biopay_profiles(id) on delete set null,
  event_type text not null,
  client_install_id text,
  ip_hash text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_biopay_enrollment_audit_created_at
  on public.biopay_enrollment_audit (created_at desc);

create index if not exists idx_biopay_enrollment_audit_profile_created_at
  on public.biopay_enrollment_audit (profile_id, created_at desc);

create table if not exists public.biopay_abuse_reports (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.biopay_profiles(id) on delete cascade,
  reason text not null,
  notes text,
  status text not null default 'open'
    check (status in ('open', 'resolved', 'dismissed')),
  client_install_id text,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists set_biopay_abuse_reports_updated_at
  on public.biopay_abuse_reports;
create trigger set_biopay_abuse_reports_updated_at
before update on public.biopay_abuse_reports
for each row
execute function public.biopay_set_updated_at();

create index if not exists idx_biopay_abuse_reports_profile_status
  on public.biopay_abuse_reports (profile_id, status, created_at desc);

create table if not exists public.biopay_match_rate_limits (
  fingerprint_hash text primary key,
  window_started_at timestamptz not null default timezone('utc', now()),
  request_count integer not null default 0
    check (request_count >= 0),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists set_biopay_match_rate_limits_updated_at
  on public.biopay_match_rate_limits;
create trigger set_biopay_match_rate_limits_updated_at
before update on public.biopay_match_rate_limits
for each row
execute function public.biopay_set_updated_at();

create index if not exists idx_biopay_match_rate_limits_updated_at
  on public.biopay_match_rate_limits (updated_at desc);

alter table public.biopay_profiles enable row level security;
alter table public.biopay_face_embeddings enable row level security;
alter table public.biopay_match_audit enable row level security;
alter table public.biopay_enrollment_audit enable row level security;
alter table public.biopay_abuse_reports enable row level security;
alter table public.biopay_match_rate_limits enable row level security;

revoke all on public.biopay_profiles from anon, authenticated;
revoke all on public.biopay_face_embeddings from anon, authenticated;
revoke all on public.biopay_match_audit from anon, authenticated;
revoke all on public.biopay_enrollment_audit from anon, authenticated;
revoke all on public.biopay_abuse_reports from anon, authenticated;
revoke all on public.biopay_match_rate_limits from anon, authenticated;

grant all on public.biopay_profiles to service_role;
grant all on public.biopay_face_embeddings to service_role;
grant all on public.biopay_match_audit to service_role;
grant all on public.biopay_enrollment_audit to service_role;
grant all on public.biopay_abuse_reports to service_role;
grant all on public.biopay_match_rate_limits to service_role;

drop policy if exists "Users can update own wallet" on public.biopay_wallets;
drop policy if exists "Users can insert own transactions" on public.biopay_transactions;
drop policy if exists "Users can insert own face template" on public.face_templates;
drop policy if exists "Users can update own face template" on public.face_templates;

revoke all on public.biopay_wallets from anon, authenticated;
revoke all on public.biopay_transactions from anon, authenticated;
revoke all on public.face_templates from anon, authenticated;

grant all on public.biopay_wallets to service_role;
grant all on public.biopay_transactions to service_role;
grant all on public.face_templates to service_role;

create or replace function public.generate_biopay_id()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate text;
begin
  loop
    candidate := lpad(((random() * 999999)::int)::text, 6, '0');
    exit when not exists (
      select 1
      from public.biopay_profiles
      where biopay_id = candidate
    );
  end loop;

  return candidate;
end;
$$;

create or replace function public.match_biopay_embedding(
  query_embedding vector,
  limit_count integer default 3
)
returns table (
  profile_id uuid,
  biopay_id text,
  display_name text,
  ussd_string text,
  similarity double precision,
  model_version text
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $$
  select
    profile.id as profile_id,
    profile.biopay_id,
    profile.display_name,
    profile.ussd_string,
    1 - (embedding.embedding <=> query_embedding) as similarity,
    embedding.model_version
  from public.biopay_face_embeddings embedding
  join public.biopay_profiles profile
    on profile.id = embedding.profile_id
  where embedding.is_active = true
    and profile.status = 'active'
  order by embedding.embedding <=> query_embedding asc
  limit greatest(1, least(coalesce(limit_count, 3), 10));
$$;

create or replace function public.find_duplicate_biopay_profile(
  query_embedding vector,
  similarity_threshold double precision default 0.90
)
returns table (
  profile_id uuid,
  biopay_id text,
  display_name text,
  similarity double precision
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $$
  select
    profile.id as profile_id,
    profile.biopay_id,
    profile.display_name,
    1 - (embedding.embedding <=> query_embedding) as similarity
  from public.biopay_face_embeddings embedding
  join public.biopay_profiles profile
    on profile.id = embedding.profile_id
  where embedding.is_active = true
    and profile.status in ('pending', 'active', 'suspended')
    and 1 - (embedding.embedding <=> query_embedding) >= similarity_threshold
  order by embedding.embedding <=> query_embedding asc
  limit 1;
$$;

create or replace function public.consume_biopay_match_rate_limit(
  p_fingerprint_hash text,
  p_window_seconds integer default 300,
  p_max_requests integer default 20
)
returns table (
  allowed boolean,
  request_count integer,
  retry_after_seconds integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  bucket public.biopay_match_rate_limits%rowtype;
  now_ts timestamptz := timezone('utc', now());
  effective_window_seconds integer := greatest(1, coalesce(p_window_seconds, 300));
  effective_max_requests integer := greatest(1, coalesce(p_max_requests, 20));
  window_end timestamptz;
begin
  loop
    select *
    into bucket
    from public.biopay_match_rate_limits
    where fingerprint_hash = p_fingerprint_hash
    for update;

    if not found then
      begin
        insert into public.biopay_match_rate_limits (
          fingerprint_hash,
          window_started_at,
          request_count
        ) values (
          p_fingerprint_hash,
          now_ts,
          1
        );

        return query
        select true, 1, 0;
        return;
      exception
        when unique_violation then
          null;
      end;
    else
      if bucket.window_started_at <= now_ts - make_interval(secs => effective_window_seconds) then
        update public.biopay_match_rate_limits
        set window_started_at = now_ts,
            request_count = 1
        where fingerprint_hash = p_fingerprint_hash;

        return query
        select true, 1, 0;
        return;
      end if;

      if bucket.request_count < effective_max_requests then
        update public.biopay_match_rate_limits
        set request_count = bucket.request_count + 1
        where fingerprint_hash = p_fingerprint_hash;

        return query
        select true, bucket.request_count + 1, 0;
        return;
      end if;

      window_end := bucket.window_started_at + make_interval(secs => effective_window_seconds);
      return query
      select
        false,
        bucket.request_count,
        greatest(1, ceil(extract(epoch from (window_end - now_ts)))::integer);
      return;
    end if;
  end loop;
end;
$$;

create or replace function public.biopay_reenroll_profile(
  p_profile_id uuid,
  p_expected_owner_token_version integer,
  p_embedding vector,
  p_model_version text,
  p_quality_score double precision default null
)
returns table (
  id uuid,
  biopay_id text,
  display_name text,
  ussd_string text,
  status text,
  owner_token_version integer,
  management_code_hash text,
  management_code_hint text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.biopay_profiles%rowtype;
begin
  update public.biopay_profiles
  set owner_token_version = owner_token_version + 1,
      status = 'active',
      updated_at = timezone('utc', now())
  where public.biopay_profiles.id = p_profile_id
    and public.biopay_profiles.owner_token_version = p_expected_owner_token_version
    and public.biopay_profiles.status <> 'deleted'
  returning *
  into updated_profile;

  if not found then
    raise exception 'BioPay profile could not be re-enrolled.';
  end if;

  update public.biopay_face_embeddings
  set is_active = false
  where profile_id = p_profile_id
    and is_active = true;

  insert into public.biopay_face_embeddings (
    profile_id,
    embedding,
    model_version,
    quality_score,
    source,
    is_active
  ) values (
    p_profile_id,
    p_embedding,
    p_model_version,
    p_quality_score,
    're_enrollment',
    true
  );

  return query
  select
    updated_profile.id,
    updated_profile.biopay_id,
    updated_profile.display_name,
    updated_profile.ussd_string,
    updated_profile.status,
    updated_profile.owner_token_version,
    updated_profile.management_code_hash,
    updated_profile.management_code_hint,
    updated_profile.created_at;
end;
$$;

create or replace function public.biopay_delete_profile(
  p_profile_id uuid,
  p_expected_owner_token_version integer
)
returns table (
  id uuid,
  biopay_id text,
  status text,
  owner_token_version integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.biopay_profiles%rowtype;
begin
  update public.biopay_face_embeddings
  set is_active = false
  where profile_id = p_profile_id
    and is_active = true;

  update public.biopay_profiles
  set status = 'deleted',
      owner_token_version = owner_token_version + 1,
      updated_at = timezone('utc', now())
  where public.biopay_profiles.id = p_profile_id
    and public.biopay_profiles.owner_token_version = p_expected_owner_token_version
    and public.biopay_profiles.status <> 'deleted'
  returning *
  into updated_profile;

  if not found then
    select *
    into updated_profile
    from public.biopay_profiles
    where public.biopay_profiles.id = p_profile_id;

    if not found then
      raise exception 'BioPay profile could not be deleted.';
    end if;
  end if;

  return query
  select
    updated_profile.id,
    updated_profile.biopay_id,
    updated_profile.status,
    updated_profile.owner_token_version;
end;
$$;

revoke all on function public.biopay_set_updated_at() from public;
revoke all on function public.generate_biopay_id() from public, anon, authenticated;
revoke all on function public.match_biopay_embedding(vector, integer) from public, anon, authenticated;
revoke all on function public.find_duplicate_biopay_profile(vector, double precision) from public, anon, authenticated;
revoke all on function public.consume_biopay_match_rate_limit(text, integer, integer) from public, anon, authenticated;
revoke all on function public.biopay_reenroll_profile(uuid, integer, vector, text, double precision) from public, anon, authenticated;
revoke all on function public.biopay_delete_profile(uuid, integer) from public, anon, authenticated;

grant execute on function public.generate_biopay_id() to service_role;
grant execute on function public.match_biopay_embedding(vector, integer) to service_role;
grant execute on function public.find_duplicate_biopay_profile(vector, double precision) to service_role;
grant execute on function public.consume_biopay_match_rate_limit(text, integer, integer) to service_role;
grant execute on function public.biopay_reenroll_profile(uuid, integer, vector, text, double precision) to service_role;
grant execute on function public.biopay_delete_profile(uuid, integer) to service_role;

commit;
