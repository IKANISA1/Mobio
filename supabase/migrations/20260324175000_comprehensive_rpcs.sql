-- ============================================================================
-- MOBI: Comprehensive Backend — Schema Fixes + Missing RPCs
-- ============================================================================
-- This migration closes all gaps identified in REVAMP_IMPLEMENTATION_PLAN.md:
--   1. Schema additions (profile columns, trip columns)
--   2. Fix member_id to numeric-safe
--   3. Core RPCs (discover, nearby, driver status)
--   4. Trip RPCs (list, detail, create, update, cancel)
--   5. Profile RPCs (update, driver mode)
--   6. BioPay RPCs (wallet, handle, QR, charge)
--   7. Admin RPCs (enhanced stats, user list, trip list)
-- ============================================================================
-- Rollback:
--   DROP FUNCTION IF EXISTS rpc_get_discover_summary CASCADE;
--   DROP FUNCTION IF EXISTS rpc_search_nearby_drivers CASCADE;
--   DROP FUNCTION IF EXISTS rpc_set_driver_online_status CASCADE;
--   DROP FUNCTION IF EXISTS rpc_list_scheduled_trips CASCADE;
--   DROP FUNCTION IF EXISTS rpc_get_trip_details CASCADE;
--   DROP FUNCTION IF EXISTS rpc_create_trip CASCADE;
--   DROP FUNCTION IF EXISTS rpc_update_trip CASCADE;
--   DROP FUNCTION IF EXISTS rpc_cancel_trip CASCADE;
--   DROP FUNCTION IF EXISTS rpc_update_profile CASCADE;
--   DROP FUNCTION IF EXISTS rpc_enable_driver_mode CASCADE;
--   DROP FUNCTION IF EXISTS rpc_disable_driver_mode CASCADE;
--   DROP FUNCTION IF EXISTS rpc_get_biopay_wallet CASCADE;
--   DROP FUNCTION IF EXISTS rpc_update_biopay_handle CASCADE;
--   DROP FUNCTION IF EXISTS fn_biopay_generate_qr CASCADE;
--   DROP FUNCTION IF EXISTS fn_biopay_resolve_qr_payload CASCADE;
--   DROP FUNCTION IF EXISTS fn_biopay_scan_and_charge CASCADE;
--   DROP FUNCTION IF EXISTS rpc_admin_list_users CASCADE;
--   DROP FUNCTION IF EXISTS rpc_admin_list_trips CASCADE;
--   DROP FUNCTION IF EXISTS rpc_admin_update_user_role CASCADE;
-- ============================================================================

-- ===========================================================================
-- PART 1: SCHEMA FIXES
-- ===========================================================================

-- 1a. Fix member_id to be numeric-safe (6-digit number instead of hex)
-- Drop the generated column and replace with a real numeric one
ALTER TABLE profiles DROP COLUMN IF EXISTS member_id;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS member_id text;

-- Generate numeric member IDs for existing rows
UPDATE profiles
SET member_id = LPAD(
  (abs(('x' || substring(id::text from 1 for 8))::bit(32)::integer) % 900000 + 100000)::text,
  6, '0'
)
WHERE member_id IS NULL;

