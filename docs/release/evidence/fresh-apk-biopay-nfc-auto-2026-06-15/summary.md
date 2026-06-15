# BioPay NFC Card UAT Evidence

Generated: 2026-06-15T12:45:22Z
Repository: /Volumes/PRO-G40/MOBI/mobi_app
Device: 13111JEC215558
Package: rw.mobi.app
APK: build/app/outputs/flutter-apk/app-release.apk
APK SHA-256: 0a220ebfe1b316b694c5684b85aed3c0bb6cd3d6e9608abca41d109859da55cf
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
- FAIL: HTTPS NFC payload launches dialer handoff
- FAIL: payload launch has no fatal app errors

## Evidence Files
- Device: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/device.txt
- Package dump: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/package.txt
- NFC service: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/nfc.txt
- App links: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/app-links.txt
- Intent resolution: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/intent-resolution.txt
- Payload launch logcat: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/payload-launch-logcat.txt
- HTTPS payload focus: docs/release/evidence/fresh-apk-biopay-nfc-auto-2026-06-15/https-payload-focus.txt

Manual physical card write/read was not run. Set NFC_UAT_MANUAL_SECONDS to capture it.
