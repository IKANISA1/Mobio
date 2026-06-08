# Admin UAT Script

Last updated: 2026-05-23

Use an approved admin account. Record tester, environment, app/web target, and
linked Supabase project.

## Core Paths

1. Open admin gateway and authenticate as admin.
2. Verify non-admin users cannot access admin routes.
3. Open dashboard and confirm aggregate metrics load.
4. Search and open user/profile records.
5. Change roles only through authorized admin flows.
6. Review vehicle type configuration for moto, cab, truck, trike, private car.
7. Review scheduled trip posts and moderation actions where present.
8. Open Reports, search/filter user reports, mark one report reviewing, then
   resolve or dismiss it with resolution notes.
9. Review audit logs and operational health events.
10. Confirm finance/payment/BioPay/ledger surfaces are not part of the active
    production workflow unless explicitly marked legacy/inactive.

## Acceptance Criteria

- Admin routes redirect unauthenticated or non-admin users.
- Admin RPCs fail without server-side authorization.
- Moderation actions create audit entries.
- No admin action can create a fare quote, dispatch, trip completion, refund, or
  trip payment settlement.
- Reports moderation updates are visible in the admin queue and remain blocked
  for non-admin users by server-side RPC authorization.
