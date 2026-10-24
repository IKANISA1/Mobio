-- SQL-only positive fixture setup. Load in the SAME psql connection before a
-- rolled-back test. Never use this helper for Auth/JWT/OTP delivery acceptance.
-- It proves only the separate workflows after their explicit authority setup.
create temp table qa_interactive_fixture_marker(value boolean);
create function pg_temp.qa_seed_interactive_authority(p_user_ids uuid[])
returns void language plpgsql as $$
declare actor record; session record; otp_id uuid; purpose text;
  previous_claims text := current_setting('request.jwt.claims',true);
  previous_sub text := current_setting('request.jwt.claim.sub',true);
begin
  if current_user not in ('postgres','supabase_admin') then
    raise exception 'DISPOSABLE_SQL_FIXTURE_AUTHORITY_REQUIRED';
  end if;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  for actor in select u.* from auth.users u where u.id=any(p_user_ids)
    and u.raw_app_meta_data->>'provider' in ('whatsapp_cloud_otp','admin_whatsapp_otp')
    and not coalesce(u.is_anonymous,false) and u.phone_confirmed_at is not null
    and u.deleted_at is null and (u.banned_until is null or u.banned_until<=clock_timestamp())
    and not exists(select 1 from mobio_private.store_review_principals r where r.user_id=u.id)
  loop
    purpose := case when actor.raw_app_meta_data->>'provider'='admin_whatsapp_otp'
      then 'admin_login' else 'app_login' end;
    for session in select s.* from auth.sessions s where s.user_id=actor.id
      and (s.not_after is null or s.not_after>clock_timestamp())
      and s.created_at >= clock_timestamp()-interval '2 minutes'
    loop
      otp_id := gen_random_uuid();
      insert into public.otp_codes(id,phone,code,code_hash,purpose,verified,expires_at)
      values(otp_id,'+' || ltrim(actor.phone,'+'),'000000',repeat('a',64),purpose,true,
        clock_timestamp()+interval '5 minutes');
      if purpose='app_login' then
        perform public.rpc_register_app_whatsapp_session(actor.id,session.id,otp_id::text);
      else
        -- Deliberately creates NO Admin lease, allowlist, profile or grant.
        perform mobio_private.bind_whatsapp_otp_account(actor.id,otp_id::text,purpose);
      end if;
    end loop;
  end loop;
  perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);
  perform set_config('request.jwt.claim.sub',coalesce(previous_sub,''),true);
exception when others then
  perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);
  perform set_config('request.jwt.claim.sub',coalesce(previous_sub,''),true);
  raise;
end $$;
revoke all on function pg_temp.qa_seed_interactive_authority(uuid[])
  from public,anon,authenticated,service_role;
