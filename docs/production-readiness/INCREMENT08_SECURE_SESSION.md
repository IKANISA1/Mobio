# Mobio Increment08 — secure session integration and acceptance

28 September 2026. Source candidate; no production deployment or native acceptance.

## Scope and prerequisites

Reconcile this delta on a complete isolated review branch containing accepted/reconciled Increments04–07. The cumulative overlay is not a standalone Flutter repository. Do not copy it blindly over newer upstream work. Preserve the original source, verified package hash and rollback branch. Read `DELTA_MANIFEST.json` and `SOURCES.json` for exact before/after identities.

This increment adds no SQL body, changes no financial transaction, and does not enable the previous default-off chat, SMS or push switches. Those prior cutovers and original full-schema/real-role requirements remain. It changes the client boundary around the existing passenger/admin OTP and Auth session exchange.

The code uses the existing `supabase_flutter` 2.12.0 LocalStorage API and already-declared crypto package. No package update, lockfile resolution or plugin install was performed. Android Keystore and iOS Security.framework are integrated through one fixed-purpose native channel. The Swift implementation is appended to the existing AppDelegate compilation unit, avoiding fabricated Xcode file/build IDs. Android Kotlin files are inside the existing main source set.

## Reviewed source application

```sh
python3 apply_increment08.py --bundle /path/to/Mobio_Increment08_2026-09-28 --repo /path/to/mobio-review
python3 apply_increment08.py --bundle /path/to/Mobio_Increment08_2026-09-28 --repo /path/to/mobio-review --apply
```

Default is check-only. The applier rejects unknown before hashes, tampered payloads and symlink/path escapes. It checks all preconditions before replacement. Replacements are atomic per file, not one atomic multi-file operation; review in a clean branch and do not permit concurrent writers. Hashes establish byte identity, not authenticity of the publisher or security correctness.

## Changes that users will notice

Existing plaintext SDK session slots for the configured project are removed; they are **not** silently imported or replayed. Existing users need a fresh WhatsApp OTP login after the upgrade. A native read/write failure never falls back to preferences. Failed credential startup shows a confirmed saved-login reset and requests a full app restart. The reset is scoped to login credentials and their native storage key; it does not delete the remote account, wallet, chat recovery pointer or pending operations.

Native future completion is serialized even after callers stop waiting. A timeout is not I/O cancellation. If a platform call remains hung, restart/support is required rather than launching competing reset/initialization calls. The exit marker is removed only after a matching server-issued fresh session has been restored and the saved session has been read back successfully. Storage-shape parsing is not signature validation or server authorization.

On web and unsupported desktop targets, session persistence is memory-only: page/process reload needs fresh login. This does not provide HttpOnly-cookie isolation, prevent XSS access to a running session, or solve multi-tab/server-worker cache policy. M014 remains open for those controls. Do not ship to unsupported targets expecting automatic native credential persistence.

The iOS policy is nonsynchronizable `AfterFirstUnlockThisDeviceOnly`. It permits access after the first post-reboot unlock, including background work; it does not require interactive biometrics or protect an already-unlocked process from compromise. An excluded installation marker prevents a lingering scoped Keychain item from silently restoring login after reinstall/restore. The Android key uses AndroidKeyStore; hardware/StrongBox backing is **not** asserted. Ciphertext and lock files are under `noBackupFilesDir`. Existing `allowBackup=false` is retained. New backup/transfer XML excludes the complete `FlutterSharedPreferences.xml` file because per-key exclusion is unavailable there. Review implications for restore of all preferences/recovery metadata; no existing values are bulk-cleared by the runtime migration.

## Verification to run before release

Use the project's pinned Flutter/Dart toolchain and complete dependencies. An absent tool, required secret, native platform or denied project is not a passing check.

```sh
# Existing complete-repository checks; preserve their project/environment requirements.
./scripts/ci/bootstrap_flutter.sh
./scripts/ci/verify_flutter.sh
flutter test test/increment08
bash scripts/ci/test_session_cipher.sh
python3 -m unittest discover -s scripts/tests -p test_increment08_contracts.py -v
python3 -m unittest discover -s scripts/tests -p test_increment08_applier.py -v
swiftc -frontend -parse ios/Runner/AppDelegate.swift
```

The JVM suite exercises real AES-GCM JCA behavior with ephemeral keys. It does not load AndroidKeyStore or Flutter. Swift parsing does not typecheck UIKit/Flutter/Security APIs. Dart tests cover storage state and method-channel/recovery fixtures, but their results must be obtained on the actual Flutter runtime. The full app still requires Android and iOS compile/sign/install checks, complete original regression tests and actual Auth compatibility.

Build/run only through the repository's reviewed release scripts or with its required public `--dart-define` values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`. Keep signing credentials out of this folder and source tree. Never use service-role credentials in the client. HTTP origins are accepted only in debug for explicit local loopback/emulator hosts; release requires HTTPS.

### Native device evidence matrix

Record artifact hash, source revision, toolchain, OS/device, account fixture and observed result for each case. Use synthetic test accounts and never archive raw credentials.

| Case | Required observation |
|---|---|
| Fresh install | No stored session; ordinary OTP establishes a new native saved login. |
| Upgrade with legacy preferences | Exact known session slots removed; no old token replay; other preferences preserved. |
| Restart and refresh | Same verified owner/session restored; legitimate rotation persists with readback. |
| Concurrent passenger/admin verification | Only one active transition; older response cannot commit the new session. |
| Logout during native write/Auth restore | Runtime access immediately locked; late work cannot reopen it; durable clear follows in-flight write. |
| Rapid A→B→A and view disposal | No old-account callback, cached protected view or binding activates; normal successful navigation does not undo login. |
| Token/key/file corruption and readback failure | No plaintext fallback and no claimed successful login; explicit scoped reset required. |
| Locked/rebooted device | Actual Keychain/Keystore availability matches accepted policy and failure stays safe. |
| Backup, transfer, uninstall/reinstall | No copied session silently authenticates a different install; review preferences/recovery metadata behavior. |
| Disk full, write/delete permission failures | No successful persistence/removal claim without acknowledgement; recoverable safe state. |
| Web refresh, multiple tabs, cached routes | No token persisted by this adapter; full browser/worker/CSP/revocation policy tested separately. |
| Pending wallet/chat records during login reset | Records remain; no automatic replay or reassignment; owner-bound server recovery still required. |

Ensure both admin and passenger endpoints return a user/session compatible with the real Auth-issued issuer/provider/session identity. Exercise the existing admin lease with expiry and revocation. Server policies remain authoritative; local checks do not replace JWT verification, RLS, active-session checks or least privilege.

## Release and rollback

Approve forced re-login, iOS accessibility, backup/restore behavior and any customer/support wording before rollout. Deliver native channel and Dart adapter in the same artifact; hot-updating only Dart onto an old native binary will fail closed because the channel is missing. Keep the previous last-known-good complete artifact and a tested forward-fix plan; downgrading should not recreate plaintext persistence as a recovery measure. Staged acceptance must include existing wallet/admin/chat/push cutovers and provider/device behavior.

No timers, background automation, cloud flags or production schedules were installed in this delivery. Full retention/deletion/restore, remaining feature switches, localization/accessibility and all other original tasks remain subject to their acceptance criteria. The new English recovery wording needs promised-language and assistive-technology review. Source-access and signing remediation (M001/M002) remain owner/security actions; no permission or key changes are implied.
