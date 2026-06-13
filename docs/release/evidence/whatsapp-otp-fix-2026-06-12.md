# WhatsApp Cloud OTP Fix Evidence - 2026-06-12

## Scope

- Fixed WhatsApp Cloud OTP delivery config resolution for app login and admin OTP functions.
- Fixed country-aware phone canonicalization for passenger/driver login,
  platform admin sign-in, and admin allowlist editing.
- Deployed only Supabase Edge Functions. No Android AAB rebuild was performed.

## Change

- `supabase/functions/_shared/whatsapp-cloud.ts`
  - Uses a complete `WHATSAPP_CLOUD_*` config when all Cloud keys are present.
  - Uses a complete legacy `WABA_*` config coherently when the Cloud namespace is incomplete.
  - Avoids mixing a newer access token with legacy phone/template IDs.
  - Captures sanitized Meta delivery error metadata without logging tokens.
- `supabase/functions/send-login-otp/index.ts`
  - Persists sanitized `delivery_error` metadata for app login OTP delivery failures.
- `supabase/functions/send-otp/index.ts`
  - Persists sanitized `delivery_error` metadata for admin OTP delivery failures.
  - Normalizes local-format admin phone numbers with `countryCode`.
  - Returns safe WhatsApp delivery failure copy instead of a generic internal
    error.
- `supabase/functions/verify-otp/index.ts`
  - Normalizes local-format admin phone numbers with `countryCode`.
- `lib/core/utils/phone_number_normalizer.dart`
  - Centralizes Dart-side country-aware E.164 normalization for app and admin
    OTP flows.
- `lib/shared/data/phone_country_codes.dart`
  - Provides a 245-entry global country/territory calling-code catalog for the
    WhatsApp input.
- `lib/shared/widgets/whatsapp_input.dart`
  - Uses the global catalog with searchable scrolling while preserving
    Supabase business-country metadata where available.
- `scripts/ci/verify_backend.sh`
  - Adds the WhatsApp Cloud config regression test to the backend gate.

## Local Verification

```text
deno fmt supabase/functions/_shared/whatsapp-cloud.ts supabase/functions/_shared/whatsapp-cloud_test.ts supabase/functions/send-login-otp/index.ts supabase/functions/send-otp/index.ts
deno check --frozen --lock=deno.lock supabase/functions/send-login-otp/index.ts supabase/functions/send-otp/index.ts
deno test --frozen --lock=deno.lock --allow-env supabase/functions/_shared/whatsapp-cloud_test.ts
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub test/core/utils/phone_number_normalizer_test.dart test/core/services/whatsapp_login_service_test.dart test/shared/data/phone_country_codes_test.dart test/models/country_test.dart
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze --no-pub
```

Result:

- Flutter focused tests passed, 11/11.
- Flutter analyzer passed with no issues.
- Deno function checks passed for `send-otp`, `verify-otp`, `send-login-otp`,
  and `verify-login-otp`.
- Deno OTP helper tests passed, 12/12.

## Linked Backend Gate

```text
SUPABASE_PROJECT_REF=paysnhuxngsvzdpwlosv REQUIRE_LINKED_SUPABASE=true scripts/ci/verify_backend.sh
```

Result:

- Secret scan passed.
- Edge Function checks passed.
- `biopay-api` tests passed, 2/2.
- OTP security tests passed, 2/2.
- Phone normalization tests passed, 5/5.
- WhatsApp Cloud tests passed, 5/5.
- CORS helper tests passed, 2/2.
- Linked Supabase DB lint passed.
- Linked backend security assertions passed.

## Deployment

Project: `paysnhuxngsvzdpwlosv`

- `send-login-otp`: ACTIVE version 10, updated `2026-06-12 15:48:32 UTC`.
- `verify-login-otp`: ACTIVE version 7, updated `2026-06-12 15:48:36 UTC`.
- `send-otp`: ACTIVE version 30, updated `2026-06-12 16:04:15 UTC`.
- `verify-otp`: ACTIVE version 24, updated `2026-06-12 16:04:19 UTC`.

## Remaining Live Proof

No approved real recipient phone was available during this run, so a real WhatsApp delivery receipt was not proven. Next approved app OTP attempt should either:

