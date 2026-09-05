import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_admin.dart';

void main() {
  test('parses BioPay admin summary and payee status', () {
    final summary = BioPayAdminSummary.fromJson({
      'total_payees': 12,
      'enrolled_payees': 10,
      'total_requests': 44,
      'pending_confirmations': 3,
      'confirmed_requests': 28,
      'match_rate': 0.875,
    });

    expect(summary.totalPayees, 12);
    expect(summary.pendingConfirmations, 3);
    expect(summary.matchRateLabel, '87.5%');

    final payee = BioPayAdminPayee.fromJson({
      'user_id': 'user-1',
      'handle': 'BP-123456',
      'display_name': 'BioPay User',
      'provider': 'aws_rekognition',
      'provider_subject_id': 'aws-face-1',
      'provider_collection_id': 'mobio-biopay-prod',
      'liveness_status': 'provider_liveness_not_required',
      'status': 'active',
      'request_count': 6,
      'confirmed_count': 5,
      'last_request_at': '2026-06-12T10:00:00Z',
      'enrolled_at': '2026-06-11T10:00:00Z',
    });

    expect(payee.isEnrolled, isTrue);
    expect(payee.enrollmentLabel, 'Enrolled');
    expect(payee.requestCount, 6);
    expect(payee.confirmedCount, 5);
  });

  test('parses AWS face provider health metadata', () {
    final status = BioPayFaceProviderStatus.fromJson({
      'provider': 'aws_rekognition',
      'production_ready': true,
      'provider_collection_id': 'mobio-biopay-prod',
      'model_version': 'aws-rekognition-face-liveness-v1',
      'payment_boundary': 'USSD dialer handoff only; no in-app settlement.',
    });

    expect(status.provider, 'aws_rekognition');
    expect(status.productionReady, isTrue);
    expect(status.providerCollectionId, 'mobio-biopay-prod');
    expect(status.modelVersion, contains('aws-rekognition'));
    expect(status.paymentBoundary, contains('USSD dialer'));
  });

  test('parses BioPay AWS enrollment state', () {
    final status = BioPayEnrollmentStatus.fromJson({
      'handle': 'BP-482013',
      'provider': 'aws_rekognition',
      'provider_subject_id': 'aws-face-1',
      'provider_collection_id': 'mobio-biopay-prod',
      'liveness_status': 'provider_liveness_not_required',
      'status': 'active',
      'consent_granted_at': '2026-06-12T10:00:00Z',
    });

    expect(status.isEnrolled, isTrue);
    expect(status.label, 'Ready');
    expect(status.subtitle, 'AWS face identity ready');
    expect(status.providerCollectionId, 'mobio-biopay-prod');
  });
}
