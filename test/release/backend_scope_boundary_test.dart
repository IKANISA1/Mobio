import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backend production scope boundary', () {
    test('legacy payment, SMS, and BioPay functions are inert', () {
      for (final path in const [
        'supabase/functions/biopay-api/index.ts',
        'supabase/functions/create-payment-intent/index.ts',
        'supabase/functions/verify-payment-status/index.ts',
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

    test(
      'MoMo SMS functions are scoped to driver subscription reconciliation',
      () {
        final parseSms = File(
          'supabase/functions/parse-sms/index.ts',
        ).readAsStringSync();
        final reconcileMomoSms = File(
          'supabase/functions/reconcile-momo-sms/index.ts',
        ).readAsStringSync();
        final sharedParser = File(
          'supabase/functions/_shared/momo-sms.ts',
        ).readAsStringSync();
        final migration = File(
          'supabase/migrations/20260614120000_wallet_referrals_driver_plus.sql',
        ).readAsStringSync();

        for (final source in [parseSms, reconcileMomoSms]) {
          expect(source, contains('createAdminClient'));
          expect(source, contains('rpc_ingest_driver_subscription_momo_sms'));
          expect(source, isNot(contains('scopeUnavailableResponse')));
          expect(source, isNot(contains('.from("sms_raw_queue")')));
          expect(source, isNot(contains('.from("transactions")')));
          expect(source, isNot(contains('.from("payment_intents")')));
        }

        expect(sharedParser, contains('MOMO_SMS_BRIDGE_SECRET'));
        expect(sharedParser, contains('OPENAI_API_KEY_REQUIRED'));
        expect(sharedParser, contains('https://api.openai.com/v1/responses'));
        expect(migration, contains('driver_subscription_momo_sms_receipts'));
        expect(migration, contains('ADMIN_OR_SERVICE_ROLE_REQUIRED'));
        expect(migration, contains('ambiguous'));
      },
    );

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
      expect(assertions, contains('biopay_transactions'));
      expect(assertions, contains('payment_intents'));
      expect(assertions, contains('sms_raw_queue'));
    });

    test('BioPay reactivation is USSD-only and AWS face bounded', () {
      final migration = File(
        'supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql',
      ).readAsStringSync();
      final optionalAmountMigration = File(
        'supabase/migrations/20260612143000_biopay_qr_optional_amount.sql',
      ).readAsStringSync();
      final profileMomoMigration = File(
        'supabase/migrations/20260612204806_profile_momo_receiver_fields.sql',
      ).readAsStringSync();
      final faceProvider = File(
        'supabase/functions/biopay-face-provider/index.ts',
      ).readAsStringSync();

      for (final table in const [
        'biopay_profiles',
        'biopay_payment_requests',
        'biopay_ussd_attempts',
        'biopay_face_sessions',
        'biopay_audit_events',
      ]) {
        expect(migration, contains('create table if not exists public.$table'));
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
        );
      }

      expect(migration, contains('fn_biopay_ussd_code'));
      expect(migration, contains('rpc_create_biopay_ussd_request'));
      expect(optionalAmountMigration, contains('Amount cannot be negative'));
      expect(optionalAmountMigration, contains('amount_minor >= 0'));
      expect(profileMomoMigration, contains('momo_number text'));
      expect(profileMomoMigration, contains('momo_pay_code text'));
      expect(profileMomoMigration, contains('fn_momo_local_number'));
      expect(profileMomoMigration, contains('07XXXXXXXX'));
      expect(profileMomoMigration, contains('rpc_create_biopay_ussd_request'));
      expect(
        profileMomoMigration,
        contains('public.fn_momo_local_number(momo_number)'),
      );
      expect(
        optionalAmountMigration,
        contains(
          "v_phone text := nullif(trim(coalesce(p_payee_phone, '')), '')",
        ),
      );
      expect(
        optionalAmountMigration,
        contains(
          'v_phone := coalesce(v_phone, nullif(trim(coalesce(p_payee_phone',
        ),
      );
      expect(migration, contains('rpc_create_biopay_face_match_request'));
      expect(migration, contains('rpc_resolve_biopay_ussd_request'));
      expect(migration, contains('rpc_record_biopay_ussd_dialer_opened'));
      expect(
        migration,
        contains(
          'create or replace function public.rpc_record_biopay_ussd_dialer_opened(\n'
          '  p_request_id uuid\n'
          ') returns jsonb',
        ),
      );
      expect(migration, contains('rpc_mark_biopay_ussd_user_paid'));
      expect(migration, contains('rpc_list_biopay_ussd_requests'));
      expect(migration, contains('rpc_confirm_biopay_ussd_external'));
      expect(migration, contains('rpc_record_biopay_face_enrollment'));
      expect(migration, contains('fn_biopay_require_admin'));
      expect(migration, contains('rpc_admin_biopay_summary'));
      expect(migration, contains('rpc_admin_biopay_list_payees'));
      expect(migration, contains('rpc_admin_biopay_list_requests'));
      expect(migration, contains('rpc_admin_biopay_system_status'));
      expect(migration, contains('rpc_admin_biopay_confirm_external'));
      expect(migration, contains("profile.role = 'admin'"));
      expect(migration, contains('dialer_opened'));
      expect(migration, contains('user_marked_paid'));
      expect(
        migration,
        contains('BioPay request is not ready for USSD dialer handoff'),
      );
      expect(migration, contains('biopay.ussd.user_marked_paid'));
      expect(migration, contains('biopay.ussd.externally_confirmed'));
      expect(migration, contains('biopay.admin.externally_confirmed'));
      expect(migration, contains('biopay.face_match.ussd_request.created'));
      expect(
        migration,
        contains('bp.provider_subject_id = v_provider_face_id'),
      );
      expect(migration, contains('matched_payee_id'));
      expect(migration, contains('payee_id = v_user_id'));
      expect(migration, contains('confirmation_source = v_source'));
      expect(
        migration,
        contains("'ussd_handoff_status', 'external_ussd_only'"),
      );
      expect(migration, contains('biopay.face.enrolled'));
      expect(migration, contains('raw_asset_deleted_at'));
      expect(migration, isNot(contains('biopay_wallets')));
      expect(migration, isNot(contains('payment_intents')));
      expect(migration, isNot(contains('sms_raw_queue')));
      expect(faceProvider, contains('FACE_PROVIDER'));
      expect(faceProvider, contains('AWS_REKOGNITION_COLLECTION_ID'));
      expect(faceProvider, contains('aws_rekognition'));
      expect(faceProvider, contains('provider_collection_id'));
      expect(faceProvider, contains('model_version'));
      expect(faceProvider, contains('CreateFaceLivenessSession'));
      expect(faceProvider, contains('GetFaceLivenessSessionResults'));
      expect(faceProvider, contains('IndexFaces'));
      expect(faceProvider, contains('SearchFacesByImage'));
      expect(faceProvider, contains('USSD dialer handoff only'));
      expect(faceProvider, isNot(contains('google_mlkit')));
      expect(faceProvider, isNot(contains('tflite')));
    });

    test(
      'WhatsApp OTP functions invalidate stale codes and hash with context',
      () {
        final otpSecurity = File(
          'supabase/functions/_shared/otp-security.ts',
        ).readAsStringSync();
        final sendLoginOtp = File(
          'supabase/functions/send-login-otp/index.ts',
        ).readAsStringSync();
        final verifyLoginOtp = File(
          'supabase/functions/verify-login-otp/index.ts',
        ).readAsStringSync();
        final playReviewLogin = File(
          'supabase/functions/_shared/play-review-login.ts',
        ).readAsStringSync();
        final sendAdminOtp = File(
          'supabase/functions/send-otp/index.ts',
        ).readAsStringSync();
        final verifyAdminOtp = File(
          'supabase/functions/verify-otp/index.ts',
        ).readAsStringSync();

        expect(otpSecurity, contains('OTP_HASH_SECRET'));
        expect(otpSecurity, contains('context?: OtpHashContext'));
        expect(sendLoginOtp, contains('const purpose = "app_login"'));
        expect(
          sendLoginOtp,
          contains('await hashOtpCode(code, { phone, purpose })'),
        );
        expect(sendLoginOtp, contains('.neq("id", insertedOtp.id)'));
        expect(sendLoginOtp, contains('isGooglePlayReviewPhone(phone)'));
        expect(sendLoginOtp, contains('GOOGLE_PLAY_REVIEW_OTP'));
        expect(
          sendLoginOtp,
          contains('Google Play review OTP prepared for app login.'),
        );
        expect(sendAdminOtp, contains('const purpose = "admin_login"'));
        expect(
          sendAdminOtp,
          contains('await hashOtpCode(code, { phone, purpose })'),
        );
        expect(sendAdminOtp, contains('.neq("id", insertedOtp.id)'));

        for (final source in [verifyLoginOtp, verifyAdminOtp]) {
          expect(source, contains('const { error: attemptError }'));
          expect(source, contains('throw attemptError'));
          expect(
            source,
            contains('await hashOtpCode(code, { phone, purpose })'),
          );
          expect(source, contains('const legacyCodeHash'));
          expect(source, contains('const { error: verifyError }'));
          expect(source, contains('.eq("phone", phone)'));
          expect(source, contains('.eq("purpose", purpose)'));
        }

        expect(playReviewLogin, contains('GOOGLE_PLAY_REVIEW_PHONE'));
        expect(playReviewLogin, contains('+250788767816'));
        expect(playReviewLogin, contains('GOOGLE_PLAY_REVIEW_OTP'));
        expect(playReviewLogin, contains('123456'));
        expect(verifyLoginOtp, contains('isGooglePlayReviewOtp(phone, code)'));
        expect(verifyLoginOtp, contains('googlePlayReviewMetadata()'));
        expect(verifyLoginOtp, contains('forceRequestedRole = false'));
        expect(verifyLoginOtp, contains('isReviewLogin,'));
        expect(verifyLoginOtp, contains('momo_number: momoNumber'));
        expect(verifyLoginOtp, contains('momo_pay_code: momoPayCode'));
      },
    );

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
