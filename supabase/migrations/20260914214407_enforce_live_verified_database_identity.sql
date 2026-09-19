-- Application ownership must resolve a live, verified identity, not only the
-- subject of a JWT. Supabase's auth.uid() remains untouched for platform use.
begin;

create or replace function public.live_auth_user_id()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  v_user_id uuid;
  v_session_id uuid;
begin
  begin
    v_user_id := auth.uid();
    v_session_id := nullif(auth.jwt()->>'session_id', '')::uuid;
  exception when invalid_text_representation then
    return null;
  end;
  if v_user_id is null or v_session_id is null then return null; end if;
  return (
    select u.id from auth.users u
    join auth.sessions s on s.user_id = u.id and s.id = v_session_id
    where u.id = v_user_id and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= now())
      and (s.not_after is null or s.not_after > now())
  );
end;
$$;

create or replace function public.verified_app_user_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.id from auth.users u
  where u.id = public.live_auth_user_id()
    and not coalesce(u.is_anonymous, false)
    and auth.jwt()->'is_anonymous' = 'false'::jsonb
    and u.phone_confirmed_at is not null
    and u.raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp', 'admin_whatsapp_otp')
$$;

revoke all on function public.live_auth_user_id() from public;
revoke all on function public.verified_app_user_id() from public;
grant execute on function public.live_auth_user_id() to anon, authenticated, service_role;
grant execute on function public.verified_app_user_id() to anon, authenticated, service_role;

-- Upgrade the effective application routines, preserving their signatures,
-- owners, grants, behavior and existing search_path settings. This also handles
-- argument defaults that previously used the unqualified JWT subject.
do $$
declare routine record;
begin
  for routine in
    select p.oid, pg_get_functiondef(p.oid) as definition
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname not in ('live_auth_user_id', 'verified_app_user_id')
      and not exists (
        select 1 from pg_depend d where d.classid = 'pg_proc'::regclass
          and d.objid = p.oid and d.deptype = 'e'
      )
  loop
    if position('auth.uid()' in routine.definition) > 0 then
      execute replace(routine.definition, 'auth.uid()', 'public.verified_app_user_id()');
    end if;
  end loop;
end;
$$;

-- RLS is also used by Storage and Realtime, outside PostgREST. Retain every
-- policy's role, operation, permissive/restrictive mode and public-read branch.
do $$
declare policy record; statement text;
begin
  for policy in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies where schemaname in ('public', 'storage')
      and (position('auth.uid()' in coalesce(qual, '')) > 0
        or position('auth.uid()' in coalesce(with_check, '')) > 0)
  loop
    statement := format('alter policy %I on %I.%I', policy.policyname, policy.schemaname, policy.tablename);
    if policy.qual is not null then
      statement := statement || format(' using (%s)', replace(policy.qual, 'auth.uid()', 'public.verified_app_user_id()'));
    end if;
    if policy.with_check is not null then
      statement := statement || format(' with check (%s)', replace(policy.with_check, 'auth.uid()', 'public.verified_app_user_id()'));
    end if;
    execute statement;
  end loop;
end;
$$;

do $$
declare column_default record;
begin
  for column_default in
    select n.nspname, c.relname, a.attname, pg_get_expr(d.adbin, d.adrelid) as expression
    from pg_attrdef d join pg_class c on c.oid = d.adrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where n.nspname = 'public'
      and position('auth.uid()' in pg_get_expr(d.adbin, d.adrelid)) > 0
  loop
    execute format('alter table %I.%I alter column %I set default %s',
      column_default.nspname, column_default.relname, column_default.attname,
      replace(column_default.expression, 'auth.uid()', 'public.verified_app_user_id()'));
  end loop;
end;
$$;

-- Give REST clients a clear authentication failure after logout/revocation.
-- Live anonymous sessions can still read public bootstrap catalogs; protected
-- ownership and RPC checks above resolve their application identity to null.
create or replace function public.enforce_live_api_session()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.role() = 'authenticated' and public.live_auth_user_id() is null then
    raise sqlstate 'PT401' using message = 'Authentication required';
  end if;
end;
$$;
revoke all on function public.enforce_live_api_session() from public;
grant execute on function public.enforce_live_api_session() to anon, authenticated, service_role;

do $$
begin
  if exists (
    select 1 from pg_db_role_setting s cross join lateral unnest(s.setconfig) setting
    where s.setrole = 'authenticator'::regrole
      and s.setdatabase in (0, (select oid from pg_database where datname = current_database()))
      and split_part(setting, '=', 1) = 'pgrst.db_pre_request'
      and split_part(setting, '=', 2) not in ('', 'public.enforce_live_api_session')
  ) then
    raise exception 'Existing PostgREST pre-request hook requires integration with the live-session guard';
  end if;
end;
$$;
alter role authenticator set pgrst.db_pre_request = 'public.enforce_live_api_session';
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
commit;
