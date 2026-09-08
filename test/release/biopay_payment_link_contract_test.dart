import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Static checks supplement behavioral parser/controller/SQL tests by guarding
// capabilities that widget tests cannot exercise on a native handset.
void main() {
  group('BioPay reviewed external handoff boundary', () {
    test(
      'entry points select the shared task and preserve insurance access',
      () {
        final home = File(
          'lib/features/biopay/presentation/biopay_home_screen.dart',
        ).readAsStringSync();
        final router = File(
          'lib/app/router/app_router.dart',
        ).readAsStringSync();
        expect(home, contains('openInsuranceAgentChat'));
        expect(router, contains("path: '/biopay/send'"));
        expect(router, contains("path: '/biopay/pay/:token'"));
        expect(router, contains('PaymentLinkArrivalScreen'));
        expect(router, contains('PaymentRequestEditor'));
        expect(router, contains('PaymentNfcLinkScreen'));
      },
    );

    test(
      'insurance banner retains the existing admin-managed public setting',
      () {
        final service = File(
          'lib/features/biopay/data/biopay_ussd_service.dart',
        ).readAsStringSync();
        final migration = File(
          'supabase/migrations/20260616110000_wallet_redemptions_and_insurance_config.sql',
        ).readAsStringSync();
        expect(service, contains('insurance_agent_whatsapp_e164'));
        expect(service, contains('rpc_get_public_app_setting'));
        expect(service, contains('insuranceAgentWhatsAppUri'));
        expect(migration, contains('rpc_admin_upsert_platform_setting'));
      },
    );

    test('Android never calls automatically or asks for call permission', () {
      final native = File(
        'android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt',
      ).readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(native, contains('rw.mobi.app/biopay_ussd_dialer'));
      expect(native, contains('Intent.ACTION_DIAL'));
      expect(native, isNot(contains('Intent.ACTION_CALL')));
      expect(native, isNot(contains('Manifest.permission.CALL_PHONE')));
      expect(manifest, isNot(contains('android.permission.CALL_PHONE')));
      expect(manifest, isNot(contains('android.intent.action.CALL')));
      expect(manifest, contains('android.intent.action.DIAL'));
      expect(
        native,
        contains('ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE'),
      );
      expect(native, contains('Intent.ACTION_PICK'));
      expect(native, contains('Intent.ACTION_OPEN_DOCUMENT'));
    });

    test(
      'iOS selects a phone property and one image without bulk contact access',
      () {
        final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
        expect(native, contains('CNContactPickerViewController'));
        expect(native, contains('CNContactProperty'));
        expect(native, contains('PHPickerViewController'));
        expect(native, contains('selectionLimit = 1'));
        expect(native, isNot(contains('enumerateContacts')));
        expect(native, isNot(contains('CNContactStore().requestAccess')));
      },
    );

    test('legacy link screen cannot automatically open a dialer', () {
      final screen = File(
        'lib/features/biopay/presentation/biopay_payment_link_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('bool get _shouldAutoLaunchDialer => false'));
    });
  });
}
