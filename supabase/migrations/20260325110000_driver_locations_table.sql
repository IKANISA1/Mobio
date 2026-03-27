-- Migration: driver_locations schema
-- Fixes missing relation error in Nearby tab

CREATE TABLE IF NOT EXISTS public.driver_locations (
  driver_id uuid references public.profiles(id) on delete cascade primary key,
  latitude double precision not null,
  longitude double precision not null,
  heading double precision,
  speed double precision,
  vehicle_type_id uuid,
  is_online boolean default false,
  updated_at timestamp with time zone default now()
);

-- Enable RLS
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- Idempotent Policy Creation
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Drivers can update their own location" ON public.driver_locations;
  DROP POLICY IF EXISTS "Anyone can view online driver locations" ON public.driver_locations;
END $$;

CREATE POLICY "Drivers can update their own location"
  ON public.driver_locations FOR ALL
  USING (auth.uid() = driver_id);

CREATE POLICY "Anyone can view online driver locations"
  ON public.driver_locations FOR SELECT
  USING (is_online = true);

-- Enable realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'driver_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
  END IF;
END $$;
