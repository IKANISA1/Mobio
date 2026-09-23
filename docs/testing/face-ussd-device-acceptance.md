# Face-to-USSD acceptance checklist

Use with the [implementation evidence report](face-ussd-implementation-20260920.md).
Local fixtures establish behavior, not measured identity accuracy or production
readiness. Record build SHA/digest, backend migration/version, model/index/policy,
device/OS, SIM operator and test date without private phone numbers or images.

## Automated coverage and remaining evidence

| Acceptance case | Maintained local evidence | Remaining live evidence |
|---|---|---|
| Real validated session; reject expiry/ownership mismatch | `scripts/qa/test_face_ussd_db.py`; `app-user_test.ts` | Target Auth/session schema and signed-in staging request |
| Login A → selected receiving B | Real SQL/PostgREST shortcut test | Consented recipient, physical dialer displays B |
| Payer has no face enrollment | Real SQL test; scanner widget fixture | Authenticated payer on device |
| Explicit choice among receiving methods | SQL and enrollment widget tests | Receiving-method management round trip |
| Number changes without recapture | SQL version/edit/change-method tests | Scan before/after approved test-number edit |
| Missing/inactive/unconfigured destination cannot dial | SQL route/method/pause/remove checks | Device shows localized fallback, zero launch |
| One capture, no liveness dependency | Enrollment widget; facade/Worker tests | Camera front still; no challenge/video/audio |
| Actual models execute | Actual local YuNet/SFace and HTTP tests | Linux amd64 container image smoke and deployed health |
| Recognition accuracy | Maintained `evaluate.py`; no cohort executed | Separate consented calibration/acceptance photos, unknowns, device/lighting variation, denominators and wrong candidates |
| Ambiguity/multiple faces | SQL margin test; typed capture/fallback handling | Actual multi-face captures and close candidates |
| Search activation | Worker async-index fixture; SQL pending state | Real Vectorize insertion delay and searchable proof |
| Pause/remove exclusion | SQL current authority even with stale candidate | Propagation lag and eventual explicit deletion |
| Replacement/cleanup | Real SQL and maintenance tests | Induced timeout/write/activation failure; old cleanup cannot delete replacement |
| Amount independence | No amount or payment-request row in SQL/widget tests | Operator asks for amount; app injects none |
| No extra application review | Scanner widget calls handoff directly | Physical scan proceeds directly to dialer |
| Final hash encoded exactly once | Native-channel URI regression | Actual dialer retains trailing `#` without `%23` display/double encoding |
| At-most-once handoff | Gate and widget rebuild/resume/cancel/account tests | Rapid taps, background during upload, back/resume and latency |
| Camera/files/permission | Native camera-channel lifecycle/temp-file tests | Permission denied/revoked; screen lock; camera in use; no background camera indicator |
| Operator/SIM behavior | No local fixture can certify this | Supported MTN Rwanda SIM, expected pre-PIN prompt, cancellation and dual-SIM selection |
| Unsupported platforms | iOS/web/desktop alternative widget tests | Each platform's camera/copy/back/accessibility behavior |
| No false payment success | SQL has no monetary request; audit only | Return/cancel does not show paid/settled |
| AWS independence | Active source/secret scan; new provider tests | Deployed secret removal and scoped remote cleanup separately approved |
| Existing flows | Full functional Flutter suite and shared Auth/backend regressions | Real WhatsApp OTP, manual number, QR and other composer journeys |

## Physical device procedure

1. Use a signed release/staging build with all four public runtime defines.
   Record whether an existing installed build can be updated without data loss.
   Do not uninstall a user's installed app to bypass a signing mismatch.
2. With approved non-sensitive accounts, sign in using WhatsApp. Recipient
   chooses receiving B (different from login A), explicitly opts in, captures
   once and waits for active setup. Record rejected capture/no-face/multiple-face
   recovery; test update, pause, resume and remove.
3. With a payer who has not enrolled, scan that recipient in person. Verify
   the exact approved B route opens once. Verify camera stops, no app amount or
   confirmation screen appears, and the final hash survives the native handoff.
4. Rebuild/rotate/background/return, cancel a scan, change account, repeat taps,
   and delay network responses. None may produce a stale or repeated launch.
   Re-scan deliberately for a new operation when required.
5. Check the supported SIM and selected SIM behavior. The application only opens
   ACTION_DIAL. Operator-session checks require an attended test; stop before
   PIN/authorization and cancel. No real transfer is necessary. Never automate
   Call, SIM selection, USSD menus or PIN entry.
6. Change B in receiving methods without recapture, scan again, and verify the
   new version. Disable the method/route and pause/remove enrollment, then
   confirm no route can launch. Verify an unknown/ambiguous recipient offers
   retry/manual/QR and never payer enrollment.
7. Use TalkBack, 200% text, EN/FR/RW, small viewport, keyboard/switch navigation,
   dark/light themes and reduced motion. Verify clear labels, focus/announcements,
   reachable back actions and at least 48px targets. No biometric certainty
   percentages or “payment completed” state should appear.
8. Measure capture/upload/inference/search/SQL/native timing and warm/cold
   p50/p95 separately. Record observed failure/retry counts. The 2s/4s warm
   targets are targets, not results. Retain consented photos only under the
   approved evaluation retention plan, outside source control.

On 20 September 2026, read-only ADB inspection found an authorized physical
Pixel 4a, Android 13, with two loaded SIM slots. This fact alone proves no
recognition or operator acceptance; no live face-service deployment/cohort was
available for the complete scan-to-dialer procedure.

An OS-level ACTION_DIAL check on that device opened the user-supplied route and
UI inspection confirmed its final `#` without double encoding. The dialer was
closed with Back. Call/SIM selection/PIN were not pressed; no operator session
or transfer was started. This is separate from testing the newly built app's
native bridge and the complete authenticated face flow.
