-- Reuse the same route-number formatting in manual/QR preparation.
begin;
create or replace function public.rpc_biopay_discovery(p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  u uuid := public.fn_biopay_discovery_user();
  m public.biopay_payment_methods;
  d public.biopay_payment_drafts;
  q public.biopay_route_quotes;
  r public.biopay_provider_routes;
  pr public.biopay_payment_requests;
  result jsonb; options jsonb; selected jsonb; current_selected jsonb; rate_count integer;
  method_ids uuid[]; versions jsonb; grantee uuid; v_request_id uuid; instruction text; endpoint text;
begin
  if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>12000 then
    raise exception 'Invalid input.';
  end if;
  if p_action in ('resolve','quote','create_link') then
    insert into public.biopay_discovery_rate_limits(owner_id,window_at,attempts) values(u,now(),1)
    on conflict(owner_id) do update set
      attempts=case when biopay_discovery_rate_limits.window_at<now()-interval '1 minute' then 1 else biopay_discovery_rate_limits.attempts+1 end,
      window_at=case when biopay_discovery_rate_limits.window_at<now()-interval '1 minute' then now() else biopay_discovery_rate_limits.window_at end
    returning attempts into rate_count;
    if rate_count>30 then raise exception 'Too many requests. Try again shortly.' using errcode='54000'; end if;
  end if;
  if p_action='workspace' then
    return jsonb_build_object(
      'methods',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]') from public.biopay_payment_methods x where owner_id=u and active),
      'links',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') from public.biopay_links x where owner_id=u),
      'drafts',(select coalesce(jsonb_agg(data order by updated_at desc),'[]') from public.biopay_payment_drafts where owner_id=u),
      'recents',(select coalesce(jsonb_agg(to_jsonb(x) order by favorite desc,updated_at desc),'[]') from public.biopay_recipient_shortcuts x where owner_id=u),
      'templates',(select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc),'[]') from public.biopay_request_templates x where owner_id=u),
      'activity',(select coalesce(jsonb_agg(to_jsonb(x) - 'token' - 'ussd_code' order by created_at desc),'[]')
        from (select * from public.biopay_payment_requests where payer_id=u or payee_id=u order by created_at desc limit 100) x));
  elsif p_action='save_method' then
    if nullif(p_data->>'id','') is not null then
      select * into m from public.biopay_payment_methods where id=(p_data->>'id')::uuid and owner_id=u for update;
      if not found or m.version is distinct from (p_data->>'version')::integer then raise exception 'Method changed. Refresh and review.'; end if;
    end if;
    if coalesce((p_data->>'preferred')::boolean,false) then
      update public.biopay_payment_methods set preferred=false where owner_id=u and preferred;
    end if;
    insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label,
      login_phone,sim_label,can_send,can_receive,phone_discoverable,preferred,version)
    values(coalesce(m.id,gen_random_uuid()),u,p_data->>'provider',p_data->>'kind',
      trim(p_data->>'identifier'),trim(p_data->>'label'),nullif(p_data->>'login_phone',''),
      nullif(p_data->>'sim_label',''),coalesce((p_data->>'can_send')::boolean,false),
      coalesce((p_data->>'can_receive')::boolean,true),coalesce((p_data->>'phone_discoverable')::boolean,false),
      coalesce((p_data->>'preferred')::boolean,false),coalesce(m.version,0)+1)
    on conflict(id) do update set provider=excluded.provider,kind=excluded.kind,
      identifier=excluded.identifier,label=excluded.label,login_phone=excluded.login_phone,
      sim_label=excluded.sim_label,can_send=excluded.can_send,can_receive=excluded.can_receive,
      phone_discoverable=excluded.phone_discoverable,preferred=excluded.preferred,
      version=excluded.version,updated_at=now()
    returning to_jsonb(biopay_payment_methods.*) into result;
    return result;
  elsif p_action='remove_method' then
    update public.biopay_payment_methods set active=false,version=version+1,updated_at=now()
      where id=(p_data->>'id')::uuid and owner_id=u and version=(p_data->>'version')::integer;
    if not found then raise exception 'Method changed. Refresh and review.'; end if;
    return '{}'::jsonb;
  elsif p_action='sharing' then
    select * into m from public.biopay_payment_methods where id=(p_data->>'id')::uuid and owner_id=u and active;
    if not found then raise exception 'Method unavailable.'; end if;
    return jsonb_build_object('method',public.fn_biopay_receiving_method(m),
      'phone_discoverable',m.phone_discoverable,
      'grants',(select coalesce(jsonb_agg(jsonb_build_object('member_id',p.member_id,'created_at',g.created_at)),'[]')
        from public.biopay_method_grants g join public.profiles p on p.id=g.grantee_id where method_id=m.id),
      'links',(select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'label',l.label,'expires_at',l.expires_at,'revoked_at',l.revoked_at)),'[]')
        from public.biopay_links l where l.owner_id=u and m.id=any(l.method_ids)));
  elsif p_action='grant' then
    select * into m from public.biopay_payment_methods where id=(p_data->>'method_id')::uuid and owner_id=u and active for update;
    if not found or m.version is distinct from (p_data->>'version')::integer then raise exception 'Method changed. Refresh and review.'; end if;
    -- Explicit sharing uses the public six-digit Mobio member ID.
    if coalesce(p_data->>'member_id','') !~ '^[0-9]{6}$' then raise exception 'Enter a six-digit Mobio ID.'; end if;
    select id into grantee from public.profiles where member_id=p_data->>'member_id';
    if grantee is null then raise exception 'This account is unavailable.'; end if;
    if coalesce((p_data->>'remove')::boolean,false) then
      delete from public.biopay_method_grants where method_id=m.id and grantee_id=grantee;
    else
      insert into public.biopay_method_grants(method_id,grantee_id) values(m.id,grantee) on conflict do nothing;
    end if;
    update public.biopay_payment_methods set version=version+1,updated_at=now() where id=m.id;
    return '{}'::jsonb;
  elsif p_action='resolve' then
    return public.fn_biopay_discover(u,p_data);
  elsif p_action='save_draft' then
    if p_data->>'owner_id' is distinct from u::text then raise exception 'Draft account changed.'; end if;
    insert into public.biopay_payment_drafts(id,owner_id,revision,data)
      values((p_data->>'id')::uuid,u,(p_data->>'revision')::integer,p_data)
    on conflict(id) do update set data=excluded.data,revision=excluded.revision,updated_at=now()
      where biopay_payment_drafts.owner_id=u and (biopay_payment_drafts.revision<excluded.revision or biopay_payment_drafts.data=excluded.data)
    returning data into result;
    if result is null then raise exception 'Draft changed. Refresh before continuing.'; end if;
    return result;
  elsif p_action='delete_draft' then
    delete from public.biopay_payment_drafts where id=(p_data->>'id')::uuid and owner_id=u;
    return '{}'::jsonb;
  elsif p_action='quote' then
    select * into d from public.biopay_payment_drafts where id=(p_data->>'id')::uuid and owner_id=u for update;
    if not found or d.revision is distinct from (p_data->>'revision')::integer then raise exception 'Save the current draft first.'; end if;
    -- Reconstruct from persisted draft, not client-selected destination metadata.
    result := public.fn_biopay_quote_options(u,d.data||jsonb_build_object('device',p_data->>'device'));
    insert into public.biopay_route_quotes(owner_id,draft_id,revision,input,options)
      values(u,d.id,d.revision,d.data||jsonb_build_object('device',p_data->>'device'),result)
      returning * into q;
    -- A recent records the user's explicit recipient choice, never a payment.
    if d.data->>'lookup' ~ '^\+2507[0-9]{8}$' and jsonb_array_length(result->'recipient'->'methods')>0 then
      insert into public.biopay_recipient_shortcuts(owner_id,lookup,nickname)
        values(u,d.data->>'lookup',d.data->>'lookup')
      on conflict(owner_id,lookup) do update set updated_at=now();
    end if;
    return result||jsonb_build_object('quote_id',q.id,'expires_at',q.expires_at,'revision',q.revision);
  elsif p_action='prepare' then
    select * into q from public.biopay_route_quotes where id=(p_data->>'quote_id')::uuid and owner_id=u for update;
    if not found or q.expires_at<=now() or q.prepared_at is not null then raise exception 'Refresh and review before opening again.'; end if;
    select * into d from public.biopay_payment_drafts where id=q.draft_id and owner_id=u for update;
    if not found or d.revision<>q.revision or d.data||jsonb_build_object('device',p_data->>'device')<>q.input or p_data->>'device' is distinct from q.input->>'device' then
      raise exception 'Payment details changed. Review again.';
    end if;
    -- Hold shared locks on every saved endpoint/adapter/link used in the quote
    -- until the prepared request commits. Mutations must wait or invalidate it.
    perform 1 from public.biopay_payment_methods where id in (
      select (x->'source'->>'id')::uuid from jsonb_array_elements(q.options->'options') x
      union select nullif(x->'destination'->>'id','manual')::uuid from jsonb_array_elements(q.options->'options') x
    ) order by id for share;
    perform 1 from public.biopay_provider_routes where id in (
      select (x->>'adapter_id')::uuid from jsonb_array_elements(q.options->'options') x
    ) order by id for share;
    perform 1 from public.biopay_links where token=q.input->>'link_token' for share;
    options := public.fn_biopay_quote_options(u,q.input);
    select x into selected from jsonb_array_elements(q.options->'options') x where x->>'id'=p_data->>'option_id';
    select x into current_selected from jsonb_array_elements(options->'options') x where x->>'id'=p_data->>'option_id';
    if selected is null or current_selected is null then
      raise exception 'Payment option unavailable. Compare again.';
    elsif selected->'source'<>current_selected->'source' then
      raise exception 'Saved source changed. Compare again.';
    elsif selected->'destination'<>current_selected->'destination' then
      raise exception 'Receiving details changed. Compare again.';
    elsif selected->'fee'<>current_selected->'fee' or selected->'tariff_version'<>current_selected->'tariff_version' then
      raise exception 'Fee evidence changed. Compare again.';
    elsif selected<>current_selected or q.options->'recipient'<>options->'recipient' then
      raise exception 'Provider instructions or sharing changed. Compare again.';
    end if;
    select * into r from public.biopay_provider_routes where id=(selected->>'adapter_id')::uuid and state='approved' for share;
    if not found then raise exception 'This payment option is unavailable.'; end if;
    if length(coalesce(q.input->>'reference',''))>80 or (position('{reference}' in r.instruction_template)>0 and
      ((r.handoff_mode='dial' and coalesce(q.input->>'reference','') !~ '^[0-9]{0,80}$')
       or (r.handoff_mode='instructions' and coalesce(q.input->>'reference','') !~ '^[A-Za-z0-9 -]{0,80}$'))) then
      raise exception 'Use letters, numbers, spaces or hyphens for the reference.';
    end if;
    endpoint := selected->'destination'->>'identifier';
    endpoint:=public.fn_biopay_route_recipient(endpoint,r.recipient_format);
    instruction := replace(replace(replace(r.instruction_template,'{recipient}',endpoint),
      '{amount}',q.input->>'amount'),'{reference}',left(coalesce(q.input->>'reference',''),80));
    if instruction ~ '[{}]' or (r.handoff_mode='dial' and instruction !~ '^\*[0-9*]+#$') then
      raise exception 'Provider instructions need review.';
    end if;
    insert into public.biopay_payment_requests(channel,payer_id,payee_id,payee_label,
      provider_code,amount_minor,currency,reference,ussd_code,status,expires_at,
      discovery_quote_id,evidence_kind,reviewed_snapshot)
    values('qr',u,nullif(selected->'destination'->>'owner_id','')::uuid,
      options->'recipient'->>'label',r.source_provider,(q.input->>'amount')::integer*100,
      'RWF',left(coalesce(q.input->>'reference',''),80),instruction,'ready_to_dial',
      now()+interval '15 minutes',q.id,'prepared',selected||jsonb_build_object(
        'source',jsonb_build_object('provider',selected->'source'->>'provider',
          'kind',selected->'source'->>'kind','label',selected->'source'->>'label',
          'identifier','•••• '||right(selected->'source'->>'identifier',4)),
        'amount_rwf',(q.input->>'amount')::integer))
    returning id into v_request_id;
    update public.biopay_route_quotes set prepared_at=now(),request_id=v_request_id where id=q.id;
    insert into public.biopay_audit_events(actor_user_id,request_id,action,metadata)
      values(u,v_request_id,'discovery_prepared',jsonb_build_object('quote_id',q.id,'adapter_version',r.adapter_version,'tariff_version',r.tariff_version));
    return jsonb_build_object('attempt_id',v_request_id,'mode',r.handoff_mode,'instruction',instruction,
      'evidence','prepared','source_label',selected->'source'->>'label','sim_label',selected->'source'->>'sim_label');
  elsif p_action='pay_again' then
    select * into pr from public.biopay_payment_requests where id=(p_data->>'id')::uuid and payer_id=u;
    if not found or pr.discovery_quote_id is null then raise exception 'Enter the recipient for a new payment.'; end if;
    select * into q from public.biopay_route_quotes where id=pr.discovery_quote_id and owner_id=u;
    if not found then raise exception 'Enter the recipient for a new payment.'; end if;
    -- Re-resolve authorization now. The returned draft still requires a fresh quote and review.
    perform public.fn_biopay_discover(u,q.input);
    result:=(q.input-'device'-'attempt_id'-'evidence')||jsonb_build_object(
      'id',gen_random_uuid(),'owner_id',u,'revision',0,'evidence','draft');
    insert into public.biopay_payment_drafts(id,owner_id,revision,data)
      values((result->>'id')::uuid,u,0,result);
    return result;
  elsif p_action='record_attempt' then
    select * into pr from public.biopay_payment_requests where id=(p_data->>'id')::uuid and payer_id=u and discovery_quote_id is not null for update;
    if not found then raise exception 'Attempt unavailable.'; end if;
    if p_data->>'evidence' not in ('handoffOpened','outcomeUnknown','userReported')
      or p_data->>'evidence' is null then raise exception 'Unsupported evidence.'; end if;
    -- Client reports can never downgrade or replace trusted external evidence.
    if pr.evidence_kind in ('operatorReviewed','providerConfirmed','receiverAcknowledged') then
      return jsonb_build_object('evidence',pr.evidence_kind);
    end if;
    if pr.evidence_kind='userReported' and p_data->>'evidence'<>'userReported' then
      return jsonb_build_object('evidence',pr.evidence_kind);
    end if;
    update public.biopay_payment_requests set evidence_kind=p_data->>'evidence',
      status=case when p_data->>'evidence'='userReported' then 'user_marked_paid' else 'dialer_opened' end,updated_at=now()
      where id=pr.id;
    if pr.evidence_kind is distinct from p_data->>'evidence' then
      insert into public.biopay_ussd_attempts(request_id,user_id,action,metadata)
        values(pr.id,u,case when p_data->>'evidence'='userReported' then 'user_marked_paid' else 'dialer_opened' end,
          jsonb_build_object('evidence_kind',p_data->>'evidence'));
    end if;
    return jsonb_build_object('evidence',p_data->>'evidence');
  elsif p_action='acknowledge' then
    select * into pr from public.biopay_payment_requests where id=(p_data->>'id')::uuid and payee_id=u and discovery_quote_id is not null for update;
    if not found then raise exception 'Request unavailable.'; end if;
    if pr.evidence_kind in ('providerConfirmed','operatorReviewed') then return jsonb_build_object('evidence',pr.evidence_kind); end if;
    update public.biopay_payment_requests set evidence_kind='receiverAcknowledged',updated_at=now() where id=pr.id;
    insert into public.biopay_audit_events(actor_user_id,request_id,action) values(u,pr.id,'receiver_acknowledged');
    return jsonb_build_object('evidence','receiverAcknowledged');
  elsif p_action='create_link' then
    select array_agg(x::uuid) into method_ids from jsonb_array_elements_text(p_data->'method_ids') x;
    if coalesce(cardinality(method_ids),0) not between 1 and 20 then raise exception 'Choose receiving methods.'; end if;
    select jsonb_object_agg(id::text,version) into versions from public.biopay_payment_methods
      where id=any(method_ids) and owner_id=u and active and can_receive;
    if (select count(*) from jsonb_object_keys(coalesce(versions,'{}')))<>cardinality(method_ids) then
      raise exception 'Receiving methods unavailable.';
    end if;
    if (p_data->>'expires_at')::timestamptz <= now() or (p_data->>'expires_at')::timestamptz > now()+interval '90 days' then
      raise exception 'Choose an expiry within 90 days.';
    end if;
    insert into public.biopay_links(owner_id,scope,method_ids,method_versions,label,amount_rwf,purpose,reference,expires_at)
    values(u,p_data->>'scope',method_ids,versions,trim(p_data->>'label'),(p_data->>'amount_rwf')::integer,
      p_data->>'purpose',coalesce(p_data->>'reference',''),(p_data->>'expires_at')::timestamptz)
    returning to_jsonb(biopay_links.*) into result;
    return result;
  elsif p_action='revoke_link' then
    update public.biopay_links set revoked_at=now(),version=version+1
      where id=(p_data->>'id')::uuid and owner_id=u and version=(p_data->>'version')::integer and revoked_at is null;
    if not found then raise exception 'Link changed. Refresh first.'; end if;
    return '{}'::jsonb;
  elsif p_action='save_recent' then
    insert into public.biopay_recipient_shortcuts(owner_id,lookup,nickname,favorite)
      values(u,p_data->>'lookup',p_data->>'nickname',coalesce((p_data->>'favorite')::boolean,false))
    on conflict(owner_id,lookup) do update set nickname=excluded.nickname,favorite=excluded.favorite,updated_at=now();
    return '{}'::jsonb;
  elsif p_action='remove_recent' then
    delete from public.biopay_recipient_shortcuts where id=(p_data->>'id')::uuid and owner_id=u;
    return '{}'::jsonb;
  elsif p_action='save_template' then
    insert into public.biopay_request_templates(owner_id,label,data) values(u,p_data->>'label',p_data->'data')
      returning to_jsonb(biopay_request_templates.*) into result;
    return result;
  elsif p_action='remove_template' then
    delete from public.biopay_request_templates where id=(p_data->>'id')::uuid and owner_id=u;
    return '{}'::jsonb;
  end if;
  raise exception 'Unsupported BioPay action.';
