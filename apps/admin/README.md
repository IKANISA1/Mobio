# Admin App Boundary

Current source of truth:

- Admin screens and widgets: `../../lib/features/admin`
- Admin route guards: `../../lib/core/router`
- Admin services: `../../lib/core/services/admin` and `../../lib/core/services/admin_service.dart`
- Generated admin PWA output: `../../build/pwa/admin`

Admin authorization remains enforced server-side through Supabase RPCs and Edge Functions. Do not duplicate admin permission logic in this folder.
