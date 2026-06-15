# BioPay NFC Card UAT Evidence

Generated: 2026-06-15T11:09:28Z
Repository: /Volumes/PRO-G40/MOBI/mobi_app
Device: 13111JEC215558
Package: rw.mobi.app
APK: build/app/outputs/flutter-apk/app-release.apk
APK SHA-256: 37bdce8333272ddf704c11c2196b1afe2ccf4b84fa7d5bf4ea51e83063dd6088
HTTPS payload: https://mobio.ikanisa.com/biopay/nfc?type=momo_pay_code&receiver=123456

## Automated Checks
- PASS: device exposes NFC feature
- PASS: device NFC service is on
- PASS: installed package has NFC permission
- PASS: installed package has HTTPS NFC app link filter
- PASS: installed package has NDEF_DISCOVERED filter
- PASS: installed package has custom mobio scheme filter
- PASS: mobio.ikanisa.com is verified for installed package
- PASS: HTTPS NFC payload resolves to Mobio
- PASS: HTTPS NFC payload launches dialer handoff
- PASS: payload launch has no fatal app errors

## Evidence Files
- Device: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/device.txt
- Package dump: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/package.txt
- NFC service: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/nfc.txt
- App links: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/app-links.txt
- Intent resolution: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/intent-resolution.txt
- Payload launch logcat: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/payload-launch-logcat.txt
- HTTPS payload focus: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/https-payload-focus.txt
- Manual NFC card logcat: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/manual-card-logcat.txt
- Manual NFC card window: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/manual-card-window.txt
- Manual NFC card screenshot: docs/release/evidence/biopay-nfc-card-uat-2026-06-15-manual/manual-card-screenshot.png
