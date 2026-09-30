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
      'user_id': '11111111-1111-4111-8111-111111111111',
      'handle': 'BP-123456',
      'display_name': 'BioPay User',
      'provider': 'opencv_sface_v1',
      'provider_subject_id': 'face-1',
      'provider_collection_id': 'mobio-biopay-prod',
      'liveness_status': 'provider_liveness_not_required',
      'status': 'active',
      'request_count': 6,
      'confirmed_count': 5,
      'last_request_at': '2026-06-12T10:00:00Z',
      'enrolled_at': '2026-06-11T10:00:00Z',
      'server_verified_at': '2026-09-06T10:00:00Z',
    });

    expect(payee.isEnrolled, isTrue);
    expect(payee.enrollmentLabel, 'Enrolled');
    expect(payee.requestCount, 6);
    expect(payee.confirmedCount, 5);
  });

  test('parses face provider health metadata', () {
    final status = BioPayFaceProviderStatus.fromJson({
      'provider': 'opencv_sface_v1',
      'production_ready': true,
      'provider_collection_id': 'mobio-biopay-prod',
      'model_version': 'yunet2023mar-sface2021dec-opencv4.11-v1',
      'payment_boundary': 'USSD dialer handoff only; no in-app settlement.',
    });

    expect(status.provider, 'opencv_sface_v1');
    expect(status.productionReady, isTrue);
    expect(
      status.providerCollectionId,
      'yunet2023mar-sface2021dec-opencv4.11-v1',
    );
    expect(status.modelVersion, contains('sface'));
    expect(status.paymentBoundary, contains('USSD dialer'));
  });

  test('parses BioPay enrollment state', () {
    final status = BioPayEnrollmentStatus.fromJson({
      'handle': 'BP-482013',
      'provider': 'opencv_sface_v1',
      'provider_subject_id': 'face-1',
      'provider_collection_id': 'mobio-biopay-prod',
      'liveness_status': 'provider_liveness_not_required',
      'status': 'active',
      'has_face': true,
      'receiving_method_id': '44444444-4444-4444-8444-444444444444',
      'pending_vector_id': null,
      'consent_granted_at': '2026-06-12T10:00:00Z',
      'server_verified_at': '2026-09-06T10:00:00Z',
    });

    expect(status.isEnrolled, isTrue);
    expect(status.label, 'Ready');
  });

  test('legacy or consentless profiles are never ready in app or Admin', () {
    final profile = <String, dynamic>{
      'user_id': '11111111-1111-4111-8111-111111111111',
      'handle': 'BP-482013',
      'display_name': 'Mobio member',
      'provider_collection_id': null,
      'request_count': 0,
      'confirmed_count': 0,
      'last_request_at': null,
      'server_verified_at': null,
      'provider': 'opencv_sface_v1',
      'provider_subject_id': 'legacy-face',
      'status': 'active',
      'consent_granted_at': '2026-06-12T10:00:00Z',
      'enrolled_at': '2026-06-12T10:00:00Z',
    };
    expect(
      () => BioPayEnrollmentStatus.fromJson(profile),
      throwsFormatException,
    );
    expect(BioPayAdminPayee.fromJson(profile).isEnrolled, isFalse);
    profile['server_verified_at'] = '2026-09-06T10:00:00Z';
    profile['consent_granted_at'] = null;
    profile['enrolled_at'] = null;
    expect(
      () => BioPayEnrollmentStatus.fromJson(profile),
      throwsFormatException,
    );
    expect(BioPayAdminPayee.fromJson(profile).isEnrolled, isFalse);
  });
}
