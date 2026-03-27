-- ============================================================================
-- MOBI: BioPay Schema — Wallets, Transactions, Face Templates
-- ============================================================================
-- Rollback:
--   DROP TABLE IF EXISTS biopay_transactions, biopay_wallets, face_templates CASCADE;
--   DROP TYPE IF EXISTS biopay_tx_type_enum, biopay_tx_status_enum CASCADE;
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enum Types
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE biopay_tx_type_enum AS ENUM ('send', 'receive', 'top_up', 'withdraw');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE biopay_tx_status_enum AS ENUM ('pending', 'completed', 'failed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2. BioPay Wallets
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS biopay_wallets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  balance     numeric(12, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  currency    text NOT NULL DEFAULT 'RWF',
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE biopay_wallets IS 'BioPay digital wallet per user.';

-- ---------------------------------------------------------------------------
-- 3. BioPay Transactions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS biopay_transactions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id     uuid NOT NULL REFERENCES biopay_wallets(id) ON DELETE CASCADE,
  counterpart   uuid REFERENCES biopay_wallets(id),
  type          biopay_tx_type_enum NOT NULL,
  status        biopay_tx_status_enum NOT NULL DEFAULT 'pending',
  amount        numeric(12, 2) NOT NULL CHECK (amount > 0),
  currency      text NOT NULL DEFAULT 'RWF',
  note          text,
  qr_code_ref   text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE biopay_transactions IS 'All BioPay payment transactions.';

-- ---------------------------------------------------------------------------
-- 4. Face Templates (for Face ID / biometric pay)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS face_templates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  template_data bytea NOT NULL,
  version       integer NOT NULL DEFAULT 1,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE face_templates IS 'Stored face biometric templates for BioPay Face Scan Pay.';

-- ---------------------------------------------------------------------------
-- 5. Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_biopay_wallets_user    ON biopay_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_biopay_tx_wallet       ON biopay_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_biopay_tx_status       ON biopay_transactions(status);
CREATE INDEX IF NOT EXISTS idx_biopay_tx_created      ON biopay_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_face_templates_user    ON face_templates(user_id);

-- ---------------------------------------------------------------------------
-- 6. RLS Policies
-- ---------------------------------------------------------------------------

ALTER TABLE biopay_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE biopay_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_templates ENABLE ROW LEVEL SECURITY;

-- Wallets: users can only see/update their own
CREATE POLICY "Users can view own wallet"
  ON biopay_wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own wallet"
  ON biopay_wallets FOR UPDATE
  USING (auth.uid() = user_id);

-- Transactions: users can see transactions on their own wallet
CREATE POLICY "Users can view own transactions"
  ON biopay_transactions FOR SELECT
  USING (
    wallet_id IN (SELECT id FROM biopay_wallets WHERE user_id = auth.uid())
  );

CREATE POLICY "Users can insert own transactions"
  ON biopay_transactions FOR INSERT
  WITH CHECK (
    wallet_id IN (SELECT id FROM biopay_wallets WHERE user_id = auth.uid())
  );

-- Face templates: users can only manage their own
CREATE POLICY "Users can view own face template"
  ON face_templates FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own face template"
  ON face_templates FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own face template"
  ON face_templates FOR UPDATE
  USING (auth.uid() = user_id);
