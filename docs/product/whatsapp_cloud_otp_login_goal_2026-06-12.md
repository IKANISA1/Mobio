# WhatsApp Cloud OTP Login Goal and Gap Review

Date: 2026-06-12
Scope: Flutter app login UI/UX, Dart client service, Supabase Edge Functions,
WhatsApp Cloud sender, OTP audit trail, and release/UAT proof.

## Goal

Make WhatsApp Cloud OTP login production-reliable for passenger and driver app
sessions:

- clean phone entry with canonical E.164 delivery target;
- clear send, resend, verify, error, and lockout states;
- backend-generated OTP with rate limits, hashed storage, short expiry, and
  structured audit events;
- WhatsApp authentication-template delivery compatible with OTP button
  requirements;
- no provider secrets or raw OTP values exposed to clients, logs, reports, or
  tests;
- verified end-to-end on the Pixel 4a from OTP send through authenticated trip
  scheduling and trip detail access.

## Current Flow

1. Flutter `WhatsAppLoginScreen` collects passenger/driver role and WhatsApp
   phone.
2. `WhatsAppLoginService.sendLoginOtp` posts to `/send-login-otp`.
3. `send-login-otp` normalizes phone, applies rate limits, stores a hashed OTP,
   sends a WhatsApp Cloud template, and records `app_auth_attempts`.
4. Flutter collects a 6-digit OTP and calls `/verify-login-otp`.
5. `verify-login-otp` validates the hash, creates or updates a Supabase Auth
   user/profile, marks the OTP verified, and returns a Supabase session.
6. Flutter restores the Supabase session and enters the passenger/driver app
   shell.
7. Platform admin sign-in uses the same WhatsApp input widget, then calls
   `/send-otp` and `/verify-otp` against the allowlisted admin number table.

## Findings

| ID | Area | Gap | Risk | Status |
| --- | --- | --- | --- | --- |
| OTP-01 | WhatsApp API payload | Sender only supplied the OTP in the template body. Authentication templates with OTP buttons require button support; provider guidance says the code is part of the OTP-button flow and must be supplied in the send payload. | High: likely delivery failure or template parameter rejection. | Fixed in code: body plus button component now sent by default; legacy disable knob available. |
| OTP-02 | Phone canonicalization | Flutter could combine `+250` with `0788...` and send `+2500788...`; backend send/verify did not use `countryCode` for local-number normalization. | High: OTP sent to wrong/invalid recipient even when user entered a valid local phone. | Fixed in Flutter and Edge Functions. |
| OTP-03 | Client success handling | Client discarded backend success metadata and always returned a constant success message. | Medium: resend/cooldown messaging could drift from backend truth. | Fixed for send success message and retry metadata. |
| OTP-04 | Delivery error UX | Backend recorded provider error metadata but returned generic `Internal error` to the app. | Medium: user sees a false network/internal error and support loses signal. | Fixed: delivery failure returns safe 502 copy while audit keeps sanitized provider details. |
| OTP-05 | UI input hygiene | Phone field accepted arbitrary formatting and OTP field did not advertise one-time-code autofill. | Medium: avoidable input mistakes and slower verification. | Fixed: digits-only local input, max length, OTP autofill hint. |
| OTP-06 | Test coverage | No focused Dart tests for WhatsApp login normalization and no Deno tests for country-aware phone normalization. | Medium: regressions likely during later auth edits. | Fixed with targeted Dart/Deno tests. |
| OTP-07 | Real device proof | Pixel 4a UAT was initially blocked by ADB/USB disconnection, then by an outdated installed APK, and is now blocked by the device PIN lock screen. | High for release claim: no end-to-end proof yet. | Open. Fresh release APK versionCode 15 is installed and launch is focused behind the lock screen. Requires human unlock plus received OTP code. |
| OTP-08 | One-tap autofill | App does not implement WhatsApp one-tap handshake/signature-hash flow. | Low for current copy-code release, medium for best UX. | Deferred goal; copy-code OTP remains acceptable. |
| OTP-09 | Country-code coverage | Runtime country picker was tied to the Supabase business-country catalog, and offline/initial fallback previously covered only a small market subset. | Medium: login degraded to hardcoded markets and could block valid WhatsApp numbers outside the transport/payment country catalog. | Fixed: WhatsApp input now uses a separate 245-entry global calling-code catalog with search; Supabase countries only enrich active business-country labels/placeholders. Contract tests added for both global calling codes and the 48 active business-country fallback. |
| OTP-10 | Admin OTP parity | Platform admin OTP still built phone numbers by string concatenation and admin Edge Functions accepted only already-canonical phone values. | High: an allowlisted admin using a local number such as `0788...` or a non-Rwanda country code could be denied or sent to the wrong canonical phone. | Fixed: admin UI, allowlist editor, `/send-otp`, and `/verify-otp` now use the same country-aware normalizer as passenger/driver login. `send-otp` returns safe WhatsApp delivery failure copy instead of generic internal error. |

## Fix Checklist

- [x] Canonicalize phone numbers in Flutter before send/verify.
- [x] Canonicalize phone numbers with `countryCode` in Edge Functions.
- [x] Include WhatsApp OTP button component by default in Cloud API template
      sends.
- [x] Preserve a legacy template escape hatch:
      `WHATSAPP_CLOUD_OTP_AUTH_BUTTON=false`.
- [x] Return a safe user-facing delivery failure instead of generic internal
      error.
- [x] Keep sanitized provider diagnostics in `app_auth_attempts.metadata`.
- [x] Add backend tests for phone normalization and OTP template components.
- [x] Add Flutter tests for phone normalization and send readiness.
- [x] Expand WhatsApp phone input to the full global country calling-code
      catalog.
- [x] Keep the Supabase business-country fallback aligned to all 48 active
      countries.
- [x] Add Flutter contract tests for the global calling-code catalog and the
      active business-country fallback catalog.
- [x] Apply country-aware normalization to platform admin OTP send/verify and
      admin allowlist editing.
- [x] Deploy updated `send-login-otp`, `send-otp`, `verify-login-otp`, and
      `verify-otp`.
- [x] Re-run linked backend gate after deploy.
- [ ] Complete Pixel 4a UAT:
  - [ ] passenger OTP send
  - [ ] passenger OTP verify
  - [ ] authenticated home
  - [ ] schedule trip
  - [ ] trips list/detail
  - [ ] edit/cancel where safe
  - [ ] driver OTP send/verify or driver role upgrade path
  - [ ] screenshots, UI dumps, and logcat evidence

## External References Used

- Supabase changelog checked on 2026-06-12; no new Edge Function breaking
  change was found for this path.
- Meta/WhatsApp Cloud API public Postman collection and provider-facing
  documentation describe authentication templates with OTP buttons and
  copy-code/one-tap behavior.

## Remaining Release Position

Code-owned OTP gaps are addressed and the updated Edge Functions are deployed.
The latest release APK is installed on Pixel 4a as versionCode 15. A 100/100
claim remains blocked until the device is manually unlocked and real Pixel 4a
UAT proves OTP delivery, verification, authenticated trip scheduling, and trip
details with screenshots/logcat.