-- Add default for new rows (trigger will set it)
CREATE OR REPLACE FUNCTION generate_numeric_member_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.member_id IS NULL THEN
    NEW.member_id := LPAD(
      (abs(('x' || substring(NEW.id::text from 1 for 8))::bit(32)::integer) % 900000 + 100000)::text,
      6, '0'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_member_id ON profiles;
CREATE TRIGGER set_member_id
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION generate_numeric_member_id();

-- 1b. Add missing profile columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_known_lat double precision;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_known_lng double precision;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS biopay_handle_type text DEFAULT 'phone';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS biopay_handle_value text DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS face_registered_at timestamptz;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name text;

-- Backfill display_name from name
UPDATE profiles SET display_name = name WHERE display_name IS NULL AND name != '';

-- 1c. Add missing trip columns
ALTER TABLE trips ADD COLUMN IF NOT EXISTS expires_at timestamptz;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS starts_at timestamptz;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS origin_place_id text;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_place_id text;

-- Index on new columns
CREATE INDEX IF NOT EXISTS idx_trips_expires_at ON trips(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trips_starts_at ON trips(starts_at) WHERE starts_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen_at DESC) WHERE last_seen_at IS NOT NULL;


-- ===========================================================================
-- PART 2: CORE RPCs (Discover + Nearby + Driver Status)
-- ===========================================================================

-- 2a. Discover summary for passenger home screen
CREATE OR REPLACE FUNCTION rpc_get_discover_summary(
  p_user_lat double precision DEFAULT NULL,
  p_user_lng double precision DEFAULT NULL,
  p_vehicle_type text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
  nearby_count integer;
  scheduled_count integer;
BEGIN
  -- Count nearby online drivers
  IF p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
    SELECT count(*) INTO nearby_count
    FROM public.driver_locations dl
    WHERE dl.is_online = true
      AND (p_vehicle_type IS NULL OR dl.vehicle_type_id = p_vehicle_type)
      AND (6371 * acos(
        cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
        cos(radians(dl.longitude) - radians(p_user_lng)) +
        sin(radians(p_user_lat)) * sin(radians(dl.latitude))
      )) <= 10;
  ELSE
    SELECT count(*) INTO nearby_count
    FROM public.driver_locations dl
    WHERE dl.is_online = true
      AND (p_vehicle_type IS NULL OR dl.vehicle_type_id = p_vehicle_type);
  END IF;

  -- Count active scheduled trips
  SELECT count(*) INTO scheduled_count
  FROM public.trips t
  WHERE t.is_active = true
    AND t.status = 'active'
    AND (p_vehicle_type IS NULL OR t.vehicle_type = p_vehicle_type);

  SELECT json_build_object(
    'nearby_driver_count', nearby_count,
    'scheduled_trip_count', scheduled_count
  ) INTO result;

  RETURN result;
END;
$$;


-- 2b. Search nearby drivers (with text search)
CREATE OR REPLACE FUNCTION rpc_search_nearby_drivers(
  p_user_lat double precision,
  p_user_lng double precision,
  p_search_text text DEFAULT NULL,
  p_vehicle_type text DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  driver_id uuid,
  display_name text,
  vehicle_type_id text,
  plate_number text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  whatsapp text,
  member_id text
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dl.driver_id,
    COALESCE(p.display_name, p.name) AS display_name,
    dl.vehicle_type_id,
    v.plate_number,
    dl.latitude,
    dl.longitude,
    (6371 * acos(
      cos(radians(p_user_lat)) * cos(radians(dl.latitude)) *
      cos(radians(dl.longitude) - radians(p_user_lng)) +
      sin(radians(p_user_lat)) * sin(radians(dl.latitude))
    )) AS distance_km,
    p.whatsapp,
    p.member_id
  FROM public.driver_locations dl
  JOIN public.profiles p ON p.id = dl.driver_id
  LEFT JOIN public.vehicles v ON v.owner_id = dl.driver_id AND v.is_active = true
  WHERE dl.is_online = true
    AND (p_vehicle_type IS NULL OR dl.vehicle_type_id = p_vehicle_type)
    AND (p_search_text IS NULL OR
         p.name ILIKE '%' || p_search_text || '%' OR
         COALESCE(p.display_name, '') ILIKE '%' || p_search_text || '%' OR
         COALESCE(v.plate_number, '') ILIKE '%' || p_search_text || '%')
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$;


-- 2c. Set driver online/offline status
CREATE OR REPLACE FUNCTION rpc_set_driver_online_status(p_is_online boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles
  SET is_online = p_is_online,
      last_seen_at = now()
  WHERE id = auth.uid();

  -- Also update driver_locations if exists
  UPDATE public.driver_locations
  SET is_online = p_is_online,
      updated_at = now()
  WHERE driver_id = auth.uid();
END;
$$;


-- ===========================================================================
-- PART 3: TRIP RPCs
-- ===========================================================================

-- 3a. List scheduled trips (mine or nearby)
CREATE OR REPLACE FUNCTION rpc_list_scheduled_trips(
  p_scope text DEFAULT 'mine',  -- 'mine' or 'nearby'
  p_mode text DEFAULT NULL,     -- 'passenger' or 'driver'
  p_vehicle_type text DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  departure_time text,
  role text,
  vehicle_type text,
  status text,
  is_recurring boolean,
  recurring_days integer[],
  note text,
  whatsapp text,
  expires_at timestamptz,
  starts_at timestamptz,
  created_at timestamptz,
  member_id text,
  distance_label text
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    t.author_id,
    t.author_name,
    t.origin,
    t.destination,
    t.departure_date,
    t.departure_time,
    t.role,
    t.vehicle_type,
    t.status,
    t.is_recurring,
    t.recurring_days,
    t.note,
    t.whatsapp,
    t.expires_at,
    t.starts_at,
    t.created_at,
    p.member_id,
    COALESCE(t.price, '') AS distance_label
  FROM public.trips t
  JOIN public.profiles p ON p.id = t.author_id
  WHERE t.is_active = true
    AND t.status = 'active'
    AND (
      (p_scope = 'mine' AND t.author_id = auth.uid()) OR
      (p_scope = 'nearby' AND t.author_id != auth.uid())
    )
    AND (p_mode IS NULL OR t.role = p_mode)
    AND (p_vehicle_type IS NULL OR t.vehicle_type = p_vehicle_type)
  ORDER BY t.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


-- 3b. Get trip details
CREATE OR REPLACE FUNCTION rpc_get_trip_details(p_trip_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'id', t.id,
    'author_id', t.author_id,
    'author_name', t.author_name,
    'origin', t.origin,
    'origin_lat', t.origin_lat,
    'origin_lng', t.origin_lng,
    'destination', t.destination,
    'dest_lat', t.dest_lat,
    'dest_lng', t.dest_lng,
    'departure_date', t.departure_date,
    'departure_time', t.departure_time,
    'role', t.role,
    'vehicle_type', t.vehicle_type,
    'status', t.status,
    'seats', t.seats,
    'price', t.price,
    'note', t.note,
    'whatsapp', t.whatsapp,
    'is_recurring', t.is_recurring,
    'recurring_days', t.recurring_days,
    'expires_at', t.expires_at,
    'starts_at', t.starts_at,
    'cancelled_at', t.cancelled_at,
    'created_at', t.created_at,
    'member_id', p.member_id,
    'author_display_name', COALESCE(p.display_name, p.name)
  )
  FROM public.trips t
  JOIN public.profiles p ON p.id = t.author_id
  WHERE t.id = p_trip_id
  INTO result;

  RETURN result;
END;
$$;


-- 3c. Create trip
CREATE OR REPLACE FUNCTION rpc_create_trip(p_payload json)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  new_id uuid;
  user_name text;
  user_whatsapp text;
BEGIN
  -- Get author info
  SELECT COALESCE(display_name, name), whatsapp
  INTO user_name, user_whatsapp
  FROM public.profiles
  WHERE id = auth.uid();

  INSERT INTO public.trips (
    author_id, author_name, origin, destination,
    origin_lat, origin_lng, dest_lat, dest_lng,
    departure_date, departure_time, role,
    vehicle_type, note, whatsapp, seats,
    is_recurring, recurring_days,
    expires_at, starts_at, origin_place_id, destination_place_id
  ) VALUES (
    auth.uid(),
    COALESCE(user_name, ''),
    COALESCE(p_payload->>'origin', ''),
    COALESCE(p_payload->>'destination', ''),
    (p_payload->>'origin_lat')::double precision,
    (p_payload->>'origin_lng')::double precision,
    (p_payload->>'dest_lat')::double precision,
    (p_payload->>'dest_lng')::double precision,
    COALESCE(p_payload->>'departure_date', ''),
    COALESCE(p_payload->>'departure_time', ''),
    COALESCE(p_payload->>'role', 'passenger'),
    COALESCE(p_payload->>'vehicle_type', 'cab'),
    p_payload->>'note',
    COALESCE(user_whatsapp, ''),
    COALESCE((p_payload->>'seats')::integer, 1),
    COALESCE((p_payload->>'is_recurring')::boolean, false),
    CASE
      WHEN p_payload->'recurring_days' IS NOT NULL
      THEN ARRAY(SELECT json_array_elements_text(p_payload->'recurring_days')::integer)
      ELSE '{}'::integer[]
    END,
    (p_payload->>'expires_at')::timestamptz,
    (p_payload->>'starts_at')::timestamptz,
    p_payload->>'origin_place_id',
    p_payload->>'destination_place_id'
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$;


-- 3d. Update trip (own trips only)
CREATE OR REPLACE FUNCTION rpc_update_trip(p_trip_id uuid, p_payload json)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.trips SET
    origin          = COALESCE(p_payload->>'origin', origin),
    destination     = COALESCE(p_payload->>'destination', destination),
    departure_date  = COALESCE(p_payload->>'departure_date', departure_date),
    departure_time  = COALESCE(p_payload->>'departure_time', departure_time),
    vehicle_type    = COALESCE(p_payload->>'vehicle_type', vehicle_type),
    note            = COALESCE(p_payload->>'note', note),
    seats           = COALESCE((p_payload->>'seats')::integer, seats),
    is_recurring    = COALESCE((p_payload->>'is_recurring')::boolean, is_recurring)
  WHERE id = p_trip_id
    AND author_id = auth.uid();  -- ownership check
END;
$$;


-- 3e. Cancel trip (own trips only)
CREATE OR REPLACE FUNCTION rpc_cancel_trip(p_trip_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.trips SET
    status = 'cancelled',
    is_active = false,
    cancelled_at = now()
  WHERE id = p_trip_id
    AND author_id = auth.uid();  -- ownership check
END;
$$;


-- ===========================================================================
-- PART 4: PROFILE RPCs
-- ===========================================================================

-- 4a. Update profile
CREATE OR REPLACE FUNCTION rpc_update_profile(p_payload json)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    name           = COALESCE(p_payload->>'name', name),
    display_name   = COALESCE(p_payload->>'display_name', display_name),
    phone          = COALESCE(p_payload->>'phone', phone),
    whatsapp       = COALESCE(p_payload->>'whatsapp', whatsapp),
    country_code   = COALESCE(p_payload->>'country_code', country_code),
    vehicle_type   = COALESCE((p_payload->>'vehicle_type')::vehicle_type_enum, vehicle_type),
    avatar_url     = COALESCE(p_payload->>'avatar_url', avatar_url),
    biopay_handle_type  = COALESCE(p_payload->>'biopay_handle_type', biopay_handle_type),
    biopay_handle_value = COALESCE(p_payload->>'biopay_handle_value', biopay_handle_value)
  WHERE id = auth.uid();
END;
$$;


-- 4b. Enable driver mode
CREATE OR REPLACE FUNCTION rpc_enable_driver_mode(p_vehicle_type text DEFAULT 'cab')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    is_driver = true,
    vehicle_type = p_vehicle_type::vehicle_type_enum,
    role = 'driver'
  WHERE id = auth.uid();
END;
$$;


-- 4c. Disable driver mode
CREATE OR REPLACE FUNCTION rpc_disable_driver_mode()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    is_driver = false,
    is_online = false,
    role = 'passenger'
  WHERE id = auth.uid();

  -- Also go offline in location table
  UPDATE public.driver_locations SET
    is_online = false
  WHERE driver_id = auth.uid();
END;
$$;


-- ===========================================================================
-- PART 5: BIOPAY RPCs
-- ===========================================================================

-- 5a. Get user's BioPay wallet (auto-create if missing)
CREATE OR REPLACE FUNCTION rpc_get_biopay_wallet()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
  wallet_exists boolean;
BEGIN
  -- Check if wallet exists
  SELECT EXISTS(
    SELECT 1 FROM public.biopay_wallets WHERE user_id = auth.uid()
  ) INTO wallet_exists;

  -- Auto-create wallet if not exists
  IF NOT wallet_exists THEN
    INSERT INTO public.biopay_wallets (user_id, balance, currency)
    VALUES (auth.uid(), 0.00, 'RWF');
  END IF;

  SELECT json_build_object(
    'id', w.id,
    'user_id', w.user_id,
    'balance', w.balance,
    'currency', w.currency,
    'is_active', w.is_active,
    'member_id', p.member_id,
    'handle_type', p.biopay_handle_type,
    'handle_value', p.biopay_handle_value,
    'has_face_id', p.has_face_id
  )
  FROM public.biopay_wallets w
  JOIN public.profiles p ON p.id = w.user_id
  WHERE w.user_id = auth.uid()
  INTO result;

  RETURN result;
END;
$$;


-- 5b. Update BioPay handle (phone or code)
CREATE OR REPLACE FUNCTION rpc_update_biopay_handle(
  p_handle_type text,
  p_handle_value text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.profiles SET
    biopay_handle_type = p_handle_type,
    biopay_handle_value = p_handle_value
  WHERE id = auth.uid();
END;
$$;


-- 5c. Generate QR payment reference (server-signed)
CREATE OR REPLACE FUNCTION fn_biopay_generate_qr(
  p_amount numeric,
  p_currency text DEFAULT 'RWF',
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  wallet_id uuid;
  tx_id uuid;
  qr_ref text;
  result json;
BEGIN
  -- Get or create wallet
  SELECT id INTO wallet_id
  FROM public.biopay_wallets
  WHERE user_id = auth.uid();

  IF wallet_id IS NULL THEN
    INSERT INTO public.biopay_wallets (user_id, balance, currency)
    VALUES (auth.uid(), 0.00, p_currency)
    RETURNING id INTO wallet_id;
  END IF;

  -- Generate unique QR reference
  qr_ref := 'MOBI-' || encode(gen_random_bytes(8), 'hex');

  -- Create pending receive transaction
  INSERT INTO public.biopay_transactions (
    wallet_id, type, status, amount, currency, note, qr_code_ref
  ) VALUES (
    wallet_id, 'receive', 'pending', p_amount, p_currency, p_note, qr_ref
  ) RETURNING id INTO tx_id;

  SELECT json_build_object(
    'qr_reference', qr_ref,
    'transaction_id', tx_id,
    'amount', p_amount,
    'currency', p_currency,
    'receiver_id', auth.uid(),
    'receiver_member_id', (SELECT member_id FROM public.profiles WHERE id = auth.uid()),
    'expires_at', (now() + interval '30 minutes')
  ) INTO result;

  RETURN result;
END;
$$;


-- 5d. Resolve a QR reference (lookup for scanner)
CREATE OR REPLACE FUNCTION fn_biopay_resolve_qr_payload(p_qr_ref text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'transaction_id', t.id,
    'amount', t.amount,
    'currency', t.currency,
    'note', t.note,
    'status', t.status,
    'receiver_id', w.user_id,
    'receiver_name', COALESCE(p.display_name, p.name),
    'receiver_member_id', p.member_id,
    'created_at', t.created_at
  )
  FROM public.biopay_transactions t
  JOIN public.biopay_wallets w ON w.id = t.wallet_id
  JOIN public.profiles p ON p.id = w.user_id
  WHERE t.qr_code_ref = p_qr_ref
    AND t.status = 'pending'
  INTO result;

  RETURN result;
END;
$$;


-- 5e. Execute QR scan payment (payer calls this)
CREATE OR REPLACE FUNCTION fn_biopay_scan_and_charge(p_qr_ref text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  tx record;
  payer_wallet_id uuid;
  result json;
BEGIN
  -- Find the pending transaction
  SELECT t.*, w.user_id AS receiver_user_id
  INTO tx
  FROM public.biopay_transactions t
  JOIN public.biopay_wallets w ON w.id = t.wallet_id
  WHERE t.qr_code_ref = p_qr_ref
    AND t.status = 'pending';

  IF tx IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'QR code not found or already used');
  END IF;

  -- Prevent self-payment
  IF tx.receiver_user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot pay yourself');
  END IF;

  -- Get payer wallet
  SELECT id INTO payer_wallet_id
  FROM public.biopay_wallets
  WHERE user_id = auth.uid();

  IF payer_wallet_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'No wallet found');
  END IF;

  -- Check balance
  IF (SELECT balance FROM public.biopay_wallets WHERE id = payer_wallet_id) < tx.amount THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Execute transfer
  UPDATE public.biopay_wallets SET balance = balance - tx.amount WHERE id = payer_wallet_id;
  UPDATE public.biopay_wallets SET balance = balance + tx.amount WHERE id = tx.wallet_id;

  -- Mark transaction as completed
  UPDATE public.biopay_transactions SET status = 'completed' WHERE id = tx.id;

  -- Create payer's send transaction
  INSERT INTO public.biopay_transactions (
    wallet_id, counterpart, type, status, amount, currency, note, qr_code_ref
  ) VALUES (
    payer_wallet_id, tx.wallet_id, 'send', 'completed', tx.amount, tx.currency, tx.note, p_qr_ref
  );

  SELECT json_build_object(
    'success', true,
    'transaction_id', tx.id,
    'amount', tx.amount,
    'currency', tx.currency
  ) INTO result;

  RETURN result;
END;
$$;


-- ===========================================================================
-- PART 6: ADMIN RPCs
-- ===========================================================================

-- 6a. List users (admin only — enforced in function)
CREATE OR REPLACE FUNCTION rpc_admin_list_users(
  p_role text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  name text,
  display_name text,
  phone text,
  role user_role_enum,
  is_driver boolean,
  vehicle_type vehicle_type_enum,
  member_id text,
  has_face_id boolean,
  is_online boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Admin check
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  RETURN QUERY
  SELECT
    p.id, p.name, p.display_name, p.phone, p.role,
    p.is_driver, p.vehicle_type, p.member_id,
    p.has_face_id, p.is_online, p.created_at
  FROM public.profiles p
  WHERE (p_role IS NULL OR p.role = p_role::user_role_enum)
    AND (p_search IS NULL OR
         p.name ILIKE '%' || p_search || '%' OR
         COALESCE(p.display_name, '') ILIKE '%' || p_search || '%' OR
         p.phone ILIKE '%' || p_search || '%' OR
         p.member_id ILIKE '%' || p_search || '%')
  ORDER BY p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


-- 6b. List trips (admin only)
CREATE OR REPLACE FUNCTION rpc_admin_list_trips(
  p_status text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  author_id uuid,
  author_name text,
  origin text,
  destination text,
  departure_date text,
  role text,
  vehicle_type text,
  status text,
  is_active boolean,
  created_at timestamptz,
  member_id text
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Admin check
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  RETURN QUERY
  SELECT
    t.id, t.author_id, t.author_name,
    t.origin, t.destination, t.departure_date,
    t.role, t.vehicle_type, t.status, t.is_active,
    t.created_at,
    p.member_id
  FROM public.trips t
  JOIN public.profiles p ON p.id = t.author_id
  WHERE (p_status IS NULL OR t.status = p_status)
    AND (p_role IS NULL OR t.role = p_role)
  ORDER BY t.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;


-- 6c. Admin update user role
CREATE OR REPLACE FUNCTION rpc_admin_update_user_role(
  p_user_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Admin check
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  UPDATE public.profiles SET
    role = p_role::user_role_enum,
    is_driver = (p_role = 'driver')
  WHERE id = p_user_id;

  -- Audit log
  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (auth.uid(), 'update_role', 'profile', p_user_id,
    json_build_object('new_role', p_role)::jsonb);
END;
$$;


-- ===========================================================================
-- PART 7: GRANTS
-- ===========================================================================

GRANT EXECUTE ON FUNCTION rpc_get_discover_summary TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_search_nearby_drivers TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_set_driver_online_status TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_list_scheduled_trips TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_trip_details TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_create_trip TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_update_trip TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_cancel_trip TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_update_profile TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_enable_driver_mode TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_disable_driver_mode TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_biopay_wallet TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_update_biopay_handle TO authenticated;
GRANT EXECUTE ON FUNCTION fn_biopay_generate_qr TO authenticated;
GRANT EXECUTE ON FUNCTION fn_biopay_resolve_qr_payload TO authenticated;
GRANT EXECUTE ON FUNCTION fn_biopay_scan_and_charge TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_list_users TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_list_trips TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_update_user_role TO authenticated;
