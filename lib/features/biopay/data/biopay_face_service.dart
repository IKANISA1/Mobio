import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class BioPayFaceService {
  BioPayFaceService({this.supabase});

  final SupabaseClient? supabase;

  Future<BioPayFaceProviderStatus> health() async {
    final client = supabase;
    if (client == null) {
      return const BioPayFaceProviderStatus(
        provider: 'not_configured',
        productionReady: false,
      );
    }
    final response = await client.functions.invoke(
      'biopay-face-provider/health',
      method: HttpMethod.get,
    );
    return BioPayFaceProviderStatus.fromJson(_mapResponse(response.data));
  }

  Future<BioPayEnrollmentStatus> enrollmentStatus() async {
    final client = supabase;
    if (client == null) {
      return BioPayEnrollmentStatus.preview();
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const BioPayEnrollmentStatus();
    }

    final row = await client
        .from('biopay_profiles')
        .select(
          'handle, provider, provider_subject_id, provider_collection_id, '
          'liveness_status, status, consent_granted_at, server_verified_at',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return const BioPayEnrollmentStatus();
    }

    return BioPayEnrollmentStatus.fromJson(row);
  }

  Future<BioPayFaceActionResult> createLivenessSession() async {
    return _invoke(
      action: 'create_liveness_session',
      body: {'client_request_token': _clientToken()},
      preview: {
        'status': 'created',
        'session_id': 'preview-liveness-session',
        'provider': 'aws_rekognition',
      },
    );
  }

  Future<BioPayFaceActionResult> enrollFace({
    required String faceProfileId,
    required List<int> imageBytes,
    required List<String> challengeIds,
    required int sampleCount,
    String? livenessSessionId,
    bool livenessRequired = false,
  }) async {
    final result = await _invoke(
      action: 'enroll_face',
      body: {
        'face_profile_id': faceProfileId,
        'image_b64': base64Encode(imageBytes),
        'liveness_session_id': livenessSessionId,
        'liveness_required': livenessRequired,
        'enrollment_sample_count': sampleCount,
        'enrollment_challenges': challengeIds,
      },
      preview: {
        'status': 'enrolled',
        'face_profile_id': faceProfileId,
        'provider_face_id': 'preview-aws-face',
        'provider': 'aws_rekognition',
        'quality_score': 0.92,
        'liveness_required': livenessRequired,
        'liveness_status': livenessRequired
            ? 'provider_liveness_pending'
            : 'provider_liveness_not_required',
        'enrollment_sample_count': sampleCount,
        'enrollment_challenges': challengeIds,
      },
    );
    return result;
  }

  Future<BioPayFaceActionResult> matchFace({required List<int> imageBytes}) {
    return _invoke(
      action: 'match_face',
      body: {'image_b64': base64Encode(imageBytes), 'max_faces': 3},
      preview: {
        'status': 'matched',
        'match_status': 'matched',
        'provider': 'aws_rekognition',
        'provider_face_id': 'preview-aws-face',
        'session_id': 'preview-face-match-session',
        'confidence': 0.93,
      },
    );
  }

  Future<BioPayFaceActionResult> _invoke({
    required String action,
    required Map<String, Object?> body,
    required Map<String, Object?> preview,
  }) async {
    final client = supabase;
    if (client == null) {
      return BioPayFaceActionResult.fromJson(preview);
    }
    final response = await client.functions.invoke(
      'biopay-face-provider',
      body: {'action': action, ...body},
    );
    return BioPayFaceActionResult.fromJson(_mapResponse(response.data));
  }

  Map<String, dynamic> _mapResponse(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  String _clientToken() =>
      'mobio-face-${DateTime.now().microsecondsSinceEpoch}';
}

class BioPayEnrollmentStatus {
  const BioPayEnrollmentStatus({
    this.handle = '',
    this.provider = '',
    this.providerSubjectId = '',
    this.providerCollectionId = '',
    this.livenessStatus = 'not_started',
    this.status = 'not_started',
    this.enrolledAt,
    this.serverVerifiedAt,
  });

  factory BioPayEnrollmentStatus.fromJson(Map<String, dynamic> json) {
    return BioPayEnrollmentStatus(
      handle: json['handle']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      providerSubjectId: json['provider_subject_id']?.toString() ?? '',
      providerCollectionId: json['provider_collection_id']?.toString() ?? '',
      livenessStatus: json['liveness_status']?.toString() ?? 'not_started',
      status: json['status']?.toString() ?? 'not_started',
      enrolledAt: DateTime.tryParse(
        json['consent_granted_at']?.toString() ?? '',
      ),
      serverVerifiedAt: DateTime.tryParse(
        json['server_verified_at']?.toString() ?? '',
      ),
    );
  }

  factory BioPayEnrollmentStatus.preview() {
    return BioPayEnrollmentStatus(
      handle: '482013',
      provider: 'aws_rekognition',
      providerSubjectId: 'preview-aws-face',
      providerCollectionId: 'mobio-biopay-prod',
      livenessStatus: 'provider_liveness_not_required',
      status: 'active',
      enrolledAt: DateTime.utc(2026, 6, 12),
      serverVerifiedAt: DateTime.utc(2026, 6, 12),
    );
  }

  final String handle;
  final String provider;
  final String providerSubjectId;
  final String providerCollectionId;
  final String livenessStatus;
  final String status;
  final DateTime? enrolledAt;
  final DateTime? serverVerifiedAt;

  bool get isEnrolled =>
      providerSubjectId.isNotEmpty &&
      serverVerifiedAt != null &&
      enrolledAt != null &&
      provider == 'aws_rekognition' &&
      status == 'active';

  String get label {
    if (isEnrolled) return 'Ready';
    if (status == 'paused') return 'Paused';
    if (status == 'deleted') return 'Removed';
    return 'Set up';
  }

  String get subtitle {
    if (isEnrolled) return 'AWS face identity ready';
    if (status == 'paused') return 'AWS face matching paused';
    return 'Enroll AWS face identity';
  }
}

class BioPayFaceProviderStatus {
  const BioPayFaceProviderStatus({
    required this.provider,
    required this.productionReady,
    this.providerCollectionId = '',
    this.modelVersion = '',
    this.paymentBoundary = '',
  });

  factory BioPayFaceProviderStatus.fromJson(Map<String, dynamic> json) {
    return BioPayFaceProviderStatus(
      provider: json['provider']?.toString() ?? 'not_configured',
      productionReady: json['production_ready'] == true,
      providerCollectionId: json['provider_collection_id']?.toString() ?? '',
      modelVersion: json['model_version']?.toString() ?? '',
      paymentBoundary: json['payment_boundary']?.toString() ?? '',
    );
  }

  final String provider;
  final bool productionReady;
  final String providerCollectionId;
  final String modelVersion;
  final String paymentBoundary;
}

class BioPayFaceActionResult {
  const BioPayFaceActionResult({required this.values});

  factory BioPayFaceActionResult.fromJson(Map<String, dynamic> json) {
    return BioPayFaceActionResult(values: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> values;

  String get status => values['status']?.toString() ?? 'unknown';
  String get sessionId => values['session_id']?.toString() ?? '';
  String get provider => values['provider']?.toString() ?? 'aws_rekognition';
  String get providerFaceId =>
      values['provider_face_id']?.toString() ?? _bestMatchFaceId;
  String get providerCollectionId =>
      values['provider_collection_id']?.toString() ?? '';
  String get livenessStatus =>
      values['liveness_status']?.toString() ?? 'provider_liveness_not_required';

  double? get qualityScore {
    final value = values['quality_score'];
    if (value is num) return value.toDouble().clamp(0, 1).toDouble();
    return null;
  }

  double get confidence {
    final value = values['confidence'];
    if (value is num) return value.toDouble();
    return 0;
  }

  String get _bestMatchFaceId {
    final matches = values['matches'];
    if (matches is! List || matches.isEmpty) return '';
    final first = matches.first;
    if (first is! Map) return '';
    return first['provider_face_id']?.toString() ?? '';
  }
}
