# Wallet, Referrals, and Driver Plus Validation - 2026-06-14

## Scope Implemented

- Token wallet ledger with wallet summaries, statement entries, and wallet-to-wallet transfers.
- Referral sharing flow with referral code creation, install/open tracking, signup completion, duplicate reward prevention, and 100-token reward only after verified install/signup completion.
- Android install referrer bridge and app-link invite route for referral attribution.
- Driver Mobio Plus subscription rules by vehicle type:
  - Moto taxi: 5,000 RWF monthly or 300 RWF daily.
  - Cabs, trucks, and trikes: 15,000 RWF monthly or 1,000 RWF daily.
  - Private vehicles: 30,000 RWF monthly or 5,000 RWF daily.
  - Bus: free forever.
  - Moto taxi, cabs, trucks, and trikes: welcome free tier capped at one passenger request per day for 30 days.
  - Private vehicles: no free tier.
- Subscription payment paths:
  - Tokens, debited from the driver's wallet and activated immediately.
  - MoMo USSD only, launching `*182*8*1*12345*{amount}#` from the app.
- Subscription payment reference format using the driver's six-digit member code plus a payment-intent fragment.
- MoMo SMS bridge reconciliation for subscription receipts, with exact reference matching first and conservative fallback matching by amount/member/timing only when unique.
- Driver entitlement enforcement in chat:
  - Locked drivers can see that passenger messages exist but message content is redacted.
  - Locked drivers cannot reply.
  - WhatsApp contact is hidden/inactive when the driver does not have Mobio Plus entitlement.
  - Upgrade CTA routes to Mobio Plus.
- Admin subscription operations visibility for recent payment requests and MoMo SMS receipts.

## Validation Commands Run

```sh
deno fmt supabase/functions/_shared/momo-sms.ts supabase/functions/_shared/momo-sms_test.ts supabase/functions/parse-sms/index.ts supabase/functions/reconcile-momo-sms/index.ts
deno test --allow-env supabase/functions/_shared/momo-sms_test.ts
deno check supabase/functions/parse-sms/index.ts supabase/functions/reconcile-momo-sms/index.ts
~/.codex/bin/supabase db push --dry-run
~/.codex/bin/supabase db lint --linked
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze
/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/release/wallet_driver_plus_contract_test.dart test/release/backend_scope_boundary_test.dart test/core/router/app_router_test.dart
JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home ./gradlew :app:compileDebugKotlin
ANDROID_TARGET_PLATFORMS=android-arm64 ANDROID_RELEASE_SHRINK=false ./scripts/release/build_android_release.sh apk
ANDROID_SERIAL=13111JEC215558 ANDROID_SMOKE_EVIDENCE_DIR=docs/release/evidence/wallet-driver-plus-android-smoke-2026-06-14 ./scripts/release/smoke_android_release.sh
./scripts/web/verify_public_site.sh landing
SKIP_FLUTTER_BUILD=true SUPABASE_URL=... SUPABASE_ANON_KEY=... PRIVACY_POLICY_URL=... ACCOUNT_DELETION_URL=... ./scripts/web/prepare_pwa_bundles.sh /tmp/mobi-pwa-assetlinks-check
npx --yes wrangler pages deploy landing --project-name=mobio --branch=main
ANDROID_HOME=/Users/jeanbosco/Library/Android/sdk ANDROID_SDK_ROOT=/Users/jeanbosco/Library/Android/sdk JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home gradle -p /Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge :app:compileDebugKotlin
ANDROID_HOME=/Users/jeanbosco/Library/Android/sdk ANDROID_SDK_ROOT=/Users/jeanbosco/Library/Android/sdk JAVA_HOME=/usr/local/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home MOMO_BRIDGE_SUPABASE_URL=... MOMO_BRIDGE_SECRET=... MOMO_BRIDGE_FUNCTION_PATH=reconcile-momo-sms MOMO_BRIDGE_ACCEPT_AFTER_MILLIS=1781429428000 gradle -p /Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge :app:assembleDebug
adb -s 13111JEC215558 install -r /Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge/app/build/outputs/apk/debug/app-debug.apk
adb -s 13111JEC215558 shell monkey -p com.firmos.momosmsbridge -c android.intent.category.LAUNCHER 1
adb -s 13111JEC215558 shell pm get-app-links rw.mobi.app
```

