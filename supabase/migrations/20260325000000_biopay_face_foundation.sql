-- ============================================================================
-- MOBI: BioPay Face-Payment Foundation (pgvector)
-- ============================================================================
-- Ported from DineIn Malta's production BioPay schema.
-- Additive migration — existing biopay_wallets/biopay_transactions untouched.
--
-- Creates:
--   1. pgvector extension
--   2. biopay_profiles (face-payment payee registry)
--   3. biopay_face_embeddings (vector(192) for MobileFaceNet)
--   4. biopay_match_audit
--   5. biopay_enrollment_audit
--   6. biopay_abuse_reports
--   7. Functions: generate_biopay_id, match_biopay_embedding,
--      find_duplicate_biopay_profile
--
-- Rollback:
--   DROP TABLE IF EXISTS biopay_abuse_reports CASCADE;
--   DROP TABLE IF EXISTS biopay_enrollment_audit CASCADE;
--   DROP TABLE IF EXISTS biopay_match_audit CASCADE;
--   DROP TABLE IF EXISTS biopay_face_embeddings CASCADE;
--   DROP TABLE IF EXISTS biopay_profiles CASCADE;
--   DROP FUNCTION IF EXISTS biopay_set_updated_at CASCADE;
--   DROP FUNCTION IF EXISTS generate_biopay_id CASCADE;
--   DROP FUNCTION IF EXISTS match_biopay_embedding CASCADE;
--   DROP FUNCTION IF EXISTS find_duplicate_biopay_profile CASCADE;
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Enable pgvector extension
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;


-- ---------------------------------------------------------------------------
-- 1. Helper trigger function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.biopay_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;


-- ---------------------------------------------------------------------------
-- 2. BioPay Profiles (face-payment payee registry)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.biopay_profiles (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  biopay_id             text NOT NULL UNIQUE
                          CHECK (biopay_id ~ '^[0-9]{6}$'),
  display_name          text NOT NULL
                          CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 80),
  ussd_string           text NOT NULL,
  ussd_normalized       text NOT NULL,
  recipient_phone_e164  text
                          CHECK (
                            recipient_phone_e164 IS NULL
                            OR recipient_phone_e164 ~ '^\+2507[0-9]{8}$'
                          ),
  status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('pending', 'active', 'suspended', 'deleted')),
  consent_version       integer NOT NULL DEFAULT 1
                          CHECK (consent_version > 0),
  consent_at            timestamptz NOT NULL DEFAULT timezone('utc', now()),
  owner_token_version   integer NOT NULL DEFAULT 1
                          CHECK (owner_token_version > 0),
  management_code_hash  text NOT NULL,
  management_code_hint  text
                          CHECK (
                            management_code_hint IS NULL
                            OR management_code_hint ~ '^[0-9]{2}$'
                          ),
  created_at            timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at            timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.biopay_profiles IS
  'MOBI BioPay face-payment payee registry. Rwanda MoMo USSD-based payments.';

COMMENT ON COLUMN public.biopay_profiles.ussd_normalized IS
  'Canonical Rwanda MTN MoMo receive-money USSD string.';

COMMENT ON COLUMN public.biopay_profiles.owner_token_version IS
  'Rotated whenever BioPay ownership credentials are re-issued or invalidated.';

-- Auto-update timestamp trigger
DROP TRIGGER IF EXISTS set_biopay_profiles_updated_at ON public.biopay_profiles;
CREATE TRIGGER set_biopay_profiles_updated_at
  BEFORE UPDATE ON public.biopay_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.biopay_set_updated_at();

-- Unique constraints for active profiles
CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_profiles_ussd_normalized_active
  ON public.biopay_profiles (ussd_normalized)
  WHERE status IN ('pending', 'active', 'suspended');

CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_profiles_phone_active
  ON public.biopay_profiles (recipient_phone_e164)
  WHERE recipient_phone_e164 IS NOT NULL
    AND status IN ('pending', 'active', 'suspended');

CREATE INDEX IF NOT EXISTS idx_biopay_profiles_status_created_at
  ON public.biopay_profiles (status, created_at DESC);


-- ---------------------------------------------------------------------------
-- 3. Face Embeddings (vector(192) for MobileFaceNet float32)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.biopay_face_embeddings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id      uuid NOT NULL
                    REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  embedding       vector(192) NOT NULL,
  model_version   text NOT NULL,
  quality_score   double precision
                    CHECK (
                      quality_score IS NULL
                      OR (quality_score >= 0 AND quality_score <= 1)
                    ),
  source          text NOT NULL DEFAULT 'enrollment'
                    CHECK (source IN ('enrollment', 're_enrollment')),
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.biopay_face_embeddings IS
  'MOBI BioPay face embeddings (192-dim MobileFaceNet). Raw face images are never stored.';

