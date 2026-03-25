-- ============================================================================
-- MOBI — Full Schema Migration
-- Tables: profiles, trips
-- Functions: handle_new_user(), set_updated_at()
-- RLS policies for all tables
-- ============================================================================

-- ============================================================================
-- 1. CUSTOM TYPES
-- ============================================================================

CREATE TYPE public.user_role AS ENUM ('passenger', 'driver', 'admin');
CREATE TYPE public.vehicle_type AS ENUM ('cab', 'moto', 'trike', 'truck', 'private');
CREATE TYPE public.trip_status AS ENUM ('active', 'cancelled', 'completed');

-- ============================================================================
-- 2. UTILITY FUNCTIONS
-- ============================================================================

-- Auto-update `updated_at` on any row change
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Auto-create a profile row when a new auth user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.phone, ''),
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', '')
  );
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 3. PROFILES TABLE
-- ============================================================================

CREATE TABLE public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone       text NOT NULL DEFAULT '',
  display_name text NOT NULL DEFAULT '',
  role        public.user_role NOT NULL DEFAULT 'passenger',
  avatar_url  text,
  vehicle     text,               -- vehicle description for drivers
  category    text,               -- e.g. 'Premium', 'Executive', 'Standard'
  location    text,               -- default pick-up area label
  whatsapp    text DEFAULT '',     -- WhatsApp number
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.profiles IS 'User profile extending auth.users — one row per sign-up.';
COMMENT ON COLUMN public.profiles.role IS 'passenger | driver | admin';

-- updated_at trigger
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Auth trigger: auto-create profile on sign-up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Indexes
CREATE INDEX idx_profiles_role     ON public.profiles (role);
CREATE INDEX idx_profiles_phone    ON public.profiles (phone);
CREATE INDEX idx_profiles_is_active ON public.profiles (is_active);

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read active profiles (needed for driver discovery)
CREATE POLICY "Public read active profiles"
  ON public.profiles
  FOR SELECT
  USING (is_active = true);

-- Users can read their own profile (even if inactive)
CREATE POLICY "Users read own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can do everything
CREATE POLICY "Admins full access to profiles"
  ON public.profiles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================================================
-- 4. TRIPS TABLE
-- ============================================================================

