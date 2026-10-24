import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/app/launch_screen.dart';
import 'package:mobi_app/app/router/error_screens.dart';
import 'package:mobi_app/app/router/screen_wrappers.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/admin_audit_log_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_auth_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_broadcasts_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_ev_chargers_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_operational_health_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_reports_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_subscriptions_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_transport_agencies_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_trips_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_users_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_vehicle_types_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/auth/application/auth_providers.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';
import 'package:mobi_app/features/auth/presentation/whatsapp_login_screen.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_admin_console_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_enroll_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_face_scan_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_home_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_write_card_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_payment_link_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_qr_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_request_payment_screen.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_scan_screen.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/features/chat/presentation/chat_screen.dart';
import 'package:mobi_app/features/ev_chargers/presentation/ev_charger_locator_screen.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/nearby/presentation/nearby_screen.dart';
import 'package:mobi_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/features/profile/data/subscription_plan_service.dart';
import 'package:mobi_app/features/profile/data/vehicle_type_service.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:mobi_app/features/profile/presentation/driver_plus_screen.dart';
import 'package:mobi_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:mobi_app/features/profile/presentation/profile_screen.dart';
import 'package:mobi_app/features/profile/presentation/wallet_screen.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/country.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';
import 'package:mobi_shared_types/models/trip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../tool/face_receiving_preview_service.dart';
import '../../../tool/preview_admin_user_contract.dart'
    show PreviewAdminUserContract;
import '../../helpers/biopay_nfc_test_channels.dart';
import '../../helpers/design_capture_fonts.dart';
import '../../helpers/mobile_scanner_test_channel.dart';
import '../../helpers/ordinary_golden_fonts.dart';
import '../../helpers/scrolled_tap_target_guideline.dart';
import '../../helpers/whatsapp_login_fixture.dart';

void main() {
  registerVisualSurfaceTests();
}

