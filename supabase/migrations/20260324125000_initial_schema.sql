-- ============================================================================
-- MOBI: Initial Schema — Enums, Tables, Indexes
-- ============================================================================
-- Rollback: DROP TABLE IF EXISTS trips, profiles CASCADE;
--           DROP TYPE IF EXISTS vehicle_type_enum, user_role_enum, trip_status_enum;
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Clean up any partial schema from prior attempts
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TYPE IF EXISTS vehicle_type_enum CASCADE;
DROP TYPE IF EXISTS user_role_enum CASCADE;
DROP TYPE IF EXISTS trip_status_enum CASCADE;

-- ---------------------------------------------------------------------------
-- 1. Custom Enum Types
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE vehicle_type_enum AS ENUM ('moto', 'cab', 'trike', 'truck', 'private');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE user_role_enum AS ENUM ('passenger', 'driver', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE trip_status_enum AS ENUM ('active', 'cancelled', 'completed', 'pending', 'approved', 'suspended', 'blocked');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Profiles Table (extends auth.users)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text NOT NULL DEFAULT '',
  phone         text NOT NULL DEFAULT '',
  role          user_role_enum NOT NULL DEFAULT 'passenger',
  location      text,
  vehicle       text,
  category      text,
  is_driver     boolean NOT NULL DEFAULT false,
  vehicle_type  vehicle_type_enum NOT NULL DEFAULT 'cab',
  whatsapp      text DEFAULT '',
  country_code  text DEFAULT '+250',
  avatar_url    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE profiles IS 'User profiles extending auth.users with MOBI-specific fields.';

-- ---------------------------------------------------------------------------
-- 3. Trips Table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS trips (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  author_name     text NOT NULL DEFAULT '',

  -- Locations
  origin          text NOT NULL,
  origin_lat      double precision,
  origin_lng      double precision,
  destination     text NOT NULL,
  dest_lat        double precision,
  dest_lng        double precision,

  -- Scheduling
  departure_date  text NOT NULL DEFAULT '',
  departure_time  text NOT NULL DEFAULT '',
  date            text DEFAULT '',        -- Legacy compat
  time            text DEFAULT '',        -- Legacy compat

  -- Trip details
  role            text NOT NULL DEFAULT 'passenger' CHECK (role IN ('passenger', 'driver')),
  whatsapp        text DEFAULT '',
  seats           integer NOT NULL DEFAULT 1 CHECK (seats >= 0),
  price           text,
  note            text,
  description     text,

  -- Status
  is_active       boolean NOT NULL DEFAULT true,
  status          text NOT NULL DEFAULT 'active',
  vehicle_type    text NOT NULL DEFAULT 'cab',

  -- Recurring
  is_recurring    boolean NOT NULL DEFAULT false,
  recurring_days  integer[] NOT NULL DEFAULT '{}',

  -- Legacy
  joined_date     text,

  -- Timestamps
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE trips IS 'Trip listings (both passenger requests and driver offers).';

-- ---------------------------------------------------------------------------
-- 4. Indexes for Performance
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_trips_author_id     ON trips(author_id);
CREATE INDEX IF NOT EXISTS idx_trips_status        ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_departure     ON trips(departure_date, departure_time);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle_type  ON trips(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_trips_is_active     ON trips(is_active);
CREATE INDEX IF NOT EXISTS idx_profiles_role       ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone      ON profiles(phone);
