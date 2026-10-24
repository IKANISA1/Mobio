# Mobio verification — 24 October 2026

Dependencies and the two stale design bindings have been repaired. The check run is **not green**; remaining failures and unavailable checks are listed below. Base commit: `d55ec24640ab20f0c750d77ee13c5993c50799f2`.

## Changes

- Restored packages and generated parts through `scripts/ci/bootstrap_flutter.sh` with the pinned Flutter 3.44.3 / Dart 3.12.2. Both package lockfiles and the tracked generated translations are unchanged.
- Reread all five maintained design authority files, refreshed only the two stale SHA-256 bindings, and retained historical hashes and unverified acceptance. See [the refresh receipt](../design/authority-refresh-20261024.md).
- Corrected the Flutter runner to require a complete JSON reporter stream, unchanged UI inputs and successful tests. It preserves raw reporter bytes with their hash and rejects interrupted or truncated runs even when Flutter exits zero. Added regression coverage, including result-write failures.
- Repaired omitted collector JVM compilation/test inputs and the SMS SQL runner's explicit validated connection URI.
- Aligned OTP test fixtures with the existing consumed-reference and purpose-bound hash contracts. Added the missing single-code `/invite/:code` app-shell route with bounded route/cache tests.
- Corrected five Flutter test fixtures to use the actual body scroller, real view metrics, visible controls and lazy sheet contents. Existing behavioral assertions remain in place.

## Results

| Check | Observed result |
|---|---|
| Dependency bootstrap | Passed on the original checkout and the byte-verified internal verification copy |
| Design authority | Passed, 5/5 external bindings; 12 focused regression tests |
| Repository structure, secret scan, GitHub Actions pins, migration preparation, diff whitespace | Passed |
| Python scripts suite | 510 passed |
| Flutter runner focused regression suite | 22 passed; real six-case Flutter smoke passed |
| Backend Deno contract/type checks | 174 passed, 1 paid-provider case ignored; linked gates explicitly skipped |
| Node privacy / push / Edge hardening / handler-intake-admin / Pages-admin workers / face service | 70 / 70 / 66 / 140 / 71 / 7 passed |
| Payment-link Deno / face-server bounds | 3 / 16 passed |
| Native checks | Swift parse passed; SessionCipher 41, NFC 20, collector policy/lease 38 scenarios; collector JUnit 49 tests passed |
| Isolated SQL | Booking/PostgREST 16, member ID 15, chat 27, push 47, privacy 28 assertions passed (133 total); SMS intake SQL/concurrent claims passed |
| `dart analyze` | Exit 0, zero errors/warnings, 318 information diagnostics |
| `flutter analyze --no-pub` | **Failed**, exit 1 on those 318 information diagnostics across 89 files |
| Complete Flutter suite | **Failed**: 2,199 visible cases passed, 34 failed; all 218 suites loaded. An additional 278 hidden load/setup completions passed. |

The full Flutter command used the repository source-binding wrapper with `--no-pub --coverage --reporter json --concurrency 2`. Final completion and reporter integrity: complete, valid terminal failure; child and wrapper both exited 1; all 2,511 started reporter tests completed with no unfinished IDs. The retained raw reporter is 1,673,113 bytes with SHA-256 `288e6a611d8fc3aa4707e08b4a1a28887932f57689490d829c9a951bd3bf4638`. The 798-file UI/configuration fingerprint before, after and on the submission is `b0d5c67497a1b1e7038b7aaef865babbb15c66b4405e4ffb26430adb9a688ef7`.

## Remaining failures

| Test file | Failed cases | Observed failure |
|---|---:|---|
| `test/features/bookings/bookings_route_disclosure_test.dart` | 2 | Full notice text exceeds its line limit at 320px / 200% text, in light and dark themes |
| `test/features/bookings/widgets/bus_agency_picker_test.dart` | 1 | 57px vertical overflow with narrow layout, 200% text and keyboard visible |
| `test/features/profile/presentation/driver_plus_account_race_test.dart` | 1 | Rendering/inspection exceptions, including an 11px vertical overflow |
| `test/features/profile/presentation/wallet_rendered_callback_race_test.dart` | 8 | Rendering/inspection exceptions, including 5px or 11px vertical overflows |
| `test/features/preview/revolut_reference_golden_test.dart` | 21 | Pixel comparisons differ for splash, wallet, Mobio Plus, profile, face scan and admin surfaces |
| `test/release/chat_fullstack_contract_test.dart` | 1 | Server-owned chat tables/RPC/realtime source contract assertion expected true and received false |

The golden baselines and app UI were not rewritten. The callback test names alone do not establish an authorization defect; their observed failures include rendering/inspection exceptions and require separate diagnosis. Analyzer rules and test assertions were not weakened.

## Checks unavailable locally

- Complete-schema migration rehearsal did not reach application migration replay: the pinned CLI still requires Realtime/Storage migration-helper images when those services are excluded. Measured missing-image pull plus unpack requirements exceeded available space on Docker's backing volume.
- Real Auth/HTTP runtime checks and helpers requiring the complete-schema fixture remain unexecuted. The frozen Auth HTTP static check passed and does not replace runtime evidence.
- Standalone BioPay discovery uses an absent floating `postgres:17-alpine` image; it was not replaced with a different fixture. Standalone native Face/USSD checks lack native PostgreSQL/PostgREST executables.
- Linked backend/storage/realtime audits and paid-provider calls were not run. Signed release builds, physical-device, deployment, store and independent-review evidence were not produced by this task.

## Evidence and preservation

Raw logs, reporter events, coverage, golden comparison failures, source manifests and dependency receipts are preserved locally under `/Users/jeanbosco/Documents/Codex/2026-10-24/mobio-checks-fixes/`. Key files are `flutter-results-final.json`, `flutter-test-source-final.json`, `flutter-final-failures.json`, `python-complete-result.json`, `backend/fix-results.json`, `native/summary.json` and `sql/summary.json`.

The first full Flutter run was interrupted after the external build volume filled. Its exit-zero result was rejected because it lacked terminal completion. Its logs and the hash-verified build archive remain preserved. The final run used a byte-verified internal copy of all source inputs; all product and Flutter test inputs remained identical to the submission. A later runner result-write metadata correction and its Python regression were independently verified; the submitted completion parser is unchanged and revalidates the preserved final reporter stream. Raw failures are retained; no release or visual acceptance is inferred.
