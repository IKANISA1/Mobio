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

        expect(manifest, isNot(contains('android.permission.CAMERA')));
        expect(manifest, isNot(contains('android.permission.READ_SMS')));
        expect(manifest, isNot(contains('android.permission.RECEIVE_SMS')));
        expect(
          manifest,
          isNot(contains('android.permission.RECEIVE_BOOT_COMPLETED')),
        );
        expect(manifest, isNot(contains('SmsReceiver')));
        expect(manifest, isNot(contains('BootReceiver')));
      },
    );

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

    test('admin payment review surface is not in active navigation', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
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
      expect(router, contains("path: '/admin/finance'"));
      expect(router, contains('ScopeUnavailableScreen'));
      expect(adminUi, isNot(contains("label: 'Finance'")));
      expect(adminUi, isNot(contains("route: '/admin/finance'")));
      expect(adminService, isNot(contains('listRiskFlags')));
      expect(adminService, isNot(contains('reviewRiskFlag')));
      expect(complianceService, isNot(contains('rpc_admin_list_risk_flags')));
      expect(complianceService, isNot(contains('admin-review-transaction')));
      expect(adminModels, isNot(contains('AdminRiskFlagItem')));
    });

    test(
      'login copy stays within discovery, trips, chat, and profile scope',
      () {
        final loginScreen = File(
          'lib/features/auth/whatsapp_login_screen.dart',
        ).readAsStringSync();

        expect(
          loginScreen,
          contains('Trip scheduling, chat, and profile data'),
        );
        expect(
          loginScreen,
          isNot(contains('chat, payments, and profile data')),
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

    test('legacy BioPay, payment, and ledger packages are not shipped', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final proguard = File(
        'android/app/proguard-rules.pro',
      ).readAsStringSync();
      final mainActivity = File(
        'android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt',
      ).readAsStringSync();

      for (final path in const [
        'lib/features/biopay',
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

      for (final dependency in const [
        'mobi_payments',
        'camera:',
        'google_mlkit_face_detection',
        'tflite_flutter',
        'qr_flutter',
        'mobile_scanner',
        'flutter_nfc_kit',
        'local_auth',
        'flutter_secure_storage',
        'image_gallery_saver_plus',
        'pigeon',
      ]) {
        expect(pubspec, isNot(contains(dependency)));
      }

      expect(mainActivity, isNot(contains('LedgerApi')));
      expect(mainActivity, isNot(contains('LedgerApiImpl')));
      expect(proguard, isNot(contains('tensorflow')));
      expect(proguard, isNot(contains('mlkit')));
      expect(proguard, isNot(contains('zxing')));
      expect(proguard, isNot(contains('plugins.camera')));
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
      expect(releaseConfig, contains('require_var ACCOUNT_DELETION_URL'));
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
      expect(goNoGoScript, contains('REQUIRE_SECRET_HISTORY_CLEAN=true'));
      expect(goNoGoScript, contains('REQUIRE_ANDROID_SIGNING=true'));
      expect(goNoGoScript, contains('PLAY_SERVICE_ACCOUNT_ROTATED'));
      expect(goNoGoScript, contains('PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE'));
      expect(goNoGoScript, contains('PLAY_CONSOLE_UPLOAD_VALIDATED'));
      expect(goNoGoScript, contains('PLAY_CONSOLE_UPLOAD_EVIDENCE'));
      expect(goNoGoScript, contains('require_evidence'));
      expect(
        goNoGoScript,
        contains(r'set $evidence_name to an existing evidence file'),
      );
      expect(goNoGoScript, contains('must not point to an example template'));
      expect(goNoGoScript, contains('GO_NO_GO_DRY_RUN'));
      expect(goNoGoScript, contains('dry-run mode cannot approve production'));
      expect(goNoGoScript, contains('RUN_ANDROID_SMOKE=false is only allowed'));
      expect(goNoGoScript, contains('RUN_FLUTTER_GATE=false is only allowed'));
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
      final chatAi = File(
        'lib/core/services/chat_ai_service.dart',
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
      expect(routeForm, contains('route labels and optional coordinates only'));
      expect(routeForm, contains('Fares and timing are agreed manually'));
      expect(chatAi, contains('agree manually'));
      expect(chatAi, isNot(contains('What price works')));
      expect(chatComposer, contains('Message about fare'));
      expect(chatComposer, isNot(contains('Message about price')));
    });

    test('backend assist and promo prompts stay inside manual fare scope', () {
      final chatAssist = File(
        'supabase/functions/chat-assist/index.ts',
      ).readAsStringSync();
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

      expect(chatAssist, contains('manually agreed fares'));
      expect(chatAssist, contains('Do not suggest automatic fare quotes'));
      expect(chatAssist, contains('What fare should we agree manually'));
      expect(chatAssist, isNot(contains('What price works')));
      expect(promo, isNot(contains('cashless payment')));
      expect(promo, isNot(contains("scan the driver's face")));
      expect(promo, contains("view the driver's profile"));
      expect(driverCard, isNot(contains('trip.price')));
      expect(nearbyScreen, contains('km away'));
      expect(sharedExports, isNot(contains('ride_request.dart')));
    });

    test('historical docs defer to current limited marketplace scope', () {
      final schemaInventory = File(
        'docs/architecture/schema_inventory.md',
      ).readAsStringSync();
      final backendAudit = File(
        'supabase/docs/backend_security_audit_2026-05-01.md',
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
      expect(playChecklist, contains('PLAY_SERVICE_ACCOUNT_ROTATION_EVIDENCE'));
      expect(playChecklist, contains('PLAY_CONSOLE_UPLOAD_EVIDENCE'));
      expect(scriptsReadme, contains('preflight_secret_history_purge.sh'));
      expect(scriptsReadme, contains('docs/release/evidence'));
    });
  });
}
