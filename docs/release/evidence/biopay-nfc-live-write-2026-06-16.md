# BioPay NFC Live Write Evidence

Generated: 2026-06-16
Repository: /Volumes/PRO-G40/MOBI/mobi_app

## Result

- Strict BioPay live readiness: PASS, 55 checks, 0 failures, 0 warnings.
- AWS Rekognition edge health: PASS, live health endpoint returned `FACE_PROVIDER=aws_rekognition`.
- Supabase edge health: PASS, live BioPay face provider health endpoint returned HTTP 200.
- Android device capability proof: PASS on Pixel 4a `13111JEC215558` for camera, NFC, app permissions, and ACTION_DIAL `tel:` support.
- Patched release APK build: PASS, `build/app/outputs/flutter-apk/app-release.apk`.
- Patched release APK install: PASS on Pixel 4a `13111JEC215558`.
- Patched Write NFC route smoke: PASS with NFC restored to `mState=on`.

## NFC Writer Fix

The live device run reproduced the production NFC failure mode shown in the user screenshots: when Android redispatched the tag immediately after write/detect, the system NFC resolver or another NFC app could take focus before Flutter received the writer result.

The native Android writer now:

- Keeps the active writer result alive across transient pauses unless the activity is actually finishing or destroyed.
- Completes the Flutter writer result at the front of the main queue before disabling reader mode.
- Debounces the just-written tag with `NfcAdapter.ignore(...)` so Android does not immediately redispatch it to the resolver.
- Suppresses BioPay self-launch for a short window after writer completion so the write screen can settle on the verified result.

## Evidence Files

- Strict live readiness: `docs/release/evidence/biopay-live-readiness-strict-2026-06-16.md`
- First physical NFC run artifacts: `build/reports/biopay-nfc-live-20260616T080718Z/`
- Patched installed route smoke: `build/reports/biopay-nfc-installed-patched-20260616/write-card-route.png`
- Patched installed route UI tree: `build/reports/biopay-nfc-installed-patched-20260616/write-card-route.xml`

## Manual Boundary

The final post-patch physical card-write pass still depends on card handling: the card must be away from the phone until the Write action has started native reader mode. In the patched device attempt, the physical card remained in the NFC field and Android dispatched it before the writer owned reader mode, which is an OS-level resolver path rather than a writer failure.
