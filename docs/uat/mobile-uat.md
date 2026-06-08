# Mobile UAT Script

Last updated: 2026-05-23

Use a signed release or closed-testing build with production-like Supabase
configuration. Record device model, Android version, app version, tester account,
and screenshots for failures.

Before manual UAT, run the install/launch smoke on a connected Android device:

```bash
scripts/release/build_android_release.sh apk
scripts/release/smoke_android_release.sh
```

The smoke script writes evidence to `build/reports/android-smoke/` and fails if
no authorized device is attached or the app does not stay running after launch.

## Core Paths

1. Launch app with valid build defines; verify no config-error screen.
2. Log in with WhatsApp as passenger.
3. Create or edit passenger profile.
4. Open Home; verify bottom tabs are Home, Trips, Profile.
5. Grant location permission and open Nearby.
6. Filter by each vehicle type: moto, cab, truck, trike, private car.
7. Open a nearby profile/listing and start in-app chat.
8. Use WhatsApp handoff where a WhatsApp contact is available.
9. Create a scheduled trip post.
10. View it under Trips > Mine.
11. Cancel own scheduled trip post.
12. Switch/login as driver and publish availability/location.
13. Verify driver can discover passenger posts and communicate without any
    request/accept/dispatch lifecycle.
14. Verify BioPay, ledger, payment, QR, NFC, SMS, fare quote, start trip, and
    complete trip flows are not reachable from active UI.
15. In chat, open conversation options, submit a report, block the peer, and
    verify messaging becomes unavailable.
16. Unblock the peer from the same chat and verify messaging can resume.
17. Confirm app handles empty states, loading states, denied location, offline
    network, and failed chat send.

## Acceptance Criteria

- No hard crash.
- No active UI asks for SMS, camera, NFC, or payment permissions.
- Location permission copy matches nearby discovery only.
- Chat and WhatsApp handoff work without creating ride-request lifecycle rows.
- Report/block actions do not expose other users' moderation records.
- Blocked users cannot continue in-app chat until unblocked.
- Scheduled trip cancellation is only available to the post owner.
- Manual fare negotiation copy is visible where trip details are shown.