/// Reuses real screen fixtures for functional accessibility checks, without
/// regenerating or accepting historical visual baselines.
void registerVisualSurfaceTests({bool accessibilityAudit = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureDirectory = Platform.environment['MOBIO_CAPTURE_DIR'];
  final ordinaryCandidateDirectory =
      Platform.environment['MOBIO_ORDINARY_GOLDEN_CANDIDATE_DIR'];
  final previousComparator = goldenFileComparator;
  final currentWalletProfileChecks = <Map<String, Object?>>[];
  if (captureDirectory != null && captureDirectory.isNotEmpty) {
    if (ordinaryCandidateDirectory?.isNotEmpty ?? false) {
      throw StateError('Choose one explicit export mode.');
    }
    goldenFileComparator = _DesignCaptureComparator(
      Directory(captureDirectory),
    );
  } else if (ordinaryCandidateDirectory?.isNotEmpty ?? false) {
    // Stage ordinary-engine renders for review. Preserve existing baselines,
    // default DPR and the declared ordinary font contract; this mode accepts
    // no comparison.
    goldenFileComparator = _DesignCaptureComparator(
      Directory(ordinaryCandidateDirectory!),
    );
  }

  setUpAll(() async {
    installMobileScannerTestChannel();
    if (captureDirectory != null && captureDirectory.isNotEmpty) {
      await loadDesignCaptureFonts();
      enableDesignCaptureTypographyFallbacks();
      final fontRecord = File('$captureDirectory/font-provenance.json');
      await fontRecord.parent.create(recursive: true);
      await fontRecord.writeAsString(
        jsonEncode({
          'capture_only': true,
          'fonts': designCaptureFontProvenance,
          'typography_fallbacks': designCaptureTypographyFallbackProvenance,
          'limitations': designCaptureFontLimitations,
          'record_stage': 'fonts_ready_before_exports',
          'acceptance_effect': 'none',
        }),
      );
    } else {
      final loader = FontLoader('packages/lucide_icons/Lucide')
        ..addFont(rootBundle.load('packages/lucide_icons/assets/lucide.ttf'));
      await loader.load();
      final materialIcons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await materialIcons.load();
      // The test engine disables automatic asset-font loading. Ordinary
      // comparisons retain the product's faces before loading their explicit
      // portable test-only fallback families.
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final fonts =
          manifest.singleWhere((entry) => entry['family'] == 'Inter')['fonts']
              as List<dynamic>;
      final inter = FontLoader('Inter');
      for (final font in fonts) {
        inter.addFont(rootBundle.load(font['asset'] as String));
      }
      await inter.load();
      await loadOrdinaryGoldenFallbackFonts();
      if (ordinaryCandidateDirectory?.isNotEmpty ?? false) {
        final fontRecord = File(
          '$ordinaryCandidateDirectory/font-provenance.json',
        );
        await fontRecord.parent.create(recursive: true);
        await fontRecord.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'ordinary_test_only': true,
            'fonts': ordinaryGoldenFontProvenance,
            'fallback_families': ordinaryGoldenFallbackFamilies,
            'limitations': ordinaryGoldenFontLimitations,
            'record_stage': 'fonts_ready_before_candidate_exports',
            'native_font_equivalence': 'unverified',
            'acceptance_effect': 'none',
          }),
          flush: true,
        );
      }
    }
  });

  tearDownAll(() async {
    try {
      restoreDesignCaptureTypographyFallbacks();
      if (captureDirectory != null && captureDirectory.isNotEmpty) {
        await File('$captureDirectory/font-provenance.json').writeAsString(
          jsonEncode({
            'capture_only': true,
            'fonts': designCaptureFontProvenance,
            'typography_fallbacks': designCaptureTypographyFallbackProvenance,
            'logo_decode': designCaptureLogoDecodeProvenance,
            'logo_paints': designCaptureLogoPaintProvenance,
            'limitations': designCaptureFontLimitations,
            'record_stage': 'suite_teardown_original_styles_restored',
            'acceptance_effect': 'none',
          }),
          flush: true,
        );
        await File(
          '$captureDirectory/current-wallet-profile-state-checks.json',
        ).writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'schema_version': 1,
            'fixture': 'Local-only current production wallet/profile widgets',
            'viewport': {'width': 320, 'height': 640},
            'text_scale': 2,
            'locale': 'English fixture',
            'safe_area': 'Zero system padding in widget-test capture',
            'checks': currentWalletProfileChecks,
            'whole_text_paint_checks': _currentWholeTextPaintChecks,
            'limitations': [
              'WalletScreen.test provides a synthetic stable AccountSnapshot and a read-only WalletService fixture; no authenticated session or backend is exercised.',
              'Profile uses its existing local UI preview fixture. A Save callback validates local UI dispatch, not stored profile persistence.',
              'QR paint payload equivalence and mocked clipboard/share dispatch are local checks, not camera scanning, native clipboard, system sharing or provider outcome evidence.',
              'Scrollable content is visited with actual margin drags. Each PNG shows a viewport at its recorded scroll state, not a stitched full-page image.',
              'The displayed invite URL may use its existing ellipsis treatment. Full URL retention is checked through the QR painter and clipboard payload.',
            ],
            'visual_acceptance': 'unverified',
            'acceptance_effect': 'none',
          }),
          flush: true,
        );
      }
    } finally {
      restoreDesignCaptureTypographyFallbacks();
      goldenFileComparator = previousComparator;
      uninstallMobileScannerTestChannel();
    }
  });
  setUp(installBioPayNfcTestChannels);
  tearDown(uninstallBioPayNfcTestChannels);

  if (!accessibilityAudit && !_isDesignCapture) {
    test(
      'ordinary reference harness loads bundled Inter before fixtures',
      () async {
        final manifest =
            jsonDecode(await rootBundle.loadString('FontManifest.json'))
                as List<dynamic>;
        final fonts =
            manifest.singleWhere((entry) => entry['family'] == 'Inter')['fonts']
                as List<dynamic>;
        expect(
          fonts.map((font) => font['weight']),
          unorderedEquals([400, 500, 600, 700]),
        );
        final widths = <double>[];
        for (final font in fonts) {
          final weight = FontWeight.values[(font['weight'] as int) ~/ 100 - 1];
          final expectedFamily = 'ReferenceHarnessExpectedInter${weight.value}';
          final expected = FontLoader(expectedFamily)
            ..addFont(rootBundle.load(font['asset'] as String));
          await expected.load();
          Size dimensions(TextStyle style) {
            final painter = TextPainter(
              text: TextSpan(text: 'MW Hamburg 12345 éç', style: style),
              textDirection: ui.TextDirection.ltr,
            )..layout();
            final result = Size(painter.width, painter.height);
            painter.dispose();
            return result;
          }

          final primaryStyle = TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: weight,
          );
          final actual = dimensions(primaryStyle);
          final expectedMetrics = dimensions(
            primaryStyle.copyWith(fontFamily: expectedFamily),
          );
          expect(actual.width, closeTo(expectedMetrics.width, 0.01));
          expect(actual.height, closeTo(expectedMetrics.height, 0.01));
          for (final productionTheme in [
            AppTheme.lightTheme,
            AppTheme.darkTheme,
          ]) {
            final ordinaryTheme = ordinaryGoldenTheme(productionTheme);
            final fallbackStyle = primaryStyle.copyWith(
              fontFamilyFallback:
                  ordinaryTheme.textTheme.bodyMedium!.fontFamilyFallback,
            );
            final fallbackMetrics = dimensions(fallbackStyle);
            expect(
              fallbackMetrics.width,
              closeTo(actual.width, 0.01),
              reason: 'Fallbacks must retain Inter ${weight.value} metrics.',
            );
            expect(fallbackMetrics.height, closeTo(actual.height, 0.01));
          }
          widths.add(actual.width);
        }
        expect(widths.toSet(), hasLength(4));
        List<TextStyle?> styles(TextTheme theme) => [
          theme.displayLarge,
          theme.displayMedium,
          theme.displaySmall,
          theme.headlineLarge,
          theme.headlineMedium,
          theme.headlineSmall,
          theme.titleLarge,
          theme.titleMedium,
          theme.titleSmall,
          theme.bodyLarge,
          theme.bodyMedium,
          theme.bodySmall,
          theme.labelLarge,
          theme.labelMedium,
          theme.labelSmall,
        ];
        for (final production in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          final original = styles(production.textTheme);
          final originalPrimary = styles(production.primaryTextTheme);
          final ordinary = ordinaryGoldenTheme(production);
          for (final pair in [
            (original, styles(ordinary.textTheme)),
            (originalPrimary, styles(ordinary.primaryTextTheme)),
          ]) {
            for (var i = 0; i < pair.$1.length; i++) {
              final sourceStyle = pair.$1[i];
              final fallbackStyle = pair.$2[i];
              expect(
                fallbackStyle,
                sourceStyle?.copyWith(
                  fontFamilyFallback: <String>{
                    ...?sourceStyle.fontFamilyFallback,
                    ...ordinaryGoldenFallbackFamilies,
                  }.toList(growable: false),
                ),
                reason: 'Only the explicit fallback list may change.',
              );
            }
          }
          expect(styles(production.textTheme), original);
          expect(styles(production.primaryTextTheme), originalPrimary);
          expect(
            ordinary.copyWith(
              textTheme: production.textTheme,
              primaryTextTheme: production.primaryTextTheme,
            ),
            production,
          );
        }
        expect(ordinaryGoldenFontProvenance, hasLength(2));
        if (!(ordinaryCandidateDirectory?.isNotEmpty ?? false)) {
          expect(goldenFileComparator, same(previousComparator));
        }
        await expectOrdinaryGoldenGlyphPaint();
      },
    );
  }

  test('Reports preview respects status, search and pagination', () async {
    final service = _PreviewAdminService();
    expect((await service.listUserReports()).map((report) => report.id), [
      'report-1',
    ]);
    expect(
      (await service.listUserReports(
        status: 'resolved',
      )).map((report) => report.id),
      ['report-2'],
    );
    expect(await service.listUserReports(status: 'all'), hasLength(2));
    expect(
      (await service.listUserReports(
        status: 'all',
        search: ' ALINE ',
      )).map((report) => report.id),
      ['report-2'],
    );
    expect(
      (await service.listUserReports(
        status: 'all',
        limit: 1,
        offset: 1,
      )).map((report) => report.id),
      ['report-2'],
    );
    expect(await service.listUserReports(status: 'all', limit: 0), isEmpty);
  });

  const compact = Size(390, 844);
  const large = Size(430, 932);
  const tablet = Size(768, 1024);
  const desktop = Size(1280, 900);
  const wideDesktop = Size(1440, 1000);

  final cases = <_GoldenCase>[
    const _GoldenCase(name: 'splash', builder: MobiLaunchScreen.new),
    for (final state in [
      'number_ready',
      'sending',
      'send_error',
      'rate_limited',
      'otp',
      'otp_invalid',
      'otp_expired',
      'verifying',
      'resend_ready',
    ])
      _GoldenCase(
        name: 'whatsapp_$state',
        builder: () {
          final service = FakeWhatsAppLoginService();
          if (state == 'sending') {
            service.send = () => Completer<WhatsAppLoginResult>().future;
          } else if (state == 'send_error') {
            service.send = () async => const WhatsAppLoginResult(
              success: false,
              message: 'Unable to send a code. Please try again.',
            );
          } else if (state == 'rate_limited') {
            service.send = () async => const WhatsAppLoginResult(
              success: false,
              message: 'Please wait before requesting another code.',
              retryAfterSeconds: 30,
            );
          }
          if (state == 'otp_invalid') {
            service.verify = () async => const WhatsAppLoginResult(
              success: false,
              message: 'That code is incorrect. Try again.',
              attemptsRemaining: 2,
            );
          } else if (state == 'otp_expired') {
            service.verify = () async => const WhatsAppLoginResult(
              success: false,
              message: 'Your code expired. Please request a new one.',
              attemptsRemaining: 0,
            );
          } else if (state == 'verifying') {
            service.verify = () => Completer<WhatsAppLoginResult>().future;
          }
          return ProviderScope(
            overrides: [
              whatsappLoginServiceProvider.overrideWithValue(service),
            ],
            child: WhatsAppLoginScreen(onBack: () {}, onSuccess: (_) {}),
          );
        },
        prepare: (tester) async {
          if (state == 'number_ready') {
            await enterPreviewPhone(tester);
            return;
          }
          await requestPreviewCode(tester);
          if (['otp_invalid', 'otp_expired', 'verifying'].contains(state)) {
            await enterPreviewCode(tester);
            await tester.ensureVisible(find.text('Verify code'));
            await tester.tap(find.text('Verify code'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
          }
          if (state == 'resend_ready') {
            await tester.pump(const Duration(seconds: 61));
          }
        },
      ),
    _GoldenCase(
      name: 'login',
      builder: () => ProviderScope(
        overrides: [
          whatsappLoginServiceProvider.overrideWithValue(
            FakeWhatsAppLoginService(),
          ),
        ],
        child: WhatsAppLoginScreen(onBack: () {}, onSuccess: (_) {}),
      ),
    ),
    _GoldenCase(
      name: 'home',
      builder: () => HomeScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onChat: (_) {},
        onChatPerson: (_) {},
        onTripDetails: (_) {},
        onViewNearby: () {},
        onViewBookings: () {},
        onSchedule: () {},
      ),
    ),
    _GoldenCase(
      name: 'bookings',
      builder: () => BookingsScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onSchedule: () {},
        onTripDetails: (_) {},
      ),
    ),
    _GoldenCase(
      name: 'schedule',
      builder: () => ScheduleTripScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onBack: () {},
      ),
    ),
    _GoldenCase(
      name: 'trip_details',
      builder: () => TripDetailsScreen(tripId: 't1', onBack: () {}),
    ),
    _GoldenCase(
      name: 'trip_edit',
      builder: () => ScheduleTripScreen(
        mode: 'driver',
        onModeChanged: (_) {},
        onBack: () {},
        editingTripId: 't1',
      ),
    ),
    _GoldenCase(
      name: 'profile',
      builder: () => ProfileScreen(
        isDarkMode: true,
        onDarkModeChanged: (_) {},
        onEditProfile: () {},
        onNfcWriteCard: () {},
        onAdminGateway: () {},
      ),
    ),
    _GoldenCase(
      name: 'wallet',
      builder: () => WalletScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'mobio_plus',
      builder: () => DriverPlusScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'edit_profile',
      builder: () => EditProfileScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'profile_setup',
      builder: () => EditProfileScreen(isFirstRun: true, onBack: () {}),
    ),
    _GoldenCase(
      name: 'notifications',
      builder: () => NotificationsScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'chat',
      builder: () => TripChatScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'nearby',
      builder: () => NearbyScreen(onChat: (_) {}, onTripDetails: (_) {}),
    ),
    _GoldenCase(
      name: 'biopay_home',
      builder: () => BioPayScreen(
        onQr: () {},
        onScan: () {},
        onFace: () {},
        onNfc: () {},
        onRequestPayment: () {},
      ),
    ),
    _GoldenCase(
      name: 'biopay_qr',
      builder: () => BioPayQrScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_scan',
      builder: () => BioPayScanScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_face_scan',
      builder: () => BioPayFaceScanScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_face_enroll',
      builder: () => ProviderScope(
        overrides: [
          biopayFaceServiceProvider.overrideWith((ref) => _GoldenFaceService()),
          paymentDiscoveryServiceProvider.overrideWith(
            (ref) => FaceReceivingPreviewService(),
          ),
        ],
        child: BioPayFaceEnrollScreen(onBack: () {}),
      ),
    ),
    _GoldenCase(
      name: 'biopay_nfc',
      builder: () => BioPayNfcScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_nfc_write_card',
      builder: () => BioPayNfcWriteCardScreen(onBack: () {}),
    ),
    const _GoldenCase(
      name: 'admin_biopay_ops',
      builder: BioPayAdminConsoleScreen.new,
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_auth',
      builder: () => AdminAuthScreen(onBack: () {}, onSuccess: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_vehicle_types',
      builder: () => AdminVehicleTypesScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_subscriptions',
      builder: () => AdminSubscriptionsScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_agencies',
      builder: () => AdminTransportAgenciesScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_reports_actual',
      builder: () => AdminReportsScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_audit_actual',
      builder: () => AdminAuditLogScreen(onBack: () {}),
      includeDesktop: true,
    ),
    const _GoldenCase(
      name: 'admin',
      builder: _adminPreview,
      includeDesktop: true,
    ),
    const _GoldenCase(
      name: 'admin_users',
      builder: AdminUsersScreen.new,
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_trips',
      builder: () => AdminTripsScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_health',
      builder: () => _adminPreview(
        tab: AdminWorkspaceTab.health,
        title: 'Operational health',
        subtitle: 'System signals and release guardrails',
      ),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_broadcasts',
      builder: () => _adminPreview(
        tab: AdminWorkspaceTab.broadcasts,
        title: 'Broadcasts',
        subtitle: 'Consent-aware campaign operations',
      ),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'ev_locator',
      builder: () => EvChargerLocatorScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_request',
      builder: () => BioPayRequestPaymentScreen(onBack: () {}),
    ),
    _GoldenCase(
      name: 'biopay_link_expired',
      builder: () => ProviderScope(
        overrides: [
          biopayUssdServiceProvider.overrideWithValue(
            _ExpiredPreviewUssdService(),
          ),
        ],
        child: BioPayPaymentLinkScreen(token: 'expired-preview', onBack: () {}),
      ),
    ),
    _GoldenCase(
      name: 'admin_ev_recovery',
      builder: () => AdminEvChargersScreen(onBack: () {}),
      includeDesktop: true,
    ),
    const _GoldenCase(
      name: 'admin_dashboard_actual',
      builder: AdminDashboardScreen.new,
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_health_actual',
      builder: () => AdminOperationalHealthScreen(onBack: () {}),
      includeDesktop: true,
    ),
    _GoldenCase(
      name: 'admin_broadcasts_actual',
      builder: () => AdminBroadcastsScreen(onBack: () {}),
      includeDesktop: true,
    ),
    const _GoldenCase(name: 'config_error', builder: ConfigErrorScreen.new),
    const _GoldenCase(name: 'not_found', builder: NotFoundScreen.new),
  ];

  final shellCases = [
    for (final (index, name) in [
      'home',
      'bookings',
      'biopay_home',
      'profile',
    ].indexed)
      _GoldenCase(
        name: '${name}_shell',
        builder: () => Stack(
          children: [
            cases.firstWhere((item) => item.name == name).builder(),
            MobiBottomNav(currentIndex: index, onTap: (_) {}),
          ],
        ),
      ),
  ];
  cases.addAll(shellCases);

  // Export only the changed states; these do not create or accept baselines.
  if (!accessibilityAudit && _isDesignCapture) {
    for (final (size, scale, light) in [
      (compact, 1.0, false),
      (compact, 1.0, true),
      (desktop, 1.0, false),
      (const Size(320, 640), 2.0, false),
    ]) {
      final theme = light ? 'light' : 'dark';
      final suffix =
          '${size.width.toInt()}x${size.height.toInt()}_${scale}x_$theme';
      testWidgets('current admin Profile Exit Admin full scroll $suffix', (
        tester,
      ) async {
        var exits = 0;
        await _pumpGolden(
          tester,
          size,
          ProviderScope(
            overrides: [
              profileServiceProvider.overrideWithValue(
                _AdminProfileCaptureService(),
              ),
              biopayFaceServiceProvider.overrideWithValue(_GoldenFaceService()),
            ],
            child: ProfileScreen.test(
              isDarkMode: !light,
              onDarkModeChanged: (_) {},
              onEditProfile: () {},
              onWallet: () {},
              onInviteAndEarn: () {},
              onMobioPlus: () {},
              onBioPayEnroll: () {},
              onNfcWriteCard: () {},
              onAdminGateway: () {},
              onExitAdmin: () => exits++,
              onSignOut: () {},
              captureAccount: () => _GoldenFaceService._account,
              isCurrent: (account) =>
                  account.identity == _GoldenFaceService._account.identity,
            ),
          ),
          light: light,
          textScale: scale,
        );
        // The loaded identity is shown in the title and identity strip.
        expect(find.text('004321'), findsNWidgets(2));
        for (final label in ['Member', 'BioPay']) {
          await _expectCompleteParagraph(tester, find.text(label));
        }
        expect(find.text('Set up'), findsNWidgets(2));
        await _expectCompleteParagraph(tester, find.text('Set up').first);
        for (var index = 0; index < 2; index++) {
          await _expectCompleteParagraph(tester, find.text('004321').at(index));
        }
        expect(find.bySemanticsLabel('Admin sign in'), findsNothing);
        await _expectGoldenCapture(
          tester,
          'goldens/revolut/admin_profile/current_${suffix}_top.png',
        );
        final list = find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(SingleChildScrollView),
        );
        expect(list, findsOneWidget);
        final page = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final exit = find.text('Exit Admin');
        final deletion = find.text('Request account deletion');
        await _dragCurrentPageUntilVisible(
          tester,
          exit,
          page,
          visibleStart: deletion,
        );
        await _expectCompleteParagraph(tester, deletion);
        await _expectCompleteParagraph(tester, exit);
        final target = find
            .ancestor(of: exit, matching: find.byType(InkWell))
            .first;
        expect(target.hitTestable(), findsOneWidget);
        expect(tester.getRect(target).height, greaterThanOrEqualTo(48));
        await _expectGoldenCapture(
          tester,
          'goldens/revolut/admin_profile/current_${suffix}_exit.png',
        );
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(exits, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('current Home selection correction batch', (tester) async {
      for (final mode in ['passenger', 'driver']) {
        await _pumpGolden(
          tester,
          compact,
          HomeScreen(
            mode: mode,
            onModeChanged: (_) {},
            onChat: (_) {},
            onChatPerson: (_) {},
            onTripDetails: (_) {},
            onViewNearby: () {},
            onViewBookings: () {},
            onSchedule: () {},
          ),
          light: true,
        );
        await _expectGoldenCapture(
          tester,
          'goldens/revolut/corrections/home_${mode}_light_390x844.png',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('current Reports filter and contact correction batch', (
      tester,
    ) async {
      await _pumpGolden(tester, wideDesktop, AdminReportsScreen(onBack: () {}));
      expect(find.text('Patrick Passenger'), findsNothing);
      final detailsOnly =
          Platform.environment['MOBIO_CAPTURE_REPORT_DETAILS_ONLY'] == 'true';
      if (!detailsOnly) {
        await _expectGoldenCapture(
          tester,
          'goldens/revolut/corrections/reports_open_1440x1000.png',
        );
      }
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(2));
      expect(find.text('u3'), findsNothing);
      expect(find.text('u4'), findsNothing);
      if (!detailsOnly) {
        await _expectGoldenCapture(
          tester,
          'goldens/revolut/corrections/reports_all_1440x1000.png',
        );
      }
      final details = find.text('Details').last;
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      expect(details.hitTestable(), findsOneWidget);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Report details'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(4));
      expect(find.text('u3'), findsNothing);
      expect(find.text('u4'), findsNothing);
      await _expectGoldenCapture(
        tester,
        'goldens/revolut/corrections/reports_details_1440x1000.png',
      );
    });
  }

  if (accessibilityAudit) {
    cases.add(
      _GoldenCase(
        name: 'scope_unavailable',
        builder: () => ScopeUnavailableScreen(onBack: () {}),
      ),
    );
    for (final (size, scale, light) in [
      (compact, 1.0, false),
      (const Size(320, 640), 2.0, false),
      (desktop, 2.0, false),
      (compact, 1.0, true),
    ]) {
      for (final item in cases) {
        if (size == desktop && !item.includeDesktop) continue;
        testWidgets(
          'accessibility ${item.name} ${size.width.toInt()}px ${scale}x${light ? ' light' : ''}',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final onError = FlutterError.onError;
            FlutterError.onError = (details) {
              FlutterError.dumpErrorToConsole(details, forceReport: true);
              onError?.call(details);
            };
            try {
              await _pumpGolden(
                tester,
                size,
                item.builder(),
                textScale: scale,
                light: light,
              );
              await item.prepare?.call(tester);
              expect(tester.takeException(), isNull);
              _expectNamedEditableFields(tester);
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              // Check the underlying pages separately; fixed shell chrome can
              // occlude text. This does not certify the overlay's contrast.
              if (scale == 1 && !item.name.endsWith('_shell')) {
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
              }
              final scrollables = tester
                  .stateList<ScrollableState>(find.byType(Scrollable))
                  .toList();
              for (final scrollable in scrollables) {
                if (!scrollable.mounted) continue;
                final position = scrollable.position;
                final step = position.viewportDimension * 0.8;
                if (step <= 0) continue;
                for (
                  var page = 0;
                  page < 12 && position.pixels < position.maxScrollExtent;
                  page++
                ) {
                  position.jumpTo(
                    (position.pixels + step).clamp(
                      position.minScrollExtent,
                      position.maxScrollExtent,
                    ),
                  );
                  await tester.pump(const Duration(milliseconds: 300));
                  expect(tester.takeException(), isNull);
                  _expectNamedEditableFields(tester);
                  await expectLater(
                    tester,
                    meetsGuideline(labeledTapTargetGuideline),
                  );
                  await expectLater(
                    tester,
                    meetsGuideline(ScrolledTapTargetGuideline()),
                  );
                }
              }
            } finally {
              FlutterError.onError = onError;
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              semantics.dispose();
            }
          },
        );
      }
    }
    return;
  }

  for (final name in [
    'splash',
    'login',
    'biopay_home',
    'wallet',
    'home',
    'profile',
    'bookings',
    'biopay_qr',
    'biopay_scan',
    'admin_users',
  ]) {
    testWidgets('light theme $name', (tester) async {
      final item = cases.firstWhere((item) => item.name == name);
      await _pumpGolden(tester, compact, item.builder(), light: true);
      await _expectGoldenCapture(
        tester,
        'goldens/revolut/light/${name}_390x844.png',
      );
    });
  }

  for (final size in [compact, large]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';

    group('Revolut-reference golden $suffix', () {
      for (final item in cases) {
        testWidgets(item.name, (tester) async {
          await _pumpGolden(tester, size, item.builder());
          await item.prepare?.call(tester);

          await _expectGoldenCapture(
            tester,
            'goldens/revolut/${item.name}_$suffix.png',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    });
  }

  for (final size in [tablet, desktop, wideDesktop]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';
    final desktopCases = cases.where((item) => item.includeDesktop).toList();

    group('Revolut-reference admin desktop golden $suffix', () {
      for (final item in desktopCases) {
        testWidgets(item.name, (tester) async {
          await _pumpGolden(tester, size, item.builder());
          await item.prepare?.call(tester);

          await _expectGoldenCapture(
            tester,
            'goldens/revolut/admin_desktop/${item.name}_$suffix.png',
          );
        });
      }
    });
  }

  // Additional current-state evidence has no historical golden baseline. It is
  // exported only in explicit capture mode; existing cases/exclusions remain.
  if (_isDesignCapture) {
    const narrow = Size(320, 640);
    for (final light in [false, true]) {
      final theme = light ? 'light' : 'dark';
      testWidgets('current wallet 320px 200 percent full scroll $theme', (
        tester,
      ) async {
        // testWidgets owns its automatic semantics handle on the pinned SDK.
        final service = _CurrentWalletCaptureService(balance: 8200);
        final native = _mockCurrentInviteDispatches();
        await _pumpGolden(
          tester,
          narrow,
          _currentWalletFixture(service),
          light: light,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        await _expectCompleteParagraph(tester, find.text('8,200 TOKENS'));
        final screenshots = <String>[];
        Future<void> captureState(String state) async {
          final path =
              'goldens/revolut/wallet_200pct_${theme}_${state}_320x640.png';
          await _expectGoldenCapture(tester, path);
          screenshots.add(path.replaceFirst('goldens/revolut/', ''));
        }

        await captureState('top');
        // The fixed page header owns a separate scrollable title. Exercise
        // the actual wallet ListView, rather than dragging that title window.
        final list = find.descendant(
          of: find.byType(WalletScreen),
          matching: find.byType(ListView),
        );
        expect(list, findsOneWidget);
        final page = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        expect(page, findsOneWidget);
        await _dragCurrentPageUntilVisible(
          tester,
          find.text('900'),
          page,
          visibleStart: find.text('Earned'),
        );
        for (final metric in [
          'Earned',
          'Sent',
          'Received',
          '10,200',
          '1,400',
          '900',
        ]) {
          final text = find.text(metric);
          await _expectCompleteParagraph(tester, text);
          _expectOneVisualLine(tester, text);
        }
        _expectBalanceUnitAndCommas(tester);
        await captureState('metrics');
        final firstAction = find.ancestor(
          of: find.text('Send'),
          matching: find.byType(InkWell),
        );
        final lastAction = find.ancestor(
          of: find.text('Copy'),
          matching: find.byType(InkWell),
        );
        await _dragCurrentPageUntilVisible(
          tester,
          lastAction,
          page,
          visibleStart: firstAction,
        );
        for (final action in ['Send', 'Redeem', 'Share', 'Copy']) {
          final text = find.text(action);
          await _expectCompleteParagraph(tester, text);
          _expectOneVisualLine(tester, text);
        }
        await captureState('actions');
        final qr = find.byType(QrImageView);
        await _dragCurrentPageUntilVisible(tester, qr, page);
        expect(find.text(_currentInviteUrl), findsOneWidget);
        await _expectCurrentInviteQrPayload(tester, qr);
        await captureState('invitation');

        final share = find.widgetWithText(MobiButton, 'Share invite');
        final copy = find.widgetWithText(MobiButton, 'Copy link');
        final enter = find.widgetWithText(MobiButton, 'Enter invite code');
        for (final action in [share, copy, enter]) {
          await _dragCurrentPageUntilVisible(tester, action, page);
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getRect(action).height, greaterThanOrEqualTo(48));
        }
        for (final label in ['Share invite', 'Copy link']) {
          final text = find.text(label);
          await _expectCompleteParagraph(tester, text);
          _expectOneVisualLine(tester, text);
        }
        await _dragCurrentPageUntilVisible(
          tester,
          find.text('Activity'),
          page,
          visibleStart: share,
        );
        await captureState('bottom');
        final activityDetails = find.text(
          '${DateFormat('d MMM, HH:mm').format(DateTime.utc(2026, 6, 15, 16, 30).toLocal())} - Synthetic referral reward',
        );
        await _dragCurrentPageUntilVisible(
          tester,
          activityDetails,
          page,
          visibleStart: find.text('Successful invite'),
        );
        await _expectCompleteParagraph(tester, find.text('Successful invite'));
        await _expectCompleteParagraph(tester, activityDetails);
        await _expectCompleteParagraph(tester, find.text('+100'));
        await captureState('activity');

        // Prove the complete URL survives display ellipsis and that the real
        // button callbacks dispatch once into controlled platform stubs.
        await _dragCurrentPageUntilVisible(tester, copy, page);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(native.copied, [_currentInviteUrl]);
        expect(find.text('Invite link copied.'), findsOneWidget);
        await _dragCurrentPageUntilVisible(tester, share, page);
        await tester.tap(share);
        await tester.pumpAndSettle();
        expect(native.shared, hasLength(1));
        expect(native.shared.single, contains(_currentInviteUrl));
        expect(tester.takeException(), isNull);
        currentWalletProfileChecks.add({
          'test': 'current wallet 320px 200 percent full scroll $theme',
          'widget': 'WalletScreen.test',
          'theme': theme,
          'balance_tokens': 8200,
          'screenshots': screenshots,
          'full_value_layout_checked': true,
          'margin_scroll_to_invitation_qr_actions_activity': true,
          'qr_paint_matches_complete_invite_url': true,
          'clipboard_stub_payload': native.copied,
          'share_stub_dispatch_count': native.shared.length,
          'wallet_service_reads': service.reads,
          'native_clipboard_share_and_camera_outcome': 'unverified',
        });
      });
      testWidgets('current wallet large balance 320px 200 percent $theme', (
        tester,
      ) async {
        final service = _CurrentWalletCaptureService(balance: 123456789);
        await _pumpGolden(
          tester,
          narrow,
          _currentWalletFixture(service),
          light: light,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        final primary = find.byKey(const ValueKey('wallet-primary-balance'));
        expect(
          tester.widget<Text>(primary).semanticsLabel,
          '123,456,789 TOKENS',
        );
        final displayed = tester
            .widget<Text>(primary)
            .textSpan!
            .toPlainText()
            .replaceAll('\u2060', '')
            .replaceAll('\u200B', '');
        expect(displayed, '123,456,789 TOKENS');
        await _expectCompleteParagraph(tester, primary);
        _expectBalanceUnitAndCommas(tester);
        await _expectCompleteParagraph(tester, find.text('123,456,789 RWF'));
        final path =
            'goldens/revolut/wallet_large_balance_200pct_${theme}_320x640.png';
        await _expectGoldenCapture(tester, path);
        currentWalletProfileChecks.add({
          'test': 'current wallet large balance 320px 200 percent $theme',
          'widget': 'WalletScreen.test',
          'theme': theme,
          'balance_tokens': 123456789,
          'screenshots': [path.replaceFirst('goldens/revolut/', '')],
          'whole_balance_and_equivalent_layout_checked': true,
          'wallet_service_reads': service.reads,
          'backend_balance_or_operation_verification': false,
        });
      });
      testWidgets(
        'current edit profile 320px 200 percent full scroll Save $theme',
        (tester) async {
          // testWidgets owns its automatic semantics handle on the pinned SDK.
          var saved = 0;
          await _pumpGolden(
            tester,
            narrow,
            EditProfileScreen(onBack: () => saved++),
            light: light,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);
          await _expectCompleteParagraph(tester, find.text('Edit profile'));
          _expectNamedEditableFields(tester);
          final top =
              'goldens/revolut/edit_profile_200pct_${theme}_top_320x640.png';
          await _expectGoldenCapture(tester, top);
          final page = find
              .descendant(
                of: find.byType(EditProfileScreen),
                matching: find.byType(Scrollable),
              )
              .first;
          final save = find.widgetWithText(MobiButton, 'Save changes');
          await _dragCurrentPageUntilVisible(
            tester,
            save,
            page,
            checkEditableFields: true,
          );
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.getRect(save).height, greaterThanOrEqualTo(48));
          final bottom =
              'goldens/revolut/edit_profile_200pct_${theme}_save_320x640.png';
          await _expectGoldenCapture(tester, bottom);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(saved, 1, reason: 'The reached Save action must dispatch.');
          expect(find.text('Profile saved.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          currentWalletProfileChecks.add({
            'test':
                'current edit profile 320px 200 percent full scroll Save $theme',
            'widget': 'EditProfileScreen',
            'theme': theme,
            'screenshots': [
              top.replaceFirst('goldens/revolut/', ''),
              bottom.replaceFirst('goldens/revolut/', ''),
            ],
            'whole_title_and_editable_line_layout_checked': true,
            'margin_scroll_to_hit_testable_Save': true,
            'local_preview_save_callback_count': saved,
            'stored_profile_persistence': 'unverified',
          });
        },
      );
    }
  }
}

Future<void> _expectGoldenCapture(WidgetTester tester, String path) async {
  if (_isDesignCapture) {
    await settleDesignCaptureFonts(tester);
    await verifyDesignCaptureLogoPaints(tester, capture: path);
    expect(tester.takeException(), isNull);
  } else {
    expectOrdinaryGoldenGlyphFallbacks(tester);
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
}

bool get _isDesignCapture =>
    Platform.environment['MOBIO_CAPTURE_DIR']?.isNotEmpty ?? false;

const _currentInviteUrl = 'https://mobio.ikanisa.com/invite/482913';
const _currentWalletAccount = AccountSnapshot(
  '11111111-1111-4111-8111-111111111111',
  'current-wallet-capture-session',
  0,
);

class _CurrentWalletCaptureService extends Fake implements WalletService {
  _CurrentWalletCaptureService({required this.balance});
  final int balance;
  final reads = <String>[];

  @override
  Future<WalletSummary> getSummary() async {
    reads.add('summary');
    return WalletSummary(
      profileId: _currentWalletAccount.userId,
      balanceTokens: balance,
      rwfEquivalent: balance,
      lifetimeEarnedTokens: balance + 2000,
      lifetimeSentTokens: 1400,
      lifetimeReceivedTokens: 900,
      successfulReferrals: 8,
      referralCode: '482913',
      shareUrl: _currentInviteUrl,
    );
  }

  @override
  Future<List<TokenLedgerEntry>> listLedger({int limit = 50}) async {
    reads.add('ledger');
    return [
      TokenLedgerEntry(
        id: '22222222-2222-4222-8222-222222222222',
        direction: 'credit',
        amountTokens: 100,
        reason: 'successful invite',
        note: 'Synthetic referral reward',
        createdAt: DateTime.utc(2026, 6, 15, 16, 30),
      ),
    ];
  }

  @override
  Future<WalletOperationRecord?> activeOperation() async {
    reads.add('active_operation');
    return null;
  }
}

Widget _currentWalletFixture(_CurrentWalletCaptureService service) =>
    ProviderScope(
      overrides: [walletServiceProvider.overrideWithValue(service)],
      child: WalletScreen.test(
        onBack: () {},
        captureAccount: () => _currentWalletAccount,
        isCurrent: (account) =>
            account.identity == _currentWalletAccount.identity &&
            account.generation == _currentWalletAccount.generation,
      ),
    );

class _CurrentInviteDispatches {
  final copied = <String>[];
  final shared = <String>[];
}

_CurrentInviteDispatches _mockCurrentInviteDispatches() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final record = _CurrentInviteDispatches();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger
    ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        record.copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    })
    ..setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method != 'share') {
        throw StateError('Unexpected share fixture method: ${call.method}');
      }
      record.shared.add(
        (call.arguments as Map<Object?, Object?>)['text']! as String,
      );
      return 'success';
    });
  addTearDown(() {
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockMethodCallHandler(shareChannel, null);
  });
  return record;
}

final _currentWholeTextPaintChecks = <Map<String, Object?>>[];

class _CurrentTextPaintingContext extends PaintingContext {
  _CurrentTextPaintingContext(OffsetLayer layer, Rect bounds)
    : super(layer, bounds);

  void finishRecording() => stopRecordingIfNeeded();
}

Future<void> _expectCompleteParagraph(WidgetTester tester, Finder text) async {
  final paragraph = _currentParagraph(tester, text);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'The whole value or heading must remain in the text layout.',
  );
  // Match RenderParagraph.performLayout's actual overflow conditions. A
  // selection-run box may overhang the paragraph without creating a clip.
  expect(paragraph.textSize.width, lessThanOrEqualTo(paragraph.size.width));
  expect(paragraph.textSize.height, lessThanOrEqualTo(paragraph.size.height));
  expect(paragraph.debugHasOverflowShader, isFalse);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  expect(boxes, isNotEmpty);

  // Paint the existing RenderParagraph unchanged into an isolated layer. This
  // measures actual ink, not advance/selection metrics, and does not replace
  // pixels in the production tree or in the exported screenshot.
  final padding =
      paragraph.textScaler.scale(paragraph.text.style?.fontSize ?? 14) * 2;
  final expanded = paragraph.paintBounds.inflate(padding);
  final rasterBounds = Rect.fromLTRB(
    expanded.left.floorToDouble(),
    expanded.top.floorToDouble(),
    expanded.right.ceilToDouble(),
    expanded.bottom.ceilToDouble(),
  );
  final handle = LayerHandle<OffsetLayer>(OffsetLayer());
  final context = _CurrentTextPaintingContext(handle.layer!, rasterBounds);
  paragraph.paint(context, Offset.zero);
  context.finishRecording();
  Rect? ink;
  try {
    ink = await tester.runAsync(() async {
      final frame = await handle.layer!
          .toImage(rasterBounds)
          .timeout(const Duration(seconds: 30));
      try {
        final pixels = await frame
            .toByteData(format: ui.ImageByteFormat.rawRgba)
            .timeout(const Duration(seconds: 30));
        expect(pixels, isNotNull);
        var left = frame.width;
        var top = frame.height;
        var right = -1;
        var bottom = -1;
        for (var y = 0; y < frame.height; y++) {
          for (var x = 0; x < frame.width; x++) {
            if (pixels!.getUint8((y * frame.width + x) * 4 + 3) == 0) continue;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
        expect(
          right,
          greaterThanOrEqualTo(left),
          reason: 'Whole text must paint ink.',
        );
        // Overscan is measurement space, not a clipping tolerance. Empty outer
        // edges are required so this measurement cannot cut off unknown ink.
        expect(left, greaterThan(0));
        expect(top, greaterThan(0));
        expect(right, lessThan(frame.width - 1));
        expect(bottom, lessThan(frame.height - 1));
        return Rect.fromLTRB(
          rasterBounds.left + left,
          rasterBounds.top + top,
          rasterBounds.left + right + 1,
          rasterBounds.top + bottom + 1,
        );
      } finally {
        frame.dispose();
      }
    });
  } finally {
    handle.layer = null;
  }
  expect(ink, isNotNull);
  final actualInk = ink!;
  final clips = <Map<String, Object?>>[];
  final verticalScroller =
      Scrollable.maybeOf(tester.element(text))?.position.axis == Axis.vertical;
  RenderObject child = paragraph;
  for (var ancestor = child.parent; ancestor != null; ancestor = child.parent) {
    final clip = ancestor.describeApproximatePaintClip(child);
    if (clip != null) {
      final extent = MatrixUtils.transformRect(
        paragraph.getTransformTo(ancestor),
        actualInk,
      );
      expect(extent.left, greaterThanOrEqualTo(clip.left - 0.01));
      expect(extent.right, lessThanOrEqualTo(clip.right + 0.01));
      final scrollWindow =
          ancestor is RenderAbstractViewport && verticalScroller;
      if (!scrollWindow) {
        expect(extent.top, greaterThanOrEqualTo(clip.top - 0.01));
        expect(extent.bottom, lessThanOrEqualTo(clip.bottom + 0.01));
      }
      clips.add({
        'ancestor': ancestor.runtimeType.toString(),
        'clip': clip.toString(),
        'actual_ink_extent': extent.toString(),
        'vertical_scroll_window': scrollWindow,
      });
    }
    child = ancestor;
  }
  final globalInk = MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    actualInk,
  );
  final viewport = MediaQuery.sizeOf(tester.element(text));
  expect(globalInk.left, greaterThanOrEqualTo(-0.01));
  expect(globalInk.right, lessThanOrEqualTo(viewport.width + 0.01));
  _currentWholeTextPaintChecks.add({
    'text': paragraph.text.toPlainText(),
    'text_size': paragraph.textSize.toString(),
    'render_size': paragraph.size.toString(),
    'selection_boxes': [for (final box in boxes) box.toRect().toString()],
    'actual_ink_bounds': actualInk.toString(),
    'clip_ancestors': clips,
    'whole_text_no_truncation_or_paragraph_overflow': true,
    'actual_ink_within_horizontal_viewport_and_non_scroll_clips': true,
    'vertical_scroll_visibility':
        'Offscreen ink in a vertical scroll window requires separate margin-scroll verification',
    'isolated_measurement_pixels_used_in_capture': false,
  });
}

void _expectOneVisualLine(WidgetTester tester, Finder text) {
  final paragraph = _currentParagraph(tester, text);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  expect(boxes, isNotEmpty);
  for (final box in boxes) {
    expect(
      box.top,
      closeTo(boxes.first.top, 0.01),
      reason: 'A metric label or amount must not split across visual lines.',
    );
  }
}

void _expectBalanceUnitAndCommas(WidgetTester tester) {
  final paragraph = _currentParagraph(
    tester,
    find.byKey(const ValueKey('wallet-primary-balance')),
  );
  final text = paragraph.text.toPlainText();
  final unitStart = text.lastIndexOf('TOKENS');
  expect(unitStart, greaterThanOrEqualTo(0));
  final unit = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: unitStart, extentOffset: unitStart + 6),
  );
  expect(unit, isNotEmpty);
  for (final box in unit) {
    expect(
      box.top,
      closeTo(unit.first.top, 0.01),
      reason: 'TOKENS must remain a complete word.',
    );
  }
  for (var i = 0; i < text.length; i++) {
    if (text[i] != ',') continue;
    var previousDigit = i - 1;
    while (previousDigit >= 0 &&
        !RegExp('[0-9]').hasMatch(text[previousDigit])) {
      previousDigit--;
    }
    expect(previousDigit, greaterThanOrEqualTo(0));
    final digit = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: previousDigit, extentOffset: previousDigit + 1),
    );
    final comma = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    expect(digit, isNotEmpty);
    expect(comma, isNotEmpty);
    expect(
      comma.first.top,
      closeTo(digit.last.top, 0.01),
      reason: 'A grouping comma must stay with its preceding digit.',
    );
  }
}

