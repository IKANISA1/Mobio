-- Countries reference table
-- Replaces hardcoded country list in Flutter AppConstants
CREATE TABLE IF NOT EXISTS public.countries (
  id         TEXT PRIMARY KEY,            -- ISO 3166-1 alpha-2 (e.g. 'KE', 'RW')
  name       TEXT NOT NULL,               -- Display name
  flag       TEXT NOT NULL DEFAULT '',     -- Emoji flag
  dialing_code TEXT NOT NULL,             -- e.g. '+254'
  currency   TEXT NOT NULL DEFAULT 'RWF', -- ISO 4217 currency code
  phone_placeholder TEXT NOT NULL DEFAULT '780 000 000',
  is_active  BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed data is in 20260325030000_expand_countries_ussd.sql (28 markets)

-- RLS: public read, authenticated admin write
ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "countries_public_read" ON public.countries;
CREATE POLICY "countries_public_read"
  ON public.countries FOR SELECT
  USING (true);

-- Helper: get currency by dialing code
CREATE OR REPLACE FUNCTION public.get_currency_for_dialing_code(p_dialing_code TEXT)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT currency FROM public.countries
  WHERE dialing_code = p_dialing_code AND is_active = true
  LIMIT 1;
$$;
