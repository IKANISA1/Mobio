-- ============================================================================
-- MOBI: Seed Data (v2)
-- ============================================================================
-- Deterministic UUIDs for reproducible test data.
-- Includes: profiles, trips (driver + passenger), biopay wallets
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Seed Profiles (with new BioPay/driver columns)
-- ---------------------------------------------------------------------------

INSERT INTO profiles (id, name, display_name, phone, role, location, vehicle, category, is_driver, vehicle_type, vehicle_number_plate, whatsapp, member_since, biopay_handle_type, biopay_handle_value, is_online)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Alex Rivera',       'Alex Rivera',       '+1 234',         'passenger', 'Downtown',        NULL,                   'Premium',   false, 'cab',     NULL,       '',            2024, 'number', '', false),
  ('00000000-0000-0000-0000-000000000002', 'Sarah Chen',        'Sarah Chen',        '+1 567',         'driver',    NULL,               'Mercedes-Benz E-Class','Executive', true,  'cab',     'RAB 201 C','1234567890',  2024, 'number', '', true),
  ('00000000-0000-0000-0000-000000000003', 'Marcus Thorne',     'Marcus Thorne',     '+1 890',         'passenger', 'Westside',         NULL,                   'Standard',  false, 'cab',     NULL,       '1234567891',  2024, 'number', '', false),
  ('00000000-0000-0000-0000-000000000004', 'Economy Trike',     'Economy Trike',     '+250 700',       'driver',    'Eastside',         'Bajay RE',             'Economy',   true,  'trike',   'RAD 518 T','1234567892',  2023, 'number', '', false),
  ('00000000-0000-0000-0000-000000000005', 'Marcus Thompson',   'Marcus Thompson',   '+250 701',       'driver',    'Downtown',         'Toyota Corolla',       'Standard',  true,  'cab',     'RAC 442 M','1234567893',  2024, 'number', '', true),
  ('00000000-0000-0000-0000-000000000006', 'Elena Rodriguez',   'Elena Rodriguez',   '+250 702',       'driver',    'Plaza',            'Yamaha NMAX',          'Standard',  true,  'moto',    'RMB 220 K','1234567894',  2024, 'number', '', true),
  ('00000000-0000-0000-0000-000000000007', 'Private Executive', 'Private Executive', '+250 703',       'driver',    'Northside',        'Audi A8',              'Executive', true,  'private', 'RPF 990 X','1234567895',  2024, 'number', '', false),
  ('00000000-0000-0000-0000-000000000008', 'Heavy Truck',       'Heavy Truck',       '+250 704',       'driver',    'Industrial Zone',  'Scania R450',          'Cargo',     true,  'truck',   'RTK 771 H','1234567896',  2024, 'number', '', false),
  ('00000000-0000-0000-0000-000000000009', 'Platform Admin',    'Platform Admin',    '+250795588248',  'admin',     NULL,               NULL,                   NULL,        false, 'cab',     NULL,       '',            2024, 'number', '', false)
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  member_since = EXCLUDED.member_since,
  vehicle_number_plate = EXCLUDED.vehicle_number_plate,
  biopay_handle_type = EXCLUDED.biopay_handle_type,
  biopay_handle_value = EXCLUDED.biopay_handle_value,
  is_online = EXCLUDED.is_online;

-- ---------------------------------------------------------------------------
-- 2. Seed Trips (driver offers)
-- ---------------------------------------------------------------------------