RenderParagraph _currentParagraph(WidgetTester tester, Finder text) {
  expect(text, findsOneWidget);
  final richText = find.descendant(of: text, matching: find.byType(RichText));
  expect(richText, findsOneWidget);
  return tester.renderObject<RenderParagraph>(richText);
}

/// Drag from page padding, away from fields, so large editable text does not
/// receive a selection gesture. Reaching a target requires its actual painted
/// rect to fit the scroll viewport; no programmatic jump fabricates visibility.
Future<void> _dragCurrentPageUntilVisible(
  WidgetTester tester,
  Finder target,
  Finder page, {
  bool checkEditableFields = false,
  Finder? visibleStart,
}) async {
  final scrollable = tester.state<ScrollableState>(page);
  for (var step = 0; step < 64; step++) {
    final viewport = tester.getRect(page);
    Rect? targetRect;
    if (target.evaluate().isNotEmpty) {
      expect(target, findsOneWidget);
      targetRect = tester.getRect(target);
      if (visibleStart != null && visibleStart.evaluate().isNotEmpty) {
        expect(visibleStart, findsOneWidget);
        targetRect = targetRect.expandToInclude(tester.getRect(visibleStart));
      }
      if (targetRect.left >= viewport.left - 0.01 &&
          targetRect.right <= viewport.right + 0.01 &&
          targetRect.top >= viewport.top - 0.01 &&
          targetRect.bottom <= viewport.bottom + 0.01) {
        expect(tester.takeException(), isNull);
        return;
      }
    }
    final previous = scrollable.position.pixels;
    final moveDown = targetRect != null && targetRect.top < viewport.top;
    var distance = viewport.height * (moveDown ? 0.55 : -0.55);
    if (targetRect != null) {
      distance = moveDown
          ? viewport.top - targetRect.top + 8
          : viewport.bottom - targetRect.bottom - 8;
      final maximum = viewport.height * 0.55;
      distance = distance.clamp(-maximum, maximum).toDouble();
      final minimum = viewport.height * 0.1;
      if (distance.abs() < minimum) {
        distance = distance < 0 ? -minimum : minimum;
      }
    }
    await tester.dragFrom(
      Offset(
        checkEditableFields ? viewport.left + 4 : viewport.center.dx,
        viewport.center.dy,
      ),
      Offset(0, distance),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (checkEditableFields) _expectNamedEditableFields(tester);
    expect(
      (scrollable.position.pixels - previous).abs(),
      greaterThan(0.01),
      reason:
          'The target is not fully visible and the real scroll made no progress.',
    );
  }
  fail(
    'The current fixture target was not reached within 64 real margin drags.',
  );
}

Future<void> _expectCurrentInviteQrPayload(
  WidgetTester tester,
  Finder qr,
) async {
  expect(qr, findsOneWidget);
  final paint = find.descendant(of: qr, matching: find.byType(CustomPaint));
  expect(paint, findsOneWidget);
  final actual = tester.widget<CustomPaint>(paint).painter;
  expect(actual, isA<QrPainter>());
  final painter = actual! as QrPainter;
  final expected = QrPainter(
    data: _currentInviteUrl,
    version: painter.version,
    errorCorrectionLevel: painter.errorCorrectionLevel,
    gapless: painter.gapless,
    eyeStyle: painter.eyeStyle,
    dataModuleStyle: painter.dataModuleStyle,
  );
  final matchesPayload = await tester.runAsync(() async {
    final size = tester.getSize(paint).width;
    final rendered = await painter
        .toImageData(size, format: ui.ImageByteFormat.png)
        .timeout(const Duration(seconds: 30));
    final expectedPaint = await expected
        .toImageData(size, format: ui.ImageByteFormat.png)
        .timeout(const Duration(seconds: 30));
    expect(rendered, isNotNull);
    expect(expectedPaint, isNotNull);
    expect(
      rendered!.buffer.asUint8List(
        rendered.offsetInBytes,
        rendered.lengthInBytes,
      ),
      orderedEquals(
        expectedPaint!.buffer.asUint8List(
          expectedPaint.offsetInBytes,
          expectedPaint.lengthInBytes,
        ),
      ),
      reason: 'The painted QR must encode the complete own invitation URL.',
    );
    return true;
  });
  expect(matchesPayload, isTrue);
}

void _expectNamedEditableFields(WidgetTester tester) {
  final fields = find.byType(EditableText);
  for (var i = 0; i < fields.evaluate().length; i++) {
    final editable = tester
        .state<EditableTextState>(fields.at(i))
        .renderEditable;
    expect(
      editable.size.height + 1,
      greaterThanOrEqualTo(editable.preferredLineHeight),
      reason: 'An input must have room for a complete enlarged-text line.',
    );
  }
  void visit(SemanticsNode node) {
    if (node.flagsCollection.isTextField) {
      expect(
        node.label.trim(),
        isNotEmpty,
        reason: 'Editable fields need a name separate from their value: $node',
      );
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root =
      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Size size,
  Widget child, {
  bool light = false,
  double textScale = 1,
}) async {
  await const AssetImage('icon/mobi_logo_transparent.png').evict();
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();

  if (_isDesignCapture) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  if (_isDesignCapture) await preloadDesignCaptureLogo(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _baseOverrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _isDesignCapture
            ? designCaptureTheme(
                light ? AppTheme.lightTheme : AppTheme.darkTheme,
              )
            : ordinaryGoldenTheme(
                light ? AppTheme.lightTheme : AppTheme.darkTheme,
              ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  if (!_isDesignCapture) {
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('icon/mobi_logo_transparent.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
  }
  await tester.pumpAndSettle();
  if (_isDesignCapture) {
    await settleDesignCaptureFonts(tester);
  }
}

Widget _adminPreview({
  AdminWorkspaceTab tab = AdminWorkspaceTab.overview,
  String title = 'Operations',
  String subtitle = 'Live platform controls',
}) {
  return AdminWorkspaceFrame(
    title: title,
    subtitle: subtitle,
    currentTab: tab,
    actions: const [
      AdminActionChip(icon: LucideIcons.refreshCw, label: 'Refresh'),
    ],
    child: ListView(
      padding: AdminLayoutTokens.pagePadding,
      children: [
        _adminPreviewMetrics(tab),
        const SizedBox(height: 20),
        _adminPreviewState(tab),
      ],
    ),
  );
}

Widget _adminPreviewMetrics(AdminWorkspaceTab tab) {
  final metrics = switch (tab) {
    AdminWorkspaceTab.users => const [
      (label: 'Pending KYC', value: '18', icon: LucideIcons.userCheck),
      (label: 'New drivers', value: '34', icon: LucideIcons.car),
      (label: 'Locked accounts', value: '3', icon: LucideIcons.lock),
    ],
    AdminWorkspaceTab.trips => const [
      (label: 'Active trips', value: '48', icon: LucideIcons.navigation),
      (label: 'Late pickups', value: '7', icon: LucideIcons.clock),
      (label: 'Escalations', value: '2', icon: LucideIcons.alertTriangle),
    ],
    AdminWorkspaceTab.health => const [
      (label: 'API health', value: '99.9%', icon: LucideIcons.activity),
      (label: 'Queue depth', value: '14', icon: LucideIcons.listChecks),
      (label: 'Open gates', value: '5', icon: LucideIcons.shieldAlert),
    ],
    AdminWorkspaceTab.broadcasts => const [
      (label: 'Drafts', value: '6', icon: LucideIcons.fileEdit),
      (label: 'Opted in', value: '82%', icon: LucideIcons.checkCircle2),
      (label: 'Scheduled', value: '4', icon: LucideIcons.calendarClock),
    ],
    _ => const [
      (label: 'Open reports', value: '12', icon: LucideIcons.flag),
      (label: 'Active trips', value: '48', icon: LucideIcons.navigation),
      (label: 'Live users', value: '214', icon: LucideIcons.users),
    ],
  };

  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final metric in metrics)
        AdminMetricCard(
          label: metric.label,
          value: metric.value,
          icon: metric.icon,
        ),
    ],
  );
}

Widget _adminPreviewState(AdminWorkspaceTab tab) {
  return switch (tab) {
    AdminWorkspaceTab.users => const AdminEmptyState(
      icon: LucideIcons.userCheck,
      title: 'User review queue ready',
      message: 'Identity, role, and access checks are visible.',
    ),
    AdminWorkspaceTab.trips => const AdminEmptyState(
      icon: LucideIcons.map,
      title: 'Trip controls available',
      message: 'Dispatch teams can scan active work and exceptions.',
    ),
    AdminWorkspaceTab.health => const AdminEmptyState(
      icon: LucideIcons.shieldCheck,
      title: 'No production blockers',
      message: 'Release guardrails and health checks are passing.',
    ),
    AdminWorkspaceTab.broadcasts => const AdminEmptyState(
      icon: LucideIcons.radio,
      title: 'Campaign workspace ready',
      message: 'Consent and audience checks are surfaced before send.',
    ),
    _ => const AdminEmptyState(
      icon: LucideIcons.shieldCheck,
      title: 'No critical alerts',
      message: 'Ops review is clear.',
    ),
  };
}

class _GoldenCase {
  final String name;
  final Widget Function() builder;
  final bool includeDesktop;
  final Future<void> Function(WidgetTester)? prepare;

  const _GoldenCase({
    required this.name,
    required this.builder,
    this.includeDesktop = false,
    this.prepare,
  });
}

/// Local account hooks exercise conditional admin Profile presentation only;
/// they never establish a verified admin session or a real sign-out outcome.
class _AdminProfileCaptureService extends Fake implements ProfileService {
  @override
  Future<Profile?> getMyProfile() async => const Profile(
    id: '11111111-1111-4111-8111-111111111111',
    memberId: '004321',
    role: 'admin',
  );
}

final _previewCountries = Country.fallbackCountries
    .where((country) => country.id == 'RW' || country.id == 'KE')
    .toList();

final _previewVehicleTypes = VehicleTypeModel.fallbackTypes
    .map(
      (type) => VehicleTypeModel(
        id: type.id,
        label: type.label,
        iconName: type.iconName,
        sortOrder: type.sortOrder,
        isActive: type.id != 'truck',
        countryIds: const ['RW', 'KE'],
      ),
    )
    .toList();

const _previewPlans = [
  SubscriptionPlanModel(
    id: 'plan-bus-daily',
    vehicleTypeId: 'bus',
    countryId: 'RW',
    intervalDays: 1,
    price: 1200,
    currency: 'RWF',
  ),
  SubscriptionPlanModel(
    id: 'plan-cab-monthly',
    vehicleTypeId: 'cab',
    countryId: 'RW',
    intervalDays: 30,
    price: 18000,
    currency: 'RWF',
  ),
  SubscriptionPlanModel(
    id: 'plan-moto-weekly',
    vehicleTypeId: 'moto',
    countryId: 'KE',
    intervalDays: 7,
    price: 900,
    currency: 'KES',
    isActive: false,
  ),
];

/// Synthetic visual-fixture authority. It never calls a backend or enrolls a
/// face; the stored baseline represents an explicit not-started enrollment.
class _GoldenFaceService extends BioPayFaceService {
  static const _account = AccountSnapshot(
    '11111111-1111-4111-8111-111111111111',
    'golden-fixture-session',
    0,
  );

  @override
  String get ownerId => _account.userId;
  @override
  AccountSnapshot captureAccount() => _account;
  @override
  bool isCurrent(AccountSnapshot account) =>
      account.identity == _account.identity &&
      account.generation == _account.generation;
  @override
  Future<BioPayEnrollmentStatus> enrollmentStatus() async =>
      const BioPayEnrollmentStatus(status: 'not_started');
}

final _baseOverrides = [
  countryServiceProvider.overrideWithValue(_PreviewCountryService()),
  vehicleTypeServiceProvider.overrideWithValue(_PreviewVehicleTypeService()),
  subscriptionPlanServiceProvider.overrideWithValue(
    _PreviewSubscriptionPlanService(),
  ),
  tripServiceProvider.overrideWithValue(_PreviewTripService()),
  adminServiceProvider.overrideWithValue(_PreviewAdminService()),
];

class _PreviewCountryService implements CountryService {
  @override
  Future<List<Country>> getCountries() async => _previewCountries;

  @override
  Future<List<Country>> getAfricanCountries() async => _previewCountries;

  @override
  Future<Country?> findById(String id) async => _previewCountries.firstWhere(
    (country) => country.id == id,
    orElse: () => _previewCountries.first,
  );

  @override
  Future<Country> findByDialingCode(String code) async =>
      findByDialingCodeSync(code) ?? _previewCountries.first;

  @override
  Country? findByDialingCodeSync(String code) => _previewCountries
      .where((country) => country.dialingCode == code)
      .firstOrNull;

  @override
  Future<String> currencyForCode(String dialingCode) async =>
      currencyForCodeSync(dialingCode);

  @override
  String currencyForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.currency ?? 'RWF';

  @override
  String momoBrandForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.momoBrand ?? 'MoMo';

  @override
  String buildUssdForNumber(
    String dialingCode,
    String phone, [
    String? amount,
  ]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForNumber(phone, amount) ??
      '';

  @override
  String buildUssdForCode(String dialingCode, String code, [String? amount]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForCode(code, amount) ?? '';

  @override
  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) => rawValue.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<void> warmCache() async {}

  @override
  void clearCache() {}
}

class _PreviewVehicleTypeService implements VehicleTypeService {
  @override
  Future<List<VehicleTypeModel>> getAll({bool includeInactive = false}) async =>
      includeInactive
      ? _previewVehicleTypes
      : _previewVehicleTypes.where((type) => type.isActive).toList();

  @override
  Future<List<VehicleTypeModel>> getForCountry(String countryId) async =>
      _previewVehicleTypes
          .where((type) => type.countryIds.contains(countryId))
          .toList();

  @override
  Future<VehicleTypeModel?> findById(String id) async =>
      _previewVehicleTypes.where((type) => type.id == id).firstOrNull;

  @override
  void invalidateCache() {}

  @override
  Future<void> warmCache() async {}

  @override
  Future<void> update(VehicleTypeModel model) async {}

  @override
  Future<void> updateCountries(
    String vehicleTypeId,
    List<String> countryIds,
  ) async {}

  @override
  Future<void> toggleActive(String vehicleTypeId, bool isActive) async {}
}

class _PreviewSubscriptionPlanService implements SubscriptionPlanService {
  @override
  SupabaseClient get supabase => throw UnimplementedError();

  @override
  Future<List<SubscriptionPlanModel>> getAll({
    bool forceRefresh = false,
  }) async => _previewPlans;

  @override
  Future<List<SubscriptionPlanModel>> getAvailablePlans(
    String vehicleTypeId,
    String countryId,
  ) async => _previewPlans
      .where(
        (plan) =>
            plan.vehicleTypeId == vehicleTypeId &&
            plan.countryId == countryId &&
            plan.isActive,
      )
      .toList();

  @override
  Future<void> upsert({
    required String vehicleTypeId,
    required String countryId,
    required int intervalDays,
    required double price,
    required String currency,
    bool isActive = true,
  }) async {}

  @override
  Future<void> toggleActive(String id, bool isActive) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<SubscriptionOperationsSnapshot> getOperationsSnapshot({
    int limit = 25,
  }) async => const SubscriptionOperationsSnapshot(
    paymentRequests: [],
    smsReceipts: [],
  );

  @override
  Future<int> expireStalePaymentRequests() async => 0;

  @override
  Future<void> confirmMomoSmsReceipt({
    required String receiptId,
    String? reviewNote,
  }) async {}

  @override
  void invalidateCache() {}
}

class _PreviewTripService implements TripService {
  List<Trip> get _trips => const [
    Trip(
      id: 't1',
      authorId: 'preview-driver',
      authorName: 'Jean Driver',
      origin: 'Kigali Heights',
      destination: 'Kimironko Terminal',
      originLat: -1.9536,
      originLng: 30.0928,
      destLat: -1.9367,
      destLng: 30.1308,
      departureDate: '2026-06-20',
      departureTime: '08:30',
      role: 'driver',
      seats: 3,
      price: 'RWF 2,500',
      note: 'Shared morning route with two open seats.',
      isActive: true,
      status: 'active',
      vehicleTypeStr: 'bus',
      isRecurring: true,
      recurringDays: [0, 2, 4],
    ),
  ];

  @override
  Future<Trip> createTrip({
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? clientRequestId,
    String? note,
  }) async => _trips.first;

  @override
  Future<Trip?> getTripById(String tripId) async =>
      _trips.where((trip) => trip.id == tripId).firstOrNull ?? _trips.first;

  @override
  Future<List<Trip>> getMyTrips() async => _trips;

  @override
  Future<List<Trip>> getNearbyTrips({String? role}) async {
    final normalizedRole = role?.trim().toLowerCase();
    if (normalizedRole == 'driver' || normalizedRole == 'passenger') {
      return _trips.where((trip) => trip.role == normalizedRole).toList();
    }
    return _trips;
  }

  @override
  Future<List<Trip>> getCounterpartScheduledTrips(String viewerMode) async {
    final roleToView = viewerMode.trim().toLowerCase() == 'driver'
        ? 'passenger'
        : 'driver';
    return getNearbyTrips(role: roleToView);
  }

  @override
  Future<List<Trip>> getPoolSuggestions(
    String tripId, {
    int limit = 10,
  }) async => _trips.take(limit).toList();

  @override
  Future<Trip> updateTrip({
    required String tripId,
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? note,
  }) async => _trips.first;

  @override
  Future<void> cancelTrip(String tripId) async {}
}

class _PreviewAdminService implements AdminService {
  final _memberContract = PreviewAdminUserContract();
  @override
  String? get currentSessionId => PreviewAdminUserContract.sessionId;
  @override
  AdminRoleRecoveryOwner get roleRecoveryOwner => _memberContract.owner;
  @override
  Future<AdminUserPage> listUsersPage(AdminUserQuery query) =>
      _memberContract.page(query);
  @override
  Future<AdminUserSnapshotRelease> releaseUsersSnapshot(String snapshotId) =>
      _memberContract.release(snapshotId);
  @override
  Future<AdminRoleBatchEnvelope> reserveRoleChange(AdminRoleReview review) =>
      _memberContract.reserve(review);
  @override
  Future<AdminRoleBatchEnvelope> executeRoleChange({
    required AdminRoleBatchEnvelope envelope,
    required String operationId,
  }) => _memberContract.execute(envelope, operationId);
  @override
  Future<AdminRoleBatchEnvelope> roleChangeStatus({
    String? batchId,
    String? reservationId,
  }) => _memberContract.status(batchId: batchId, reservationId: reservationId);
  @override
  Future<AdminRoleBatchEnvelope> sealRoleChange({
    String? batchId,
    String? reservationId,
  }) => _memberContract.seal(batchId: batchId, reservationId: reservationId);

  @override
  String? get currentUserId => PreviewAdminUserContract.actorId;

  @override
  Future<bool> checkAdminAccess(String phoneE164) async => true;

  @override
  Future<AdminDashboardStats> getDashboardStats() async =>
      const AdminDashboardStats(
        totalUsers: 214,
        activeDrivers: 58,
        activePassengers: 156,
        totalTrips: 482,
        activeTrips: 48,
        cancelledTrips: 6,
      );

  @override
  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminUserListItem(
      id: 'u1',
      name: 'Chantal Rider',
      phone: '+250788111222',
      role: 'passenger',
      isDriver: false,
      hasFaceId: true,
      isOnline: true,
      memberId: '482013',
      createdAt: '2026-06-10T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [
    AdminTripListItem(
      id: 'trip-1',
      authorId: 'u2',
      authorName: 'Jean Driver',
      origin: 'Kigali Heights',
      destination: 'Kimironko Terminal',
      role: 'driver',
      vehicleType: 'bus',
      status: 'active',
      isActive: true,
      departureDate: '2026-06-20',
      memberId: '593821',
    ),
  ];

  @override
  Future<void> cancelTrip({required String tripId, String? reason}) async {}

  @override
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {}

  @override
  Future<AdminTokenAdjustmentReceipt> adjustUserTokens({
    required String userId,
    required int amountTokens,
    String? note,
  }) async => AdminTokenAdjustmentReceipt(
    ledgerEntryId: 'ledger-$userId',
    profileId: userId,
    amountTokens: amountTokens,
    status: 'completed',
  );

  @override
  Future<List<AdminWhatsappNumberItem>> listWhatsappAdminNumbers() async =>
      const [
        AdminWhatsappNumberItem(
          id: 'allow-1',
          phoneE164: '+250788000111',
          countryCode: '+250',
          isActive: true,
          displayName: 'Ops lead',
        ),
      ];

  @override
  Future<AdminWhatsappNumberItem> upsertWhatsappAdminNumber({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    bool isActive = true,
  }) async => AdminWhatsappNumberItem(
    id: 'allow-1',
    phoneE164: phoneE164,
    countryCode: countryCode,
    isActive: isActive,
    displayName: displayName,
  );

  @override
  Future<AdminWhatsappNumberItem> setWhatsappAdminNumberActive({
    required String id,
    required bool isActive,
  }) async => AdminWhatsappNumberItem(
    id: id,
    phoneE164: '+250788000111',
    countryCode: '+250',
    isActive: isActive,
  );

  @override
  Future<List<AdminAccessAttemptItem>> listAdminAccessAttempts({
    int limit = 20,
  }) async => const [
    AdminAccessAttemptItem(
      id: 'attempt-1',
      phoneE164: '+250788000111',
      status: 'approved',
      sourceApp: 'admin',
      createdAt: '2026-06-13T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminNotificationItem>> listAdminNotifications({
    int limit = 12,
  }) async => const [
    AdminNotificationItem(
      id: 'notice-1',
      userId: 'preview-admin',
      type: 'admin_digest',
      title: 'Daily ops review ready',
      body: 'Reports, trips, and BioPay queues are up to date.',
    ),
  ];

  @override
  Future<AdminPlatformSettings> getPlatformSettings() async =>
      const AdminPlatformSettings(
        insuranceAgentWhatsappE164: '+250795588248',
        tokenRedemptionAdminMemberId: '482013',
      );

  @override
  Future<AdminPlatformSettings> updatePlatformSetting({
    required String key,
    required String value,
  }) async => getPlatformSettings();

  @override
  Future<List<AdminTokenRedemptionItem>> listTokenRedemptions({
    String status = 'pending',
    int limit = 8,
  }) async => const [
    AdminTokenRedemptionItem(
      id: 'redeem-1',
      requesterProfileId: 'u1',
      requesterName: 'Chantal Rider',
      requesterMemberId: '482013',
      adminMemberId: '482999',
      momoNumber: '0788111222',
      amountTokens: 5000,
      amountRwf: 5000,
      status: 'pending',
      createdAt: '2026-06-16T08:00:00Z',
    ),
  ];

  @override
  Future<AdminTokenRedemptionItem> updateTokenRedemptionStatus({
    required String requestId,
    required String status,
    String? adminNote,
  }) async => AdminTokenRedemptionItem(
    id: requestId,
    requesterProfileId: 'u1',
    requesterName: 'Chantal Rider',
    requesterMemberId: '482013',
    adminMemberId: '482999',
    momoNumber: '0788111222',
    amountTokens: 5000,
    amountRwf: 5000,
    status: status,
    adminNote: adminNote,
  );

  @override
  Future<void> markAdminNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllAdminNotificationsRead() async {}

  @override
  Future<int> sendPromoNotification({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 42;

  @override
  Future<String> requestPromoApproval({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 'campaign-1';

  @override
  Future<List<AdminCampaignApprovalItem>> listCampaignApprovals({
    String? status,
    String? campaignType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<List<AdminNotificationConsentSummary>>
  getNotificationConsentSummary() async => const [
    AdminNotificationConsentSummary(
      organizationId: 'org-1',
      organizationName: 'Mobio',
      eligibleProfileCount: 120,
      promotionalInAppCount: 82,
      promotionalPushCount: 70,
      promotionalAnyCount: 96,
      revokedOrDeniedCount: 8,
    ),
  ];

  @override
  Future<AdminCampaignAudiencePreview> getCampaignAudiencePreview({
    required String campaignId,
  }) async => const AdminCampaignAudiencePreview(
    campaignId: 'campaign-1',
    organizationId: 'org-1',
    eligibleRecipientCount: 120,
    promotionalConsentCount: 96,
    promotionalInAppCount: 82,
    promotionalPushCount: 70,
    revokedOrDeniedCount: 8,
    alreadySentCount: 0,
  );

  @override
  Future<List<AdminAuditLogItem>> listCampaignAuditTimeline({
    required String campaignId,
  }) async => _auditLogs;

  @override
  Future<List<AdminNotificationConsentTrendPoint>> getNotificationConsentTrend({
    int days = 30,
  }) async => const [
    AdminNotificationConsentTrendPoint(
      bucketDate: '2026-06-13',
      grantedCount: 96,
      revokedOrDeniedCount: 8,
      inAppGrantedCount: 82,
      pushGrantedCount: 70,
    ),
  ];

  @override
  Future<void> approveCampaign({
    required String campaignId,
    required bool approved,
    String? notes,
  }) async {}

  @override
  Future<int> sendApprovedCampaign({required String campaignId}) async => 96;

  @override
  Future<int> sendSystemAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 120;

  @override
  Future<int> sendPromo({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 96;

  @override
  Future<int> sendAnnouncement({
    required String title,
    String? body,
    Map<String, dynamic>? metadata,
  }) async => 120;

  static const _auditLogs = [
    AdminAuditLogItem(
      id: 'audit-1',
      adminName: 'Platform admin',
      action: 'review_report',
      targetType: 'user_report',
      targetId: 'report-1',
      details: {'status': 'reviewing', 'queue': 'safety'},
      createdAt: '2026-06-13T08:00:00Z',
    ),
    AdminAuditLogItem(
      id: 'audit-2',
      adminName: 'Ops lead',
      action: 'update_user_role',
      targetType: 'profile',
      targetId: 'u1',
      details: {'from': 'passenger', 'to': 'driver'},
      createdAt: '2026-06-12T14:30:00Z',
    ),
  ];

  @override
  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? action,
    String? targetType,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => _auditLogs;

  @override
  Future<List<AdminOperationalHealthEventItem>> listOperationalHealthEvents({
    String? status,
    String? severity,
    String? service,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async => const [
    AdminOperationalHealthEventItem(
      id: 'health-1',
      service: 'biopay',
      component: 'aws-face',
      status: 'ok',
      severity: 'info',
      message: 'Face provider responding within threshold.',
      userName: 'System',
      ingestOrigin: 'preview',
      occurredAt: '2026-06-13T08:00:00Z',
    ),
  ];

  @override
  Future<List<AdminUserReportItem>> listUserReports({
    String status = 'open',
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    const reports = [
      AdminUserReportItem(
        id: 'report-1',
        reporterId: 'u1',
        reporterName: 'Chantal Rider',
        reporterPhone: '+250788111222',
        reportedId: 'u2',
        reportedName: 'Jean Driver',
        reportedPhone: '+250788333444',
        conversationId: 'conversation-1',
        tripId: 'trip-1',
        category: 'unsafe_behavior',
        details: 'Driver requested an off-platform payment before pickup.',
        status: 'open',
        createdAt: '2026-06-13T07:30:00Z',
      ),
      AdminUserReportItem(
        id: 'report-2',
        reporterId: 'u3',
        reporterName: 'Patrick Passenger',
        reportedId: 'u4',
        reportedName: 'Aline Driver',
        category: 'route_mismatch',
        details: 'Pickup location changed without confirmation.',
        status: 'resolved',
        resolutionNotes: 'Driver warned and route note updated.',
        createdAt: '2026-06-12T15:00:00Z',
      ),
    ];
    final query = search?.trim().toLowerCase() ?? '';
    final filtered = reports.where((report) {
      if (status != 'all' && report.status != status) return false;
      if (query.isEmpty) return true;
      return [
        report.reporterName,
        report.reporterPhone,
        report.reportedName,
        report.reportedPhone,
        report.category,
        report.details,
        report.resolutionNotes,
      ].whereType<String>().any((value) => value.toLowerCase().contains(query));
    });
    return filtered
        .skip(offset < 0 ? 0 : offset)
        .take(limit < 0 ? 0 : limit)
        .toList(growable: false);
  }

  @override
  Future<void> reviewUserReport({
    required String reportId,
    required String status,
    String? notes,
  }) async {}
}

/// Capture-only mode: writes synthetic renders for human review, without
/// comparing or approving a baseline. Normal invocations still compare goldens.
class _DesignCaptureComparator extends GoldenFileComparator {
  _DesignCaptureComparator(this.directory);
  final Directory directory;
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final relative = golden.path.replaceFirst('goldens/revolut/', '');
    final target = File('${directory.path}/$relative');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(imageBytes);
  }
}

class _ExpiredPreviewUssdService extends BioPayUssdService {
  @override
  BioPayUssdPaymentRequest resolvePreviewToken(String token) {
    throw const FormatException('Expired synthetic request');
  }
}
