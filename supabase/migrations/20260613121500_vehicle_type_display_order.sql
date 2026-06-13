-- Canonical customer-facing vehicle type order:
-- Moto Taxi, Bus, Cab, Truck, Trike, Others.

update public.vehicle_types
set sort_order = case id
  when 'moto' then 1
  when 'bus' then 2
  when 'cab' then 3
  when 'truck' then 4
  when 'trike' then 5
  when 'private' then 6
  else sort_order
end,
label = case id
  when 'moto' then 'Moto Taxi'
  when 'bus' then 'Bus'
  when 'cab' then 'Cab'
  when 'truck' then 'Truck'
  when 'trike' then 'Trike'
  when 'private' then 'Others'
  else label
end,
updated_at = now()
where id in ('moto', 'bus', 'cab', 'truck', 'trike', 'private');
