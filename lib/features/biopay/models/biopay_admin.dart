import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

class BioPayAdminSummary {
  const BioPayAdminSummary({
    required this.totalPayees,
    required this.enrolledPayees,
    required this.totalRequests,
    required this.pendingConfirmations,
    required this.confirmedRequests,
    required this.matchRate,
  });

  factory BioPayAdminSummary.fromJson(Map<String, dynamic> json) {
    return BioPayAdminSummary(
      totalPayees: (json['total_payees'] as num?)?.toInt() ?? 0,
      enrolledPayees: (json['enrolled_payees'] as num?)?.toInt() ?? 0,
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      pendingConfirmations:
          (json['pending_confirmations'] as num?)?.toInt() ?? 0,
      confirmedRequests: (json['confirmed_requests'] as num?)?.toInt() ?? 0,
      matchRate: (json['match_rate'] as num?)?.toDouble() ?? 0,
    );
  }

  factory BioPayAdminSummary.preview() {
    return const BioPayAdminSummary(
      totalPayees: 24,
      enrolledPayees: 21,
      totalRequests: 86,
      pendingConfirmations: 3,
      confirmedRequests: 64,
      matchRate: 0.91,
    );
  }

  final int totalPayees;
  final int enrolledPayees;
  final int totalRequests;
  final int pendingConfirmations;
  final int confirmedRequests;
  final double matchRate;

  String get matchRateLabel => '${(matchRate * 100).toStringAsFixed(1)}%';
}

class BioPayAdminPayee {
  const BioPayAdminPayee({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.provider,
    required this.providerSubjectId,
    required this.providerCollectionId,
    required this.livenessStatus,
    required this.status,
    required this.requestCount,
    required this.confirmedCount,
    required this.lastRequestAt,
    required this.enrolledAt,
  });

  factory BioPayAdminPayee.fromJson(Map<String, dynamic> json) {
    return BioPayAdminPayee(
      userId: json['user_id']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'BioPay payee',
      provider: json['provider']?.toString() ?? 'aws_rekognition',
      providerSubjectId: json['provider_subject_id']?.toString() ?? '',
      providerCollectionId: json['provider_collection_id']?.toString() ?? '',
      livenessStatus: json['liveness_status']?.toString() ?? 'not_started',
      status: json['status']?.toString() ?? 'active',
      requestCount: (json['request_count'] as num?)?.toInt() ?? 0,
      confirmedCount: (json['confirmed_count'] as num?)?.toInt() ?? 0,
      lastRequestAt: DateTime.tryParse(
        json['last_request_at']?.toString() ?? '',
      ),
      enrolledAt: DateTime.tryParse(json['enrolled_at']?.toString() ?? ''),
    );
  }

  factory BioPayAdminPayee.preview({
    required String userId,
    required String handle,
    required String displayName,
    required int requestCount,
    required int confirmedCount,
    required DateTime lastRequestAt,
  }) {
    return BioPayAdminPayee(
      userId: userId,
      handle: handle,
      displayName: displayName,
      provider: 'aws_rekognition',
      providerSubjectId: 'aws-face-$handle',
      providerCollectionId: 'mobio-biopay-prod',
      livenessStatus: 'provider_liveness_not_required',
      status: 'active',
      requestCount: requestCount,
      confirmedCount: confirmedCount,
      lastRequestAt: lastRequestAt,
      enrolledAt: lastRequestAt.subtract(const Duration(days: 18)),
    );
  }

  final String userId;
  final String handle;
  final String displayName;
  final String provider;
  final String providerSubjectId;
  final String providerCollectionId;
  final String livenessStatus;
  final String status;
  final int requestCount;
  final int confirmedCount;
  final DateTime? lastRequestAt;
  final DateTime? enrolledAt;

  bool get isEnrolled => providerSubjectId.isNotEmpty && status == 'active';
  String get enrollmentLabel => isEnrolled ? 'Enrolled' : 'Pending';
}

class BioPayAdminSystemStatus {
  const BioPayAdminSystemStatus({
    required this.overallStatus,
    required this.faceProvider,
    required this.faceProviderReady,
    required this.collectionId,
    required this.databaseStatus,
    required this.ussdHandoffStatus,
    required this.pendingConfirmations,
    required this.lastAuditAt,
  });

  factory BioPayAdminSystemStatus.fromJson(Map<String, dynamic> json) {
    return BioPayAdminSystemStatus(
      overallStatus: json['overall_status']?.toString() ?? 'unknown',
      faceProvider: json['face_provider']?.toString() ?? 'aws_rekognition',
      faceProviderReady: json['face_provider_ready'] == true,
      collectionId: json['collection_id']?.toString() ?? '',
      databaseStatus: json['database_status']?.toString() ?? 'available',
      ussdHandoffStatus: json['ussd_handoff_status']?.toString() ?? 'external',
      pendingConfirmations:
          (json['pending_confirmations'] as num?)?.toInt() ?? 0,
      lastAuditAt: DateTime.tryParse(json['last_audit_at']?.toString() ?? ''),
    );
  }

  factory BioPayAdminSystemStatus.preview() {
    return BioPayAdminSystemStatus(
      overallStatus: 'operational',
      faceProvider: 'aws_rekognition',
      faceProviderReady: true,
      collectionId: 'mobio-biopay-prod',
      databaseStatus: 'available',
      ussdHandoffStatus: 'external_ussd_only',
      pendingConfirmations: 3,
      lastAuditAt: DateTime.now().subtract(const Duration(minutes: 8)),
    );
  }

  final String overallStatus;
  final String faceProvider;
  final bool faceProviderReady;
  final String collectionId;
  final String databaseStatus;
  final String ussdHandoffStatus;
  final int pendingConfirmations;
  final DateTime? lastAuditAt;

  BioPayAdminSystemStatus copyWith({
    String? overallStatus,
    String? faceProvider,
    bool? faceProviderReady,
    String? collectionId,
    String? databaseStatus,
    String? ussdHandoffStatus,
    int? pendingConfirmations,
    DateTime? lastAuditAt,
  }) {
    return BioPayAdminSystemStatus(
      overallStatus: overallStatus ?? this.overallStatus,
      faceProvider: faceProvider ?? this.faceProvider,
      faceProviderReady: faceProviderReady ?? this.faceProviderReady,
      collectionId: collectionId ?? this.collectionId,
      databaseStatus: databaseStatus ?? this.databaseStatus,
      ussdHandoffStatus: ussdHandoffStatus ?? this.ussdHandoffStatus,
      pendingConfirmations: pendingConfirmations ?? this.pendingConfirmations,
      lastAuditAt: lastAuditAt ?? this.lastAuditAt,
    );
  }
}

class BioPayAdminSnapshot {
  const BioPayAdminSnapshot({
    required this.summary,
    required this.payees,
    required this.requests,
    required this.systemStatus,
  });

  final BioPayAdminSummary summary;
  final List<BioPayAdminPayee> payees;
  final List<BioPayUssdPaymentRequest> requests;
  final BioPayAdminSystemStatus systemStatus;
}
