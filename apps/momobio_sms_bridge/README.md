# Mo Mobio

Mo Mobio is a private in-house Android SMS collector for Mobio driver subscription MoMo payments.

It is intentionally minimal:

- listens only to new incoming SMS delivered after SMS access is enabled
- queues raw SMS locally
- combines the ordered parts of a completed incoming SMS before hashing and queuing
- uploads raw SMS to MOBI Supabase through `momobio-sms-ingest`
- keeps an always-on foreground service notification while the phone is running
- schedules WorkManager network recovery so queued SMS sync resumes when internet is available
- starts recovery after boot and after app updates
- retries automatically until the queue is empty
- does not parse, match, or validate subscriptions on the device
- does not request `READ_SMS` and does not scan pre-install inbox messages
- does not include service-role, Postgres, OpenAI, or SMS bridge secrets

The backend parses each raw SMS through OpenAI inside Supabase Edge Functions, stores the receipt and transaction rows, and decides whether each SMS is unmatched, ambiguous, matched, duplicate, ignored, or confirms a driver subscription using `rpc_ingest_driver_subscription_momo_sms`.

Duplicate delivery is handled server-side. The receipt table is unique by SMS hash and provider transaction reference, and the transaction table is unique by receipt and provider transaction reference, so app retries or duplicate incoming SMS broadcasts do not create a second payment record.

## Build

```bash
SUPABASE_URL=https://<mobio-project>.supabase.co \
SUPABASE_ANON_KEY=<public-anon-key> \
../../android/gradlew :app:assembleRelease
```

From the repo root:

```bash
SUPABASE_URL=$SUPABASE_URL \
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
android/gradlew -p apps/momobio_sms_bridge :app:assembleRelease
```

## Device UAT

This operational UAT script grants SMS access and starts collection. Component
regressions should use the isolated QA package below.

```bash
SUPABASE_URL=$SUPABASE_URL \
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
apps/momobio_sms_bridge/scripts/device_uat.sh
```

## Isolated component tests

Run JVM codec, queue, multipart-decoding and upload-orchestration tests from the repository root:

```bash
android/gradlew -p apps/momobio_sms_bridge :app:testDebugUnitTest --offline
```

The small cached-compiler runner is available when a Gradle build is impractical:

```bash
python3 apps/momobio_sms_bridge/scripts/test_jvm.py --output build/qa/collector-jvm
```

It reads the generated constants from an actual QA build. If that file is absent,
run `android/gradlew -p apps/momobio_sms_bridge :app:generateQaBuildConfig --offline`
once. The runner does not create a substitute runtime configuration. Upload tests
use a synthetic connection and signer; they never open a socket or create a key.

Both use synthetic messages. The preference double tests concurrency and error
handling, but cannot establish Android disk persistence.

The `qa` build type uses `com.momobio.app.qa`, blank backend configuration and a
manifest without permissions, application components or automatic initialization.
Its instrumentation APK also requests no permissions. It has no collector UI and
cannot receive SMS or upload. Build both APKs without operational configuration:

```bash
android/gradlew -p apps/momobio_sms_bridge :app:assembleQa :app:assembleQaAndroidTest --offline
```

Verify and copy both built APKs before installing them on a fresh, dedicated emulator:

```bash
python3 apps/momobio_sms_bridge/scripts/verify_qa_apks.py --output build/qa/collector-apks
```

Use an explicit adb serial for every action. Run
`com.momobio.app.qa.test/androidx.test.runner.AndroidJUnitRunner` with
`adb -s SERIAL shell am instrument -w -r`. The six component tests check package
isolation, Android JSON and multipart PDU parsing, Keystore signatures, queue
concurrency and stored acknowledgements. Synthetic PDUs are parsed directly;
no SMS broadcast is sent. Run again after stopping the QA process and replacing
the QA APK without clearing its data to check continuity. These component checks
do not establish operational collection, backend matching, device power behavior
or release acceptance.
