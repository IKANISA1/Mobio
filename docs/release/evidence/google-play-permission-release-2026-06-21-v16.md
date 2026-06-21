# Google Play upload and permission declaration evidence - 2026-06-21

Timestamp: 2026-06-21 14:07:03 CAT
Package: rw.mobi.app
Version: 1.0.0+16
AAB: build/app/outputs/bundle/release/app-release.aab
AAB SHA256: 4d077cb48056a2cdf46a3427b885774d4935e4daca0d9b339493ade725a6dd3b
AAB size: 85.3 MB

Code changes:
- Restored android.permission.ACCESS_BACKGROUND_LOCATION.
- Restored android.permission.CALL_PHONE.
- Kept android.permission.FOREGROUND_SERVICE_LOCATION.
- Native USSD bridge uses ACTION_CALL when CALL_PHONE is granted and ACTION_DIAL fallback otherwise.
- Driver live sharing requests Permission.locationAlways only for background live sharing.
- In-app disclosure updated for background live driver sharing.

Build and validation:
- flutter analyze --no-pub: PASS.
- focused release/location/BioPay tests: PASS.
- scan_secrets.sh: PASS.
- Android release AAB build: PASS.
- Merged release manifests contain ACCESS_BACKGROUND_LOCATION, CALL_PHONE, FOREGROUND_SERVICE_LOCATION, android.intent.action.CALL, and GeolocatorLocationService foregroundServiceType="location".

Google Play:
- Uploaded build 16 to Google Play internal track as draft via fastlane supply.
- Play API verification: internal track version codes include [16, 3].
- Play Console App Content page opened in Chrome: title "App content | Mobio".
- Play Console Policy status page showed a privacy-policy rejection on 2026-06-21.
- Updated and deployed https://mobio.ikanisa.com/privacy-policy to disclose background location, BioPay, MoMo USSD, camera/face, NFC, wallet tokens, redemption, subscriptions, phone/USSD handoff, data retention, account deletion, and service providers.
- Live verification at 2026-06-21 14:30:19 CAT: https://mobio.ikanisa.com/privacy-policy?play_review=20260621 returned HTTP 200 and contained "Last updated: June 21, 2026", "background location", "BioPay", "MoMo USSD", and "info [at] ikanisa.com".

Pending UI-only work:
- Complete App Content declarations in Play Console using docs/release/google-play-sensitive-permissions-2026-06-21.md.
- Attach Android demo videos for background location and direct MoMo USSD handoff.
- Submit/send changes for review after declarations are complete.
