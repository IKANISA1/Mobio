# Security Privacy Compliance Audit - 2026-06-15

## Scope

Secrets, PII, permissions, Play/App Store evidence, data safety, admin escalation paths, audit logging, wallet/ledger ownership, SMS/BioPay boundaries, release signing, Maps/FCM service evidence, and dependency/supply-chain concerns.

## Current Evidence Already Known

- v14 Android go/no-go gate previously passed committed secret scan and secret-history proof.
- Current Mo Mobio SMS scope removes `READ_SMS` and inbox backfill.
- Main Mobio Android app SMS permissions remain out of scope and are checked by release boundary tests.
- Play upload, Maps server key evidence, FCM HTTP v1 evidence, and Play service-account retention evidence exist for Android v14 gate.

## Worklist

| Area | Required evidence | Status |
| --- | --- | --- |
| Current worktree secret scan | Run `scripts/qa/scan_secrets.sh` after current docs/source batch | Passed |
| Git history secret proof | Run or cite `scripts/qa/check_secret_history.sh` after final batch | Passed |
| Android permissions | Main app manifest plus Mo Mobio SMS manifest boundary | In progress; SMS utility boundary fixed |
| iOS permissions | Camera/NFC/Photos usage, App Store evidence if shipping iOS | Pending |
| Admin privilege escalation | Admin guards, allowlist, RPC server checks, audit logs | Pending |
| PII handling | Phone, location, chat, SMS, face provider metadata, push tokens | Pending |
| Data safety/store declarations | Play/App Store metadata matches active product scope | Pending refresh |
| Supply chain | Pinned workflows, lockfiles, dependency risk, plugin migration warnings | Pending |

## Evidence Added This Phase

- `./scripts/qa/scan_secrets.sh` passed on the current worktree.
- `./scripts/qa/check_secret_history.sh` passed.
- `node scripts/validate-momobio-sms-bridge.mjs` passed and verifies the Mo Mobio SMS utility does not use `READ_SMS`, `readAllSms`, or `content://sms/inbox`.
- Public site scope verification passed with `./scripts/web/verify_public_site.sh`.
- PWA bundle verification passed with `./scripts/web/verify_pwa_bundles.sh build/pwa`.

## Findings

| ID | Severity | Finding | Status | Next action |
| --- | --- | --- | --- | --- |
| SEC-001 | Fixed | Current worktree and Git history secret scans are green. | Fixed | Re-run before final commit/push. |
| SEC-002 | Fixed | Mo Mobio SMS no longer requests inbox read access; it receives only new incoming SMS. | Fixed | Keep old `READ_SMS` QA evidence marked historical only. |
| SEC-003 | Needs owner evidence | iOS release privacy/signing/provider evidence is not refreshed in this phase yet. | Open | Run feasible iOS release proof and attach App Store/TestFlight owner evidence before iOS go-live. |
