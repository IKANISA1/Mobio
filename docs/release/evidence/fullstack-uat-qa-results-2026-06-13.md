# MOBI Fullstack UAT and QA Results

Date: 2026-06-13  
Status: Initial Phase 1 execution started. Production readiness is currently **NO-GO**.

## Summary

The fullstack UAT plan has been created at:

- `/Volumes/PRO-G40/MOBI/mobi_app/docs/release/evidence/fullstack-uat-qa-plan-2026-06-13.md`

Initial static and automated gates were executed. The app is not yet production-ready because the complete UAT has not been run and the first execution batch already found release-blocking gaps.

## Commands Run

```bash
/Volumes/PRO-G40/flutter_3_44/bin/flutter pub get
scripts/qa/scan_secrets.sh
scripts/qa/audit_storage_realtime.sh
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze
/Volumes/PRO-G40/flutter_3_44/bin/flutter test
scripts/ci/verify_backend.sh
```

## Gate Results

| Area | Result | Evidence |
| --- | --- | --- |
| Dependency sync | PASS | `flutter pub get` completed. 93 packages have newer incompatible versions. |
| Static Dart/Flutter analysis | PASS | `flutter analyze` reported no issues. |
| Local secret-pattern scan | PASS | `scripts/qa/scan_secrets.sh` reported `secret-pattern scan passed`. |
| Supabase storage/realtime audit | BLOCKED | `scripts/qa/audit_storage_realtime.sh` failed with Supabase platform 403 and requested `SUPABASE_DB_PASSWORD`. |
| Backend local function tests | PASS WITH SKIP | `scripts/ci/verify_backend.sh` passed local Deno tests but skipped linked Supabase security gates. |
| Flutter test suite | FAIL | Golden regressions in profile and BioPay surfaces; scanner plugin test teardown issue. |

## Backend Result Detail

`scripts/ci/verify_backend.sh` passed these local function tests:

- `supabase/functions/biopay-api/index_test.ts`
- `supabase/functions/biopay-face-provider/index_test.ts`
- `supabase/functions/_shared/otp-security_test.ts`
- `supabase/functions/_shared/phone_test.ts`
- `supabase/functions/_shared/whatsapp-cloud_test.ts`

Important limitation:

- Linked Supabase security gates were skipped because the environment did not provide `SUPABASE_PROJECT_REF` plus `SUPABASE_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`.
- Storage/realtime audit failed with 403 against the Supabase platform endpoint, so live database, RLS, storage, and realtime readiness are not yet proven in this run.

## Frontend Result Detail

`flutter test` failed in:

- `test/features/preview/revolut_reference_golden_test.dart`

Current failing golden surfaces reported by the test runner:

- `profile_390x844`
- `profile_430x932`
- `biopay_home_390x844`
- `biopay_home_430x932`
- `biopay_qr_390x844`
- `biopay_qr_430x932`
- `biopay_scan_390x844`
- `biopay_scan_430x932`
- `biopay_face_scan_390x844`
- `biopay_face_scan_430x932`
- `biopay_face_enroll_390x844`
- `biopay_face_enroll_430x932`
- `biopay_nfc_390x844`
- `biopay_nfc_430x932`

Severity:

- BioPay golden failures are P0 for visual QA because the pixel diffs are extreme, commonly above 90 percent.
- Profile golden drift is smaller but repeatable and still must be reviewed before release.
- `MissingPluginException(No implementation found for method stop on channel dev.steenbakker.mobile_scanner/scanner/method)` appeared during scanner golden execution. This is a P1 test-harness blocker because it can make scanner visual tests noisy or unreliable.

Current generated failure artifacts:

- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_home_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_home_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_qr_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_qr_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_scan_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_scan_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_scan_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_scan_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_enroll_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_face_enroll_430x932_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_nfc_390x844_testImage.png`
- `/Volumes/PRO-G40/MOBI/mobi_app/test/features/preview/failures/biopay_nfc_430x932_testImage.png`

Note: the `failures/` folder also contains older June 12 files for non-BioPay screens. Those older files are not treated as fresh findings from this Phase 1 run unless revalidated.

## Current P0 Findings

### P0-1: Full Flutter test suite fails

The current suite fails visual regression checks. This blocks production readiness until the intended visual baseline is clarified and tests are either updated correctly or the UI is fixed.

Required resolution:

- Decide whether the current BioPay UI screenshots are the intended baseline.
- If intended, regenerate goldens after manual review against BioPay reference screenshots and MOBI design direction.
- If not intended, refit BioPay screens and rerun goldens.
- Add scanner plugin mocks so `biopay_scan` tests are deterministic.

### P0-2: Live Supabase database/RLS/storage/realtime gates are not proven

The local backend unit tests passed, but live linked security gates were skipped or blocked.

Required resolution:

- Provide or configure a valid linked Supabase DB password or access token with sufficient privileges.
- Re-run storage/realtime audit.
- Re-run backend verification with linked gates enabled.
- Produce RLS and storage proof for production tables.

### P0-3: Full UAT coverage is not complete

The repo still needs the complete UAT defined in the plan, including every screen, live backend/API, real device walkthrough, admin, PWA, and release reproducibility.

Required resolution:

- Execute the remaining phases in `fullstack-uat-qa-plan-2026-06-13.md`.
- Produce screenshot manifest, function matrix, device UAT evidence, and final go/no-go.

## Current P1 Findings

### P1-1: Dependency aging needs review

`flutter pub get` reports 93 packages with newer incompatible versions. This is not an immediate blocker, but it increases upgrade and maintenance risk.

### P1-2: iOS Swift Package Manager warning

Flutter reports `permission_handler_apple` does not support Swift Package Manager for iOS. This is a future Flutter compatibility risk and should be tracked before iOS release hardening.

## BioPay-Specific Assessment

BioPay restoration has partial positive evidence from earlier device and backend checks:

- BioPay entry points are present in the installed Android app.
- Face scan/enrollment paths are configured around AWS Rekognition.
- The current boundary remains USSD dialer handoff only.
- QR, NFC, face scan, and face enrollment surfaces exist.

But BioPay is not production-cleared because:

- Visual regression currently fails across every BioPay golden surface.
- Full live face enrollment/match UAT has not been completed in this Phase 1 run.
- Full QR/NFC/USSD end-to-end manual device proof has not been completed in this Phase 1 run.
- Admin BioPay confirmation workflow still needs full live UAT.

## Next Execution Batch

1. Fix or formally rebaseline the BioPay/profile visual goldens after manual screenshot review.
2. Add deterministic scanner plugin mocking for widget/golden tests.
3. Re-run `flutter test`.
4. Configure linked Supabase credentials without exposing secrets in logs.
5. Re-run storage/realtime audit and backend verification with linked gates.
6. Execute full physical-device UAT walkthrough from the plan.
7. Build fresh release APK/AAB from clean state and prove reproducibility.
8. Write final go/no-go report.