CREATE TABLE public.trips (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- Locations
  origin          text NOT NULL,
  origin_lat      double precision,
  origin_lng      double precision,
  destination     text NOT NULL,
  dest_lat        double precision,
  dest_lng        double precision,

  -- Schedule
  departure_date  date NOT NULL,
  departure_time  text NOT NULL,    -- e.g. '08:30' or '14:30'

  -- Trip config
  role            text NOT NULL DEFAULT 'passenger'
                  CHECK (role IN ('passenger', 'driver')),
  vehicle_type    public.vehicle_type NOT NULL DEFAULT 'cab',
  seats           smallint NOT NULL DEFAULT 1 CHECK (seats > 0 AND seats <= 50),
  note            text,

  -- Recurrence
  is_recurring    boolean NOT NULL DEFAULT false,
  recurring_days  smallint[] NOT NULL DEFAULT '{}',

  -- Status
  status          public.trip_status NOT NULL DEFAULT 'active',

  -- Timestamps
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.trips IS 'Ride-sharing trips — passengers seeking rides or drivers offering seats.';
COMMENT ON COLUMN public.trips.role IS 'passenger = seeking ride, driver = offering ride';
COMMENT ON COLUMN public.trips.recurring_days IS '0=Mon..6=Sun — which days this trip repeats';

-- updated_at trigger
CREATE TRIGGER set_trips_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Indexes
CREATE INDEX idx_trips_author_id      ON public.trips (author_id);
CREATE INDEX idx_trips_status         ON public.trips (status);
CREATE INDEX idx_trips_departure      ON public.trips (departure_date, departure_time);
CREATE INDEX idx_trips_role_status    ON public.trips (role, status);
CREATE INDEX idx_trips_vehicle_type   ON public.trips (vehicle_type);
CREATE INDEX idx_trips_origin_coords  ON public.trips (origin_lat, origin_lng) WHERE origin_lat IS NOT NULL;
CREATE INDEX idx_trips_dest_coords    ON public.trips (dest_lat, dest_lng) WHERE dest_lat IS NOT NULL;

-- RLS
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

-- Anyone can read active trips (needed for discovery/nearby)
CREATE POLICY "Public read active trips"
  ON public.trips
  FOR SELECT
  USING (status = 'active');

-- Authors can read all their own trips (incl cancelled/completed)
CREATE POLICY "Authors read own trips"
  ON public.trips
  FOR SELECT
  USING (auth.uid() = author_id);

-- Authenticated users can create trips
CREATE POLICY "Auth users create trips"
  ON public.trips
  FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Authors can update their own trips only
CREATE POLICY "Authors update own trips"
  ON public.trips
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Authors can delete their own trips
CREATE POLICY "Authors delete own trips"
  ON public.trips
  FOR DELETE
  USING (auth.uid() = author_id);

-- Admins can do everything
CREATE POLICY "Admins full access to trips"
  ON public.trips
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================================================
-- 5. SAVED PLACES TABLE (for user favorite/recent locations)
-- ============================================================================

CREATE TABLE public.saved_places (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label           text NOT NULL,                    -- e.g. 'Home', 'Work', 'Airport'
  place_id        text,                             -- Google Places ID (optional)
  formatted_address text NOT NULL,
  latitude        double precision NOT NULL,
  longitude       double precision NOT NULL,
  is_favorite     boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.saved_places IS 'User-saved locations (favorites, recent, home, work).';

CREATE TRIGGER set_saved_places_updated_at
  BEFORE UPDATE ON public.saved_places
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX idx_saved_places_user    ON public.saved_places (user_id);
CREATE INDEX idx_saved_places_fav     ON public.saved_places (user_id, is_favorite) WHERE is_favorite = true;

ALTER TABLE public.saved_places ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own places"
  ON public.saved_places FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users create own places"
  ON public.saved_places FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own places"
  ON public.saved_places FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own places"
  ON public.saved_places FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 6. TRIP REQUESTS TABLE (passenger → driver matching)
-- ============================================================================

CREATE TABLE public.trip_requests (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id         uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  requester_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  message         text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  -- Prevent duplicate requests
  UNIQUE (trip_id, requester_id)
);

COMMENT ON TABLE public.trip_requests IS 'Join requests from passengers to driver trips (or vice versa).';

CREATE TRIGGER set_trip_requests_updated_at
  BEFORE UPDATE ON public.trip_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX idx_trip_requests_trip      ON public.trip_requests (trip_id);
CREATE INDEX idx_trip_requests_requester ON public.trip_requests (requester_id);
CREATE INDEX idx_trip_requests_status    ON public.trip_requests (status);

ALTER TABLE public.trip_requests ENABLE ROW LEVEL SECURITY;

-- Requesters can read their own requests
CREATE POLICY "Requesters read own requests"
  ON public.trip_requests FOR SELECT
  USING (auth.uid() = requester_id);

-- Trip authors can read requests to their trips
CREATE POLICY "Authors read trip requests"
  ON public.trip_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.id = trip_id AND t.author_id = auth.uid()
    )
  );

-- Authenticated users can create requests
CREATE POLICY "Auth users create requests"
  ON public.trip_requests FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

-- Trip authors can update request status (accept/reject)
CREATE POLICY "Authors update request status"
  ON public.trip_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.id = trip_id AND t.author_id = auth.uid()
    )
  );

-- Requesters can cancel their own requests
CREATE POLICY "Requesters cancel own requests"
  ON public.trip_requests FOR UPDATE
  USING (auth.uid() = requester_id)
  WITH CHECK (auth.uid() = requester_id);

-- Admins full access
CREATE POLICY "Admins full access to trip_requests"
  ON public.trip_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================================================
-- 7. GRANT PUBLIC API ACCESS
-- ============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trips TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_places TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trip_requests TO authenticated;
GRANT UPDATE ON public.profiles TO authenticated;
