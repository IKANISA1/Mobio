# Google Play Sensitive Permissions Declaration - 2026-06-21

> Historical 21 June 2026 record. The upload command near the end now also
> requires the candidate manifest, separate artifact-bound approval, eleven
> reviewed receipts, and reviewer-controlled key documented in
> [release/README.md](README.md#android-candidate-and-play-promotion).

Package: `rw.mobi.app`

## App Access

Name:

`Google Play review account`

Username, email address, or phone number:

`+250788767816`

Password:

`123456`

Any other information required for access:

`Select Passenger, enter +250788767816, tap Send code, then enter OTP 123456. No WhatsApp message is required for this review account. To review Driver features, select Driver and use the same phone and OTP.`

## Permission Matrix

| Permission | Status | Product purpose | Play declaration |
| --- | --- | --- | --- |
| `ACCESS_FINE_LOCATION` | Declared | Nearby pickup, nearby drivers, driver live location | Data safety and location permissions |
| `ACCESS_COARSE_LOCATION` | Declared | Approximate location fallback | Data safety and location permissions |
| `ACCESS_BACKGROUND_LOCATION` | Declared | Driver live sharing while the driver is online, including when the app is minimized | Background location declaration required |
| `FOREGROUND_SERVICE` | Declared | Android foreground service for live driver sharing | Foreground service declaration may be required |
| `FOREGROUND_SERVICE_LOCATION` | Declared | Android 14+ location foreground service type for live driver sharing | Foreground service location declaration may be required |
| `CALL_PHONE` | Declared | User-initiated MoMo USSD handoff via `tel:*182...%23` outside Mobio | Phone permission declaration required if Play prompts |
| `CAMERA` | Declared | BioPay face enrollment and payment confirmation | Data safety and camera access |
| `NFC` | Declared | BioPay NFC card/device reading and writing | NFC feature disclosure |
| `POST_NOTIFICATIONS` | Declared | Chats, trip posts, account updates | Notification runtime permission |
| `WAKE_LOCK` | Declared | Keep live driver location foreground service active while online | Foreground service support |

## Background Location Declaration

Core functionality:

`Mobio is a mobility and payment app. Driver live sharing is core to the mobility feature: drivers can explicitly go online and share their current location so passengers can find nearby available drivers.`

Why background location is needed:

`Mobio needs background location only for driver live sharing after a driver explicitly turns online. While online, the app publishes the driver's location so passengers can find nearby available drivers. This must continue when the driver switches apps or the screen is off because drivers commonly wait for passengers while using other apps. The driver can stop sharing at any time by going offline.`

Why foreground-only access is not enough:

`Foreground-only location would stop sharing when the driver leaves Mobio, making the driver disappear from nearby availability even though they intentionally stayed online. That breaks the driver availability feature and prevents passengers from finding online drivers.`

User benefit:

`Passengers can find nearby online drivers. Drivers remain discoverable while online and can stop sharing anytime.`

Data accessed:

`Precise or approximate device location, driver online status, heading and speed when available.`

How data is used/shared:

`Location is used only to update the driver's live availability and show nearby online drivers to passengers. It is not used for advertising and is not sold.`

Prominent disclosure shown in app:

`Allow background location so Mobio can share your driver location with passengers while you are online, even if you switch apps. Turn off sharing anytime by going offline.`

Demo video script:

`Open Mobio. Sign in with the Google Play review account. Switch to Driver. Open the driver/home sharing control. Tap the control to go online. Show the live location disclosure. Grant foreground location, then grant background location. Show the foreground notification "Mobio live location" with the text "Mobio is sharing your driver location while you are online." Press Home or switch apps while the notification remains active. Reopen Mobio and tap offline to stop sharing.`

## Phone / CALL_PHONE Declaration

Core functionality:

`Mobio supports MoMo USSD payment handoff. When a user chooses MoMo USSD, Mobio opens the phone app with a tel:*182...%23 code so the user can complete payment outside Mobio through the mobile network USSD flow.`

Why `CALL_PHONE` is needed:

`CALL_PHONE is used only for user-initiated MoMo USSD handoff. The app attempts ACTION_CALL for tel:*182...%23 after the user taps the MoMo USSD payment action, so the Android phone app launches the USSD session directly outside Mobio. If the permission is denied or direct call is unavailable, Mobio falls back to ACTION_DIAL.`

Limitations:

`Mobio does not read call logs, does not monitor calls, does not place arbitrary calls, and does not use CALL_PHONE for advertising or analytics.`

Demo video script:

`Open BioPay or Driver Plus payment. Select MoMo USSD. Show the MoMo USSD payment action. Tap the action. Show the phone permission prompt if it appears. Grant permission. Show Android opening the external phone/USSD flow with a tel:*182...%23 code. Return to Mobio.`

## Foreground Service Location Declaration

Foreground service type:

`location`

Play Console status:

`Updated on 2026-06-21. The declaration now uses User-initiated location sharing and links to https://mobio.ikanisa.com/play-review/foreground-location-demo. The change was sent for Google Play review.`

Purpose:

`Driver live sharing while the driver is online.`

User visible notification:

Title: `Mobio live location`

Text: `Mobio is sharing your driver location while you are online.`

Start condition:

`The foreground service starts only after the signed-in driver explicitly enables live sharing/goes online.`

Stop condition:

`The foreground service stops when the driver goes offline or live sharing is cancelled.`

## Privacy Policy / Store Listing Notes

Store listing and privacy policy must disclose:

- Driver location may be collected in the background while the driver is online.
- Location is used to show nearby online drivers to passengers and support mobility matching.
- Drivers can stop live sharing by going offline.
- MoMo USSD handoff opens the phone app outside Mobio using `tel:*182...%23`.

## Required Play Console Work

1. App access: use the review account above.
2. Foreground service / Location foreground service declaration: completed and sent for review with `https://mobio.ikanisa.com/play-review/foreground-location-demo`.
3. Sensitive app permissions / Background location: complete or update if Play prompts after the v17 bundle is uploaded.
4. Phone permission declaration: complete if Play prompts for `CALL_PHONE` after the v17 bundle is uploaded.
5. Upload the v17 app bundle that includes restored permissions and the fixed BioPay NFC intent filters.
6. Send the release for review after all App content items show complete.

Current upload blocker:

`The optimized v17 AAB is built, but this machine does not currently have a usable Google Play Android Publisher service-account JSON. The local gcloud accounts also require interactive reauthentication before direct Play Developer API upload can proceed.`

Validated upload command after the credential blocker is removed:

```bash
PLAY_RELEASE_TRACK=production \
PLAY_RELEASE_STATUS=completed \
PLAY_PRODUCTION_APPROVED=true \
./scripts/release/upload_google_play_release.sh
```
