# Institutional collector acceptance and recovery — 28 September 2026

**Status: procedure and engineering acceptance criteria; not an executed fleet drill.**
No production database, signing account, phone, SIM or operator account was changed.

## Preconditions and ownership

Assign a fleet custodian, payments reconciliation owner, release owner and privacy
contact. Approve dedicated devices/SIMs, the distribution channel, the observed
receipt format, sender/merchant/currency configuration and retention/recovery rules.
Do not use personal inboxes. Public-store SMS/foreground-service approvals, where
applicable, are separate from private source compilation. Do not claim those
approvals from this document.

Inventory the installed version and certificate, enrolled collector public-key
fingerprint, server revocation/expiry, pending/review counts and oldest receipt.
Do not place signing passwords, private device keys, raw receipt bodies, MoMo PINs,
full account numbers or authentication tokens in ordinary test logs or Drive reports.
The application must continue using the existing device key across a supported update.

## Version-bound device matrix

Record exact app hash/version/certificate, Android version, device model, SIM/operator,
filter fingerprint, server build/schema and approved synthetic or consented evidence.
Every row needs pass/fail/not-run, an evidence reference and accountable reviewer.

| Scenario | Required observation |
|---|---|
| Blank/invalid configuration | Collection disabled; no capture or network fallback |
| Notice declined or revoked | No new admission/upload scheduling; stored unresolved evidence retained |
| Changed policy with unchanged label | Fingerprint change requires renewed notice acceptance |
| Unrelated SMS / unapproved sender | No new local row and no outbound request for that body |
| Genuine supported receipt | Exact multipart content, timestamp and stable hash admitted once |
| Empty queue / absent enrollment | No false server verification; signed health rejected |
| Expired/revoked collector key | Server refuses; local evidence retained and enrollment state visible |
| Allocation disabled | Health distinct from allocation; receipt held for review without AI processing |
| Offline → online | Original receipt identity retained, bounded batches drain without double credit |
| Partial server acknowledgment | Only acknowledged known hashes lose local raw bodies |
| Lost HTTP response after server commit | Repeat submission yields one financial effect; operator reconciliation agrees |
| Concurrent UI/service/worker | Shared lease permits one uploader; pending work is not replaced |
| 429 / Retry-After / provider outage | Persisted bounded delay, no rapid resubmission loop or redirect |
| Crash during migration / acknowledgment | Either before or after transaction state survives, never partial deletion |
| Corrupt legacy row / database | Review/recovery state; no automatic deletion or clear-data workaround |
| Queue row/byte/disk capacity | Existing pending evidence preserved; refusal visible and reconciled |
| Pending age / ack retention | Old pending moves to review; only acknowledged history is pruned |
| Signed update / restart / reboot | Device identity and unresolved evidence retained; recovery behavior recorded |
| Force-stop / OEM battery restriction | Limitation visible; reconcile missed broadcasts instead of promising recovery |
| Dual-SIM / wrong personal SIM | Custodian verifies approved institutional configuration; sender filter is not SIM verification |
| Notification and accessibility | Meaningful state, TalkBack focus, readable counts/errors; no raw receipt or PIN exposed |

The current in-session tests are portable SQLite/JVM/Node tests, not results for
these device/operator scenarios. Existing WorkManager constraints do not establish
timing guarantees under all device states.

## Reconciliation and safe response

Reconcile trusted operator receipts with server admissions, review decisions and
activated invoices daily for the controlled pilot. Track missing, duplicated,
rejected, quarantined, ambiguous and matched records separately. A server health
acknowledgment or a local empty queue is not a payment-settlement receipt.

For a capacity, corrupt-storage, revoked-key or missed-broadcast warning: pause
collection when necessary; preserve the device and current evidence; notify the
named payments/fleet owner; reconcile from approved independent operator records.
Do not uninstall, clear app data, drop queue rows, change hashes or improvise an
invoice match merely to restore a green status. Do not send raw queue dumps through
ordinary email or a broadly shared folder. Establish and rehearse an approved
restricted recovery/quarantine workflow before launch; that UI/workflow is not
provided by this increment.

An existing exposed signing store must be classified and remediated using its
actual upload/app-signing role. This code does not rotate a key or attest that an
existing credential is safe. Preserve the supported update path and stop on a
certificate mismatch. Device-key enrollment and application signing are distinct.

## Rollout and rollback

1. Rehearse cumulative SQL/RLS/Auth changes on an isolated schema with production-like
   constraints. All six forward bodies remain unapplied in this delivery.
2. Exercise parser/allocator and unknown-result behavior with approved operator
   fixtures; do not enable allocation using synthetic example merchant/sender values.
3. Deploy compatible registry/health/ingest functions to staging, then verify the
   registry, configuration and maintained endpoints through authenticated calls.
4. Compile the exact managed-signing artifact and run the matrix on a small approved
   fleet. Confirm version monotonicity before replacement; do not allow downgrades.
5. Promote only with version-bound payments, security, privacy and operations approval.

For rollback, pause/suspend the affected feature and preserve queue/schema evidence.
Do not downgrade to the old permissive SMS allocator or debug-signed collector. A
queue-schema change requires a forward-repair or explicitly rehearsed compatible
reader; no automatic destructive downgrade exists.

## Primary documentation used for implementation review

- Android SQLiteOpenHelper API: https://developer.android.com/reference/android/database/sqlite/SQLiteOpenHelper
- Android WorkManager unique work/management: https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/manage-work
- Android application signing: https://developer.android.com/studio/publish/app-signing

These references describe platform behavior; organization-specific policies,
operator formats, signed artifacts and actual deployments need separate evidence.
