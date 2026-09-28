import 'dart:async';
import 'dart:convert';

import 'package:mobi_app/features/biopay/domain/face_shortcut.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FaceServiceException implements Exception {
  const FaceServiceException(this.code);
  final String code;
}

class BioPayFaceService {
  BioPayFaceService({this.supabase});
  final SupabaseClient? supabase;
  String? get ownerId => supabase?.auth.currentUser?.isAnonymous == false
      ? supabase?.auth.currentUser?.id
      : null;
  Future<Map<String, dynamic>> invoke(
    String action, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = supabase;
    final account = ownerId;
    if (client == null || account == null) {
      throw const FaceServiceException('AUTH_EXPIRED');
    }
    try {
      final response = await client.functions
          .invoke('biopay-face-provider', body: {'action': action, ...body})
          .timeout(const Duration(seconds: 15));
      if (account != ownerId) throw const FaceServiceException('AUTH_EXPIRED');
      final result = response.data;
      if (result is! Map) {
        throw const FaceServiceException('SERVICE_UNAVAILABLE');
      }
      final data = Map<String, dynamic>.from(result);
      if (data['success'] == false) {
        throw FaceServiceException(
          data['code']?.toString() ?? 'SERVICE_UNAVAILABLE',
        );
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details;
      throw FaceServiceException(
        details is Map
            ? details['code']?.toString() ?? 'SERVICE_UNAVAILABLE'
            : 'SERVICE_UNAVAILABLE',
      );
    } on TimeoutException {
      throw const FaceServiceException('TIMEOUT');
    }
  }

  Future<BioPayEnrollmentStatus> enrollmentStatus() async {
    if (supabase == null) return const BioPayEnrollmentStatus();
    return BioPayEnrollmentStatus.fromJson(await invoke('status'));
  }

  Future<String> enrollFace({
    required List<int> imageBytes,
    required String methodId,
    required String idempotencyKey,
    required bool consent,
  }) async {
    if (!consent) throw const FaceServiceException('CONSENT_REQUIRED');
    if (imageBytes.length > 1500000) {
      throw const FaceServiceException('IMAGE_TOO_LARGE');
    }
    final result = await invoke('enroll', {
      'image_b64': base64Encode(imageBytes),
      'method_id': methodId,
      'idempotency_key': idempotencyKey,
      'consent': consent,
      'consent_version': 'face-discovery-v1',
    });
    return result['status']?.toString() ?? 'processing';
  }

  Future<PreparedFaceUssdShortcut> resolveShortcut({
    required List<int> imageBytes,
    required String idempotencyKey,
  }) async {
    if (imageBytes.length > 1500000) {
      throw const FaceServiceException('IMAGE_TOO_LARGE');
    }
    final result = await invoke('resolve', {
      'image_b64': base64Encode(imageBytes),
      'idempotency_key': idempotencyKey,
    });
    if (result['status'] != 'dial_ready') {
      throw FaceServiceException(
        result['code']?.toString() ??
            switch (result['status']) {
              'no_match' => 'NO_MATCH',
              'ambiguous' => 'AMBIGUOUS_MATCH',
              _ => 'RECIPIENT_UNAVAILABLE',
            },
      );
    }
    return PreparedFaceUssdShortcut.fromJson(result);
  }

  Future<void> changeMethod(String id) async {
    await invoke('change_method', {'method_id': id});
  }

  Future<void> setEnrollmentAction(String action) async {
    if (!const ['pause', 'resume', 'remove'].contains(action)) {
      throw ArgumentError.value(action);
    }
    await invoke(action);
  }

  Future<void> recordHandoff(String requestId) async {
    await invoke('handoff', {'request_id': requestId});
  }

  Future<BioPayFaceProviderStatus> health() async {
    if (supabase == null) {
      return const BioPayFaceProviderStatus(
        provider: 'not_configured',
        productionReady: false,
      );
    }
    final response = await supabase!.functions
        .invoke('biopay-face-provider/health', method: HttpMethod.get)
        .timeout(const Duration(seconds: 15));
    return BioPayFaceProviderStatus.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

class BioPayEnrollmentStatus {
  const BioPayEnrollmentStatus({
    this.status = 'not_started',
    this.receivingMethodId,
    this.hasFace = false,
    this.pending = false,
  });
  final String status;
  final String? receivingMethodId;
  final bool hasFace, pending;
  factory BioPayEnrollmentStatus.fromJson(Map<String, dynamic> json) =>
      BioPayEnrollmentStatus(
        status: json['status']?.toString() ?? 'not_started',
        receivingMethodId: json['receiving_method_id'] as String?,
        hasFace: json['has_face'] == true,
        pending: json['pending_vector_id'] != null,
      );
  factory BioPayEnrollmentStatus.preview() => const BioPayEnrollmentStatus();
  bool get isEnrolled => hasFace && status == 'active';
  // Compatibility for profile badges; screens use translated copy.
  String get label => switch (status) {
    'active' => 'Ready',
    'paused' => 'Paused',
    'deleted' => 'Removed',
    'processing' => 'Processing',
    'reenrollment_required' => 'Update',
    'unavailable' => 'Unavailable',
    _ => 'Set up',
  };
}

class BioPayFaceProviderStatus {
  const BioPayFaceProviderStatus({
    required this.provider,
    required this.productionReady,
    this.providerCollectionId = '',
    this.modelVersion = '',
    this.paymentBoundary = '',
    this.configured = false,
    this.modelLoaded = false,
    this.indexCompatible = false,
    this.databaseContract = false,
    this.lastAcceptanceAt,
  });
  final String provider, providerCollectionId, modelVersion, paymentBoundary;
  final bool productionReady,
      configured,
      modelLoaded,
      indexCompatible,
      databaseContract;
  final String? lastAcceptanceAt;
  factory BioPayFaceProviderStatus.fromJson(Map<String, dynamic> json) =>
      BioPayFaceProviderStatus(
        provider: json['provider']?.toString() ?? 'not_configured',
        productionReady: json['production_ready'] == true,
        providerCollectionId: json['model_version']?.toString() ?? '',
        modelVersion: json['model_version']?.toString() ?? '',
        paymentBoundary: json['payment_boundary']?.toString() ?? '',
        configured: json['configured'] == true,
        modelLoaded: json['model_loaded'] == true,
        indexCompatible: json['index_compatible'] == true,
        databaseContract: json['database_contract'] == true,
        lastAcceptanceAt: json['last_acceptance_at']?.toString(),
      );
}
