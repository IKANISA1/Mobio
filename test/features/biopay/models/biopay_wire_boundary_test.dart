import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/domain/biopay_admin.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';

Map<String, dynamic> paymentRow() => {
  'id': '11111111-1111-4111-8111-111111111111',
  'token': 'abcdefghijklmnopqrstuvwx',
  'channel': 'qr',
  'provider_code': 'mtn_rw',
  'payee_label': 'Merchant',
  'amount_minor': 150000,
  'currency': 'RWF',
  'reference': 'BP-123',
  'ussd_code': '*182*8*1*12345*1500#',
  'status': 'ready_to_dial',
  'expires_at': '2026-10-01T08:45:00Z',
  'created_at': '2026-10-01T08:30:00Z',
  'confirmed_at': null,
  'confirmation_source': null,
};

Map<String, dynamic> payeeRow() => {
  'user_id': '11111111-1111-4111-8111-111111111111',
  'handle': 'bio-111111111111',
  'display_name': 'Merchant',
  'provider': 'opencv_sface_v1',
  'provider_subject_id': null,
  'provider_collection_id': null,
  'status': 'reenrollment_required',
  'request_count': 0,
  'confirmed_count': 0,
  'last_request_at': null,
  'enrolled_at': null,
  'server_verified_at': null,
};

void main() {
  test(
    'open amount is explicit zero and cannot be a missing/fractional amount',
    () {
      expect(
        BioPayUssdPaymentRequest.fromJson({
          ...paymentRow(),
          'amount_minor': 0,
        }).amountLabel,
        'Open amount',
      );
      for (final invalid in [null, 1.5, -1, '150000']) {
        expect(
          () => BioPayUssdPaymentRequest.fromJson({
            ...paymentRow(),
            'amount_minor': invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'missing/invalid request identity, token, channel and status are rejected',
    () {
      for (final row in [
        {...paymentRow(), 'id': 'broken'},
        {...paymentRow()}..remove('token'),
        {...paymentRow(), 'token': ''},
        {...paymentRow(), 'channel': 'unknown'},
        {...paymentRow()}..remove('status'),
        {...paymentRow(), 'status': 'unknown'},
        {...paymentRow()}..remove('expires_at'),
        {...paymentRow(), 'expires_at': 'broken'},
      ]) {
        expect(
          () => BioPayUssdPaymentRequest.fromJson(row),
          throwsFormatException,
        );
      }
      expect(
        () => BioPayRequestStatus.fromWireName(null),
        throwsFormatException,
      );
    },
  );

  test(
    'resolve projection requires exact bearer token and preserves absent created time',
    () {
      final projection = paymentRow()
        ..remove('created_at')
        ..remove('confirmed_at')
        ..remove('confirmation_source');
      final request = BioPayUssdPaymentRequest.fromResolvedJson(
        projection,
        token: 'abcdefghijklmnopqrstuvwx',
      );
      expect(request.createdAt, isNull);
      expect(request.status, BioPayRequestStatus.readyToDial);
      expect(
        () => BioPayUssdPaymentRequest.fromResolvedJson(
          projection,
          token: 'different-token',
        ),
        throwsFormatException,
      );
      expect(
        () => BioPayUssdPaymentRequest.fromJson(projection),
        throwsFormatException,
      );
    },
  );

  test('confirmation status must carry confirmed timestamp and source', () {
    expect(
      () => BioPayUssdPaymentRequest.fromJson({
        ...paymentRow(),
        'status': 'confirmed',
      }),
      throwsFormatException,
    );
    final request = BioPayUssdPaymentRequest.fromJson({
      ...paymentRow(),
      'status': 'confirmed',
      'confirmed_at': '2026-10-01T08:35:00Z',
      'confirmation_source': 'operator-reference',
    });
    expect(request.confirmedAt, DateTime.utc(2026, 10, 1, 8, 35));
  });

  test('nullable unenrolled admin provider fields stay explicit', () {
    final payee = BioPayAdminPayee.fromJson(payeeRow());
    expect(payee.isEnrolled, false);
    expect(payee.enrollmentLabel, 'Update required');
    expect(payee.lastRequestAt, isNull);
  });

  test(
    'admin payee identities/counts/status cannot be fabricated or truncated',
    () {
      for (final row in [
        {...payeeRow(), 'user_id': 7},
        {...payeeRow()}..remove('provider'),
        {...payeeRow()}..remove('status'),
        {...payeeRow(), 'request_count': 1.9},
        {...payeeRow(), 'enrolled_at': 'broken'},
      ]) {
        expect(() => BioPayAdminPayee.fromJson(row), throwsFormatException);
      }
    },
  );

  test(
    'missing admin summary or system health never appears available/zero',
    () {
      expect(() => BioPayAdminSummary.fromJson({}), throwsFormatException);
      expect(() => BioPayAdminSystemStatus.fromJson({}), throwsFormatException);
    },
  );
}
