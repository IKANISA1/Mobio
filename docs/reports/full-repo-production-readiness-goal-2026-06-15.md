# Full Repo Production Readiness Goal - 2026-06-15

## Objective

Complete a deep, phased, evidence-backed production readiness audit and remediation pass for the entire MOBI repository. The scope includes the Mobio Flutter app, BioPay as a Mobio feature, wallet/tokens/subscriptions/Mobio Plus, Mo Mobio SMS internal utility app, admin panel/PWA, Supabase backend, release scripts/evidence, security/privacy/compliance, design/navigation/accessibility, and all QA gates needed for go-live decisions.

This goal is not complete until every phase below has either:

- a completed workpaper with current-state evidence,
- a production readiness register disposition,
- linked command or runtime proof where feasible, and
- code-owned fixes implemented and re-tested when the finding is inside this repo.

## Non-Negotiable Scope Rules

- BioPay is a feature inside Mobio. It must not be reported as a separate app identity.
- Mo Mobio SMS is a private in-house office-phone utility app. It is not a Play Store/public user app and it does not require a public-app SMS bridge secret.
- Main Mobio app SMS permissions must stay absent. SMS collection belongs only to the private Mo Mobio SMS utility app.
- Wallet, token, subscription, Mobio Plus, referral, and ledger behavior must remain server-owned where the current product contract requires it.
- Release conclusions must separate code-owned proof from owner-held or externally executed evidence.
- No raw secrets may be copied into audit artifacts.

## Phase Control

| Phase | Workpaper | Required output | Status |
| --- | --- | --- | --- |
| 0. Stabilize current diff | Git status plus diff triage | Identify uncommitted changes, isolate user-owned work, and avoid auditing half-applied source | In progress |
| 1. Repo inventory | `docs/reports/full-repo-inventory-2026-06-15.md` | Current source map for apps, packages, backend, scripts, docs, evidence | Completed first pass |
| 2. Screen and route matrix | `docs/reports/route-screen-matrix-2026-06-15.md` | Every active route/screen mapped to owner, role, auth, backend dependencies, permissions, states, nav, tests, risk | In progress |
| 3. Mobio feature audit | `docs/reports/mobio-feature-audit-2026-06-15.md`; focused workpaper `docs/reports/mobio-profile-wallet-subscription-audit-2026-06-15.md` | Feature-by-feature audit for auth, onboarding, home, nearby, bookings, scheduling, chat, profile, wallet, tokens, subscriptions, Mobio Plus, BioPay, public transport, referrals, notifications, privacy, location, settings | In progress |
| 4. Mo Mobio SMS audit | `docs/reports/momobio-sms-audit-2026-06-15.md` | Internal utility app audit for SMS permissions, foreground service, boot recovery, direct Supabase ingestion, OpenAI parser path, device evidence | Completed first pass |
| 5. Admin panel audit | `docs/reports/admin-panel-audit-2026-06-15.md` | Admin auth, allowlists/OTP, reports/blocks, subscriptions, transport/catalog, BioPay ops, notifications, health, deployment, privilege boundaries | Pending |
| 6. Supabase/backend audit | `docs/reports/supabase-backend-audit-2026-06-15.md` | Migrations, RLS, RPCs, Edge Functions, triggers, secrets, linked remote state, destructive-operation protections, tests | Pending |
| 7. Security/privacy/compliance audit | `docs/reports/security-privacy-compliance-audit-2026-06-15.md` | Secrets, PII, permissions, Play/App Store evidence, data safety, admin escalation, audit logging, wallet/ledger, SMS/BioPay boundaries | Pending |
| 8. Design/navigation/accessibility audit | `docs/reports/design-navigation-accessibility-audit-2026-06-15.md` | Screen-by-screen review against Mobio/Revolut expectations, responsive layout, semantics, text fit, keyboard/back flow | Pending |
| 9. QA gates | `docs/reports/qa-gates-2026-06-15.md` | Targeted tests, split full Flutter coverage, Supabase, Android build/smoke, feasible iOS proof, admin/web proof, device/browser evidence, golden status | In progress |
| 10. Readiness register | `docs/reports/production-readiness-register-2026-06-15.md` | Blocker, High, Medium, Low, False positive, Fixed, Needs owner evidence, with file paths, commands, proof, go/no-go impact | In progress |

## Current Baseline

- Last pushed commit before this phase: `c458446 Finalize Mobio v14 production gate evidence`.
- QR save/share was fixed before this phase and pushed as part of the current `main` history.
- Android v14 gate previously reached `GO: all production gates passed`.
- Current worktree is dirty again with Mo Mobio SMS, profile/Driver Plus, BioPay QR/NFC, release metadata, and audit workpaper changes. These changes have now passed focused validators/tests, analyzer, sidecar compile, grouped Flutter non-preview tests, and preview/golden tests, but the final audit cannot close until remaining release/web/iOS evidence is refreshed and the batch is committed or explicitly deferred.

## Completion Criteria

1. Current diff is either committed with proof, intentionally isolated, or documented as out of scope with exact file paths.
2. The repo inventory covers all executable apps, generated apps, local packages, backend areas, scripts, docs, and evidence folders.
3. The route/screen matrix covers all routes in `lib/core/router/app_router.dart` and every screen under `lib/features`.
4. Every requested feature area has a workpaper and a readiness-register disposition.
5. Every blocker or high-risk code-owned finding has a fix or an explicit deferred reason with go/no-go impact.
6. QA gates are rerun after code-owned fixes that affect runtime behavior.
7. Final output separates Android, iOS, admin/PWA, Supabase, Mo Mobio SMS, and owner-evidence status.
