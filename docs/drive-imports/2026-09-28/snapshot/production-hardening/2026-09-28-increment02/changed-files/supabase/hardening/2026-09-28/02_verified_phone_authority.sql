-- Forward BODY. Deploy with the corresponding verify-login-otp change, not independently.
-- No alias-derived account reassignment; ambiguous/unverified historical records need recovery.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function public._mobio_verified_phone_owner(p_phone text)
returns uuid language plpgsql security definer set search_path='' as $$
declare candidate auth.users%rowtype; matches integer;
begin
  if coalesce(p_phone,'') !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'INVALID_VERIFIED_PHONE' using errcode='22023';
  end if;
  select count(*) into matches from auth.users u
  where u.phone in (p_phone, substring(p_phone from 2));
  if matches=0 then return null; end if;
  if matches<>1 then raise exception 'AMBIGUOUS_PHONE_IDENTITY' using errcode='42501'; end if;
  select * into strict candidate from auth.users u
  where u.phone in (p_phone, substring(p_phone from 2));
  if candidate.phone_confirmed_at is null or coalesce(candidate.is_anonymous,false)
     or candidate.deleted_at is not null or candidate.banned_until>now() then
    raise exception 'PHONE_IDENTITY_UNAVAILABLE' using errcode='42501';
  end if;
  return candidate.id;
end $$;
revoke all on function public._mobio_verified_phone_owner(text) from public, anon, authenticated;

create or replace function public.rpc_lookup_verified_phone_owner(p_phone text)
returns uuid language plpgsql security definer set search_path='' as $$
begin
  if not public._mobio_is_service_role() then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  return public._mobio_verified_phone_owner(p_phone);
end $$;
revoke all on function public.rpc_lookup_verified_phone_owner(text) from public, anon, authenticated;
grant execute on function public.rpc_lookup_verified_phone_owner(text) to service_role;

-- Trigger checks request role, not current_user: a client-invoked SECURITY DEFINER
-- profile RPC must not bypass protection of authoritative fields.
create or replace function public.fn_guard_profile_identity_authority()
returns trigger language plpgsql security definer set search_path='' as $$
declare request_role text := coalesce(
  nullif(current_setting('request.jwt.claim.role',true),''),
  nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role','');
begin
  if request_role='service_role' or (request_role='' and session_user in ('postgres','supabase_admin')) then
    return new;
  end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
     or new.phone is distinct from old.phone
     or new.whatsapp_e164 is distinct from old.whatsapp_e164
     or new.whatsapp_verified_at is distinct from old.whatsapp_verified_at
     or new.auth_provider is distinct from old.auth_provider
     or new.member_id is distinct from old.member_id then
    raise exception 'VERIFIED_IDENTITY_FIELDS_READ_ONLY' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function public.fn_guard_profile_identity_authority() from public, anon, authenticated;
drop trigger if exists guard_profile_identity_authority on public.profiles;
create trigger guard_profile_identity_authority before update on public.profiles
for each row execute function public.fn_guard_profile_identity_authority();

-- Discovery must resolve the same verified Auth authority, not an editable alias.
-- Full function body appended below, preserving manual/link and private-grant behavior.
create or replace function public.fn_biopay_discover(p_user uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l public.biopay_links; result jsonb; v_phone text; verified_owner uuid; manual jsonb; legacy public.biopay_payment_requests; legacy_match text[];
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
  -- No distinction between private, unavailable and absent recipient in public output.
  begin
    verified_owner := public._mobio_verified_phone_owner(v_phone);
  exception when sqlstate '42501' or sqlstate '22023' then
    verified_owner := null;
  end;
  -- Identical no-results response for private and nonexistent profiles.
  select coalesce(jsonb_agg(public.fn_biopay_receiving_method(m) order by m.id),'[]') into result
    from public.biopay_payment_methods m join public.profiles p on p.id=m.owner_id
    where m.active and m.can_receive and p.id=verified_owner
    and (m.owner_id=p_user or m.phone_discoverable or exists(
      select 1 from public.biopay_method_grants g where g.method_id=m.id and g.grantee_id=p_user));
  return jsonb_build_object('label','Shared receiving details','assurance','shared',
    'lookup',v_phone,'methods',result);
end $$;

revoke all on function public.fn_biopay_discover(uuid,jsonb) from public,anon,authenticated;
notify pgrst, 'reload schema';
commit;