## Passed Evidence

- Deno MoMo SMS parser tests passed: 5 tests.
- Deno checks passed for `parse-sms` and `reconcile-momo-sms`.
- Flutter analyze passed with no issues.
- Focused Flutter contract/router tests passed.
- Final focused Flutter contract/router tests passed after the app-link and SMS bridge updates.
- Android Kotlin debug compile passed.
- Android arm64 release APK build passed.
- Physical Android smoke passed on device `13111JEC215558`.
- Public site verification passed with Android assetlinks coverage.
- Combined Pages/PWA bundle verification passed with Android assetlinks coverage.
- Cloudflare Pages deployment completed for project `mobio`, branch `main`.
- Live `https://mobio.ikanisa.com/.well-known/assetlinks.json` returns `application/json` and the expected `rw.mobi.app` fingerprint.
- Android domain verification for `rw.mobi.app` reports `mobio.ikanisa.com: verified`.
- MoMo SMS Bridge app compiled, built, and installed on device `13111JEC215558`.
- MoMo SMS Bridge app was launched with the cutoff-enabled build and did not upload historical queued SMS.
- Release APK evidence:
  - APK: `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `22e7abd33421202f2b22932f6daf6e8c1f1295f39314d061d1e0d9d7780157d2`
  - Version code: `12`
  - Version name: `1.0.0`
- Device smoke evidence:
  - Log: `docs/release/evidence/wallet-driver-plus-android-smoke-2026-06-14/smoke-20260614T085913Z.log`
  - Screenshot: `docs/release/evidence/wallet-driver-plus-android-smoke-2026-06-14/smoke-20260614T085913Z.png`
  - UI tree: `docs/release/evidence/wallet-driver-plus-android-smoke-2026-06-14/smoke-20260614T085913Z.xml`
- MoMo SMS Bridge APK evidence:
  - APK: `/Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge/app/build/outputs/apk/debug/app-debug.apk`
  - SHA-256: `7106958e99b948be09c2319589a14c115e7f38d9d9305d81599efadc2b35bf16`
  - Package: `com.firmos.momosmsbridge`
  - Version code: `1`
  - Version name: `1.0.0`
  - Device install: `Success`
  - Runtime permissions on device: `READ_SMS` and `RECEIVE_SMS` granted.
  - Upload cutoff: `1781429428000`.
  - Local queue count after launch: `42`.
  - Safe-launch screenshot: `/Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge/qa/mobio-bridge-cutoff-20260614.png`
  - Safe-launch UI tree: `/Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge/qa/mobio-bridge-cutoff-20260614.xml`

## Supabase Status

- `20260614120000_wallet_referrals_driver_plus.sql` was applied to project `paysnhuxngsvzdpwlosv`.
- `20260614124500_service_role_claim_compat.sql` was applied to support both flat and JSON Supabase JWT role claims for service-role-only SMS reconciliation.
- After applying the wallet/referral/driver-plus migrations, authenticated `supabase db push --dry-run` reported:

```text
Remote database is up to date.
```

- A later final dry-run reported a separate untracked rentals migration, `20260614153000_rentals_vehicle_type_onboarding.sql`. That migration is outside this wallet/referral/driver-plus scope and was not applied in this pass.
- Local Supabase execution was not available because Docker was not reachable:

```text
Cannot connect to the Docker daemon at unix:///Users/jeanbosco/.docker/run/docker.sock.
```

- Linked database lint returned exit code 0 earlier in validation, but it also reported pre-existing remote extension-schema issues unrelated to this migration.

## Edge Functions

- `parse-sms` deployed to project `paysnhuxngsvzdpwlosv`, active version `29`, updated at `2026-06-14 09:12:33 UTC`.
- `reconcile-momo-sms` deployed to project `paysnhuxngsvzdpwlosv`, active version `14`, updated at `2026-06-14 09:12:35 UTC`.
- Both functions were deployed with JWT verification disabled so the separate SMS bridge app can call them without a user session.
- The functions now fail closed unless `MOMO_SMS_BRIDGE_SECRET` or `SMS_BRIDGE_SECRET` is configured.
- `MOMO_SMS_BRIDGE_SECRET` was configured in Supabase with a generated secret value. The value was not printed or written into the repo.
- The secret was rotated again after updating and installing the configured MoMo SMS Bridge app, so the installed bridge APK and Supabase function share the current secret.
- CORS preflight for `https://mobio.ikanisa.com` allows `x-mobi-sms-secret` and `x-sms-bridge-secret`.

