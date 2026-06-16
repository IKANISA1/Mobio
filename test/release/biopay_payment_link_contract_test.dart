import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BioPay direct MoMo USSD request contract', () {
    const homePath = 'lib/features/biopay/biopay_home_screen.dart';
    const requestScreenPath =
        'lib/features/biopay/biopay_request_payment_screen.dart';
    const payerScreenPath =
        'lib/features/biopay/biopay_payment_link_screen.dart';
    const flowSharedPath = 'lib/features/biopay/biopay_flow_shared.dart';
    const servicePath = 'lib/core/services/biopay_ussd_service.dart';
    const routerPath = 'lib/core/router/app_router.dart';
    const configPath = 'lib/core/config/supabase_config.dart';
    const manifestPath = 'android/app/src/main/AndroidManifest.xml';
    const migrationPath =
        'supabase/migrations/20260615135000_biopay_payment_request_links.sql';
    const configMigrationPath =
        'supabase/migrations/20260616110000_wallet_redemptions_and_insurance_config.sql';

    test('BioPay home exposes MoMo USSD request action', () {
      final home = File(homePath).readAsStringSync();
      final router = File(routerPath).readAsStringSync();

      expect(home, contains('Get Payment Link'));
      expect(home, contains('Motor insurance'));
      expect(home, contains('3000 TOKENS'));
      expect(home, contains('openInsuranceAgentChat'));
      expect(home, contains('onRequestPayment'));
      expect(router, contains("context.push('/biopay/request-payment')"));
    });

    test('insurance banner uses admin-managed public setting', () {
      final service = File(servicePath).readAsStringSync();
      final migration = File(configMigrationPath).readAsStringSync();

      expect(service, contains('insurance_agent_whatsapp_e164'));
      expect(service, contains('rpc_get_public_app_setting'));
      expect(service, contains('+250795588248'));
      expect(service, contains('insuranceAgentWhatsAppUri'));
      expect(migration, contains('app_platform_settings'));
      expect(migration, contains('rpc_admin_upsert_platform_setting'));
      expect(migration, contains('insurance_agent_whatsapp_e164'));
      expect(migration, contains('is_public'));
    });

    test('payee creates a direct MoMo USSD link with receiver and amount', () {
      final screen = File(requestScreenPath).readAsStringSync();

      expect(screen, contains('BioPayRequestPaymentScreen'));
      expect(screen, contains('BioPayReceiverField'));
      expect(screen, contains('BioPayReceiveAmountField'));
      expect(screen, contains('amountMinorFromController'));
      expect(screen, contains('_hasValidReceiver'));
      expect(screen, contains('_hasValidAmount'));
      expect(screen, contains("BioPayDetailRow(label: 'Receiver'"));
      expect(screen, contains("BioPayDetailRow(label: 'Amount'"));
      expect(screen, contains('Share on WhatsApp'));
      expect(
        screen,
        contains("primaryLabel: request == null ? 'Generate USSD link'"),
      );
      expect(screen, contains("child: const Text('Copy USSD link')"));
      expect(screen, contains('MoMo USSD link ready'));
      expect(screen, contains('paymentRequestDialerUri(request)'));
      expect(screen, isNot(contains('paymentRequestUri(request).toString()')));
      expect(
        screen,
        isNot(
          contains(
            'variant: MobiButtonVariant.ghost,\n'
            '                    onPressed: isCopying ? null : onCopy',
          ),
        ),
      );
      expect(screen, contains('paymentRequestWhatsAppUri'));
      expect(screen, contains('paymentRequestShareText'));
      expect(
        screen,
        isNot(
          contains(
            'Share it on WhatsApp. The payer taps the link and Mobio opens MoMo USSD.',
          ),
        ),
      );
    });

    test('QR output uses Rwanda logo gradient and tight logo badge', () {
      final flowShared = File(flowSharedPath).readAsStringSync();

      expect(flowShared, contains('_rwandaLogoGradient'));
      expect(flowShared, contains('Color(0xFF00A3E0)'));
      expect(flowShared, contains('Color(0xFFFAD201)'));
      expect(flowShared, contains('Color(0xFF00A651)'));
      expect(flowShared, contains('logoBadgeWidth'));
      expect(flowShared, contains('logoBadgeHeight'));
      expect(flowShared, isNot(contains('constraints.maxWidth * 0.24')));
    });

    test('payer link resolves and Android auto-launches the USSD dialer', () {
      final payerScreen = File(payerScreenPath).readAsStringSync();
      final service = File(servicePath).readAsStringSync();
      final router = File(routerPath).readAsStringSync();
      final config = File(configPath).readAsStringSync();
      final manifest = File(manifestPath).readAsStringSync();

      expect(router, contains("path: '/biopay/pay/:token'"));
      expect(router, contains("path.startsWith('/biopay/pay/')"));
      expect(config, contains('MOBIO_PUBLIC_APP_URL'));
      expect(service, contains("path: '/biopay/pay/"));
      expect(service, contains("Uri.parse('tel:\$encoded')"));
      expect(service, contains('paymentRequestDialerUri'));
      expect(service, contains('paymentRequestWhatsAppUri'));
      expect(service, contains('Receiver:'));
      expect(service, contains('Tap this MoMo USSD link:'));
      expect(service, isNot(contains('Request reference:')));
      expect(payerScreen, contains('TargetPlatform.android'));
      expect(payerScreen, contains('_shouldAutoLaunchDialer'));
      expect(payerScreen, contains('openUssdDialer(request)'));
      expect(payerScreen, contains('Open MoMo USSD'));
      expect(manifest, contains('android:pathPrefix="/biopay/pay"'));
      expect(manifest, contains('android:scheme="tel"'));
      expect(manifest, contains('android.permission.CALL_PHONE'));
      expect(manifest, contains('android.hardware.telephony'));
    });

    test(
      'Android native bridge places MoMo USSD call before dialer fallback',
      () {
        final mainActivity = File(
          'android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt',
        ).readAsStringSync();

        expect(mainActivity, contains('rw.mobi.app/biopay_ussd_dialer'));
        expect(mainActivity, contains('launchNativeUssd(call, result)'));
        expect(mainActivity, contains('Intent.ACTION_CALL'));
        expect(mainActivity, contains('Intent.ACTION_DIAL'));
        expect(mainActivity, contains('Manifest.permission.CALL_PHONE'));
        expect(mainActivity, contains('BIOPAY_USSD_CALL_PERMISSION_REQUEST'));
      },
    );

    test('backend records shared-link dialer handoff without profile row', () {
      final migration = File(migrationPath).readAsStringSync();

      expect(migration, contains('rpc_record_biopay_ussd_dialer_opened'));
      expect(migration, contains('v_profile_exists'));
      expect(migration, contains('shared_payment_link'));
      expect(migration, contains('anonymous_auth_user_id'));
      expect(
        migration,
        contains('without requiring the payer to have a profile row'),
      );
    });
  });
}
