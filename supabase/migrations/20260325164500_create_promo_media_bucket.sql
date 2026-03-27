-- Create the promo-media storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('promo-media', 'promo-media', true)
ON CONFLICT (id) DO NOTHING;

-- Grant public read access to the bucket
CREATE POLICY "Public Read Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'promo-media');

-- Grant service role full access (insert, update, delete) to the bucket
-- This is technically handled by RLS bypass for service roles, but explicit policy is good practice
CREATE POLICY "Service Role Full Access"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id = 'promo-media')
WITH CHECK (bucket_id = 'promo-media');
