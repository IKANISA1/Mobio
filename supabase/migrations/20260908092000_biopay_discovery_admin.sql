begin;

create table public.biopay_provider_evidence (
  provider text primary key,
  name text not null,
  published_root text,
  source_url text,
  reviewed_on date not null,
  evidence_state text not null default 'root_only'
);
alter table public.biopay_provider_evidence enable row level security;
revoke all on public.biopay_provider_evidence from public,anon,authenticated;
grant all on public.biopay_provider_evidence to service_role;

create or replace function public.rpc_admin_biopay_routes(p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); r public.biopay_provider_routes; result jsonb;
begin
  if u is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true)
    or (auth.jwt()->'app_metadata'->>'provider') is distinct from 'admin_whatsapp_otp'
    or not exists(select 1 from public.profiles p join public.admin_whatsapp_numbers a on a.phone_e164=p.phone
      where p.id=u and p.role='admin' and a.is_active)
  then raise exception 'Admin sign-in required' using errcode='42501'; end if;
  if p_action='list' then
    return jsonb_build_object('routes',(select coalesce(jsonb_agg(to_jsonb(x) order by updated_at desc),'[]') from public.biopay_provider_routes x),
      'evidence',(select coalesce(jsonb_agg(to_jsonb(x) order by name),'[]') from public.biopay_provider_evidence x));
  end if;
  if p_data->>'id' is not null then
    select * into r from public.biopay_provider_routes where id=(p_data->>'id')::uuid for update;
    if not found or r.adapter_version is distinct from (p_data->>'adapter_version')::integer then
      raise exception 'Route changed. Refresh before continuing.';
    end if;
  end if;
  if p_action='save' then
    insert into public.biopay_provider_routes(id,source_provider,source_kind,requires_login_phone,
      destination_provider,destination_kind,rail,purpose,min_rwf,max_rwf,
      fee_certainty,fee_rwf,fee_all_in,steps,handoff_mode,instruction_template,recipient_format,
      device_families,requires_sim,adapter_version,tariff_version,valid_from,valid_until,evidence_url,tariff_evidence_url,test_evidence_url,state)
    values(coalesce(r.id,gen_random_uuid()),p_data->>'source_provider',p_data->>'source_kind',
      coalesce((p_data->>'requires_login_phone')::boolean,false),p_data->>'destination_provider',
      p_data->>'destination_kind',p_data->>'rail',p_data->>'purpose',(p_data->>'min_rwf')::integer,
      (p_data->>'max_rwf')::integer,p_data->>'fee_certainty',(p_data->>'fee_rwf')::integer,
      coalesce((p_data->>'fee_all_in')::boolean,false),(p_data->>'steps')::integer,p_data->>'handoff_mode',
      nullif(p_data->>'instruction_template',''),coalesce(p_data->>'recipient_format','raw'),array(select jsonb_array_elements_text(p_data->'device_families')),
      coalesce((p_data->>'requires_sim')::boolean,true),coalesce(r.adapter_version,0)+1,
      coalesce(r.tariff_version,0)+1,(p_data->>'valid_from')::timestamptz,(p_data->>'valid_until')::timestamptz,p_data->>'evidence_url',p_data->>'tariff_evidence_url',p_data->>'test_evidence_url','draft')
    on conflict(id) do update set source_provider=excluded.source_provider,source_kind=excluded.source_kind,
      requires_login_phone=excluded.requires_login_phone,destination_provider=excluded.destination_provider,
      destination_kind=excluded.destination_kind,rail=excluded.rail,purpose=excluded.purpose,
      min_rwf=excluded.min_rwf,max_rwf=excluded.max_rwf,fee_certainty=excluded.fee_certainty,
      fee_rwf=excluded.fee_rwf,fee_all_in=excluded.fee_all_in,steps=excluded.steps,
      handoff_mode=excluded.handoff_mode,instruction_template=excluded.instruction_template,recipient_format=excluded.recipient_format,
      device_families=excluded.device_families,requires_sim=excluded.requires_sim,
      adapter_version=excluded.adapter_version,tariff_version=excluded.tariff_version,
      valid_from=excluded.valid_from,valid_until=excluded.valid_until,
      evidence_url=excluded.evidence_url,tariff_evidence_url=excluded.tariff_evidence_url,test_evidence_url=excluded.test_evidence_url,
      state='draft',tested_at=null,tested_by=null,reviewed_at=null,reviewed_by=null,updated_at=now()
    returning to_jsonb(biopay_provider_routes.*) into result;
  elsif p_action='tested' and r.id is not null then
    if r.state<>'draft' or nullif(r.instruction_template,'') is null
      or position('{recipient}' in r.instruction_template)=0 or position('{amount}' in r.instruction_template)=0
      or r.valid_until is null or r.valid_until<=now() or r.valid_until<=r.valid_from
      or replace(replace(replace(r.instruction_template,'{recipient}',''),'{amount}',''),'{reference}','') ~ '[{}]'
      or (r.handoff_mode='dial' and replace(replace(replace(r.instruction_template,'{recipient}','1'),'{amount}','1'),'{reference}','1') !~ '^\*[0-9*]+#$')
      or (r.handoff_mode='dial' and r.destination_kind='mobileWallet' and r.recipient_format='raw')
      or r.test_evidence_url is null or r.test_evidence_url !~ '^https://'
      or cardinality(r.device_families)=0 or r.evidence_url is null or r.tariff_evidence_url is null
      or r.evidence_url !~ '^https://' or r.tariff_evidence_url !~ '^https://'
    then raise exception 'Complete provider, tariff and device-test evidence first.'; end if;
    update public.biopay_provider_routes set state='tested',tested_at=now(),tested_by=u,updated_at=now()
      where id=r.id returning to_jsonb(biopay_provider_routes.*) into result;
  elsif p_action='approve' and r.id is not null then
    if r.state<>'tested' or r.tested_by=u then raise exception 'An independent administrator must review the tested route.'; end if;
    update public.biopay_provider_routes set state='approved',reviewed_at=now(),reviewed_by=u,updated_at=now()
      where id=r.id returning to_jsonb(biopay_provider_routes.*) into result;
  elsif p_action='disable' and r.id is not null then
    update public.biopay_provider_routes set state='disabled',adapter_version=adapter_version+1,updated_at=now()
      where id=r.id returning to_jsonb(biopay_provider_routes.*) into result;
  else raise exception 'Unsupported route action.'; end if;
  insert into public.biopay_audit_events(actor_user_id,action,metadata)
    values(u,'provider_route_'||p_action,jsonb_build_object('route_id',result->>'id',
      'adapter_version',result->'adapter_version','tariff_version',result->'tariff_version'));
  return result;
