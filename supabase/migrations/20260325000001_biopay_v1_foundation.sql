-- ============================================================================
-- MOBI BioPay v1: Replace insecure wallet schema with identity-first backend
-- ============================================================================
-- Ported from dinein_app's biopay_rw_foundation.sql with improvements:
--   1. 192-dim embeddings from start (no migration needed later)
--   2. Durable rate limiting table (not in-memory, survives cold starts)
--   3. Postgres functions for transactional re-enroll / delete
-- ============================================================================
-- Rollback:
--   DROP TABLE IF EXISTS biopay_rate_limits, biopay_abuse_reports,
--     biopay_enrollment_audit, biopay_match_audit,
--     biopay_face_embeddings, biopay_profiles CASCADE;
--   DROP FUNCTION IF EXISTS biopay_set_updated_at, generate_biopay_id,
--     match_biopay_embedding, find_duplicate_biopay_profile,
--     biopay_cleanup_rate_limits CASCADE;
--   -- To restore old schema, re-run migrations 20260324141000 + 20260324175000
-- ============================================================================

begin;

-- ===================================================================
-- PART 0: REMOVE INSECURE OLD SCHEMA
-- ===================================================================

-- Drop old wallet RPCs (these allowed client-side balance mutation)
DROP FUNCTION IF EXISTS rpc_get_biopay_wallet() CASCADE;
DROP FUNCTION IF EXISTS rpc_update_biopay_handle(text, text) CASCADE;
DROP FUNCTION IF EXISTS fn_biopay_generate_qr(numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS fn_biopay_resolve_qr_payload(text) CASCADE;
DROP FUNCTION IF EXISTS fn_biopay_scan_and_charge(text) CASCADE;

-- Drop insecure tables (client could mutate wallet balance + forge transactions)
DROP TABLE IF EXISTS biopay_transactions CASCADE;
DROP TABLE IF EXISTS biopay_wallets CASCADE;
DROP TABLE IF EXISTS face_templates CASCADE;

-- Drop insecure enum types
DROP TYPE IF EXISTS biopay_tx_type_enum CASCADE;
DROP TYPE IF EXISTS biopay_tx_status_enum CASCADE;

-- Remove BioPay-specific columns from profiles (state now in biopay_profiles)
ALTER TABLE profiles DROP COLUMN IF EXISTS has_face_id;
ALTER TABLE profiles DROP COLUMN IF EXISTS face_registered_at;
ALTER TABLE profiles DROP COLUMN IF EXISTS biopay_handle_type;
ALTER TABLE profiles DROP COLUMN IF EXISTS biopay_handle_value;

-- ===================================================================
-- PART 1: EXTENSIONS
-- ===================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ===================================================================
-- PART 2: UTILITY FUNCTION
-- ===================================================================

CREATE OR REPLACE FUNCTION public.biopay_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

-- ===================================================================
-- PART 3: BIOPAY PROFILES
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.biopay_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  biopay_id text NOT NULL UNIQUE
    CHECK (biopay_id ~ '^[0-9]{6}$'),
  display_name text NOT NULL
    CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 80),
  ussd_string text NOT NULL,
  ussd_normalized text NOT NULL,
  recipient_phone_e164 text
    CHECK (
      recipient_phone_e164 IS NULL
      OR recipient_phone_e164 ~ '^\+2507[0-9]{8}$'
    ),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('pending', 'active', 'suspended', 'deleted')),
  consent_version integer NOT NULL
    CHECK (consent_version > 0),
  consent_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  owner_token_version integer NOT NULL DEFAULT 1
    CHECK (owner_token_version > 0),
  management_code_hash text NOT NULL,
  management_code_hint text
    CHECK (
      management_code_hint IS NULL
      OR management_code_hint ~ '^[0-9]{2}$'
    ),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.biopay_profiles IS
  'MOBI BioPay payee registry. Backend-owned, not client-accessible.';

DROP TRIGGER IF EXISTS set_biopay_profiles_updated_at
  ON public.biopay_profiles;
CREATE TRIGGER set_biopay_profiles_updated_at
BEFORE UPDATE ON public.biopay_profiles
FOR EACH ROW
EXECUTE FUNCTION public.biopay_set_updated_at();

CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_profiles_ussd_normalized_active
  ON public.biopay_profiles (ussd_normalized)
  WHERE status IN ('pending', 'active', 'suspended');

CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_profiles_phone_active
  ON public.biopay_profiles (recipient_phone_e164)
  WHERE recipient_phone_e164 IS NOT NULL
    AND status IN ('pending', 'active', 'suspended');

CREATE INDEX IF NOT EXISTS idx_biopay_profiles_status_created_at
  ON public.biopay_profiles (status, created_at DESC);

-- ===================================================================
-- PART 4: FACE EMBEDDINGS (192-dim from start)
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.biopay_face_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL
    REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  embedding vector(192) NOT NULL,
  model_version text NOT NULL,
  quality_score double precision
    CHECK (
      quality_score IS NULL
      OR (quality_score >= 0 AND quality_score <= 1)
    ),
  source text NOT NULL DEFAULT 'enrollment'
    CHECK (source IN ('enrollment', 're_enrollment')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.biopay_face_embeddings IS
  'MOBI BioPay face embeddings (192-dim). Raw face images must never be persisted.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_face_embeddings_profile_active
  ON public.biopay_face_embeddings (profile_id)
  WHERE is_active;

CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_profile_created_at
  ON public.biopay_face_embeddings (profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_model_version
  ON public.biopay_face_embeddings (model_version);

CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_embedding_cosine
  ON public.biopay_face_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 64);

-- ===================================================================
-- PART 5: AUDIT TABLES
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.biopay_match_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  matched_profile_id uuid
    REFERENCES public.biopay_profiles(id) ON DELETE SET NULL,
  similarity double precision,
  result text NOT NULL
    CHECK (result IN ('matched', 'no_match', 'rate_limited', 'rejected', 'error')),
  client_install_id text,
  ip_hash text,
  device_label text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_match_audit_created_at
  ON public.biopay_match_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_match_audit_profile_created_at
  ON public.biopay_match_audit (matched_profile_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.biopay_enrollment_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid
    REFERENCES public.biopay_profiles(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  client_install_id text,
  ip_hash text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_enrollment_audit_created_at
  ON public.biopay_enrollment_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_enrollment_audit_profile_created_at
  ON public.biopay_enrollment_audit (profile_id, created_at DESC);

-- ===================================================================
-- PART 6: ABUSE REPORTS
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.biopay_abuse_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL
    REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  notes text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'dismissed')),
  client_install_id text,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

DROP TRIGGER IF EXISTS set_biopay_abuse_reports_updated_at
  ON public.biopay_abuse_reports;
CREATE TRIGGER set_biopay_abuse_reports_updated_at
BEFORE UPDATE ON public.biopay_abuse_reports
FOR EACH ROW
EXECUTE FUNCTION public.biopay_set_updated_at();

CREATE INDEX IF NOT EXISTS idx_biopay_abuse_reports_profile_status
  ON public.biopay_abuse_reports (profile_id, status, created_at DESC);

-- ===================================================================
-- PART 7: DURABLE RATE LIMITING TABLE (improvement over dinein_app)
-- ===================================================================

CREATE TABLE IF NOT EXISTS public.biopay_rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint_hash text NOT NULL,
  action text NOT NULL DEFAULT 'match',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_rate_limits_fingerprint_action
  ON public.biopay_rate_limits (fingerprint_hash, action, created_at DESC);

-- Cleanup function for expired rate limit entries (call periodically)
CREATE OR REPLACE FUNCTION public.biopay_cleanup_rate_limits(
  p_window_minutes integer DEFAULT 5
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM public.biopay_rate_limits
  WHERE created_at < timezone('utc', now()) - (p_window_minutes || ' minutes')::interval;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- ===================================================================
-- PART 8: RLS + ACCESS CONTROL (service_role only)
-- ===================================================================

ALTER TABLE public.biopay_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_match_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_enrollment_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_abuse_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_rate_limits ENABLE ROW LEVEL SECURITY;

-- REVOKE all access from anon and authenticated users
REVOKE ALL ON public.biopay_profiles FROM anon, authenticated;
REVOKE ALL ON public.biopay_face_embeddings FROM anon, authenticated;
REVOKE ALL ON public.biopay_match_audit FROM anon, authenticated;
REVOKE ALL ON public.biopay_enrollment_audit FROM anon, authenticated;
REVOKE ALL ON public.biopay_abuse_reports FROM anon, authenticated;
REVOKE ALL ON public.biopay_rate_limits FROM anon, authenticated;

-- GRANT full access to service_role (used by edge function)
GRANT ALL ON public.biopay_profiles TO service_role;
GRANT ALL ON public.biopay_face_embeddings TO service_role;
GRANT ALL ON public.biopay_match_audit TO service_role;
GRANT ALL ON public.biopay_enrollment_audit TO service_role;
GRANT ALL ON public.biopay_abuse_reports TO service_role;
GRANT ALL ON public.biopay_rate_limits TO service_role;

-- ===================================================================
-- PART 9: SERVER-SIDE FUNCTIONS (service_role only)
-- ===================================================================

-- Generate unique 6-digit BioPay ID
CREATE OR REPLACE FUNCTION public.generate_biopay_id()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  candidate text;
BEGIN
  LOOP
    candidate := lpad(((random() * 999999)::int)::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.biopay_profiles
      WHERE biopay_id = candidate
    );
  END LOOP;

  RETURN candidate;
END;
$$;

-- Match embedding against enrolled profiles
CREATE OR REPLACE FUNCTION public.match_biopay_embedding(
  query_embedding vector,
  limit_count integer DEFAULT 3
)
RETURNS TABLE (
  profile_id uuid,
  biopay_id text,
  display_name text,
  ussd_string text,
  similarity double precision,
  model_version text
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    profile.id AS profile_id,
    profile.biopay_id,
    profile.display_name,
    profile.ussd_string,
    1 - (embedding.embedding <=> query_embedding) AS similarity,
    embedding.model_version
  FROM public.biopay_face_embeddings embedding
  JOIN public.biopay_profiles profile
    ON profile.id = embedding.profile_id
  WHERE embedding.is_active = true
    AND profile.status = 'active'
  ORDER BY embedding.embedding <=> query_embedding ASC
  LIMIT greatest(1, least(coalesce(limit_count, 3), 10));
$$;

-- Find duplicate face during enrollment
CREATE OR REPLACE FUNCTION public.find_duplicate_biopay_profile(
  query_embedding vector,
  similarity_threshold double precision DEFAULT 0.90
)
RETURNS TABLE (
  profile_id uuid,
  biopay_id text,
  display_name text,
  similarity double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    profile.id AS profile_id,
    profile.biopay_id,
    profile.display_name,
    1 - (embedding.embedding <=> query_embedding) AS similarity
  FROM public.biopay_face_embeddings embedding
  JOIN public.biopay_profiles profile
    ON profile.id = embedding.profile_id
  WHERE embedding.is_active = true
    AND profile.status IN ('pending', 'active', 'suspended')
    AND 1 - (embedding.embedding <=> query_embedding) >= similarity_threshold
  ORDER BY embedding.embedding <=> query_embedding ASC
  LIMIT 1;
$$;

-- Durable rate limit check (improvement: works across cold starts)
CREATE OR REPLACE FUNCTION public.biopay_check_rate_limit(
  p_fingerprint_hash text,
  p_action text DEFAULT 'match',
  p_window_minutes integer DEFAULT 5,
  p_max_requests integer DEFAULT 20
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  request_count integer;
BEGIN
  -- Count recent requests
  SELECT count(*) INTO request_count
  FROM public.biopay_rate_limits
  WHERE fingerprint_hash = p_fingerprint_hash
    AND action = p_action
    AND created_at > timezone('utc', now()) - (p_window_minutes || ' minutes')::interval;

  IF request_count >= p_max_requests THEN
    RETURN false;  -- Rate limited
  END IF;

  -- Record this request
  INSERT INTO public.biopay_rate_limits (fingerprint_hash, action)
  VALUES (p_fingerprint_hash, p_action);

  RETURN true;  -- Allowed
END;
$$;

-- Revoke function access from public
REVOKE ALL ON FUNCTION public.biopay_set_updated_at() FROM public;
REVOKE ALL ON FUNCTION public.generate_biopay_id() FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.match_biopay_embedding(vector, integer) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.find_duplicate_biopay_profile(vector, double precision) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.biopay_check_rate_limit(text, text, integer, integer) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.biopay_cleanup_rate_limits(integer) FROM public, anon, authenticated;

-- Grant to service_role only
GRANT EXECUTE ON FUNCTION public.generate_biopay_id() TO service_role;
GRANT EXECUTE ON FUNCTION public.match_biopay_embedding(vector, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.find_duplicate_biopay_profile(vector, double precision) TO service_role;
GRANT EXECUTE ON FUNCTION public.biopay_check_rate_limit(text, text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.biopay_cleanup_rate_limits(integer) TO service_role;

commit;
