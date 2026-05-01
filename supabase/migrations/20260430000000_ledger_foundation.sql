-- MOBI Ledger Foundation
-- Migration for integrating PayLedger SMS/Transaction tracking into MOBI

-- 1. Add sender_id to countries
-- Used by Android SmsReceiver to filter MoMo transaction SMS
ALTER TABLE public.countries
  ADD COLUMN IF NOT EXISTS sender_id VARCHAR(50);

-- Update Rwanda's sender_id (canonical default)
UPDATE public.countries SET sender_id = 'M-Money' WHERE id = 'RW';

-- 2. Transactions Table
CREATE TABLE IF NOT EXISTS public.transactions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    agent_id         CHAR(6) NOT NULL, -- Storing profile.member_id for native compat
    transaction_ref  VARCHAR(60),
    payer_name       VARCHAR(120),
    payer_number     VARCHAR(25),
    amount           NUMERIC(14,2) NOT NULL,
    currency         CHAR(3) NOT NULL,
    network          VARCHAR(30) NOT NULL,
    balance_after    NUMERIC(14,2),
    direction        VARCHAR(3) NOT NULL CHECK (direction IN ('IN', 'OUT')),
    txn_timestamp    TIMESTAMPTZ NOT NULL,
    raw_sms          TEXT NOT NULL,
    sms_hash         CHAR(64) NOT NULL,
    parse_confidence FLOAT4,
    country          CHAR(2) NOT NULL,
    parsed_at        TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deduplication constraint
ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_dedup UNIQUE (sms_hash, agent_id);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_transactions_agent ON public.transactions (agent_id);
CREATE INDEX IF NOT EXISTS idx_transactions_agent_date ON public.transactions (agent_id, txn_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_profile ON public.transactions (profile_id);

-- RLS: user sees only own transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_transactions_select" ON public.transactions
    FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "users_own_transactions_insert" ON public.transactions
    FOR INSERT WITH CHECK (profile_id = auth.uid());

-- 3. SMS Raw Queue (Audit Trail)
CREATE TABLE IF NOT EXISTS public.sms_raw_queue (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    agent_id       CHAR(6) NOT NULL, -- Storing profile.member_id for native compat
    raw_sms        TEXT NOT NULL,
    sender         VARCHAR(50) NOT NULL,
    sms_hash       CHAR(64) NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'parsed', 'failed')),
    received_at    TIMESTAMPTZ NOT NULL,
    processed_at   TIMESTAMPTZ,
    error_msg      TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Deduplication on raw queue
CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_raw_queue_dedup ON public.sms_raw_queue (sms_hash, agent_id);

-- RLS: user sees own queue items
ALTER TABLE public.sms_raw_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_queue_select" ON public.sms_raw_queue
    FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "users_own_queue_insert" ON public.sms_raw_queue
    FOR INSERT WITH CHECK (profile_id = auth.uid());

-- 4. Enable Realtime for transactions
-- Check if publication exists first, or just try adding
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'transactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
    END IF;
END $$;
