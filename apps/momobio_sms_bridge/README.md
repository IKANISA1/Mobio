# Mo Mobio institutional receipt collector

This Android application collects **new, explicitly configured institutional receipt
notifications**, not the historical inbox. It is a separate application from the
consumer Mobio app. A sender/marker match only minimizes collection; it does not
prove a payment. Supabase remains the allocation authority.

## Current implementation

Before collection, a custodian accepts the in-app notice and grants SMS access.
The stored notice is bound to a SHA-256 fingerprint of the complete filter policy;
changing senders or markers requires renewed acceptance. There are no production
sender or marker defaults. Use a dedicated institutional device and SIM. The code
does not authenticate the SIM owner or cryptographically authenticate an SMS sender.

Eligible messages are encoded and admitted to a private SQLite queue. All three
sync callers (UI, foreground service and WorkManager) use one OS-backed file lock.
Retries persist their next-attempt time and honor bounded Retry-After guidance.
An empty queue does not prove service health: a signed health request must confirm
that the server recognizes the collector. Enrollment health and automatic allocation
are displayed separately. Pausing collection revokes local notice acceptance and
stops future scheduled collection/upload attempts; a request already in flight may
finish. Revoking Android SMS permission also stops further capture.

The receiver does not request READ_SMS. Force-stop, device loss, an unreceived
broadcast, disk failure or a capacity refusal can leave missing receipts that need
operator reconciliation. There is no claim of guaranteed always-on collection.

## Queue limits and recovery

These are engineering defaults, not approved legal retention periods:

| Control | Source value / behavior |
|---|---|
| Sender/marker entries | 1–20 of each, literal case-insensitive comparisons |
| Raw SMS body | At most 8,192 UTF-8 bytes |
| Encoded local record | At most 12,288 bytes |
| Pending + quarantined records | At most 10,000 records and 16 MiB of payload |
| Per request | At most 50 records, bounded by a 400,000-byte envelope budget |
| Response | At most 262,144 bytes |
| Acknowledged raw bodies | Removed transactionally; this is not cryptographic erasure |
| Acknowledgment hash history | At most 100,000 entries / 90 days |
| Unresolved pending receipts | After 30 days move to quarantine, not silent deletion |
| Empty healthy probe | No more frequently than five minutes through the shared lease |
| UI health freshness | Prior server acknowledgment expires after 15 minutes |
| Retry | Exponential 30 seconds to one hour plus up to 25% jitter; server Retry-After capped at seven days |

Queue capacity never evicts pending evidence to accept a newer record. It refuses
new admission and records a visible reconciliation warning. Oversized or malformed
legacy storage is not cleared: upgrade stops for supervised recovery. Parseable
legacy messages and acknowledgment history migrate in one transaction; malformed
rows are quarantined. Legacy preferences are cleared only after the database commit.
The SQLite corruption handler preserves evidence rather than accepting automatic
file deletion. The dedicated fleet still needs an authorized, tested recovery and
quarantine-resolution procedure before operational rollout; no raw export or
release-from-quarantine UI is shipped in this increment.

## Build operational release

Use an approved signing identity and supply configuration through the build
host's protected environment/secret store. Do not commit secret values or put
passwords in shell history. Required variable names:

```
SUPABASE_URL
SUPABASE_ANON_KEY
COLLECTOR_POLICY_VERSION
COLLECTOR_ALLOWED_SENDERS
COLLECTOR_RECEIPT_MARKERS
COLLECTOR_KEYSTORE_PATH
COLLECTOR_KEY_ALIAS
COLLECTOR_KEYSTORE_PASSWORD
COLLECTOR_KEY_PASSWORD
```

The backend URL must be one HTTPS origin, without credentials, path, query or
fragment. The public client key is not a service-role key. Sender/marker CSV values
must come from reviewed operator receipt fixtures, not the synthetic test examples.
Backend allocation configuration is separate and must also be reviewed.

From the repository root:

```bash
android/gradlew -p apps/momobio_sms_bridge --no-daemon :app:assembleRelease
```

Release tasks reject missing managed signing/filter configuration. The source
version is 1.0.1 / code 2: the release owner must reconcile it with the installed
fleet and bump it when necessary; no deployed version was inspected here.

## Non-destructive installation check

Set `ANDROID_SERIAL` for an explicitly selected authorized device and
`COLLECTOR_EXPECTED_CERT_SHA256` to the independently approved certificate digest.
Set `ADB` and `APKSIGNER` only when these executables are not on PATH. Then:

```bash
apps/momobio_sms_bridge/scripts/device_uat.sh
```

This builds with managed signing, verifies the exact certificate, and installs
with `adb install -r`. It does not use a debug signing key, grant SMS permissions,
clear data, uninstall, force-stop, enroll a collector or assert a paid result.
A signing mismatch is a stop condition, not permission to uninstall the old app.
The generated receipt proves only installation steps, never functional UAT.

## Testing boundaries

Portable tests run locally without an Android SDK or live provider:

```bash
python3 -m unittest discover -s scripts/tests -p test_collector_queue_contracts.py -v
node --experimental-transform-types --loader ./scripts/tests/edge/fixture-loader.mjs --test scripts/tests/edge/handlers.test.mjs
bash scripts/ci/run_hardening_tests.sh
```

The SQLite tests execute the actual shipped schema and DML via Python SQLite.
The JVM policy/lease tests compile production pure Kotlin and exercise real file
locks, including contention from a separate JVM. Neither substitutes for Android
SQLiteOpenHelper, WorkManager, Keystore, telephony, permissions or OEM behavior.

The permission-free QA package remains `com.momobio.app.qa`. It uses blank backend
and filter configuration and has no activities, providers, receivers or services:

```bash
android/gradlew -p apps/momobio_sms_bridge --no-daemon :app:testQaUnitTest :app:assembleQa :app:assembleQaAndroidTest
python3 apps/momobio_sms_bridge/scripts/verify_qa_apks.py --output build/qa/collector-apks
```

Run instrumentation only on the verified QA package and an explicit adb serial.
`DurableQueueDeviceTest` adds actual-adapter checks for migration, partial/unknown
acknowledgments, quarantine, expiry, concurrent admission, bounded batch size and
persisted backoff. These tests are authored but were not run in this increment's
execution environment. The cached-compiler helper still covers the legacy
preference-queue implementation; do not present those legacy tests as SQLite tests.

## Server rollout and unresolved gates

The signed `{ "action": "health" }` operation uses the existing collector
signature, registry, replay and rate gates. It parses no SMS and allocates nothing.
Disabled allocation, unapproved senders and missing merchant configuration are
held for server review **before** calling the AI parser. This does not implement
a new asynchronous durable intake worker: valid batch parsing is still sequential.
Large valid batches, partial completion and lost acknowledgments therefore still
need M032/provider-latency work. A connect/read timeout is not an overall deadline.

Do not deploy this collector over the original unsafe booking/identity/receipt
schema. Integrate the cumulative hardening patch, generate and review the six
forward migration bodies, rehearse the full schema, then deploy compatible Edge
functions before accepting an operational collector upgrade. All live financial,
Auth, device, store, privacy and signing-rotation acceptance remains separate.
See `docs/operations/collector-acceptance-2026-09-28.md`.
