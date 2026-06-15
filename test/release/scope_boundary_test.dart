import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production scope boundary', () {
    test(
      'Android manifest does not request inactive BioPay/SMS permissions',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(manifest, contains('android.permission.CAMERA'));
        expect(manifest, contains('android.permission.NFC'));
        expect(manifest, isNot(contains('android.permission.READ_SMS')));
        expect(manifest, isNot(contains('android.permission.RECEIVE_SMS')));
        expect(
          manifest,
          isNot(contains('android.permission.RECEIVE_BOOT_COMPLETED')),
        );
        expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
        expect(
          manifest,
          contains('android.permission.ACCESS_ADSERVICES_AD_ID'),
        );
        expect(
          manifest,
          contains('android.permission.ACCESS_ADSERVICES_ATTRIBUTION'),
        );
        expect(manifest, contains('tools:node="remove"'));
        expect(manifest, isNot(contains('SmsReceiver')));
        expect(manifest, isNot(contains('BootReceiver')));
      },
    );

    test('iOS plist declares camera only for active BioPay scanning', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('NSCameraUsageDescription'));
      expect(plist, contains('NFCReaderUsageDescription'));
      expect(plist, contains('BioPay QR scanning'));
      expect(plist, contains('AWS-backed face enrollment'));
      expect(plist, contains('USSD dialer'));
      expect(plist, isNot(contains('face scan')));
      expect(plist, isNot(contains('scan BioPay faces')));
      expect(plist, isNot(contains('calculate routes')));
      expect(plist, isNot(contains('route calculation')));
      expect(plist, contains('nearby drivers and passengers'));
      expect(plist, contains('Google Maps handoff'));
    });

    test('profile edit flow does not expose BioPay handle editing', () {
      final editScreen = File(
        'lib/features/profile/edit_profile_screen.dart',
      ).readAsStringSync();
      final editProvider = File(
        'lib/features/profile/providers/edit_profile_provider.dart',
      ).readAsStringSync();
      final editState = File(
        'lib/features/profile/models/edit_profile_state.dart',
      ).readAsStringSync();

      expect(editScreen, isNot(contains('ProfileBiopaySection')));
      expect(editScreen, isNot(contains('profile_biopay_section.dart')));
      expect(editProvider, isNot(contains('bioPayServiceProvider')));
      expect(editProvider, isNot(contains('features/biopay')));
      expect(editState, isNot(contains('BiopayHandleType')));
    });

    test(
      'admin BioPay ops is explicit and legacy finance review is absent',
      () {
        final router = File(
          'lib/core/router/app_router.dart',
        ).readAsStringSync();
        final adminUi = File(
          'lib/features/admin/widgets/admin_ui.dart',
        ).readAsStringSync();
        final adminService = File(
          'lib/core/services/admin_service.dart',
        ).readAsStringSync();
        final complianceService = File(
          'lib/core/services/admin/admin_compliance_service.dart',
        ).readAsStringSync();
        final adminModels = File(
          'packages/shared-types/lib/src/models/admin/admin_models.dart',
        ).readAsStringSync();

        expect(
          File(
            'lib/features/admin/admin_finance_review_screen.dart',
          ).existsSync(),
          isFalse,
        );
        expect(router, isNot(contains('admin_finance_review_screen.dart')));
        expect(router, contains("path: '/admin/biopay'"));
        expect(router, contains("path: '/admin/finance'"));
        expect(router, contains("=> '/admin/biopay'"));
        expect(adminUi, isNot(contains("label: 'Finance'")));
        expect(adminUi, contains("label: 'BioPay'"));
        expect(adminUi, contains("route: '/admin/biopay'"));
        expect(adminUi, isNot(contains("route: '/admin/finance'")));
        expect(adminService, isNot(contains('listRiskFlags')));
        expect(adminService, isNot(contains('reviewRiskFlag')));
        expect(complianceService, isNot(contains('rpc_admin_list_risk_flags')));
        expect(complianceService, isNot(contains('admin-review-transaction')));
        expect(adminModels, isNot(contains('AdminRiskFlagItem')));
      },
    );

    test(
      'login copy stays within discovery, trips, chat, and profile scope',
      () {
        final loginScreen = File(
          'lib/features/auth/whatsapp_login_screen.dart',
        ).readAsStringSync();
        final screenWrappers = File(
          'lib/core/router/screen_wrappers.dart',
        ).readAsStringSync();

        expect(loginScreen, contains('WhatsApp login'));
        expect(loginScreen, isNot(contains('Verified WhatsApp required')));
        expect(
          loginScreen,
          isNot(contains('chat, payments, and profile data')),
        );
        expect(screenWrappers, contains('BioPay USSD handoff'));
        expect(screenWrappers, isNot(contains('Payment, ledger, BioPay')));
        expect(
          screenWrappers,
          isNot(contains('BioPay, dispatch lifecycle, and trip settlement')),
        );
      },
    );

    test('ride-request lifecycle is not shipped in active Flutter package', () {
      final providers = File(
        'lib/core/providers/service_providers.dart',
      ).readAsStringSync();

      expect(
        File('lib/core/services/ride_request_service.dart').existsSync(),
        isFalse,
      );
      expect(
        File('lib/shared/widgets/ride_request_sheet.dart').existsSync(),
        isFalse,
      );
      expect(File('lib/models/ride_request.dart').existsSync(), isFalse);
      expect(
        File('packages/shared-types/lib/models/ride_request.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          'packages/shared-types/lib/src/models/ride_request.dart',
        ).existsSync(),
        isFalse,
      );
      expect(providers, isNot(contains('rideRequestServiceProvider')));
      expect(providers, isNot(contains('RideRequestService')));
    });

    test('scheduled trip posts do not expose completed trip lifecycle state', () {
      final tripModel = File(
        'packages/shared-types/lib/src/models/trip.dart',
      ).readAsStringSync();
      final adminTrips = File(
        'lib/features/admin/admin_trips_screen.dart',
      ).readAsStringSync();
      final adminStats = File(
        'lib/features/admin/widgets/admin_stats_grid.dart',
      ).readAsStringSync();
      final adminModels = File(
        'packages/shared-types/lib/src/models/admin/admin_models.dart',
      ).readAsStringSync();
      final cleanupMigration = File(
        'supabase/migrations/20260501135000_scope_cleanup_scheduled_trip_post_status.sql',
      ).readAsStringSync();

      expect(tripModel, isNot(contains("JsonValue('completed')")));
      expect(adminTrips, isNot(contains("label: 'Completed'")));
      expect(adminTrips, isNot(contains("_statusFilter = 'completed'")));
      expect(adminStats, isNot(contains('completedTrips')));
      expect(adminStats, contains("label: 'Trip Posts'"));
      expect(adminModels, isNot(contains('completedTrips')));
      expect(cleanupMigration, isNot(contains("'completed_trips'")));
      expect(
        cleanupMigration,
        contains("coalesce(t.status, 'active') <> 'completed'"),
      );
    });

    test('BioPay is active but remains USSD and AWS bounded', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final proguard = File(
        'android/app/proguard-rules.pro',
      ).readAsStringSync();
      final mainActivity = File(
        'android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt',
      ).readAsStringSync();
      final iosAppDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final scopeDoc = File(
        'docs/product/biopay_ussd_aws_reactivation_scope_2026-06-12.md',
      ).readAsStringSync();
      final referenceMap = File(
        'docs/product/biopay_reference_screen_gap_map_2026-06-12.md',
      ).readAsStringSync();
      final biopayService = File(
        'lib/core/services/biopay_ussd_service.dart',
      ).readAsStringSync();
      final biopayAdminService = File(
        'lib/core/services/biopay_admin_service.dart',
      ).readAsStringSync();
      final biopayFaceService = File(
        'lib/core/services/biopay_face_service.dart',
      ).readAsStringSync();
      final profileScreen = File(
        'lib/features/profile/profile_screen.dart',
      ).readAsStringSync();
      final screenWrappers = File(
        'lib/core/router/screen_wrappers.dart',
      ).readAsStringSync();
      final biopayNfcScreen = File(
        'lib/features/biopay/biopay_nfc_screen.dart',
      ).readAsStringSync();
      final biopayQrExport = File(
        'lib/features/biopay/biopay_qr_export.dart',
      ).readAsStringSync();
      final biopayQrExportIo = File(
        'lib/features/biopay/biopay_qr_export_io.dart',
      ).readAsStringSync();
      final biopayQrExportStub = File(
        'lib/features/biopay/biopay_qr_export_stub.dart',
      ).readAsStringSync();
      final biopayScreen = [
        'lib/features/biopay/biopay_screen.dart',
        'lib/features/biopay/biopay_admin_console_screen.dart',
        'lib/features/biopay/biopay_face_enroll_screen.dart',
        'lib/features/biopay/biopay_face_scan_screen.dart',
        'lib/features/biopay/biopay_flow_shared.dart',
        'lib/features/biopay/biopay_home_screen.dart',
        'lib/features/biopay/biopay_nfc_screen.dart',
        'lib/features/biopay/biopay_nfc_write_card_screen.dart',
        'lib/features/biopay/biopay_qr_screen.dart',
        'lib/features/biopay/biopay_scan_screen.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final biopayModel = File(
        'lib/features/biopay/models/biopay_ussd_payment.dart',
      ).readAsStringSync();
      final iosEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final liveReadinessScript = File(
        'scripts/qa/verify_biopay_live_readiness.sh',
      ).readAsStringSync();

      for (final path in const [
        'lib/features/ledger',
        'lib/features/payments',
        'lib/core/services/biopay_service.dart',
        'packages/payments',
        'assets/ml',
        'pigeons/ledger_bridge.dart',
        'android/app/src/main/kotlin/com/mobi/ledger',
        'android/app/src/main/kotlin/rw/mobi/app/ledger',
      ]) {
        expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
      }
      expect(
        FileSystemEntity.typeSync('lib/features/biopay'),
        isNot(FileSystemEntityType.notFound),
      );

      for (final dependency in const [
        'mobi_payments',
        'google_mlkit_face_detection',
        'tflite_flutter',
        'local_auth',
        'flutter_secure_storage',
        'image_gallery_saver_plus',
        'pigeon',
      ]) {
        expect(pubspec, isNot(contains(dependency)));
      }

      expect(mainActivity, isNot(contains('LedgerApi')));
      expect(mainActivity, isNot(contains('LedgerApiImpl')));
      expect(mainActivity, contains('rw.mobi.app/biopay_qr_export'));
      expect(mainActivity, contains('savePngToGallery'));
      expect(mainActivity, contains('MediaStore.Images.Media'));
      expect(mainActivity, contains('Pictures/Mobio'));
      expect(iosAppDelegate, contains('rw.mobi.app/biopay_qr_export'));
      expect(iosAppDelegate, contains('savePngToGallery'));
      expect(iosAppDelegate, contains('UIImageWriteToSavedPhotosAlbum'));
      expect(iosInfoPlist, contains('NSPhotoLibraryAddUsageDescription'));
      expect(pubspec, contains('enable-swift-package-manager: false'));
      expect(
        FileSystemEntity.typeSync(
          'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        ),
        FileSystemEntityType.notFound,
      );
      expect(proguard, isNot(contains('tensorflow')));
      expect(proguard, isNot(contains('mlkit')));
      expect(proguard, isNot(contains('zxing')));
      expect(scopeDoc, contains('external-payment assistant'));
      expect(scopeDoc, contains('FACE_PROVIDER=aws_rekognition'));
      expect(scopeDoc, contains('USSD dialer'));
      expect(
        referenceMap,
        contains('Reference repo: `/Volumes/PRO-G40/BioPay`'),
      );
      expect(referenceMap, contains('Confirm Match'));
      expect(referenceMap, contains('hide the raw full USSD string'));
      expect(referenceMap, contains('BioPay Ops'));
      expect(referenceMap, contains('/admin/biopay'));
      expect(referenceMap, contains('RWF amount field'));
      expect(
        referenceMap,
        contains(
          'Face enrollment UI reference repo: `/Volumes/PRO-G40/MEMORIES`',
        ),
      );
      expect(referenceMap, contains('Center`, `Turn`, `Hold'));
      expect(
        referenceMap,
        contains('QR generation remains a payee/share surface'),
      );
      expect(referenceMap, contains('do not embed the raw USSD code'));
      expect(scopeDoc, contains('QR generation is a payee/share surface'));
      expect(scopeDoc, contains('must not embed the raw USSD code'));
      expect(biopayService, contains("Uri.parse('tel:"));
      expect(biopayService, contains('createPreviewRequest'));
      expect(biopayService, contains('resolvePreviewToken'));
      expect(biopayService, contains('createFaceMatchPaymentRequest'));
      expect(biopayService, contains('rpc_create_biopay_face_match_request'));
      expect(biopayService, contains('markUserPaid'));
      expect(biopayService, contains('rpc_mark_biopay_ussd_user_paid'));
      expect(biopayService, contains('recordDialerOpened'));
      expect(biopayService, contains('rpc_record_biopay_ussd_dialer_opened'));
      expect(biopayService, contains('listPaymentRequests'));
      expect(biopayService, contains('rpc_list_biopay_ussd_requests'));
      expect(biopayService, contains('confirmExternally'));
      expect(biopayService, contains('rpc_confirm_biopay_ussd_external'));
      expect(biopayService, isNot(contains('payment_intents')));
      expect(biopayAdminService, contains('rpc_admin_biopay_summary'));
      expect(biopayAdminService, contains('rpc_admin_biopay_list_payees'));
      expect(biopayAdminService, contains('rpc_admin_biopay_system_status'));
      expect(biopayAdminService, contains('rpc_admin_biopay_confirm_external'));
      expect(biopayAdminService, contains('faceService.health'));
      expect(biopayAdminService, contains('providerCollectionId'));
      expect(biopayAdminService, isNot(contains('payment_intents')));
      expect(biopayFaceService, contains('biopay-face-provider'));
      expect(biopayFaceService, contains('create_liveness_session'));
      expect(biopayFaceService, contains('enroll_face'));
      expect(biopayFaceService, contains('match_face'));
      expect(biopayFaceService, contains('liveness_required'));
      expect(biopayFaceService, contains('enrollment_sample_count'));
      expect(biopayFaceService, contains('enrollment_challenges'));
      expect(biopayFaceService, contains('provider_liveness_not_required'));
      expect(biopayFaceService, contains('provider_face_id'));
      expect(biopayFaceService, contains('rpc_record_biopay_face_enrollment'));
      expect(biopayFaceService, contains('provider_face_id'));
      expect(biopayFaceService, contains('provider_collection_id'));
      expect(biopayFaceService, contains('provider_collection_id'));
      expect(biopayFaceService, contains('model_version'));
      expect(biopayFaceService, contains('payment_boundary'));
      expect(biopayFaceService, contains('enrollmentStatus'));
      expect(biopayFaceService, contains("from('biopay_profiles')"));
      expect(biopayFaceService, contains('provider_subject_id'));
      expect(biopayFaceService, contains('Enroll AWS face identity'));
      expect(biopayFaceService, contains('AWS face identity ready'));
      expect(biopayFaceService, isNot(contains('google_mlkit')));
      expect(biopayFaceService, isNot(contains('tflite')));
      expect(profileScreen, contains('BioPay Face'));
      expect(profileScreen, contains('Write NFC Card'));
      expect(profileScreen, isNot(contains('Momo')));
      expect(profileScreen, isNot(contains('Google')));
      expect(screenWrappers, contains("context.push('/biopay/enroll')"));
      expect(
        screenWrappers,
        contains("context.push('/biopay/nfc/write-card')"),
      );
      expect(biopayNfcScreen, isNot(contains('Write NFC Card')));
      expect(biopayScreen, contains('Dial USSD'));
      expect(biopayScreen, contains('Generate QR Code'));
      expect(biopayScreen, contains("'Save'"));
      expect(biopayScreen, contains("'Share'"));
      expect(biopayQrExport, contains('if (dart.library.io)'));
      expect(biopayQrExport, contains('biopay_qr_export_io.dart'));
      expect(biopayQrExportIo, contains('MethodChannel'));
      expect(biopayQrExportIo, contains('savePngToGallery'));
      expect(biopayQrExportIo, contains('getTemporaryDirectory'));
      expect(biopayQrExportIo, contains('SharePlus.instance.share'));
      expect(biopayQrExportIo, contains('XFile'));
      expect(biopayQrExportIo, isNot(contains('return false;')));
      expect(biopayQrExportStub, contains('return false;'));
      expect(biopayScreen, isNot(contains('Share QR Code')));
      expect(
        biopayScreen,
        isNot(contains('ClipboardData(text: buildBioPayQrPayload(request))')),
      );
      expect(
        File(
          'test/features/biopay/biopay_payment_surfaces_test.dart',
        ).readAsStringSync(),
        contains("expect(find.text('Dial USSD'), findsNothing)"),
      );
      expect(biopayScreen, contains('Activate NFC'));
      expect(biopayScreen, isNot(contains('Receive with NFC')));
      expect(biopayScreen, isNot(contains('Tap to Pay')));
      expect(biopayScreen, isNot(contains('Prepare tap tag')));
      expect(biopayScreen, contains('Start Enrollment'));
      expect(biopayScreen, isNot(contains('AWS liveness session')));
      expect(biopayScreen, contains('Capture center'));
      expect(biopayScreen, contains('Capture turn'));
      expect(biopayScreen, contains('Finish enrollment'));
      expect(biopayScreen, contains('straight_1'));
      expect(biopayScreen, contains('turn_pose'));
      expect(biopayScreen, contains('straight_2'));
      expect(biopayScreen, contains('_FittedCameraPreview'));
      expect(biopayScreen, contains('BioPayFaceOvalGuide'));
      expect(biopayScreen, contains('BioPayPoseCueStrip'));
      expect(
        biopayScreen,
        contains('Camera permission is required to enroll your face'),
      );
      expect(biopayScreen, isNot(contains('Amount (RWF, optional)')));
      expect(biopayScreen, contains('AMOUNT'));
      expect(biopayScreen, contains('BioPayReceiveAmountField'));
      expect(biopayScreen, contains('GroupedWholeNumberTextInputFormatter'));
      expect(biopayScreen, contains('Number'));
      expect(biopayScreen, contains('Code'));
      expect(biopayScreen, isNot(contains('MoMo number / MoMo Pay code')));
      expect(biopayScreen, isNot(contains('No QR request')));
      expect(biopayScreen, contains('amountMinorFromController'));
      expect(biopayScreen, contains('optionalAmountMinorFromController'));
      expect(biopayScreen, contains('buildBioPayQrPayload'));
      expect(biopayScreen, contains('bioPayTokenFromPayload'));
      expect(biopayScreen, contains("'type': 'mobio_biopay_request'"));
      expect(biopayScreen, contains('BioPayAdminConsoleScreen'));
      expect(biopayScreen, contains('BioPay Ops'));
      expect(biopayScreen, contains('Confirmations'));
      expect(biopayScreen, isNot(contains("title: 'Activity'")));
      expect(biopayScreen, isNot(contains('_BioPayAdminSection.activity')));
      expect(
        biopayScreen,
        contains('AWS face identity and external USSD handoff'),
      );
      expect(biopayScreen, contains('Payee Directory'));
      expect(biopayScreen, contains('System Status'));
      expect(biopayScreen, contains('External USSD only'));
      expect(biopayScreen, contains('admin_external_reference'));
      expect(biopayScreen, contains('QrImageView'));
      expect(biopayScreen, contains('MobileScanner'));
      expect(biopayScreen, contains('BarcodeFormat.qrCode'));
      expect(biopayScreen, contains('DetectionSpeed.noDuplicates'));
      expect(biopayScreen, contains('autoZoom: true'));
      expect(biopayScreen, contains('FlutterNfcKit'));
      expect(biopayScreen, contains('writeNDEFRecords'));
      expect(biopayScreen, contains('CameraController'));
      expect(biopayScreen, contains('CameraPreview'));
      expect(biopayScreen, contains('resolveRequest'));
      expect(biopayScreen, contains('I finished USSD'));
      expect(biopayScreen, contains('Waiting confirmation'));
      expect(biopayScreen, contains("'Confirmation', value: 'External'"));
      expect(biopayScreen, contains('Confirm external'));
      expect(biopayScreen, isNot(contains('BioPayActivityScreen')));
      expect(biopayScreen, isNot(contains('listPaymentRequests')));
      expect(biopayScreen, isNot(contains('confirmExternally')));
      expect(biopayScreen, isNot(contains('No BioPay activity')));
      expect(biopayScreen, isNot(contains('View activity')));
      expect(biopayScreen, contains('No enrolled BioPay face matched'));
      expect(biopayScreen, contains('createFaceMatchPaymentRequest'));
      expect(biopayScreen, contains('Start Face Scan'));
      expect(biopayScreen, contains('Match face'));
      expect(
        biopayScreen,
        contains('Camera permission is required to scan your face'),
      );
      expect(
        biopayScreen,
        isNot(contains('openedRequest = await ussdService.openUssdDialer')),
      );
      expect(biopayScreen, isNot(contains('Capture with AWS face match')));
      expect(biopayScreen, isNot(contains('Preview scan')));
      expect(
        biopayScreen,
        isNot(
          contains("primaryLabel: _request == null\n          ? 'Scanning'"),
        ),
      );
      expect(biopayScreen, isNot(contains('request.ussdCode')));
      expect(biopayScreen, isNot(contains("'Pay'")));
      expect(biopayModel, contains('required this.token'));
      expect(biopayModel, contains("'token': token"));
      expect(iosEntitlements, contains('com.apple.developer.nfc'));
      expect(liveReadinessScript, contains('REQUIRE_BIOPAY_AWS_LIVE'));
      expect(liveReadinessScript, contains('REQUIRE_BIOPAY_SUPABASE_LIVE'));
      expect(liveReadinessScript, contains('REQUIRE_BIOPAY_DEVICE_LIVE'));
      expect(liveReadinessScript, contains('REQUIRE_BIOPAY_LIVE'));
      expect(liveReadinessScript, contains('require_aws_live=true'));
      expect(liveReadinessScript, contains('require_supabase_live=true'));
      expect(liveReadinessScript, contains('require_device_live=true'));
      expect(liveReadinessScript, contains('BIOPAY_FACE_HEALTH_URL'));
      expect(liveReadinessScript, contains('FACE_PROVIDER'));
      expect(liveReadinessScript, contains('aws_rekognition'));
      expect(liveReadinessScript, contains('AWS_REKOGNITION_COLLECTION_ID'));
      expect(liveReadinessScript, contains('Deno edge tests'));
      expect(liveReadinessScript, contains('Enrollment challenge metadata'));
      expect(liveReadinessScript, contains('Enrollment sample metadata'));
      expect(liveReadinessScript, contains('android.hardware.camera'));
      expect(liveReadinessScript, contains('android.hardware.nfc'));
      expect(liveReadinessScript, contains('android.intent.action.DIAL'));
      expect(liveReadinessScript, contains('tel:*182%23'));
      expect(liveReadinessScript, contains('Payment remains outside the app'));
    });

    test('Play Store text metadata matches marketplace scope', () {
      final metadataFiles = Directory('android/fastlane/metadata/android/en-US')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'));
      final metadata = metadataFiles
          .map((file) => file.readAsStringSync())
          .join('\n')
          .toLowerCase();

      expect(metadata, contains('nearby driver and passenger discovery'));
      expect(metadata, contains('whatsapp handoff'));
      expect(metadata, contains('manual fare'));
      expect(metadata, contains('does not process ride payments'));

      for (final prohibitedClaim in const [
        'biopay biometric',
        'mtn momo',
        'live location tracking',
        'real-time location tracking',
        'trip management',
        'book rides',
        'incoming ride requests',
        'acceptances and declines',
        'payment options',
      ]) {
        expect(metadata, isNot(contains(prohibitedClaim)));
      }
    });

    test('public website and policy pages match marketplace scope', () {
      final publicSiteFiles = Directory('landing')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.html'));
      final publicSite = publicSiteFiles
          .map((file) => file.readAsStringSync())
          .join('\n')
          .toLowerCase();

      expect(publicSite, contains('account deletion'));
      expect(publicSite, contains('nearby discovery'));
      expect(publicSite, contains('scheduled trip posts'));
      expect(publicSite, contains('whatsapp handoff'));
      expect(publicSite, contains('does not provide automatic fare quotes'));
      expect(publicSite, contains('does not process in-app ride payments'));

      for (final prohibitedClaim in const [
        'biopay biometric',
        'biometric payments',
        'pay with face',
        'pay instantly',
        'mtn momo',
        'route calculations',
        'enable ride booking',
        'ride bookings',
        'start a ride',
      ]) {
        expect(publicSite, isNot(contains(prohibitedClaim)));
      }
    });

    test('release builds require account deletion URL define', () {
      final config = File(
        'lib/core/config/supabase_config.dart',
      ).readAsStringSync();
      final releaseScript = File(
        'scripts/release/build_android_release.sh',
      ).readAsStringSync();
      final releaseConfig = File(
        'scripts/ci/verify_release_config.sh',
      ).readAsStringSync();
      final profileScreen = File(
        'lib/features/profile/profile_screen.dart',
      ).readAsStringSync();

      expect(config, contains('ACCOUNT_DELETION_URL'));
      expect(config, contains('hasAccountDeletionUrl'));
      expect(releaseScript, contains('"ACCOUNT_DELETION_URL"'));
      expect(releaseScript, contains('missing.append(key)'));
      expect(releaseScript, contains('Add them to .env or export them'));
      expect(releaseScript, contains(r'build_cmd=("$FLUTTER_BIN" build'));
      expect(releaseScript, contains('build appbundle --release --no-pub'));
      expect(releaseScript, contains('build apk --release --no-pub'));
      expect(releaseScript, contains(r'${#target_platform_args[@]}'));
      expect(releaseScript, contains(r'${#gradle_property_args[@]}'));
      expect(releaseConfig, contains('require_var ACCOUNT_DELETION_URL'));
      expect(releaseConfig, contains('REQUIRE_IOS_FIREBASE:-true'));
      expect(releaseConfig, contains('REQUIRE_IOS_NATIVE:-true'));
      expect(profileScreen, contains('SupabaseConfig.accountDeletionUrl'));
      expect(profileScreen, contains('Delete Account'));
    });

    test('release pipeline defaults to internal Play validation', () {
      final releaseWorkflow = File(
        '.github/workflows/release.yml',
      ).readAsStringSync();
      final ciWorkflow = File('.github/workflows/ci.yml').readAsStringSync();
      final fastfile = File('android/fastlane/Fastfile').readAsStringSync();
      final releaseConfig = File(
        'scripts/ci/verify_release_config.sh',
      ).readAsStringSync();
      final backendVerify = File(
        'scripts/ci/verify_backend.sh',
      ).readAsStringSync();
      final actionPinCheck = File(
        'scripts/ci/check_github_actions_pinned.sh',
      ).readAsStringSync();
      final secretHistoryCheck = File(
        'scripts/qa/check_secret_history.sh',
      ).readAsStringSync();
      final smokeScript = File(
        'scripts/release/smoke_android_release.sh',
      ).readAsStringSync();
      final goNoGoScript = File(
        'scripts/release/go_no_go_check.sh',
      ).readAsStringSync();
      final denoLock = File('deno.lock').readAsStringSync();
      final workflowFiles = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
          );

      expect(releaseWorkflow, contains("PLAY_RELEASE_TRACK || 'internal'"));
      expect(releaseWorkflow, contains('release_target:'));
      expect(releaseWorkflow, contains('default: android'));
      expect(releaseWorkflow, contains("inputs.release_target != 'android'"));
      expect(releaseWorkflow, contains("inputs.release_target == 'android'"));
      expect(releaseWorkflow, contains('REQUIRE_IOS_FIREBASE:'));
      expect(releaseWorkflow, contains('REQUIRE_IOS_NATIVE:'));
      expect(releaseWorkflow, contains('fetch-depth: 0'));
      expect(releaseWorkflow, contains("REQUIRE_SECRET_HISTORY_CLEAN: 'true'"));
      expect(releaseWorkflow, contains('SUPABASE_DB_PASSWORD'));
      expect(releaseWorkflow, contains("REQUIRE_LINKED_SUPABASE: 'true'"));
      expect(ciWorkflow, contains('SUPABASE_DB_PASSWORD'));
      expect(releaseWorkflow, isNot(contains('track: production')));
      expect(fastfile, contains('ENV.fetch("PLAY_RELEASE_TRACK", "internal")'));
      expect(fastfile, contains('require_production_approval!'));
      expect(fastfile, contains('lane :promote_to_production'));
      expect(fastfile, contains('PLAY_PRODUCTION_APPROVED=true is required'));
      expect(releaseConfig, contains('PLAY_RELEASE_TRACK:-internal'));
      expect(releaseConfig, contains('REQUIRE_SECRET_HISTORY_CLEAN:-false'));
      expect(releaseConfig, contains('scripts/qa/check_secret_history.sh'));
      expect(
        releaseConfig,
        contains('PLAY_PRODUCTION_APPROVED=true is required'),
      );
      expect(backendVerify, contains('deno.lock'));
      expect(backendVerify, contains('--frozen'));
      expect(backendVerify, contains(r'--lock="$deno_lock"'));
      expect(denoLock, contains('"version": "5"'));
      expect(denoLock, contains('"npm:@supabase/supabase-js@2"'));
      expect(actionPinCheck, contains('40-character commit SHAs'));
      expect(secretHistoryCheck, contains('fetch-depth: 0'));
      expect(
        secretHistoryCheck,
        contains('android/fastlane/play-store-service-account.json'),
      );
      for (final workflow in workflowFiles) {
        final usesLines = workflow.readAsLinesSync().where(
          (line) => RegExp(r'^\s*-?\s*uses:').hasMatch(line),
        );
        for (final line in usesLines) {
          expect(line, matches(RegExp(r'uses:\s+\S+@[0-9a-f]{40}\b')));
        }
      }
      expect(smokeScript, contains('apksigner'));
      expect(smokeScript, contains('verify --verbose --print-certs'));
      expect(smokeScript, contains(r'pidof "$package_name"'));
      expect(smokeScript, contains('write_android_signing_files.sh'));
      expect(smokeScript, contains('generated_signing_files'));
      expect(smokeScript, contains('rm -f android/key.properties'));
      expect(goNoGoScript, contains('REQUIRE_LINKED_SUPABASE=true'));
      expect(goNoGoScript, contains('source .env'));
      expect(goNoGoScript, contains('REQUIRE_SECRET_HISTORY_CLEAN=true'));
      expect(goNoGoScript, contains('REQUIRE_ANDROID_SIGNING=true'));
      expect(goNoGoScript, contains('RELEASE_TARGET:-all'));
      expect(goNoGoScript, contains('all|android|ios'));
      expect(goNoGoScript, contains('RELEASE_TARGET must be one of'));
      expect(
        goNoGoScript,
        contains(
          r'REQUIRE_IOS_FIREBASE="$([[ "$release_target" == "android" ]] && echo false || echo true)"',
        ),
      );
      expect(
        goNoGoScript,
        contains(
          r'REQUIRE_IOS_NATIVE="$([[ "$release_target" == "android" ]] && echo false || echo true)"',
        ),
      );
      expect(goNoGoScript, contains('PLAY_SERVICE_ACCOUNT_RETAINED'));
      expect(goNoGoScript, contains('PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE'));
      expect(goNoGoScript, contains('PLAY_CONSOLE_UPLOAD_VALIDATED'));
      expect(goNoGoScript, contains('PLAY_CONSOLE_UPLOAD_EVIDENCE'));
      expect(goNoGoScript, contains('require_evidence'));
      expect(goNoGoScript, contains('require_play_service_account_decision'));
      expect(goNoGoScript, contains('RUN_MOBIO_FEATURE_GATE'));
      expect(
        goNoGoScript,
        contains('Mobio integrated feature readiness gates'),
      );
      expect(goNoGoScript, contains('REQUIRE_BIOPAY_LIVE'));
      expect(goNoGoScript, contains('REQUIRE_BIOPAY_LIVE:-true'));
      expect(
        goNoGoScript,
        contains('scripts/qa/verify_mobio_feature_readiness.sh'),
      );
      expect(
        goNoGoScript,
        contains(r'set $evidence_name to an existing evidence file'),
      );
      expect(goNoGoScript, contains('must not point to an example template'));
      expect(goNoGoScript, contains('GO_NO_GO_DRY_RUN'));
      expect(goNoGoScript, contains('dry-run mode cannot approve production'));
      expect(goNoGoScript, contains('RUN_ANDROID_SMOKE=false is only allowed'));
      expect(goNoGoScript, contains('RUN_FLUTTER_GATE=false is only allowed'));
      expect(
        goNoGoScript,
        contains('RUN_MOBIO_FEATURE_GATE=false is only allowed'),
      );
      expect(goNoGoScript, contains('smoke_android_release.sh'));
      expect(goNoGoScript, contains('NO-GO'));
    });

    test('scheduled trips do not compute automatic routes or fares', () {
      final scheduleProvider = File(
        'lib/features/bookings/providers/schedule_trip_provider.dart',
      ).readAsStringSync();
      final routeForm = File(
        'lib/features/bookings/widgets/trip_route_form.dart',
      ).readAsStringSync();
      final chatComposer = File(
        'lib/features/chat/widgets/chat_composer.dart',
      ).readAsStringSync();
      final placesService = File(
        'lib/core/services/places_service.dart',
      ).readAsStringSync();
      final mapsGateway = File(
        'supabase/functions/maps-gateway/index.ts',
      ).readAsStringSync();
      final scheduleState = File(
        'lib/features/bookings/models/schedule_trip_state.dart',
      ).readAsStringSync();
      final routeMapCard = File(
        'lib/shared/widgets/route_map_card.dart',
      ).readAsStringSync();
      final sharedExports = File(
        'packages/shared-types/lib/mobi_shared_types.dart',
      ).readAsStringSync();

      expect(scheduleProvider, isNot(contains('computeRoute')));
      expect(scheduleProvider, isNot(contains('compute_route')));
      expect(scheduleProvider, isNot(contains('routeInfo')));
      expect(scheduleState, isNot(contains('RouteInfo')));
      expect(scheduleState, isNot(contains('isComputingRoute')));
      expect(routeForm, isNot(contains('RouteInfo')));
      expect(routeMapCard, isNot(contains('RouteInfo')));
      expect(sharedExports, isNot(contains('route_info.dart')));
      expect(File('lib/models/route_info.dart').existsSync(), isFalse);
      expect(
        File('packages/shared-types/lib/models/route_info.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          'packages/shared-types/lib/src/models/route_info.dart',
        ).existsSync(),
        isFalse,
      );
      expect(placesService, isNot(contains('computeRoute')));
      expect(placesService, isNot(contains('compute_route')));
      expect(mapsGateway, contains('Route calculation is outside Mobio scope'));
      expect(mapsGateway, isNot(contains('directions/v2:computeRoutes')));
      expect(
        routeForm,
        isNot(contains('route labels and optional coordinates only')),
      );
      expect(
        routeForm,
        isNot(contains('Fares and timing are agreed manually')),
      );
      expect(routeForm, isNot(contains('Save From')));
      expect(routeForm, isNot(contains('Save To')));
      expect(
        File('lib/core/services/chat_ai_service.dart').existsSync(),
        isFalse,
      );
      expect(
        File('lib/features/chat/models/chat_ai_assist.dart').existsSync(),
        isFalse,
      );
      expect(chatComposer, contains('Message about fare'));
      expect(chatComposer, isNot(contains('Message about price')));
    });

    test(
      'chat assist is removed and promo prompts stay inside manual fare scope',
      () {
        final promo = File(
          'supabase/functions/generate-promo-content/index.ts',
        ).readAsStringSync();
        final driverCard = File(
          'lib/shared/widgets/driver_card.dart',
        ).readAsStringSync();
        final nearbyScreen = File(
          'lib/features/nearby/nearby_screen.dart',
        ).readAsStringSync();
        final sharedExports = File(
          'packages/shared-types/lib/mobi_shared_types.dart',
        ).readAsStringSync();

        expect(
          File('supabase/functions/chat-assist/index.ts').existsSync(),
          isFalse,
        );
        expect(promo, isNot(contains('cashless payment')));
        expect(promo, isNot(contains("scan the driver's face")));
        expect(promo, contains("view the driver's profile"));
        expect(driverCard, isNot(contains('trip.price')));
        expect(nearbyScreen, contains('km away'));
        expect(sharedExports, isNot(contains('ride_request.dart')));
      },
    );

    test('historical docs defer to current limited marketplace scope', () {
      final schemaInventory = File(
        'docs/architecture/schema_inventory.md',
      ).readAsStringSync();
      final backendAudit = File(
        'supabase/docs/backend_security_audit_2026-05-01.md',
      ).readAsStringSync();
      final readinessPlan = File(
        'docs/product/mobio_100_percent_mobile_readiness_goal_and_plan_2026-06-08.md',
      ).readAsStringSync();

      expect(schemaInventory, contains('Last updated: 2026-06-08'));
      expect(schemaInventory, contains('Current source of truth'));
      expect(schemaInventory, contains('Active Marketplace Schema'));
      expect(schemaInventory, contains('Removed Or Historical Schema'));
      expect(schemaInventory, contains('driver_locations'));
      expect(schemaInventory, contains('user_reports'));
      expect(schemaInventory, contains('user_blocks'));
      expect(
        schemaInventory,
        contains('Linked Supabase replay and assertions remain'),
      );
      expect(
        schemaInventory,
        isNot(contains('New Schema Required (Unified Payment Intent System')),
      );
      expect(schemaInventory, isNot(contains('MOBI Master Schema')));
      expect(schemaInventory, isNot(contains('sender_id` (from PayLedger')));

      expect(backendAudit, contains('Historical snapshot'));
      expect(backendAudit, contains('historical findings only'));
      expect(backendAudit, contains('docs/product/scope.md'));
      expect(backendAudit, contains('docs/release/go-no-go.md'));
      expect(
        readinessPlan,
        contains('biopay_ussd_aws_reactivation_scope_2026-06-12.md'),
      );
      expect(
        readinessPlan,
        contains(
          'BioPay remains limited to USSD handoff and AWS face identity',
        ),
      );
      expect(
        readinessPlan,
        isNot(contains('revive payments, BioPay, ledgers')),
      );
    });

    test('secret history purge has a non-destructive preflight', () {
      final preflight = File(
        'scripts/qa/preflight_secret_history_purge.sh',
      ).readAsStringSync();
      final runbook = File(
        'docs/security/secret_rotation_runbook.md',
      ).readAsStringSync();
      final playChecklist = File(
        'docs/release/google-play-submission.md',
      ).readAsStringSync();
      final scriptsReadme = File('scripts/README.md').readAsStringSync();

      expect(preflight, contains('git-filter-repo'));
      expect(preflight, contains('git rev-parse --is-shallow-repository'));
      expect(preflight, contains('git status --porcelain'));
      expect(preflight, contains('Do not run'));
      expect(preflight, contains('check_secret_history.sh'));
      expect(
        preflight,
        contains('android/fastlane/play-store-service-account.json'),
      );
      expect(runbook, contains('preflight_secret_history_purge.sh'));
      expect(playChecklist, contains('preflight_secret_history_purge.sh'));
      expect(
        playChecklist,
        contains('PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE'),
      );
      expect(playChecklist, contains('PLAY_CONSOLE_UPLOAD_EVIDENCE'));
      expect(scriptsReadme, contains('preflight_secret_history_purge.sh'));
      expect(
        scriptsReadme,
        contains('PLAY_SERVICE_ACCOUNT_RETENTION_EVIDENCE'),
      );
      expect(scriptsReadme, contains('docs/release/evidence'));
    });
  });
}
