-- ============================================================================
-- MOBI BioPay: pgvector IVFFlat index maintenance
-- ============================================================================
-- Purpose: Provides a callable function and optional pg_cron job
-- for nightly REINDEX of the BioPay face embeddings IVFFlat index.
-- IVFFlat indexes degrade as data distribution changes over time.
--
-- Rollback:
--   SELECT cron.unschedule('biopay-reindex-embeddings');
--   DROP FUNCTION IF EXISTS public.biopay_reindex_embeddings() CASCADE;
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Callable reindex function (service_role only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.biopay_reindex_embeddings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REINDEX INDEX CONCURRENTLY idx_biopay_face_embeddings_embedding_cosine;
  RAISE NOTICE '[biopay] IVFFlat index reindexed at %', now();
END;
$$;

REVOKE ALL ON FUNCTION public.biopay_reindex_embeddings() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.biopay_reindex_embeddings() TO service_role;

-- ---------------------------------------------------------------------------
-- 2. pg_cron nightly job (only if pg_cron extension is available)
-- ---------------------------------------------------------------------------
-- Uncomment the following if pg_cron is enabled on your Supabase instance:
--
-- SELECT cron.schedule(
--   'biopay-reindex-embeddings',     -- job name
--   '0 3 * * *',                      -- 3:00 AM UTC daily
--   $$SELECT biopay_reindex_embeddings()$$
-- );

COMMIT;
