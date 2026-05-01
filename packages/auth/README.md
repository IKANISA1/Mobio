# Auth Package Boundary

Current source of truth:

- Session and admin guard: `../../lib/core/auth`, `../../lib/core/services/supabase_session_service.dart`
- WhatsApp app login: `../../lib/core/services/whatsapp_login_service.dart`
- Admin OTP login: `../../lib/core/services/otp_service.dart`
- Backend OTP/admin helpers: `../../supabase/functions/_shared`

Server-side authorization remains authoritative. Flutter role helpers are for routing and user experience only.
