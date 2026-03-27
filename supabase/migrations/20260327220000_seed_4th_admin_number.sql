-- Seed the 4th admin WhatsApp number that was missing from the initial seed.
-- Note: +3569999711145 has country_code +356 (Malta).
-- This migration is idempotent via ON CONFLICT.

insert into public.admin_whatsapp_numbers (phone_e164, country_code, display_name, is_active)
values
  ('+3569999711145', '+356', 'Platform Admin (MT)', true)
on conflict (phone_e164) do update
set
  country_code = excluded.country_code,
  display_name = coalesce(public.admin_whatsapp_numbers.display_name, excluded.display_name),
  is_active = true;
