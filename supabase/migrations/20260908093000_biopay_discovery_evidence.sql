begin;

-- Legacy confirmation RPCs remain available to older clients. For discovery
-- attempts, their claims are evidence reports, never provider confirmation.
create or replace function public.fn_biopay_discovery_evidence_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid(); provider_authority boolean:=coalesce(auth.jwt()->>'role','')='service_role';
  operator_authority boolean; prior_evidence text;
begin
  if tg_op='UPDATE' then prior_evidence:=old.evidence_kind; end if;
  if new.discovery_quote_id is null then return new; end if;
  operator_authority:=coalesce((auth.jwt()->'app_metadata'->>'provider')='admin_whatsapp_otp',false)
    and exists(select 1 from public.profiles p join public.admin_whatsapp_numbers a on a.phone_e164=p.phone
      where p.id=u and p.role='admin' and a.is_active);
  if not provider_authority then
    if new.status='confirmed' then
      if operator_authority then
        if coalesce(new.confirmation_source,'') !~ '^operator_review:.{6,120}$' then raise exception 'Evidence reference required.'; end if;
        new.evidence_kind:='operatorReviewed';
      elsif new.payee_id=u then new.evidence_kind:='receiverAcknowledged';
      else raise exception 'Trusted confirmation evidence required.' using errcode='42501'; end if;
      new.status:='user_marked_paid'; new.confirmed_at:=null;
    end if;
    if new.evidence_kind='providerConfirmed'
      or (new.evidence_kind='operatorReviewed' and not operator_authority and prior_evidence is distinct from 'operatorReviewed')
      or (new.evidence_kind='receiverAcknowledged' and new.payee_id is distinct from u and prior_evidence is distinct from 'receiverAcknowledged')
    then raise exception 'Evidence authority required.' using errcode='42501'; end if;
  end if;
  return new;
end $$;
revoke all on function public.fn_biopay_discovery_evidence_guard() from public,anon,authenticated;
create trigger biopay_discovery_evidence_guard before insert or update on public.biopay_payment_requests
for each row execute function public.fn_biopay_discovery_evidence_guard();
commit;
