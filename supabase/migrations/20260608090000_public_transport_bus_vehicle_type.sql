-- Mobio public transport expansion: add buses to both the legacy enum and the
-- dynamic vehicle type catalog used by mobile and admin UI.

alter type public.vehicle_type_enum add value if not exists 'bus';

insert into public.vehicle_types (id, label, icon_name, sort_order, is_active)
values ('bus', 'Bus', 'bus', 3, true)
on conflict (id) do update
set
  label = excluded.label,
  icon_name = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();
