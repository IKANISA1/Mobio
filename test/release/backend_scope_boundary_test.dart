import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backend production scope boundary', () {
    test('legacy payment, SMS, and BioPay functions are inert', () {
      for (final path in const [
        'supabase/functions/biopay-api/index.ts',
        'supabase/functions/create-payment-intent/index.ts',
        'supabase/functions/verify-payment-status/index.ts',
        'supabase/functions/parse-sms/index.ts',
        'supabase/functions/reconcile-momo-sms/index.ts',
        'supabase/functions/admin-review-transaction/index.ts',
      ]) {
        final source = File(path).readAsStringSync();

        expect(source, contains('scopeUnavailableResponse'));
        expect(source, isNot(contains('createAdminClient')));
        expect(source, isNot(contains('.from("payment_intents")')));
        expect(source, isNot(contains('.from("transactions")')));
        expect(source, isNot(contains('.from("sms_raw_queue")')));
        expect(source, isNot(contains('.from("biopay_profiles")')));
      }
    });

    test('cleanup migration removes out-of-scope legacy schema objects', () {
      final migration = File(
        'supabase/migrations/20260501134000_scope_cleanup_legacy_trip_payment_biopay.sql',
      ).readAsStringSync();
      final finalCleanup = File(
        'supabase/migrations/20260524001000_final_scope_cleanup_after_linked_history.sql',
      ).readAsStringSync();

      for (final objectName in const [
        'public.payment_intents',
        'public.payment_events',
        'public.qr_payment_sessions',
        'public.nfc_payment_sessions',
        'public.transactions',
        'public.sms_raw_queue',
        'public.ride_requests',
        'public.trip_requests',
        'public.biopay_profiles',
        'public.biopay_wallets',
        'public.biopay_transactions',
        'public.face_templates',
      ]) {
        expect(migration, contains('drop table if exists $objectName cascade'));
      }

      expect(migration, contains('rpc_admin_list_risk_flags'));
      expect(migration, contains('rpc_resolve_qr_payment_session'));
      expect(migration, contains('rpc_resolve_nfc_payment_session'));
      expect(migration, contains('fn_biopay_scan_and_charge'));
      expect(migration, contains('drop column if exists biopay_handle_type'));
      expect(migration, contains('drop column if exists biopay_handle_value'));
      expect(migration, contains('drop column if exists has_face_id'));
      expect(migration, contains('drop column if exists sender_id'));
      expect(migration, contains("permission_key = 'admin.finance.review'"));

      expect(
        finalCleanup,
        contains('alter publication supabase_realtime drop table'),
      );
      expect(
        finalCleanup,
        contains('drop table if exists public.transactions cascade'),
      );
      expect(
        finalCleanup,
        contains('drop table if exists public.sms_raw_queue cascade'),
      );
      expect(finalCleanup, contains('drop column if exists sender_id'));
      expect(finalCleanup, contains('admin.operations.read'));
    });

    test('linked backend assertions reject legacy schema if it remains', () {
      final assertions = File(
        'supabase/tests/backend_security_assertions.sql',
      ).readAsStringSync();

      expect(assertions, contains('out-of-scope legacy table still exists'));
      expect(assertions, contains('out-of-scope legacy routine still exists'));
      expect(
        assertions,
        contains('out-of-scope profile BioPay column still exists'),
      );
      expect(
        assertions,
        contains('out-of-scope country SMS sender column still exists'),
      );
      expect(assertions, contains('trip_requests'));
      expect(assertions, contains('biopay_profiles'));
      expect(assertions, contains('payment_intents'));
      expect(assertions, contains('sms_raw_queue'));
    });

    test(
      'shared unavailable response documents the approved product scope',
      () {
        final source = File(
          'supabase/functions/_shared/scope-unavailable.ts',
        ).readAsStringSync();

        expect(source, contains('nearby discovery'));
        expect(source, contains('scheduled trip posts'));
        expect(source, contains('WhatsApp handoff'));
        expect(source, contains('No in-app fare engine'));
        expect(source, contains('payment settlement'));
        expect(source, contains('SMS ledger ingestion'));
      },
    );
  });
}
