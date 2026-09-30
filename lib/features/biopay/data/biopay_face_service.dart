import 'dart:async';
import 'dart:convert';

import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/domain/face_shortcut.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FaceServiceException implements Exception {
  const FaceServiceException(this.code, {this.operation, this.operationId});
  final String code;
  final String? operation;
  final String? operationId;
}

class BioPayFaceService {
  BioPayFaceService({
    this.supabase,
    AccountSnapshot Function()? captureAccount,
    bool Function(AccountSnapshot)? isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;
  final SupabaseClient? supabase;
  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;

  // Successful states emitted by the provider and its SQL authority. A missing
  // or invented state cannot confirm a mutation that may already have run.
  static const _mutationStatuses = <String, Set<String>>{
    'enroll': {'active', 'processing', 'cancelled'},
    'resolve': {
      'dial_ready',
      'no_match',
      'ambiguous',
      'recipient_unavailable',
      'unavailable',
      'route_unavailable',
    },
    'pause': {'updated'},
    'resume': {'updated'},
    'remove': {'updated'},
    'change_method': {'updated'},
    'handoff': {'recorded'},
  };

  AccountSnapshot captureAccount() {
    try {
      final account = _captureOverride?.call() ?? AccountContext.capture();
      if (!isCurrent(account)) throw const StaleAccountWork();
      return account;
    } on Object {
      throw const FaceServiceException('AUTH_EXPIRED');
    }
  }

  bool isCurrent(AccountSnapshot account) =>
      ownerId == account.userId &&
      (_isCurrentOverride?.call(account) ?? AccountContext.isCurrent(account));
  String? get ownerId => supabase?.auth.currentUser?.isAnonymous == false
      ? supabase?.auth.currentUser?.id
      : null;
  Future<Map<String, dynamic>> invoke(
    String action, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = supabase;
    if (client == null || ownerId == null) {
      throw const FaceServiceException('AUTH_EXPIRED');
    }
    final account = captureAccount();
    final operationId =
        (body['idempotency_key'] ?? body['request_id'] ?? body['method_id'])
            ?.toString();
    FaceServiceException unconfirmed() => FaceServiceException(
      'OUTCOME_UNKNOWN',
      operation: 'biopay_face:$action',
      operationId: operationId,
    );
    try {
      final request = client.functions.invoke(
        'biopay-face-provider',
        body: {'action': action, ...body},
      );
      final response = action == 'status'
          ? await RequestDeadline.read(request)
          : await RequestDeadline.mutation(
              request,
              operation: 'biopay_face:$action',
              operationId: operationId,
            );
      if (!isCurrent(account)) {
        throw const FaceServiceException('AUTH_EXPIRED');
      }
      final result = response.data;
      if (result is! Map || result.keys.any((key) => key is! String)) {
        throw const FormatException('Invalid Face reply');
      }
      final data = Map<String, dynamic>.from(result);
      if (data['success'] == false) {
        throw FaceServiceException(
          data['code']?.toString() ?? 'SERVICE_UNAVAILABLE',
        );
      }
      if (data['success'] != true ||
          (action != 'status' &&
              _mutationStatuses[action]?.contains(data['status']) != true)) {
        throw const FormatException('Invalid Face acknowledgement');
      }
      return data;
    } on MutationOutcomeUnknownException {
      throw unconfirmed();
    } on FormatException {
      if (action != 'status') throw unconfirmed();
      throw const FaceServiceException('SERVICE_UNAVAILABLE');
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
    final status = result['status'];
    if (status is! String || !_mutationStatuses['enroll']!.contains(status)) {
      throw FaceServiceException(
        'OUTCOME_UNKNOWN',
        operation: 'biopay_face:enroll',
        operationId: idempotencyKey,
      );
    }
    return status;
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
    try {
      return PreparedFaceUssdShortcut.fromJson(result);
    } on Object {
      throw FaceServiceException(
        'OUTCOME_UNKNOWN',
        operation: 'biopay_face:resolve',
        operationId: idempotencyKey,
      );
    }
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
    final response = await RequestDeadline.read(
      supabase!.functions.invoke(
        'biopay-face-provider/health',
        method: HttpMethod.get,
      ),
    );
    return BioPayFaceProviderStatus.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

class BioPayEnrollmentStatus {
  const BioPayEnrollmentStatus({
    this.status = 'unavailable',
    this.receivingMethodId,
    this.hasFace = false,
    this.pending = false,
  });
  final String status;
  final String? receivingMethodId;
  final bool hasFace, pending;
  factory BioPayEnrollmentStatus.fromJson(Map<String, dynamic> json) {
    // Exact fields emitted by rpc_biopay_face_authority('status'). Nullable
    // method/vector values are intentional; missing fields are not absence.
    final status = json['status'];
    if (status is! String ||
        !const {
          'not_started',
          'active',
          'paused',
          'deleted',
          'processing',
          'reenrollment_required',
          'receiving_method_required',
          'rejected',
        }.contains(status) ||
        json['has_face'] is! bool ||
        !json.containsKey('receiving_method_id') ||
        !json.containsKey('pending_vector_id')) {
      throw const FormatException('Invalid Face enrollment status');
    }
    final method = json['receiving_method_id'];
    final vector = json['pending_vector_id'];
    if ((method != null &&
            (method is! String ||
                !RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(method))) ||
        (vector != null &&
            (vector is! String || vector.isEmpty || vector.trim() != vector))) {
      throw const FormatException('Invalid Face enrollment references');
    }
    return BioPayEnrollmentStatus(
      status: status == 'rejected' ? 'unavailable' : status,
      receivingMethodId: method as String?,
      hasFace: json['has_face'] as bool,
      pending: vector != null,
    );
  }
  factory BioPayEnrollmentStatus.preview() =>
      const BioPayEnrollmentStatus(status: 'not_started');
  bool get isEnrolled => hasFace && status == 'active';
  bool get isUnavailable => status == 'unavailable';
  // Compatibility for profile badges; screens use translated copy.
  String get label => switch (status) {
    'active' => 'Ready',
    'paused' => 'Paused',
    'deleted' => 'Removed',
    'processing' => 'Processing',
    'reenrollment_required' => 'Update',
    'unavailable' => 'Unavailable',
    'not_started' => 'Set up',
    _ => 'Unavailable',
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
