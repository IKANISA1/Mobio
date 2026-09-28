# Mobio Increment08 — implementation delivery report

28 September 2026 · Native session storage, fresh-login commit and logout race protection

**Status: source candidate with the local evidence below. No Flutter/Dart, Android Keystore or iOS Keychain behavioral acceptance has run. No production deployment occurred.**

## Delivery and task status

This increment contains **31 new or modified repository files** and a **207-file cumulative overlay**, retaining previous work. It includes the Flutter session-storage controller and adapter, Android Keystore/encryption channel, iOS Keychain channel, revised passenger/admin login and logout integration, recovery UI, native/domain/widget test sources, CI changes, guarded source applier, patch, checksums and the updated 95-task register.

Delivery: https://drive.google.com/drive/folders/16uKtJ0pDmn_uVnlo7Tpt-ittYxnwhvrC

Original source root: https://drive.google.com/drive/folders/120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57

Ten tasks advanced: **M003, M007, M009, M010, M014, M053, M054, M055, M077 and M090**. The register has **10 advanced now, 39 with prior source work awaiting acceptance, and 46 not advanced in this increment**. These are delivery categories, not percentages of completed application functionality. All 95 original IDs, priorities, owner roles, dependencies and acceptance criteria are preserved. No task was marked accepted for production merely because source was added.

Original Drive source and older delivery packages are unchanged. The cumulative source is an integration overlay, not a complete standalone app repository or signed artifact. No SQL body or live feature flag was added or changed; all eleven previous forward SQL bodies are retained byte-for-byte.

## Implemented source

### OS-backed native credential storage

The existing locked Supabase Flutter LocalStorage contract is replaced with a narrow session adapter. On Android, the implementation uses a generated AndroidKeyStore AES key and an authenticated AES-GCM envelope bound to the configured project namespace. Ciphertext and process-lock files live under no-backup storage; atomic file replacement and readback are required before success. Unknown keys, malformed envelopes and failed integrity checks do not become an empty or newly authenticated session. Hardware/StrongBox backing is not assumed or claimed.

On iOS, the implementation uses a nonsynchronizable generic-password Keychain item scoped to the app service and project namespace. The selected accessibility is AfterFirstUnlockThisDeviceOnly, allowing background access after the initial post-reboot unlock. An excluded installation marker clears lingering scoped items when the installation marker is absent; a corrupt marker can be reset explicitly. No biometric prompt, payer authentication or new payment authorization feature was added.

The native channel accepts only read/write/clear/reset of the scoped session value. It does not accept arbitrary filesystem paths or caller-selected key aliases. There is no preference-storage fallback after a native failure. Existing allowBackup=false is retained and backup/transfer rules exclude the preferences file; actual OEM and iOS restore behavior must still be accepted on devices.

### Fresh login and stale-write rejection

Passenger and administrator verification now share one foreground transition ticket. The expected server response must match the issuer, verified user, provider and fresh session identity restored by the actual Auth exchange. Local shape parsing is explicitly not JWT-signature verification or server authorization. Ordinary SDK persistence events may rotate only the already accepted same session; they cannot silently establish an initial login or replace another owner/provider.

The controller serializes writes and clears. Logout invalidates local trust before awaiting I/O; in-flight writes are followed by the queued clear. Native/SDK queues remain occupied until the original futures settle, even when a caller stops waiting on a timeout. The exit marker is removed only after credential readback and final transition checks.

The two login screens identify their own verification attempt for disposal cancellation. An old screen cannot cancel a newer screen's request; normal navigation after a committed login does not undo that login. Admin access still requires its existing server-owned lease. Complete real Auth/session, sensitive-RPC and native race acceptance remains open.

### Legacy upgrade, web sessions and recovery

Known plaintext SDK session slots for the configured project are removed, not silently replayed or migrated into the new secure store. The upgrade therefore requires a new WhatsApp OTP login for existing plaintext sessions. Other preferences, wallet records and chat recovery pointers are not bulk-cleared.

Browser and unsupported desktop targets use memory-only session persistence. Reloading the page/process requires fresh login. This is not an HttpOnly-cookie architecture and does not solve XSS, multi-tab revocation, cached routes or service-worker policy; those portions of M014 remain open.

Mandatory credential initialization precedes SDK session restoration. Failed startup exposes a confirmed reset of saved login and requires restart rather than concurrently reinitializing the SDK. Reset affects the scoped credential store/key, not the server account or pending financial/chat operations. A hung native call may require restarting the app; a timeout is not cancellation. Recovery wording is currently English and still requires promised-language/accessibility review.

