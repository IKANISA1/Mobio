-- Forward BODY. Generate a real Supabase migration with scripts/ci/prepare_hardening_migrations.py.
-- Canonical six-digit Mobio member IDs: unique, server-managed and collision-safe.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Hold writers through preflight, backfill and the unique constraint. Existing
-- external references can contain a member ID, so changing a historical value
-- without an account-level reviewed mapping would be destructive.
lock table public.profiles in share row exclusive mode;
do $preflight$
declare
  invalid_count bigint;
  duplicate_count bigint;
begin
  select count(*) into invalid_count from public.profiles
  where member_id is not null and member_id !~ '^[0-9]{6}$';
  select count(*) into duplicate_count from (
    select member_id from public.profiles
    where member_id is not null
    group by member_id having count(*) > 1
  ) duplicate_ids;
  if invalid_count > 0 or duplicate_count > 0 then
    raise exception 'MEMBER_ID_REMEDIATION_REQUIRED'
      using errcode='P0001',
      detail=format('invalid_rows=%s; duplicate_values=%s',invalid_count,duplicate_count);
  end if;
end
$preflight$;

create or replace function public._mobio_allocate_member_id()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate text;
  attempts integer := 0;
begin
  -- Serialize this very small allocation critical section. The unique index below
  -- remains the final invariant; the lock avoids check-then-insert races.
  perform pg_catalog.pg_advisory_xact_lock(636624648, 1);
  loop
    attempts := attempts + 1;
    if attempts > 900000 then
      raise exception 'MEMBER_ID_SPACE_EXHAUSTED' using errcode = '54000';
    end if;
    candidate := pg_catalog.lpad((100000 + pg_catalog.floor(random() * 900000)::integer)::text, 6, '0');
    exit when not exists (
      select 1 from public.profiles p where p.member_id = candidate
    );
  end loop;
  return candidate;
end
$$;
revoke all on function public._mobio_allocate_member_id() from public, anon, authenticated;

-- Backfill every row through separate commands so each allocation observes prior assignments.
do $backfill$
declare
  row_to_fix record;
begin
  for row_to_fix in
    select id from public.profiles where member_id is null order by created_at nulls last, id
  loop
    update public.profiles
    set member_id = public._mobio_allocate_member_id()
    where id = row_to_fix.id;
  end loop;
end
$backfill$;

create unique index if not exists profiles_member_id_unique
  on public.profiles(member_id);

alter table public.profiles
  drop constraint if exists profiles_member_id_format_check;
alter table public.profiles
  add constraint profiles_member_id_format_check
  check (member_id ~ '^[0-9]{6}$');
alter table public.profiles
  alter column member_id set not null;

create or replace function public.fn_assign_mobio_member_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_role text := coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'role',
    ''
  );
begin
  -- Client inserts never choose their public identifier. Trusted import/migration
  -- contexts may preserve a supplied unique six-digit value.
  if request_role <> 'service_role'
     and not (request_role = '' and session_user in ('postgres', 'supabase_admin')) then
    new.member_id := public._mobio_allocate_member_id();
  elsif new.member_id is null then
    new.member_id := public._mobio_allocate_member_id();
  elsif new.member_id !~ '^[0-9]{6}$' then
    raise exception 'INVALID_MEMBER_ID' using errcode = '22023';
  end if;
  return new;
end
$$;
revoke all on function public.fn_assign_mobio_member_id() from public, anon, authenticated;

drop trigger if exists assign_mobio_member_id on public.profiles;
create trigger assign_mobio_member_id
before insert on public.profiles
for each row execute function public.fn_assign_mobio_member_id();

notify pgrst, 'reload schema';
commit;
