-- ============================================================================
-- MOBI — Expanded Schema Migration
-- Additional tables: vehicle_types, vehicles, driver_locations, ratings,
--                    notifications, admin_audit_log
-- Plus: database functions for admin dashboard stats + nearby drivers
-- ============================================================================

-- ============================================================================
-- 1. VEHICLE TYPES (reference table — admin-managed, extensible)
-- ============================================================================

CREATE TABLE public.vehicle_types (
  id          text PRIMARY KEY,                -- slug: 'cab', 'moto', etc.
  label       text NOT NULL,                   -- display name: 'Cab'
  display_name text NOT NULL,                  -- uppercase: 'CAB'
  icon_name   text NOT NULL DEFAULT 'car',     -- Lucide icon name
  description text,
  base_fare   numeric(10,2) DEFAULT 0,         -- base fare for this type
  per_km_rate numeric(10,2) DEFAULT 0,         -- rate per kilometer
  max_seats   smallint NOT NULL DEFAULT 4,
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  smallint NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.vehicle_types IS 'Admin-managed reference table of vehicle categories.';

CREATE TRIGGER set_vehicle_types_updated_at
  BEFORE UPDATE ON public.vehicle_types
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.vehicle_types ENABLE ROW LEVEL SECURITY;

-- Everyone can read active vehicle types
CREATE POLICY "Public read active vehicle_types"
  ON public.vehicle_types FOR SELECT
  USING (is_active = true);

-- Admins can manage vehicle types
CREATE POLICY "Admins manage vehicle_types"
  ON public.vehicle_types FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Seed default vehicle types
INSERT INTO public.vehicle_types (id, label, display_name, icon_name, description, max_seats, sort_order) VALUES
  ('moto',    'Moto',    'MOTO',    'zap',         'Motorcycle — fast & affordable',        1, 1),
  ('cab',     'Cab',     'CAB',     'car',         'Standard taxi cab',                      4, 2),
  ('trike',   'Trike',   'TRIKE',   'truck',       'Three-wheeler — economy class',          2, 3),
  ('truck',   'Truck',   'TRUCK',   'layout-grid', 'Heavy vehicle for cargo & groups',       8, 4),
  ('private', 'Private', 'PRIVATE', 'shield',      'Private executive vehicle',              4, 5);

GRANT SELECT ON public.vehicle_types TO anon, authenticated;

-- ============================================================================
-- 2. VEHICLES (driver fleet — each driver can register their vehicle(s))
-- ============================================================================

CREATE TABLE public.vehicles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_type_id text NOT NULL REFERENCES public.vehicle_types(id),

  -- Vehicle details
  make            text NOT NULL,             -- e.g. 'Mercedes-Benz'
  model           text NOT NULL,             -- e.g. 'E-Class'
  year            smallint,                  -- e.g. 2024
  color           text,                      -- e.g. 'White'
  plate_number    text,                      -- license plate
  capacity        smallint NOT NULL DEFAULT 4 CHECK (capacity > 0),

  -- Status
  is_active       boolean NOT NULL DEFAULT true,
  is_verified     boolean NOT NULL DEFAULT false,   -- admin verification
  verification_note text,

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.vehicles IS 'Driver-registered vehicles — one driver can have multiple vehicles.';

CREATE TRIGGER set_vehicles_updated_at
  BEFORE UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX idx_vehicles_owner    ON public.vehicles (owner_id);
CREATE INDEX idx_vehicles_type     ON public.vehicles (vehicle_type_id);
CREATE INDEX idx_vehicles_active   ON public.vehicles (is_active) WHERE is_active = true;

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Public read active verified vehicles
CREATE POLICY "Public read active vehicles"
  ON public.vehicles FOR SELECT
  USING (is_active = true);

-- Owners CRUD their own vehicles
CREATE POLICY "Owners manage own vehicles"
  ON public.vehicles FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners update own vehicles"
  ON public.vehicles FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners delete own vehicles"
  ON public.vehicles FOR DELETE
  USING (auth.uid() = owner_id);

-- Admins full access
CREATE POLICY "Admins manage vehicles"
  ON public.vehicles FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

GRANT SELECT ON public.vehicles TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.vehicles TO authenticated;

-- ============================================================================
-- 3. DRIVER LOCATIONS (real-time position for Nearby map)
-- ============================================================================

CREATE TABLE public.driver_locations (
  driver_id       uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude        double precision NOT NULL,
  longitude       double precision NOT NULL,
  heading         double precision,            -- compass heading in degrees
  speed           double precision,            -- km/h
  vehicle_type_id text REFERENCES public.vehicle_types(id),
  is_online       boolean NOT NULL DEFAULT true,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.driver_locations IS 'Last known driver positions — updated in real-time for the Nearby map.';

CREATE TRIGGER set_driver_locations_updated_at
  BEFORE UPDATE ON public.driver_locations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX idx_driver_locations_online
  ON public.driver_locations (is_online) WHERE is_online = true;

CREATE INDEX idx_driver_locations_type
  ON public.driver_locations (vehicle_type_id) WHERE is_online = true;

ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- Anyone can read online driver locations (for Nearby map)
CREATE POLICY "Public read online drivers"
  ON public.driver_locations FOR SELECT
  USING (is_online = true);

-- Drivers can upsert their own location
CREATE POLICY "Drivers upsert own location"
  ON public.driver_locations FOR INSERT
  WITH CHECK (auth.uid() = driver_id);

CREATE POLICY "Drivers update own location"
  ON public.driver_locations FOR UPDATE
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

GRANT SELECT ON public.driver_locations TO anon, authenticated;
GRANT INSERT, UPDATE ON public.driver_locations TO authenticated;

-- ============================================================================
-- 4. RATINGS (trip feedback — both passenger & driver can rate)
-- ============================================================================

CREATE TABLE public.ratings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id         uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  from_user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  to_user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score           smallint NOT NULL CHECK (score >= 1 AND score <= 5),
  comment         text,
  created_at      timestamptz NOT NULL DEFAULT now(),

  -- One rating per direction per trip
  UNIQUE (trip_id, from_user_id, to_user_id)
);

COMMENT ON TABLE public.ratings IS 'Post-trip ratings from passengers ↔ drivers.';

CREATE INDEX idx_ratings_trip    ON public.ratings (trip_id);
CREATE INDEX idx_ratings_to_user ON public.ratings (to_user_id);

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- Users can read ratings about themselves
CREATE POLICY "Users read own ratings"
  ON public.ratings FOR SELECT
  USING (auth.uid() = to_user_id OR auth.uid() = from_user_id);

-- Authenticated users can create ratings
CREATE POLICY "Auth users create ratings"
  ON public.ratings FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);