end $$;
revoke all on function public.rpc_admin_biopay_routes(text,jsonb) from public,anon;
grant execute on function public.rpc_admin_biopay_routes(text,jsonb) to authenticated;

-- Legacy MoMo receiving data stays in profiles for existing Wallet consumers.
-- New methods start private; sending is an explicit user choice.
insert into public.biopay_payment_methods(owner_id,provider,kind,identifier,label)
select p.id,'mtn_rw','mobileWallet',case
  when regexp_replace(p.momo_number,'[^0-9]','','g') ~ '^07[0-9]{8}$'
    then '+250'||substring(regexp_replace(p.momo_number,'[^0-9]','','g') from 2)
  else '+'||regexp_replace(p.momo_number,'[^0-9]','','g') end,'MoMo'
from public.profiles p where regexp_replace(coalesce(p.momo_number,''),'[^0-9]','','g') ~ '^(07[0-9]{8}|2507[0-9]{8})$'
on conflict do nothing;
insert into public.biopay_payment_methods(owner_id,provider,kind,identifier,label)
select p.id,'mtn_rw','merchantCode',p.momo_pay_code,'MoMo Pay'
from public.profiles p where p.momo_pay_code ~ '^[0-9]{3,20}$'
on conflict do nothing;

-- Published entry roots are research leads, never executable adapters.
insert into public.biopay_provider_evidence(provider,name,published_root,source_url,reviewed_on,evidence_state) values
('mtn_rw','MTN MoMo','*182#','https://www.mtn.co.rw/','2026-09-08','published_root_only'),
('bk_rw','Bank of Kigali','*334#','https://bk.rw/personal/digital-products','2026-09-08','published_root_only'),
('bpr_rw','BPR Bank','*150#','https://bpr.rw/products/bpr-ekash','2026-09-08','published_ekash_entry_only'),
('im_rw','I&M Bank Rwanda','*227#','https://www.imbankgroup.com/rw/ways-to-bank/mobile-banking/','2026-09-08','published_root_only'),
('access_rw','Access Bank Rwanda','*903#','https://rwanda.accessbankplc.com/personal/e-channels/access-mobile-ussd','2026-09-08','published_root_only'),
('equity_rw','Equity Bank Rwanda','*555#','https://equitygroupholdings.com/rw/fr/equity-bank-rwanda-et-rswitch-lancent-ekash-pour-ameliorer-linteroperabilite-financiere-et-promouvoir-une-economie-sans-especes-pour-les-clients-dequity-bank/','2026-09-08','published_ekash_entry_only'),
('airtel_rw','Airtel Money',NULL,NULL,'2026-09-08','primary_payment_flow_not_reverified');

commit;
