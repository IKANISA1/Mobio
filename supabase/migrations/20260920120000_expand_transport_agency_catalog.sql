-- Agency names supplied by the product owner on 2026-09-20.
-- Only catalog names are supplied: contact/fleet/schedule details stay unset.
-- Existing IDs, contact details, and admin activation decisions are preserved.
begin;

create temporary table mobio_agency_catalog_20260920 (
  name text primary key,
  previous_name text
) on commit drop;

insert into mobio_agency_catalog_20260920 (name, previous_name)
values
  ('ALPHA EXPRESS COMPANY', null),
  ('CAPITAL', null),
  ('CITY EXPRESS', null),
  ('DIFFERENT EXPRESS', null),
  ('EA BUS & TRAVEL LIMITED', null),
  ('EBENEZER EXPRESS', null),
  ('EXCEL TRAVEL&TOURS AGENCY', null),
  ('FIDELITY EXPRESS', null),
  ('GICUMBI TRANSPORT COOPERATIVE', null),
  ('HORIZON EXPRESS', null),
  ('HUYE TC', null),
  ('INDONYI EXPRESS', null),
  ('INTERNATIONAL EXPRESS', null),
  ('JALI TRANSPORT', null),
  ('KAYONZA TC', null),
  ('KIGALI BUS SERVICES', null),
  ('KIGALI COACH TOURS & TRAVEL', null),
  ('KIVU BELT EXPRESS', null),
  ('LA COLOMBE EXPRESS', null),
  ('MASH BUS SERVICES', null),
  ('MATUNDA EXPRESS', null),
  ('MODERN COAST', null),
  ('MUHANGA TC', null),
  ('MUSANZE TC', null),
  ('NGOMA TC', null),
  ('NYABUGOGO TC', null),
  ('NYAGATARE TC', null),
  ('OMEGA', null),
  ('RITCO', null),
  ('ROYAL EXPRESS', null),
  ('RUBAVU TC', null),
  ('RUHIRE EXPRESS', null),
  ('RUSIZI TC', null),
  ('SELECT EXPRESS AGENCY', null),
  ('SHALOM TRANSPORTATION LIMITED', null),
  ('SIMBA COACH', null),
  ('STAR EXPRESS', null),
  ('STELLA EXPRESS', null),
  ('TRINITY TRANSPORTERS', 'TRINITY EXPRESS'),
  ('TRIPARTITE TOURS', null),
  ('VIRUNGA EXPRESS', null),
  ('VOLCANO', 'VOLCANO EXPRESS'),
  ('YAHOO CAR EXPRESS', null);

-- Keep references to existing agencies intact, including the old preview names.
update public.transport_agencies agency
set name = catalog.name,
    updated_at = timezone('utc', now())
from mobio_agency_catalog_20260920 catalog
where agency.organization_id = public.default_organization_id()
  and upper(regexp_replace(trim(agency.name), '\s+', ' ', 'g'))
      in (catalog.name, catalog.previous_name)
  and agency.name is distinct from catalog.name;

insert into public.transport_agencies (organization_id, name, slug)
select public.default_organization_id(),
       catalog.name,
       public._normalize_transport_agency_slug(catalog.name)
from mobio_agency_catalog_20260920 catalog
where not exists (
  select 1
  from public.transport_agencies agency
  where agency.organization_id = public.default_organization_id()
    and upper(regexp_replace(trim(agency.name), '\s+', ' ', 'g')) = catalog.name
)
on conflict (slug) do nothing;

commit;