-- Only one active embedding per profile
CREATE UNIQUE INDEX IF NOT EXISTS uq_biopay_face_embeddings_profile_active
  ON public.biopay_face_embeddings (profile_id)
  WHERE is_active;

CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_profile_created_at
  ON public.biopay_face_embeddings (profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_model_version
  ON public.biopay_face_embeddings (model_version);

-- IVFFlat cosine similarity index for fast matching
CREATE INDEX IF NOT EXISTS idx_biopay_face_embeddings_embedding_cosine
  ON public.biopay_face_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 64);


-- ---------------------------------------------------------------------------
-- 4. Match Audit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.biopay_match_audit (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  matched_profile_id  uuid
                        REFERENCES public.biopay_profiles(id) ON DELETE SET NULL,
  similarity          double precision,
  result              text NOT NULL
                        CHECK (result IN ('matched', 'no_match', 'rate_limited', 'rejected', 'error')),
  client_install_id   text,
  ip_hash             text,
  device_label        text,
  details             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_match_audit_created_at
  ON public.biopay_match_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_match_audit_profile_created_at
  ON public.biopay_match_audit (matched_profile_id, created_at DESC);


-- ---------------------------------------------------------------------------
-- 5. Enrollment Audit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.biopay_enrollment_audit (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id          uuid
                        REFERENCES public.biopay_profiles(id) ON DELETE SET NULL,
  event_type          text NOT NULL,
  client_install_id   text,
  ip_hash             text,
  details             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_biopay_enrollment_audit_created_at
  ON public.biopay_enrollment_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_biopay_enrollment_audit_profile_created_at
  ON public.biopay_enrollment_audit (profile_id, created_at DESC);


-- ---------------------------------------------------------------------------
-- 6. Abuse Reports
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.biopay_abuse_reports (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id          uuid NOT NULL
                        REFERENCES public.biopay_profiles(id) ON DELETE CASCADE,
  reason              text NOT NULL,
  notes               text,
  status              text NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open', 'resolved', 'dismissed')),
  client_install_id   text,
  resolved_at         timestamptz,
  resolution_notes    text,
  created_at          timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at          timestamptz NOT NULL DEFAULT timezone('utc', now())
);

DROP TRIGGER IF EXISTS set_biopay_abuse_reports_updated_at ON public.biopay_abuse_reports;
CREATE TRIGGER set_biopay_abuse_reports_updated_at
  BEFORE UPDATE ON public.biopay_abuse_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.biopay_set_updated_at();

CREATE INDEX IF NOT EXISTS idx_biopay_abuse_reports_profile_status
  ON public.biopay_abuse_reports (profile_id, status, created_at DESC);


-- ---------------------------------------------------------------------------
-- 7. RLS — all tables service_role only
-- ---------------------------------------------------------------------------
ALTER TABLE public.biopay_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_match_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_enrollment_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biopay_abuse_reports ENABLE ROW LEVEL SECURITY;

-- Revoke all from anon/authenticated — Edge Function uses service_role
REVOKE ALL ON public.biopay_profiles FROM anon, authenticated;
REVOKE ALL ON public.biopay_face_embeddings FROM anon, authenticated;
REVOKE ALL ON public.biopay_match_audit FROM anon, authenticated;
REVOKE ALL ON public.biopay_enrollment_audit FROM anon, authenticated;
REVOKE ALL ON public.biopay_abuse_reports FROM anon, authenticated;

GRANT ALL ON public.biopay_profiles TO service_role;
GRANT ALL ON public.biopay_face_embeddings TO service_role;
GRANT ALL ON public.biopay_match_audit TO service_role;
GRANT ALL ON public.biopay_enrollment_audit TO service_role;
GRANT ALL ON public.biopay_abuse_reports TO service_role;


-- ---------------------------------------------------------------------------
-- 8. Functions
-- ---------------------------------------------------------------------------

-- 8a. Generate unique 6-digit BioPay ID
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

-- 8b. Match a face embedding against active profiles (cosine similarity)
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

-- 8c. Find duplicate face profile above threshold
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


-- ---------------------------------------------------------------------------
-- 9. Function Grants — service_role only
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.biopay_set_updated_at() FROM public;
REVOKE ALL ON FUNCTION public.generate_biopay_id() FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.match_biopay_embedding(vector, integer) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.find_duplicate_biopay_profile(vector, double precision) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.generate_biopay_id() TO service_role;
GRANT EXECUTE ON FUNCTION public.match_biopay_embedding(vector, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.find_duplicate_biopay_profile(vector, double precision) TO service_role;


COMMIT;