## Verification actually completed

**671 local checks passed: 70 new and 601 rerun prior checks. The 70 new checks comprise 52 executable tests and 18 static source assertions. This is not an end-to-end test count.**

| Lane | Passed | Boundary |
|---|---:|---|
| New session cipher | 41 | Real JVM/JCA AES-GCM, ephemeral keys, wrong-key/AAD/tamper/size cases and temporary-file roundtrip; not AndroidKeyStore. |
| New guarded applier | 11 | Actual filesystem, path/symlink, drift and repeat-apply behavior. |
| New integration assertions | 18 | Static source/XML assertions; not Dart or native behavior. |
| Prior Python hardening | 253 | Selected mixed executable fixtures and source checks. |
| Prior push worker/provider | 70 | TypeScript/HTTP/crypto with explicit external fixtures. |
| Prior pure Edge modules | 66 | Existing Node module logic. |
| Prior Edge handlers | 138 | Existing Auth/database/SDK fixture substitutions. |
| Prior inference HTTP | 16 | Real bounded HTTP with fake model. |
| Prior NFC policy | 20 | Compiled JVM, not physical NFC. |
| Prior collector policies/leases | 38 | Compiled Kotlin and OS file leases, not WorkManager/device. |
| **Total** | **671** | **Local evidence only.** |

Swift syntax parsing succeeded; it did not typecheck Flutter/UIKit/Security APIs or build an iOS app. YAML/TOML/Python/shell syntax, Actions source pins and unchanged dependency/SQL-body checks passed. The exact guarded applier applied **31 files**, all expected hashes matched, and a second application changed **zero**. Independent Git patch checking/application produced the same 31 hashes. Source replacement is atomic per file, not one cross-file transaction.

Initial broad Python discovery exposed two static assertions tied to prior source locations, corrected to equivalent checks at the new shared implementation. That broad discovery also encountered absent PWA/web baseline dependencies and is not claimed passing. The final selected hardening lanes above pass. Initial Edge module-load failures were resolved by restoring unchanged files with exact current-index blob matches, not by fabricating replacement source. Initial and final evidence is retained separately.

The bounded export-pattern scan found only existing private-key delimiter parsing/ephemeral-test formatting strings, not embedded key material. This is not a complete repository/history credential audit. No private key files, signing stores, Git objects or live environment files are included.

## Unexecuted acceptance and source limitations

**Zero new Dart storage-controller, Flutter adapter/widget, Android Keystore or iOS Keychain behavioral tests were executed.** Their source is authored but the required Flutter/Dart, Android SDK/emulator and iOS runtime are unavailable here. Native builds, signed artifacts, actual backup/reinstall, locked-device, interrupted-I/O and session-switch cases still require evidence. The JVM suite is not a substitute for those tests.

Full PostgreSQL migration/role/transaction rehearsal, real Auth/PostgREST, native Deno entrypoints, live provider/device journeys, hosted CI and production release were not run. Earlier permission denial for the source-referenced Mobio Supabase project was respected; no alternative credentials or account workarounds were sought.

The baseline remains the previous overlay, selected original Drive files and partial current-index recovery. A complete canonical upstream main revision has not been established. Source IDs and before/after hashes are recorded. Tool availability and original dependency-load failures are not hidden by the passing-check total.

## Integration and remaining work

**Ship the native channel and Dart adapter in the same reviewed artifact.** A Dart-only update to an old native binary will fail closed because its storage channel is missing. Approve the forced fresh login, browser reload behavior, iOS background accessibility and preferences-backup implications before rollout. Do not restore plaintext fallback to work around a native failure. Follow `INTEGRATION_RUNBOOK.md` and test the existing admin/wallet/chat/SMS/push transition requirements as well.

Folder permissions were read again and still show anyone-with-link writer access. M001/M002 remain immediate owner/security work. No permissions, live credentials, financial records, databases, schedulers or flags were changed.

M010 has source implementation now but remains open for native acceptance. Full deletion/retention, remaining feature switches, localization/accessibility, broader callback cleanup, monitoring/recovery, operator/model acceptance and all other original backlog requirements remain tracked. The approved face-to-USSD scope is unchanged: no liveness, PIN capture, automatic debit or new settlement/routing engine was introduced.