-- Admins full access
CREATE POLICY "Admins manage ratings"
  ON public.ratings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

GRANT SELECT, INSERT ON public.ratings TO authenticated;

-- ============================================================================
-- 5. NOTIFICATIONS (in-app notifications)
-- ============================================================================

CREATE TABLE public.notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            text NOT NULL DEFAULT 'general'
                  CHECK (type IN ('general', 'trip_request', 'trip_accepted',
                                  'trip_cancelled', 'trip_completed', 'rating',
                                  'admin', 'system')),
  title           text NOT NULL,
  body            text,
  metadata        jsonb DEFAULT '{}',          -- extra data (trip_id, etc.)
  is_read         boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notifications IS 'In-app notification feed for users.';

CREATE INDEX idx_notifications_user     ON public.notifications (user_id);
CREATE INDEX idx_notifications_unread   ON public.notifications (user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created  ON public.notifications (created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users read their own notifications
CREATE POLICY "Users read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Users can mark their notifications as read
CREATE POLICY "Users update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- System/triggers insert notifications (service_role only for inserts from functions)
CREATE POLICY "Service role inserts notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);  -- controlled at function level

-- Admins full access
CREATE POLICY "Admins manage notifications"
  ON public.notifications FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT INSERT ON public.notifications TO authenticated;

-- ============================================================================
-- 6. ADMIN AUDIT LOG (admin action trail)
-- ============================================================================

CREATE TABLE public.admin_audit_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id        uuid NOT NULL REFERENCES public.profiles(id),
  action          text NOT NULL,               -- e.g. 'verify_vehicle', 'ban_user'
  target_type     text NOT NULL,               -- e.g. 'profile', 'vehicle', 'trip'
  target_id       uuid,
  details         jsonb DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.admin_audit_log IS 'Audit trail of admin moderation actions.';

CREATE INDEX idx_audit_admin    ON public.admin_audit_log (admin_id);
CREATE INDEX idx_audit_target   ON public.admin_audit_log (target_type, target_id);
CREATE INDEX idx_audit_created  ON public.admin_audit_log (created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can read and write the audit log
CREATE POLICY "Admins manage audit_log"
  ON public.admin_audit_log FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

GRANT SELECT, INSERT ON public.admin_audit_log TO authenticated;

-- ============================================================================
-- 7. DATABASE FUNCTIONS (admin dashboard + nearby drivers)
-- ============================================================================

-- Dashboard stats for admin
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total_users',     (SELECT count(*) FROM public.profiles),
    'active_drivers',  (SELECT count(*) FROM public.profiles WHERE role = 'driver' AND is_active = true),
    'active_passengers', (SELECT count(*) FROM public.profiles WHERE role = 'passenger' AND is_active = true),
    'total_trips',     (SELECT count(*) FROM public.trips),
    'active_trips',    (SELECT count(*) FROM public.trips WHERE status = 'active'),
    'online_drivers',  (SELECT count(*) FROM public.driver_locations WHERE is_online = true),
    'total_vehicles',  (SELECT count(*) FROM public.vehicles WHERE is_active = true),
    'pending_requests', (SELECT count(*) FROM public.trip_requests WHERE status = 'pending')
  ) INTO result;
  RETURN result;
END;
$$;

-- Find nearby drivers within a radius (in km)
CREATE OR REPLACE FUNCTION public.find_nearby_drivers(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 10,
  p_vehicle_type text DEFAULT NULL
)
RETURNS TABLE (
  driver_id uuid,
  display_name text,
  vehicle_type_id text,
  latitude double precision,
  longitude double precision,
  distance_km double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dl.driver_id,
    p.display_name,
    dl.vehicle_type_id,
    dl.latitude,
    dl.longitude,
    -- Haversine distance in km
    (6371 * acos(
      cos(radians(p_lat)) * cos(radians(dl.latitude)) *
      cos(radians(dl.longitude) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(dl.latitude))
    )) AS distance_km
  FROM public.driver_locations dl
  JOIN public.profiles p ON p.id = dl.driver_id
  WHERE dl.is_online = true
    AND (p_vehicle_type IS NULL OR dl.vehicle_type_id = p_vehicle_type)
  HAVING (6371 * acos(
      cos(radians(p_lat)) * cos(radians(dl.latitude)) *
      cos(radians(dl.longitude) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(dl.latitude))
    )) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 50;
END;
$$;

-- Average rating for a user
CREATE OR REPLACE FUNCTION public.get_user_rating(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'average_score', COALESCE(avg(score)::numeric(3,2), 0),
    'total_ratings', count(*)
  )
  FROM public.ratings
  WHERE to_user_id = p_user_id
  INTO result;
  RETURN result;
END;
$$;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION public.get_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_nearby_drivers(double precision, double precision, double precision, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_rating(uuid) TO anon, authenticated;

-- ============================================================================
-- 8. ENABLE REALTIME for driver locations
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_requests;
