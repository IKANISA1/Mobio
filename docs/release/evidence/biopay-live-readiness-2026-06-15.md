# BioPay Live Readiness Evidence

Generated: 2026-06-14T22:08:53Z
Repository: /Volumes/PRO-G40/MOBI/mobi_app

## Result

- Checks run: 55
- Failures: 0
- Warnings: 0
- Live AWS required: true
- Live Supabase required: true
- Live Android device required: true
- Strict live proof required: true

## Checks

- PASS: BioPay route - lib/core/router/app_router.dart contains 'path: '/biopay''
- PASS: BioPay QR route - lib/core/router/app_router.dart contains 'path: '/biopay/qr''
- PASS: BioPay face scan route - lib/core/router/app_router.dart contains 'path: '/biopay/face-scan''
- PASS: BioPay enrollment route - lib/core/router/app_router.dart contains 'path: '/biopay/enroll''
- PASS: BioPay NFC route - lib/core/router/app_router.dart contains 'path: '/biopay/nfc''
- PASS: No public BioPay activity route - lib/core/router/app_router.dart does not contain 'path: '/biopay/activity''
- PASS: Admin BioPay route - lib/core/router/app_router.dart contains 'path: '/admin/finance''
- PASS: Profile BioPay enrollment entry - lib/features/profile/profile_screen.dart contains 'BioPay Face'
- PASS: Profile routes to enrollment - lib/core/router/screen_wrappers.dart contains 'context.push('/biopay/enroll')'
- PASS: USSD dialer handoff - lib/core/services/biopay_ussd_service.dart contains 'Uri.parse('tel:'
- PASS: Dial action copy - lib/features/biopay/biopay_flow_shared.dart contains 'Dial USSD'
- PASS: User paid claim copy - lib/features/biopay/biopay_flow_shared.dart contains 'I finished USSD'
- PASS: External confirmation copy - lib/features/biopay/biopay_admin_console_screen.dart contains 'Confirm external'
- PASS: Admin confirmations copy - lib/features/biopay/biopay_admin_console_screen.dart contains 'Confirmations'
- PASS: No admin Activity screen copy - lib/features/biopay/biopay_screen.dart does not contain 'title: 'Activity''
- PASS: External confirmation RPC - supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql contains 'rpc_confirm_biopay_ussd_external'
- PASS: Face scan preview start - lib/features/biopay/biopay_face_scan_screen.dart contains 'Start Face Scan'
- PASS: Face scan explicit match - lib/features/biopay/biopay_face_scan_screen.dart contains 'Match face'
- PASS: QR share uses safe payload - lib/features/biopay/biopay_flow_shared.dart contains 'data: buildBioPayQrPayload(request)'
- PASS: No visible raw USSD display - lib/features/biopay/biopay_flow_shared.dart does not contain 'request.ussdCode'
- PASS: No payment-intents dependency - lib/core/services/biopay_ussd_service.dart does not contain 'payment_intents'
- PASS: No in-app Pay command - lib/features/biopay/biopay_flow_shared.dart does not contain ''Pay''
- PASS: Face scan does not auto-open USSD - lib/features/biopay/biopay_face_scan_screen.dart does not contain 'openedRequest = await ussdService.openUssdDialer'
- PASS: Edge function slug - lib/core/services/biopay_face_service.dart contains 'biopay-face-provider'
- PASS: Liveness action - lib/core/services/biopay_face_service.dart contains 'create_liveness_session'
- PASS: Enroll action - lib/core/services/biopay_face_service.dart contains 'enroll_face'
- PASS: Match action - lib/core/services/biopay_face_service.dart contains 'match_face'
- PASS: AWS provider edge - supabase/functions/biopay-face-provider/index.ts contains 'aws_rekognition'
- PASS: AWS Rekognition API - supabase/functions/biopay-face-provider/index.ts contains 'rekognition'
- PASS: AWS collection status - supabase/functions/biopay-face-provider/index.ts contains 'provider_collection_id'
- PASS: AWS module versions - supabase/functions/biopay-face-provider/index.ts contains 'module_versions'
- PASS: Enrollment challenge metadata - supabase/functions/biopay-face-provider/index.ts contains 'enrollment_challenges'
- PASS: Enrollment sample metadata - lib/core/services/biopay_face_service.dart contains 'enrollment_sample_count'
- PASS: Explicit liveness status - lib/core/services/biopay_face_service.dart contains 'provider_liveness_not_required'
- PASS: Enrollment persistence RPC - supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql contains 'rpc_record_biopay_face_enrollment'
- PASS: No Google ML Kit dependency - pubspec.yaml does not contain 'google_mlkit_face_detection'
- PASS: No TFLite dependency - pubspec.yaml does not contain 'tflite_flutter'
- PASS: Android camera permission - android/app/src/main/AndroidManifest.xml contains 'android.permission.CAMERA'
- PASS: Android NFC permission - android/app/src/main/AndroidManifest.xml contains 'android.permission.NFC'
- PASS: No Android SMS read - android/app/src/main/AndroidManifest.xml does not contain 'android.permission.READ_SMS'
- PASS: No Android SMS receive - android/app/src/main/AndroidManifest.xml does not contain 'android.permission.RECEIVE_SMS'
- PASS: iOS camera usage - ios/Runner/Info.plist contains 'NSCameraUsageDescription'
- PASS: iOS NFC usage - ios/Runner/Info.plist contains 'NFCReaderUsageDescription'
- PASS: iOS NFC entitlement - ios/Runner/Runner.entitlements contains 'com.apple.developer.nfc'
- PASS: Deno edge check - biopay-face-provider compiles
- PASS: Deno edge tests - biopay-face-provider metadata contract passed
- PASS: Focused Flutter BioPay tests - feature, router, and boundary tests passed
- PASS: env SUPABASE_ANON_KEY - present
- PASS: Live AWS provider proof - HTTP 200 FACE_PROVIDER=aws_rekognition health at https://paysnhuxngsvzdpwlosv.supabase.co/functions/v1/biopay-face-provider/health
- PASS: env SUPABASE_ANON_KEY - present
- PASS: Live Supabase BioPay face health - HTTP 200 FACE_PROVIDER=aws_rekognition health at https://paysnhuxngsvzdpwlosv.supabase.co/functions/v1/biopay-face-provider/health
- PASS: Device camera feature - 13111JEC215558 exposes android.hardware.camera
- PASS: Device NFC feature - 13111JEC215558 exposes android.hardware.nfc
- PASS: Installed package permissions - rw.mobi.app requests camera and NFC
- PASS: USSD tel dialer capability - device resolves ACTION_DIAL tel: intent

## Boundary

Payment remains outside the app. BioPay only creates or resolves requests and opens a tel: USSD dialer handoff; external evidence is required for confirmed status.
