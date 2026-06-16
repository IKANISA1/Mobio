begin;

-- Launch seed for the EV charger locator. These rows make the first
-- production release usable before admins curate a larger live catalog.
--
-- Source notes checked on 2026-06-16:
-- - Volkswagen/CFAO Rwanda lists Plot G10 in Kigali Special Economic Zone.
-- - Rwanda MININFRA/GGGI identify Volkswagen stations at KSEZ and KCC.
-- - IZI Electric announced a 120 kW Century Park fast charger.
-- - Kabisa lists EV House at 1 KN 77 St, Kigali.
-- - EVP lists active Kigali car stations including Nyamirambo 1.
-- - RRA/Silverback Mall public pages place RRA HQ at Silverback Mall,
--   Kicukiro Sonatube; EVP public posts identify the charger there.
-- - EVP public posts identify a Lemigo Hotel 120 kW fast charger.

with seed_rows (
  id,
  name,
  address,
  latitude,
  longitude,
  connector_types,
  operator_name,
  phone,
  power_kw,
  price_note,
  place_id,
  is_active
) as (
  values
    (
      '51000000-0000-0000-0000-000000000001'::uuid,
      'Volkswagen Rwanda SEZ Charger',
      'Plot G10, Kigali Special Economic Zone, Gasabo',
      -1.9526760::double precision,
      30.1566106::double precision,
      array['Type 2']::text[],
      'Volkswagen Rwanda / CFAO Mobility',
      '+250788179500',
      22.00::numeric,
      'Confirm public access with Volkswagen Rwanda before arrival.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000002'::uuid,
      'Kigali Convention Centre EV Station',
      'Kigali Convention Centre, KG 2 Roundabout, Kimihurura',
      -1.9552880::double precision,
      30.0937817::double precision,
      array['Type 2']::text[],
      'Volkswagen Mobility Solutions Rwanda',
      null::text,
      22.00::numeric,
      'Confirm access with Kigali Convention Centre or Radisson Blu.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000003'::uuid,
      'IZI Fast Charge - Century Park',
      'Century Park Hotel and Residences, 13 KG 9 Ave, Nyarutarama',
      -1.9525400::double precision,
      30.1018500::double precision,
      array['DC fast']::text[],
      'IZI Electric Rwanda',
      null::text,
      120.00::numeric,
      'Published launch price: RWF 400 per kWh.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000004'::uuid,
      'Kabisa EV House',
      '1 KN 77 St, Kiyovu, below Camp Kigali',
      -1.9512643::double precision,
      30.0593834::double precision,
      array['EV charging']::text[],
      'Kabisa',
      '6420',
      null::numeric,
      'Confirm current bay availability with Kabisa.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000005'::uuid,
      'EVP Silverback Mall Fast Charger',
      'Silverback Mall, RRA Headquarters, Kicukiro Sonatube',
      -1.9687816::double precision,
      30.1026542::double precision,
      array['GB/T']::text[],
      'EVP Charger Rwanda',
      null::text,
      120.00::numeric,
      'Confirm current tariff and status in the EVP app.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000006'::uuid,
      'EVP Lemigo Hotel Fast Charger',
      'Lemigo Hotel, Rugando, Kimihurura',
      -1.9537600::double precision,
      30.0966800::double precision,
      array['GB/T']::text[],
      'EVP Charger Rwanda',
      '+250784999705',
      120.00::numeric,
      'Open 24 hours per EVP public station posts; confirm current status in the EVP app.',
      null::text,
      true
    ),
    (
      '51000000-0000-0000-0000-000000000007'::uuid,
      'EVP Nyamirambo 1 Car Station',
      'Nyamirambo, Kigali',
      -1.9821000::double precision,
      30.0441000::double precision,
      array['GB/T']::text[],
      'EVP Charger Rwanda',
      null::text,
      null::numeric,
      'Confirm current tariff and status in the EVP app.',
      null::text,
      true
    )
)
insert into public.ev_chargers (
  id,
  organization_id,
  name,
  address,
  latitude,
  longitude,
  connector_types,
  operator_name,
  phone,
  power_kw,
  price_note,
  place_id,
  is_active,
  created_by
)
select
  seed.id,
  public.default_organization_id(),
  seed.name,
  seed.address,
  seed.latitude,
  seed.longitude,
  seed.connector_types,
  seed.operator_name,
  seed.phone,
  seed.power_kw,
  seed.price_note,
  seed.place_id,
  seed.is_active,
  null::uuid
from seed_rows seed
where public.default_organization_id() is not null
on conflict (id) do update
set
  name = excluded.name,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  connector_types = excluded.connector_types,
  operator_name = excluded.operator_name,
  phone = excluded.phone,
  power_kw = excluded.power_kw,
  price_note = excluded.price_note,
  place_id = excluded.place_id,
  is_active = excluded.is_active,
  updated_at = timezone('utc', now());

commit;
