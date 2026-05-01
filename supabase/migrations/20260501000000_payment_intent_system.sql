-- Payment Intent System
-- Phase 4 Migration for Super App Merge

-- 1. admin_audit_logs
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin select audit logs" ON public.admin_audit_logs FOR SELECT USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "Admin insert audit logs" ON public.admin_audit_logs FOR INSERT WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 2. payment_intents
CREATE TABLE IF NOT EXISTS public.payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    amount NUMERIC(14,2) NOT NULL,
    currency CHAR(3) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'processing', 'authorized', 'completed', 'failed', 'disputed')),
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('ussd_momo', 'qr', 'nfc', 'face_id', 'cash')),
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL, -- Null until reconciled with ledger
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.payment_intents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users select own intents" ON public.payment_intents FOR SELECT USING (auth.uid() = payer_id OR auth.uid() = payee_id);
CREATE POLICY "Users insert own intents" ON public.payment_intents FOR INSERT WITH CHECK (auth.uid() = payer_id);
CREATE POLICY "Admin manage intents" ON public.payment_intents FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 3. payment_events (State transitions for intents)
CREATE TABLE IF NOT EXISTS public.payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intent_id UUID NOT NULL REFERENCES public.payment_intents(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL,
    actor_id UUID REFERENCES auth.users(id), -- User or Admin who triggered the change
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.payment_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users select own events" ON public.payment_events FOR SELECT USING (EXISTS (SELECT 1 FROM public.payment_intents pi WHERE pi.id = intent_id AND (pi.payer_id = auth.uid() OR pi.payee_id = auth.uid())));
CREATE POLICY "Users insert own events" ON public.payment_events FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.payment_intents pi WHERE pi.id = intent_id AND pi.payer_id = auth.uid()));
CREATE POLICY "Admin manage events" ON public.payment_events FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 4. qr_payment_sessions
CREATE TABLE IF NOT EXISTS public.qr_payment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    intent_id UUID REFERENCES public.payment_intents(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    amount NUMERIC(14,2),
    status VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'scanned', 'completed', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.qr_payment_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public select qr sessions" ON public.qr_payment_sessions FOR SELECT USING (true); -- Needed for scanning
CREATE POLICY "Users insert own qr sessions" ON public.qr_payment_sessions FOR INSERT WITH CHECK (auth.uid() = payee_id);
CREATE POLICY "Admin manage qr sessions" ON public.qr_payment_sessions FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 5. nfc_payment_sessions
CREATE TABLE IF NOT EXISTS public.nfc_payment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    intent_id UUID REFERENCES public.payment_intents(id) ON DELETE CASCADE,
    ndef_payload TEXT NOT NULL,
    amount NUMERIC(14,2),
    status VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'read', 'completed', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.nfc_payment_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public select nfc sessions" ON public.nfc_payment_sessions FOR SELECT USING (true);
CREATE POLICY "Users insert own nfc sessions" ON public.nfc_payment_sessions FOR INSERT WITH CHECK (auth.uid() = payee_id);

-- 6. risk_flags
CREATE TABLE IF NOT EXISTS public.risk_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES public.transactions(id),
    intent_id UUID REFERENCES public.payment_intents(id),
    flag_type VARCHAR(50) NOT NULL CHECK (flag_type IN ('duplicate_sms', 'unmatched_sms', 'suspicious_amount', 'dispute', 'manual_flag')),
    severity VARCHAR(20) NOT NULL DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT,
    resolved BOOLEAN NOT NULL DEFAULT false,
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.risk_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin manage risk flags" ON public.risk_flags FOR ALL USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE payment_intents;
ALTER PUBLICATION supabase_realtime ADD TABLE payment_events;
ALTER PUBLICATION supabase_realtime ADD TABLE qr_payment_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE nfc_payment_sessions;
