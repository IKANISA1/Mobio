-- BioPay QR generation can carry an open amount.
-- A blank amount is represented as amount_minor = 0 and should not force a
-- fake minimum payment amount into the generated receiver code.

alter table public.biopay_payment_requests
  drop constraint if exists biopay_payment_requests_amount_minor_check;

alter table public.biopay_payment_requests
  add constraint biopay_payment_requests_amount_minor_check
  check (amount_minor >= 0);

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
  normalized_phone text := regexp_replace(coalesce(p_payee_phone, ''), '[^0-9+]', '', 'g');
  receiver text := coalesce(nullif(normalized_phone, ''), p_reference);
begin
  if p_provider_code = 'mtn_rw' then
    if amount_major <= 0 then
      return '*182*8*1*' || receiver || '#';
    end if;

    return '*182*8*1*' || receiver || '*' || amount_major::text || '#';
  end if;

  if amount_major <= 0 then
    return '*' || p_provider_code || '*' || receiver || '#';
  end if;

  return '*' || p_provider_code || '*' || receiver || '*' || amount_major::text || '#';
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
  v_phone text := nullif(trim(coalesce(p_payee_phone, '')), '');
  v_row public.biopay_payment_requests;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_channel not in ('qr', 'nfc', 'face') then
    raise exception 'Invalid BioPay channel';
  end if;

  if p_amount_minor < 0 then
    raise exception 'Amount cannot be negative';
  end if;

  select coalesce(v_phone, whatsapp, phone)
    into v_phone
  from public.profiles
  where id = v_user_id;

  v_phone := coalesce(v_phone, nullif(trim(coalesce(p_payee_phone, '')), ''));

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
