# Integrations

This folder documents external integration ownership. Runtime code remains in the current app/Supabase paths until each adapter is extracted safely.

| Integration | Current source |
| --- | --- |
| WhatsApp | `../supabase/functions/_shared/whatsapp-cloud.ts`, OTP Edge Functions, Flutter WhatsApp login/admin services |
| Telegram | No runtime adapter found |
| Google Chat | No runtime adapter found |
| Teams | No runtime adapter found |
| Email | Auth/admin email identifiers only; no mail adapter found |
| Voice | No runtime adapter found |
| USSD | BioPay QR/USSD services in Flutter and country schema/RPCs |
| Payments | Payment Edge Functions, QR/NFC resolver RPCs, Android ledger, MoMo SMS reconciliation |

Adapter extraction rule: keep channel-specific transport logic here; keep authorization, payment state, and tenant isolation in Supabase-backed domain services.