## Live Production Smoke

Run ID: `wdp_1781428418748_d9baa7`

Result:

```json
{
  "ok": true,
  "checks": [
    "rules: 30-day moto/cab/trike/truck and private no-trial visible",
    "referral: verified install credited 100 tokens and duplicate did not double-credit",
    "wallet: wallet-to-wallet transfer moved 20 tokens",
    "subscription tokens: 300-token moto daily payment activated Mobio Plus",
    "subscription MoMo: secret-protected USSD SMS bridge matched payment and activated Mobio Plus",
    "chat entitlement: private locked driver saw redacted passenger message and reply was blocked"
  ],
  "cleanup": "ok"
}
```

The smoke created temporary users/profiles/trips/payment requests/receipts and removed them successfully.

## MoMo SMS Bridge App

- The separate Android bridge app at `/Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge` now uploads to MOBI `reconcile-momo-sms`.
- It uses `x-mobi-sms-secret` and no Supabase service-role key.
- It uploads queued SMS one at a time and removes successfully uploaded message hashes even when a later queued SMS fails.
- A secret-protected diagnostic call to `reconcile-momo-sms` returned HTTP `200`; the diagnostic receipt was deleted afterward.
- The configured APK was installed with `adb install -r`, preserving existing app data.
- The configured APK was rebuilt with `MOMO_BRIDGE_ACCEPT_AFTER_MILLIS=1781429428000`, then launched on device `13111JEC215558`.
- Historical queued SMS were not uploaded after launch:
  - Queue before launch: `42`.
  - Queue after launch: `42`.
  - Latest production receipt check before launch: `[]`.
  - Latest production receipt check after launch: `[]`.
- The running bridge UI reports `Running` and `No new SMS / Queued: 42`.

Final bridge checks:

- `gradle -p /Volumes/PRO-G40/MEMORIES/apps/momo_sms_bridge :app:compileDebugKotlin`: passed.
- Installed package `com.firmos.momosmsbridge`: present on device `13111JEC215558`.
- Runtime SMS permissions: `READ_SMS` and `RECEIVE_SMS` granted.
- App process after safe launch: running.

## App Link Status

Device check:

```sh
adb -s 13111JEC215558 shell pm get-app-links rw.mobi.app
```

Previously reported:

```text
mobio.ikanisa.com: 1024
```

After deploying `landing/.well-known/assetlinks.json` to Cloudflare Pages and re-running Android verification, the device reports:

```text
mobio.ikanisa.com: verified
```

## 30-Day Correction

The free trial expiry is implemented as 30 days. A repository search for the previous incorrect longer-duration wording did not find any remaining feature text or logic using that value.

## Post-Review Hardening

- Follow-up migration `20260614165000_driver_subscription_momo_payer_phone_matching.sql` was applied to project `paysnhuxngsvzdpwlosv`.
- The migration keeps reference-code matching as the primary MoMo reconciliation path, and adds payer-phone snapshot/matching as a fallback discriminator when the fixed MoMo USSD string cannot transmit Mobio's internal reference code.
- Follow-up migration `20260614170000_driver_passenger_scheduled_chat_privacy.sql` was applied to project `paysnhuxngsvzdpwlosv`.
- The migration extends driver entitlement usage, reply blocking, and message redaction to passenger-authored scheduled trip posts, so drivers cannot bypass Mobio Plus by messaging passenger schedules directly.
- Post-push `supabase db push --dry-run` reported `Remote database is up to date`.
- Chat external-contact gating was tightened so locked driver conversations disable both WhatsApp and phone-call actions, leaving in-app chat as the only passenger contact path until Mobio Plus access is available.
- Preview TripService test doubles were aligned with the real `getNearbyTrips({role})` and `getCounterpartScheduledTrips(viewerMode)` API so `flutter analyze` is clean.
- Focused contract test after the hardening passed:
  - `/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/release/wallet_driver_plus_contract_test.dart`
- MoMo SMS parser tests after the hardening passed:
  - `deno test --allow-env supabase/functions/_shared/momo-sms_test.ts`
- `flutter analyze` was re-run after the hardening and passed with no issues.

## Second Audit Hardening