INSERT INTO trips (id, author_id, author_name, origin, origin_lat, origin_lng, destination, dest_lat, dest_lng, departure_date, departure_time, date, time, role, whatsapp, seats, price, is_active, status, vehicle_type, joined_date)
VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Executive Cab',     'Downtown',        -1.9503, 29.8839, 'Mercedes-Benz E-Class • White', NULL, NULL, '2026-03-25', '08:30 AM', '2026-03-25', '08:30 AM', 'driver', '1234567890', 3, '0.4 km', true, 'approved', 'cab',     '2024-01-15'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'MOBI Moto',         'Westside',        -1.9353, 29.8639, 'Yamaha NMAX • Matte Black',     NULL, NULL, '2026-03-25', '09:00 AM', '2026-03-25', '09:00 AM', 'driver', '1234567891', 1, '0.9 km', true, 'pending',  'moto',    '2024-02-20'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 'Economy Trike',     'Eastside',        -1.9453, 29.8939, 'Bajay RE • Yellow',             NULL, NULL, '2026-03-25', '10:00 AM', '2026-03-25', '10:00 AM', 'driver', '1234567892', 2, '1.2 km', false,'suspended','trike',   '2023-11-05'),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000007', 'Private Executive', 'Northside',       -1.9303, 29.8539, 'Audi A8 • Black',               NULL, NULL, '2026-03-25', '11:00 AM', '2026-03-25', '11:00 AM', 'driver', '1234567895', 4, '1.5 km', true, 'approved', 'private', '2024-04-01'),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000008', 'Heavy Truck',       'Industrial Zone', -1.9403, 29.8739, 'Scania R450 • Blue',            NULL, NULL, '2026-03-25', '12:00 PM', '2026-03-25', '12:00 PM', 'driver', '1234567896', 2, '2.5 km', true, 'approved', 'truck',   '2024-05-15'),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000005', 'Marcus Thompson',   'Downtown',        -1.9403, 29.8739, 'Airport',                       NULL, NULL, '2026-03-25', 'Now',      '2026-03-25', 'Now',      'driver', '1234567893', 4, '1.2 KM', true, 'approved', 'cab',     '2024-03-01'),
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000006', 'Elena Rodriguez',   'Plaza',           -1.9503, 29.8839, 'Station',                       NULL, NULL, '2026-03-25', 'Now',      '2026-03-25', 'Now',      'driver', '1234567894', 1, '0.8 KM', true, 'approved', 'moto',    '2024-03-10')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Seed Trips (passenger ride requests — visible to drivers)
-- ---------------------------------------------------------------------------

INSERT INTO trips (id, author_id, author_name, origin, origin_lat, origin_lng, destination, dest_lat, dest_lng, departure_date, departure_time, date, time, role, whatsapp, seats, is_active, status, vehicle_type)
VALUES
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Alex Rivera',   'Downtown',     -1.9403, 29.8739, 'Airport',                    -1.9700, 29.9200, '2026-03-25', '09:30 AM', '2026-03-25', '09:30 AM', 'passenger', '',            1, true, 'active', 'cab'),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'Marcus Thorne', 'Westside',     -1.9353, 29.8639, 'City Center',                -1.9450, 29.8750, '2026-03-25', '10:15 AM', '2026-03-25', '10:15 AM', 'passenger', '1234567891',  2, true, 'active', 'moto'),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Alex Rivera',   'Hotel Rwanda', -1.9503, 29.8839, 'Kigali Convention Center',   -1.9550, 29.8900, '2026-03-26', '07:00 AM', '2026-03-26', '07:00 AM', 'passenger', '',            3, true, 'active', 'private')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Seed BioPay Wallets
-- ---------------------------------------------------------------------------

INSERT INTO biopay_wallets (id, user_id, balance, currency, is_active)
VALUES
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 15000.00, 'RWF', true),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 42500.00, 'RWF', true),
  ('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003',  8250.00, 'RWF', true),
  ('30000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 67000.00, 'RWF', true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Seed BioPay Transactions
-- ---------------------------------------------------------------------------

INSERT INTO biopay_transactions (id, wallet_id, counterpart, type, status, amount, currency, note)
VALUES
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'send',    'completed', 5000.00,  'RWF', 'Trip payment: Downtown → Airport'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'receive', 'completed', 5000.00,  'RWF', 'Trip payment received'),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', NULL,                                   'top_up',  'completed', 10000.00, 'RWF', 'MoMo top-up'),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000003', 'receive', 'completed', 3000.00,  'RWF', 'Face Scan Pay received')
ON CONFLICT (id) DO NOTHING;
