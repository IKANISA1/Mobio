begin;

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
  amount_major integer := ceil(greatest(p_amount_minor, 0)::numeric / 100)::integer;
  normalized_receiver text := regexp_replace(coalesce(p_payee_phone, ''), '[^0-9+]', '', 'g');
  receiver text := coalesce(nullif(normalized_receiver, ''), p_reference);
  mtn_menu text := case
    when receiver ~ '^[0-9]{5,6}$' then '*182*8*1'
    else '*182*1*1'
  end;
begin
  if p_provider_code = 'mtn_rw' then
    if amount_major <= 0 then
      return mtn_menu || '*' || receiver || '#';
    end if;

    return mtn_menu || '*' || receiver || '*' || amount_major::text || '#';
  end if;

  if amount_major <= 0 then
    return '*' || p_provider_code || '*' || receiver || '#';
  end if;

  return '*' || p_provider_code || '*' || receiver || '*' || amount_major::text || '#';
end;
$$;

comment on function public.fn_biopay_ussd_code(text, text, integer, text) is
  'Builds direct USSD dial strings for BioPay. MTN Rwanda MoMo Pay codes use *182*8*1; Rwanda MoMo phone numbers use *182*1*1.';

commit;
