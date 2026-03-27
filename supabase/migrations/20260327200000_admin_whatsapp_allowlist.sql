begin;

create table if not exists public.admin_whatsapp_numbers (
  id uuid primary key default gen_random_uuid(),
  phone_e164 text not null unique,
  country_code text not null,
  display_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint admin_whatsapp_numbers_phone_e164_check
    check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  constraint admin_whatsapp_numbers_country_code_check
    check (country_code ~ '^\+[1-9][0-9]{0,4}$'),
  constraint admin_whatsapp_numbers_phone_prefix_check
    check (phone_e164 like country_code || '%')
);

alter table public.admin_whatsapp_numbers
  add column if not exists country_code text,
  add column if not exists display_name text,
  add column if not exists is_active boolean,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

update public.admin_whatsapp_numbers
set country_code = case
  when phone_e164 like '+250%' then '+250'
  when phone_e164 like '+356%' then '+356'
  else '+250'
end
where country_code is null;

update public.admin_whatsapp_numbers
set is_active = true
where is_active is null;

update public.admin_whatsapp_numbers
set created_at = timezone('utc', now())
where created_at is null;

update public.admin_whatsapp_numbers
set updated_at = timezone('utc', now())
where updated_at is null;

alter table public.admin_whatsapp_numbers
  alter column phone_e164 set not null,
  alter column country_code set not null,
  alter column is_active set default true,
  alter column is_active set not null,
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null,
  alter column updated_at set default timezone('utc', now()),
  alter column updated_at set not null;

create index if not exists idx_admin_whatsapp_numbers_active
  on public.admin_whatsapp_numbers(is_active, phone_e164);

drop trigger if exists set_admin_whatsapp_numbers_updated_at
  on public.admin_whatsapp_numbers;
create trigger set_admin_whatsapp_numbers_updated_at
before update on public.admin_whatsapp_numbers
for each row
execute function public.handle_updated_at();

alter table public.admin_whatsapp_numbers enable row level security;

revoke all on public.admin_whatsapp_numbers from anon, authenticated;
grant all on public.admin_whatsapp_numbers to service_role;

insert into public.admin_whatsapp_numbers (phone_e164, country_code, display_name, is_active)
values
  ('+250795588248', '+250', 'Platform Admin', true),
  ('+250788767816', '+250', 'Platform Admin', true),
  ('+35677186193', '+356', 'Platform Admin', true)
on conflict (phone_e164) do update
set
  country_code = excluded.country_code,
  display_name = coalesce(public.admin_whatsapp_numbers.display_name, excluded.display_name),
  is_active = true;

commit;
