# Mo Mobio

Mo Mobio is a private in-house Android SMS collector for Mobio driver subscription MoMo payments.

It is intentionally minimal:

- listens only to new incoming SMS delivered after SMS access is enabled
- queues raw SMS locally
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

```bash
SUPABASE_URL=$SUPABASE_URL \
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
apps/momobio_sms_bridge/scripts/device_uat.sh
```
