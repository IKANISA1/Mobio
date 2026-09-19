# Local OTP verification and session review

15 September 2026, Africa/Kigali. This batch executes the exported production verification handlers against real isolated Auth and PostgREST services. **Thirty final HTTP checks pass.** It adds two repaired findings and advances the existing OTP/Admin identity review. The overall system review and release acceptance remain incomplete.

## Reproduced defects and repairs

**FQA-033 — Existing-user lookup prevented valid Admin login (P1).** An allowlisted passenger supplied a valid Admin-purpose OTP, but verification returned HTTP 500. Auth had stored the verified phone without its leading plus sign; the handler compared it directly with the normalized input, missed the account and attempted duplicate creation. A separate existing Admin outside the first 1,000 Auth users also received HTTP 500 because the lookup searched only page one. Both requests consumed their valid OTP before failing.

The lookup now compares normalized phone digits, retains the internal-email compatibility path and reads subsequent pages until it finds the account or exhausts the inventory. Auth lookup errors propagate before provisioning. Retests reuse the same Auth user, add no duplicate account, issue a real session and resolve the expected Admin database identity. The earlier consumer/Admin session becomes unusable after the existing password rotation.

**FQA-034 — Malformed request JSON returned HTTP 500 (P2).** Both verification endpoints classified an unreadable request body as an internal error. They now return HTTP 400 at the parsing boundary. Unexpected downstream failures retain their server-error path. Two real HTTP retests and six unit cases verify client-error handling; the unit cases also require zero backend calls.

## Executed checks

| Layer | Result | Evidence under build/qa/fullstack-qa-20260914/ |
| --- | --- | --- |
| Actual verification and session creation | 30/30 bounded checks pass | edge-otp-session-final-regression.json |
| Default Admin session handler with mocked HTTP | 8 cases pass, including both phone formats, legacy email, pages 2/11, new-user provisioning and failed lookup pages | edge-session-deno-test.log |
| Entire Deno test tree | 101 passed, 0 failed, 1 existing ignored test | edge-session-deno-test.log |
| Edge entrypoint type checks | All 16 pass with the frozen lockfile | edge-session-deno-check.log |
| Dart / Flutter | No analysis issues; 643 tests pass on pinned Flutter 3.44.3 / Dart 3.12.2 | edge-session-dart-analyze.log; edge-session-flutter-test.log |
| Structure / secrets / whitespace | Pass | edge-session-validation-runs.json |
| Android release script | Stops before compilation for the four missing public runtime values | edge-session-android-release-guard.log |

The live cases cover passenger-to-Admin transition, returning driver identity/role preservation, six-digit member IDs and Rwanda dialing defaults; incorrect guesses, five-attempt lockout, expiry, replay and app/Admin purpose separation; missing/deactivated Admin allowlisting; and unsupported methods/input. Six simultaneous correct requests issue exactly one Auth session for each purpose. Six simultaneous incorrect requests at the last available attempt increment the row once, leave it unverified and cannot bypass the lockout. Expected competing responses may be 400, 409 or 429 depending on when each request observes the row.

These are bounded and overlapping checks, not a complete state/role inventory or a system-wide coverage percentage. Eight new session unit tests use mocked HTTP responses through the default handler path; only the separately recorded 30-case batch establishes real local service behavior.

## Environment and evidence qualification

The host is Deno 2.9.6 running the production handlers without injected session dependencies or mocked fetch. It calls real GoTrue 2.195.0 and PostgREST 16.1 services using the fully replayed PostgreSQL 17.6 database. The backend containers share a network-none namespace with no published ports. A loopback-only transport forwards actual requests through `docker exec` and curl. Generated local service credentials match that isolated Auth/REST configuration and remain private.

Synthetic OTPs are generated and hashed with the production helper, then inserted into the owned local database. Verification executes the actual profile updates, permission grants, password rotation and Auth sign-in. **OTP message issuance/delivery was not executed.** Play Integrity enforcement is disabled only in this fixture; device attestation is unverified. Running handlers under Deno does not establish parity with the hosted Supabase Edge runtime, its gateway or deployment configuration.

Initial transport and fixture errors are retained separately in edge-session-harness-qualification.json. The nc transport cancelled Auth work; replacing it with curl required preserving chunk framing until the response parser decoded it. An initial public-country probe used the wrong column. Bulk Auth fixtures initially lacked the instance identifier that the Auth listing requires. These were test-harness problems and are not counted as product findings. Production defects were reproduced after transport qualification.

The 1,001-user pagination dataset is removed. Readback verifies all 36 Edge fixture definitions: 32 have been cleared and four verified actors remain, alongside the seven prior Auth fixtures. Current retained state is 11 users, 11 sessions, three conversations, four messages and no queued HTTP requests, notifications or FCM tokens. The two retained Edge Admins hold 48 explicit permission rows; no grant exists outside the retained Edge actors. Six allowlist rows consist of four preexisting migration seeds and two owned test Admin entries. Cron execution remains disabled. Original private credentials/logs remain outside the evidence directory with mode 0600; a sanitized runtime log is retained.

## Source binding and remaining work

Current source: **1,961 files**, fingerprint `382b3d0ca57ca423339afa22fd706f906e4e331dc2717673545afdca716bc447`. Five Edge implementation/test files changed or were added; no files were removed. Database migrations, SQL suites, Dart, Kotlin, build scripts and lockfiles are unchanged from the preceding checkpoint. The earlier complete 102-migration rehearsal, nine SQL suites and eight rate-limit tests retain their original verified bindings.

Continue with OTP sending/recovery and hosted Edge runtime parity; remaining actor/RPC/argument paths; Storage HTTP, Realtime delivery and jobs; configured browser/Admin/PWA/native journeys; and platform/design acceptance. Local session verification does not establish message delivery, deployed state, mobile/browser usability, signing/store readiness or independent/owner acceptance. **Overall readiness remains NO-GO and the execution goal remains active.**