- Follow-up migration `20260614171500_driver_plus_helper_function_grants.sql` was applied to project `paysnhuxngsvzdpwlosv`.
- The migration revokes public/authenticated access to internal helper functions `_momo_phone_match(text, text)` and `_set_subscription_payment_request_payer_snapshot()`.
- Follow-up migration `20260614172000_driver_subscription_start_idempotency.sql` was applied to project `paysnhuxngsvzdpwlosv`.
- The migration adds `driver_subscription_payment_requests.client_request_id`, a unique `(profile_id, client_request_id)` index, and a 3-argument `rpc_start_driver_subscription(uuid, text, text)` so subscription starts are idempotent across duplicate client submissions.
- The Flutter driver-plus payment flow now sends `p_client_request_id` when starting token or MoMo USSD subscription payment requests.
- iOS Associated Domains entitlement now includes `applinks:mobio.ikanisa.com`.
- Public-site/PWA verification now validates Android `assetlinks.json`, emits proper headers for `/.well-known/apple-app-site-association`, and validates the AASA app ID when `APPLE_TEAM_ID` is supplied.
- Apple Team ID `63STJ5N27W` was provided for IKANISA LTD, so `landing/.well-known/apple-app-site-association` now declares `63STJ5N27W.rw.mobi.app` for `/invite/*`.
- iOS referral attribution now creates an `iosul_...` install proof when a referral invite is opened through an iOS Universal Link, and sends `install_proof: ios_universal_link_first_open` when completing signup.
- Referral attribution now clears stale pending install IDs when a later referral link does not carry a valid install proof.
- Post-push `supabase db push --dry-run` reported `Remote database is up to date`.
- Unauthenticated production Edge Function probe returned HTTP `401` with `SMS bridge unauthorized`, confirming `reconcile-momo-sms` is deployed and fails closed without the bridge secret.

Second audit verification:

- `/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze`: passed with no issues.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/release/wallet_driver_plus_contract_test.dart test/release/discoverability_privacy_contract_test.dart test/release/mobile_readiness_contract_test.dart`: passed.
- `deno test --allow-env supabase/functions/_shared/momo-sms_test.ts`: passed.
- `APPLE_TEAM_ID=63STJ5N27W ./scripts/web/verify_public_site.sh landing`: passed.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter test test/core/services/referral_attribution_service_test.dart test/release/wallet_driver_plus_contract_test.dart`: passed.
- `/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze`: passed with no issues after the iOS referral attribution update.
- `REQUIRE_IOS_FIREBASE=false FIREBASE_IOS_APP_ID="" ./scripts/ci/verify_ios_release.sh`: passed and built `build/ios/iphoneos/Runner.app`.
- Built iOS app evidence: `build/ios/iphoneos/Runner.app` is 39 MB, bundle id is `rw.mobi.app`, executable SHA-256 is `3dd22a4835ab0b5344dc08683d851b733989d1d3a37a3f8bb1d6ae4b2c4b86bc`.
- `~/.codex/bin/supabase db push --dry-run`: remote database is up to date.
- `curl -X POST https://paysnhuxngsvzdpwlosv.supabase.co/functions/v1/reconcile-momo-sms -d '{}'`: returned HTTP `401` and failed closed.
- `npx --yes wrangler pages deploy landing --project-name=mobio --branch=main --commit-dirty=true`: deployed the public site to Cloudflare Pages preview `https://be934b8a.mobio-1h0.pages.dev`.
- Live `https://mobio.ikanisa.com/.well-known/apple-app-site-association` returned HTTP `200`, `content-type: application/json; charset=utf-8`, and `63STJ5N27W.rw.mobi.app`.

## Final Scope Notes

- Code-owned wallet/referral/driver-plus gates from this pass are closed and deployed.
- Android referral install proof is implemented through Play Install Referrer and verified app links.
- iOS universal-link entitlement is now present and production AASA is live on `mobio.ikanisa.com`.
- iOS referral reward proof is implemented as first-open Universal Link proof (`iosul_...`) because Apple does not expose an Android-style user-level App Store install referrer to the app.
- iOS Firebase remains intentionally absent from this no-codesign build proof because no real `FIREBASE_IOS_APP_ID` or `ios/Runner/GoogleService-Info.plist` is checked in; Firebase services disable themselves on iOS when the app id is missing and do not block wallet/referral/driver-plus flows.
