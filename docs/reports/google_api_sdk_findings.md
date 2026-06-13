# Google API And SDK Findings

Date: 2026-06-13
Repo: `/Volumes/PRO-G40/MOBI/mobi_app`

## Decision Boundary

Mobio does not support route computation inside the app. Google Routes API,
Compute Route Matrix, Directions API, Distance Matrix API, route ETA/duration,
route distance, route polylines, fare-distance basis, and dispatch-grade routing
are permanently out of context for this app. Do not list them as needed APIs,
SDKs, production-readiness gaps, roadmap items, or implementation tasks.

The approved map behavior is:

- Google Places/Geocoding through the server-side Supabase `maps-gateway`.
- Route labels and optional coordinates stored on scheduled trip posts.
- External Google Maps deep links for map display, navigation, traffic, route
  rendering, and trusted vehicle position viewing.
- `maps-gateway` returns `410` for `compute_route`.

## Current Implementation Findings

| Severity | Finding | Evidence | Required action |
| --- | --- | --- | --- |
| P0 | Route APIs are not needed and must stay absent. | `maps-gateway` rejects `compute_route`; scope tests and gateway tests guard no route/fare computation. | Keep route APIs excluded from docs, code, schema, CI, and store copy. |
| P1 | Places and reverse geocoding are implemented through a server-side gateway, which is the correct boundary for key protection. | `lib/core/services/places_service.dart` invokes `maps-gateway`; `supabase/functions/maps-gateway/index.ts` calls Places API New and Geocoding API. | Keep Google Maps Platform keys server-side only. |
| P1 | Maps gateway key resolution is now restricted to the server Maps secret. | Gateway requires `GOOGLE_MAPS_SERVER_API_KEY`; tests reject `GOOGLE_MAPS_API_KEY` and `GEMINI_API_KEY` fallback for Maps calls. | Keep production docs and deployment evidence standardized on `GOOGLE_MAPS_SERVER_API_KEY`; do not use Gemini keys for Maps Platform calls. |
| P1 | Maps gateway now has dedicated regression tests. | `supabase/functions/maps-gateway/index_test.ts` covers auth, Places autocomplete, place details, reverse geocode, Rwanda bounds, rate limit behavior, and permanent `compute_route` 410. | Keep this test in `scripts/ci/verify_backend.sh` and extend it before changing gateway behavior. |
| P1 | Places Autocomplete session tokens are wired end-to-end. | `PlaceAutocompleteField` generates a token per autocomplete selection flow; `PlacesService` forwards it to autocomplete and details calls. | Keep tokens ephemeral and reset them after selection or clear. |
| P2 | Query predictions are suppressed for the route-posting selection UI. | Gateway sets `includeQueryPredictions: false`; client filters non-place suggestions and rejects empty place IDs before details calls. | Do not re-enable query predictions unless a separate text-search selection flow exists. |
| P1 | Android Firebase is configured; iOS Firebase is partially runtime-defined. | Android has `android/app/google-services.json`; iOS currently relies on Dart defines and has no checked-in `GoogleService-Info.plist`. | For iOS release, generate/verify FlutterFire iOS config, APNs capability/key, FCM token proof, and Crashlytics symbol upload proof. |
| P1 | FCM server send path exists, with production proof handled by non-secret evidence gates. | `send-push` uses FCM HTTP v1 service account secrets; go/no-go now requires `FCM_HTTP_V1_SECRET_VALIDATED` and `FCM_HTTP_V1_SECRET_EVIDENCE`. | Validate `FIREBASE_SERVICE_ACCOUNT_JSON` or split service account secrets in the deployment environment with non-secret evidence before release. |

## Needed Google APIs And SDKs

| Capability | Needed Google/Firebase API or SDK | Status |
| --- | --- | --- |
| Place autocomplete | Places API New, server-side via `maps-gateway` | Needed and implemented |
| Place details | Places API New, server-side via `maps-gateway` | Needed and implemented |
| Reverse geocoding | Geocoding API, server-side via `maps-gateway` | Needed and implemented |
| External map handoff | Google Maps URL deep links | Needed and implemented; no embedded Maps SDK required |
| Device location permission/GPS | Flutter `geolocator` and native OS permissions | Needed and implemented; Google Geolocation API is not needed |
| Android Firebase app config | Firebase Core plus checked-in Android registration | Needed and implemented |
| iOS Firebase app config | Firebase Core with iOS app registration and APNs setup | Needed before iOS release |
| Push notifications | Firebase Cloud Messaging client SDK and FCM HTTP v1 server send | Needed; client/server code exists, deployed secret proof still required |
| Analytics | Firebase Analytics | Needed as optional infrastructure; gated by Remote Config |
| Crash reporting | Firebase Crashlytics | Needed as optional infrastructure; release dSYM/symbol proof required |
| Feature flags | Firebase Remote Config | Needed as optional infrastructure; app defaults must remain safe |
| Firebase Auth bootstrap | Firebase Auth anonymous session, infrastructure only | Optional; does not replace Supabase auth |
| Embedded maps | Maps SDK for Android/iOS or Maps JavaScript API | Not needed; Mobio does not embed maps |
| Route ETA/distance/polyline | Google Routes API, Directions API, Distance Matrix API | Permanently not needed and out of context |
| Driver/passenger route matrix | Compute Route Matrix | Permanently not needed and out of context |

## Implementation Status

1. Implemented: `maps-gateway` accepts only `GOOGLE_MAPS_SERVER_API_KEY` for Google Maps Platform calls.
2. Implemented: `maps-gateway` unit tests cover autocomplete, details, reverse geocode, Rwanda boundaries, auth/rate limiting, and `compute_route` 410.
3. Implemented: Places Autocomplete session-token lifecycle is wired in Flutter and gateway calls.
4. Implemented: query predictions are suppressed/filtered so empty-place-ID selections cannot trigger details calls.
5. Release evidence required: run FlutterFire iOS configuration before iOS release and produce non-secret APNs/FCM/Crashlytics evidence.
6. Release evidence required: produce non-secret deployment evidence that FCM HTTP v1 service account secrets are configured for `send-push`.
7. Permanent rule: keep Google Routes API, Compute Route Matrix, Directions API, Distance Matrix API, ETA/distance/polyline/matrix, fare-distance, and dispatch-routing out of all Mobio implementation plans.

## Go/No-Go Evidence Variables

Set these only after the matching non-secret evidence file exists:

- `GOOGLE_MAPS_SERVER_SECRET_VALIDATED=true`
- `GOOGLE_MAPS_SERVER_SECRET_EVIDENCE=/path/to/evidence.md`
- `FCM_HTTP_V1_SECRET_VALIDATED=true`
- `FCM_HTTP_V1_SECRET_EVIDENCE=/path/to/evidence.md`
- `IOS_FIREBASE_APNS_VALIDATED=true`
- `IOS_FIREBASE_APNS_EVIDENCE=/path/to/evidence.md`
- `IOS_CRASHLYTICS_SYMBOLS_VALIDATED=true`
- `IOS_CRASHLYTICS_SYMBOLS_EVIDENCE=/path/to/evidence.md`
