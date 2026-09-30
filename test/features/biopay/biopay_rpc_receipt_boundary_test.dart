import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/biopay_admin_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/biopay_wire_boundary_test.dart' show paymentRow, payeeRow;

SupabaseClient fixture(Object? raw) {
  final client = SupabaseClient(
    'https://biopay-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(raw),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  test(
    'acknowledged actions require their declared resulting state and confirmation source',
    () async {
      final original = BioPayUssdPaymentRequest.fromJson(paymentRow());
      final unchanged = BioPayUssdService(supabase: fixture(paymentRow()));
      await expectLater(
        unchanged.recordDialerOpened(original),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      await expectLater(
        unchanged.markUserPaid(original),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      final wrongSource = BioPayUssdService(
        supabase: fixture({
          ...paymentRow(),
          'status': 'confirmed',
          'confirmed_at': '2026-10-01T08:35:00Z',
          'confirmation_source': 'different-reference',
        }),
      );
      await expectLater(
        wrongSource.confirmExternally(
          request: original,
          confirmationSource: 'operator-reference',
        ),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test(
    'complete action acknowledgements preserve each authoritative resulting state',
    () async {
      final original = BioPayUssdPaymentRequest.fromJson(paymentRow());
      final dialer = await BioPayUssdService(
        supabase: fixture({...paymentRow(), 'status': 'dialer_opened'}),
      ).recordDialerOpened(original);
      expect(dialer.status, BioPayRequestStatus.dialerOpened);
      final marked = await BioPayUssdService(
        supabase: fixture({...paymentRow(), 'status': 'user_marked_paid'}),
      ).markUserPaid(dialer);
      expect(marked.status, BioPayRequestStatus.userMarkedPaid);
      final confirmed =
          await BioPayUssdService(
            supabase: fixture({
              ...paymentRow(),
              'status': 'confirmed',
              'confirmed_at': '2026-10-01T08:35:00Z',
              'confirmation_source': 'operator-reference',
            }),
          ).confirmExternally(
            request: marked,
            confirmationSource: ' operator-reference ',
          );
      expect(confirmed.status, BioPayRequestStatus.confirmed);
    },
  );
  test('malformed acknowledged create cannot claim a usable request', () async {
    for (final raw in [
      null,
      {...paymentRow()}..remove('token'),
      {...paymentRow(), 'amount_minor': 160000},
      {...paymentRow(), 'status': 'draft'},
    ]) {
      await expectLater(
        BioPayUssdService(supabase: fixture(raw)).createPaymentRequest(
          channel: BioPayRequestChannel.qr,
          amountMinor: 150000,
          payeeLabel: 'Merchant',
        ),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    }
  });

  test(
    'complete creation preserves exact channel and reviewed amount',
    () async {
      final request = await BioPayUssdService(supabase: fixture(paymentRow()))
          .createPaymentRequest(
            channel: BioPayRequestChannel.qr,
            amountMinor: 150000,
            payeeLabel: 'Merchant',
          );
      expect(request.amountMinor, 150000);
      expect(request.token, 'abcdefghijklmnopqrstuvwx');
    },
  );

  test(
    'dialer receipt must preserve immutable request identity and instruction',
    () async {
      final original = BioPayUssdPaymentRequest.fromJson(paymentRow());
      final changed = {
        ...paymentRow(),
        'ussd_code': '*182*1*1*0788000000*1500#',
        'status': 'dialer_opened',
      };
      await expectLater(
        BioPayUssdService(
          supabase: fixture(changed),
        ).recordDialerOpened(original),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test(
    'admin confirmation cannot substitute another request receipt',
    () async {
      final original = BioPayUssdPaymentRequest.fromJson(paymentRow());
      final changed = {
        ...paymentRow(),
        'id': '22222222-2222-4222-8222-222222222222',
        'status': 'confirmed',
        'confirmed_at': '2026-10-01T08:35:00Z',
        'confirmation_source': 'operator-reference',
      };
      await expectLater(
        BioPayAdminService(supabase: fixture(changed)).confirmRequestExternally(
          request: original,
          confirmationSource: 'operator-reference',
        ),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test(
    'malformed admin payee rows cannot become partial enrolled-looking output',
    () async {
      await expectLater(
        BioPayAdminService(supabase: fixture([payeeRow(), {}])).listPayees(),
        throwsFormatException,
      );
    },
  );
}