end $$;

-- Lookup preparation rate is operational throughput, never biometric accuracy.
-- Historical AWS face sessions are not counted as the new service's activity.
create or replace function public.rpc_admin_biopay_summary() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; attempts bigint; prepared bigint;
begin
  perform public.fn_biopay_require_admin();
  select jsonb_build_object('total_payees',count(*),'enrolled_payees',count(*) filter(
    where provider='opencv_sface_v1' and provider_subject_id is not null and status='active'
      and consent_version='face-discovery-v1' and server_verified_at is not null and deleted_at is null))
    into result from public.biopay_profiles;
  select result||jsonb_build_object('total_requests',count(*),
    'pending_confirmations',count(*) filter(where status='user_marked_paid'),
    'confirmed_requests',count(*) filter(where status='confirmed'))
    into result from public.biopay_payment_requests;
  select count(*),count(*) filter(where outcome='dial_ready') into attempts,prepared
    from public.biopay_provider_operations where action='resolve';
  return result||jsonb_build_object('match_rate',case when attempts=0 then 0
    else round(prepared::numeric/attempts,4) end,'lookup_attempts',attempts,'prepared_shortcuts',prepared);
end $$;

create function public.rpc_biopay_face_readiness() returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.biopay_face_policy;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  select * into p from public.biopay_face_policy where model_version='yunet2023mar-sface2021dec-opencv4.11-v1';
  return jsonb_build_object('database_contract',coalesce(p.dimensions=128,false)
      and to_regprocedure('public.rpc_reserve_biopay_provider_operation(uuid,text,uuid,text,text)') is not null
      and to_regprocedure('public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)') is not null
      and to_regclass('public.biopay_face_revisions') is not null
      and to_regclass('public.biopay_face_cleanup') is not null
      and not has_function_privilege('authenticated','public.rpc_biopay_face_authority(uuid,uuid,text,jsonb)','EXECUTE'),
    'policy_accepted',coalesce(p.enabled,false),
    'last_acceptance_evidence',p.acceptance_evidence,'last_acceptance_at',p.accepted_at,
    'route_configured',exists(select 1 from public.biopay_provider_routes where face_enabled and state<>'disabled' and valid_from<=now() and valid_until>now()));
end $$;
revoke all on function public.rpc_biopay_face_readiness() from public,anon,authenticated;
grant execute on function public.rpc_biopay_face_readiness() to service_role;
create or replace function public.rpc_admin_biopay_system_status() returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform public.fn_biopay_require_admin();
  return jsonb_build_object('overall_status','acceptance_required','face_provider','opencv_sface_v1',
    'face_provider_ready',false,'collection_id','yunet2023mar-sface2021dec-opencv4.11-v1',
    'database_status','available','ussd_handoff_status','external_ussd_only',
    'pending_confirmations',(select count(*) from public.biopay_payment_requests where status='user_marked_paid'),
    'last_audit_at',(select max(created_at) from public.biopay_audit_events));
end $$;
commit;