- return success and deliver the OTP over WhatsApp, or
- record sanitized Meta error details in `metadata.delivery_error` on the relevant audit table for exact follow-up.

## Device UI Regression Fixed

During unlocked Pixel 4a UAT, the WhatsApp login screen showed a `No internet
connection` banner even though Android reported validated Wi-Fi and shell ping
succeeded.

Fix:

- `lib/shared/widgets/connectivity_overlay.dart`
  - Empty connectivity results are treated as unknown instead of offline.
  - Offline state is debounced before showing the banner.
  - The banner is rendered only while offline.
- `scripts/qa/capture_android_uat_state.sh`
  - Removed `NotificationShade` from lock-screen detection to avoid false
    locked-device exits while the app is focused.
- `test/shared/widgets/connectivity_overlay_test.dart`
  - Covers empty connectivity results, offline debounce, and recovery before
    debounce expiry.

Verification:

```text
/Volumes/PRO-G40/flutter_3_44/bin/flutter test --no-pub test/shared/widgets/connectivity_overlay_test.dart test/core/utils/phone_number_normalizer_test.dart test/shared/data/phone_country_codes_test.dart
/Volumes/PRO-G40/flutter_3_44/bin/flutter analyze --no-pub
ANDROID_SERIAL=13111JEC215558 ANDROID_UAT_STEP=11-connectivity-overlay-fixed ANDROID_UAT_WAIT_SECONDS=8 scripts/qa/capture_android_uat_state.sh
```

Result:

- Flutter tests passed, 9/9.
- Flutter analyzer passed with no issues.
- APK versionCode `16` installed successfully on Pixel 4a.
- Post-fix UI tree and screenshot showed no `No internet connection` banner.

## Live Pixel OTP Retry

Device: Pixel 4a `13111JEC215558`

Result:

- Passenger WhatsApp OTP send was retried from the installed release APK.
- App reached the backend and returned the safe user-facing copy:
  `WhatsApp delivery failed. Please try again in a moment.`
- Latest `app_auth_attempts` metadata showed Meta Graph error:
  - status `404`
  - error code `132001`
  - error type `OAuthException`
  - message `Template name does not exist in the translation`
  - config source `waba_legacy`

Runtime diagnostics:

- Current WABA sender resolved through Meta Graph to verified name `IKANISA`
  and display number ending `27 51`.
- Current configured template name resolved inside the Edge runtime as
  `mobio_otp_code`.
- A temporary JWT/service-role-only diagnostic Edge Function was deployed,
  invoked, and deleted after use.
- A temporary test secret `WHATSAPP_CLOUD_TEMPLATE_LANGUAGE_CODE=en` was set,
  retested, and then unset because the error remained `132001`.

Conclusion:

- Flutter phone entry, country normalization, Supabase invocation, audit logging,
  and user-facing error handling are working.
- Live WhatsApp delivery is blocked by the deployed WABA/template configuration:
  the active sender/template pair does not have the `mobio_otp_code`
  translation available to Meta.
- Required fix is external configuration: set the Mobi WhatsApp Cloud sender
  phone number ID and an approved OTP authentication template name/language in
  Supabase secrets, or approve/add the missing template translation for the
  currently configured WABA.

## Sibling Template Reuse

The sibling repo implementations were checked for their WhatsApp Cloud OTP
template convention:

- MEMORIES / PICTURED uses `gikundiro` with `en_US`.
- PayLedger uses `gikundiro` with `en_US`.
- FANZONE defaults its WhatsApp OTP function to `gikundiro` with `en_US`.
- COOL requires `WHATSAPP_AUTH_TEMPLATE_NAME` and sends `en_US`.

Action:

```text
WABA_OTP_TEMPLATE_NAME=gikundiro
```

was set on project `paysnhuxngsvzdpwlosv`, replacing the previous live
template name `mobio_otp_code`.

Result:

- Pixel 4a retry advanced from the delivery-failure state to the `Enter OTP`
  screen.
- Latest `app_auth_attempts` row changed to:
  - status `otp_sent`
  - reason `OTP dispatched for app login.`
  - metadata stage `send_login_otp`

Remaining:

- Human-provided WhatsApp OTP code is required to complete verify-login and
  continue authenticated trips UAT.
