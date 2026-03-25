class BiopayProfile {
  final String id;
  final String biopayId;
  final String displayName;
  final String ussdString;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BiopayProfile({
    required this.id,
    required this.biopayId,
    required this.displayName,
    required this.ussdString,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BiopayProfile.fromJson(Map<String, dynamic> json) => BiopayProfile(
    id: json['id'] as String? ?? '',
    biopayId: json['biopay_id'] as String,
    displayName: json['display_name'] as String,
    ussdString: json['ussd_string'] as String,
    status: json['status'] as String? ?? 'active',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.now(),
  );

  bool get isActive => status == 'active';
}

class MatchResult {
  final bool isMatch;
  final String? displayName;
  final String? ussdString;
  final String? biopayId;
  final double? score;
  final bool isCached;

  const MatchResult({
    required this.isMatch,
    this.displayName,
    this.ussdString,
    this.biopayId,
    this.score,
    this.isCached = false,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    isMatch: json['match'] as bool? ?? false,
    displayName: json['display_name'] as String?,
    ussdString: json['ussd_string'] as String?,
    biopayId: json['biopay_id'] as String?,
    score: (json['score'] as num?)?.toDouble(),
  );

  factory MatchResult.noMatch() => const MatchResult(isMatch: false);

  factory MatchResult.cached({
    required String biopayId,
    required String displayName,
    required String ussdString,
    required double score,
  }) => MatchResult(
    isMatch: true,
    displayName: displayName,
    ussdString: ussdString,
    biopayId: biopayId,
    score: score,
    isCached: true,
  );
}

class EnrollmentResult {
  final bool success;
  final String? biopayId;
  final String? ownerToken;
  final String? managementCode;
  final String? managementCodeHint;
  final String? displayName;
  final String? ussdString;
  final DateTime? enrolledAt;
  final String? error;

  const EnrollmentResult({
    required this.success,
    this.biopayId,
    this.ownerToken,
    this.managementCode,
    this.managementCodeHint,
    this.displayName,
    this.ussdString,
    this.enrolledAt,
    this.error,
  });

  factory EnrollmentResult.fromJson(Map<String, dynamic> json) =>
      EnrollmentResult(
        success:
            (json['success'] as bool?) ??
            ((json['biopay_id'] as String?)?.isNotEmpty == true &&
                (json['owner_token'] as String?)?.isNotEmpty == true),
        biopayId: json['biopay_id'] as String?,
        ownerToken: json['owner_token'] as String?,
        managementCode: json['management_code'] as String?,
        managementCodeHint: json['management_code_hint'] as String?,
        displayName: json['display_name'] as String?,
        ussdString: json['ussd_string'] as String?,
        enrolledAt: json['enrolled_at'] != null
            ? DateTime.tryParse(json['enrolled_at'] as String)
            : null,
        error: json['error'] as String?,
      );

  factory EnrollmentResult.failure(String error) =>
      EnrollmentResult(success: false, error: error);
}

class BiopayLocalSession {
  final String biopayId;
  final String ownerToken;
  final String displayName;
  final String? managementCodeHint;
  final DateTime savedAt;

  const BiopayLocalSession({
    required this.biopayId,
    required this.ownerToken,
    required this.displayName,
    required this.savedAt,
    this.managementCodeHint,
  });

  BiopayLocalSession copyWith({
    String? biopayId,
    String? ownerToken,
    String? displayName,
    String? managementCodeHint,
    DateTime? savedAt,
  }) => BiopayLocalSession(
    biopayId: biopayId ?? this.biopayId,
    ownerToken: ownerToken ?? this.ownerToken,
    displayName: displayName ?? this.displayName,
    managementCodeHint: managementCodeHint ?? this.managementCodeHint,
    savedAt: savedAt ?? this.savedAt,
  );

  Map<String, dynamic> toJson() => {
    'biopay_id': biopayId,
    'owner_token': ownerToken,
    'display_name': displayName,
    'management_code_hint': managementCodeHint,
    'saved_at': savedAt.toIso8601String(),
  };

  factory BiopayLocalSession.fromJson(Map<String, dynamic> json) =>
      BiopayLocalSession(
        biopayId: json['biopay_id'] as String,
        ownerToken: json['owner_token'] as String,
        displayName: json['display_name'] as String? ?? '',
        managementCodeHint: json['management_code_hint'] as String?,
        savedAt: json['saved_at'] != null
            ? DateTime.parse(json['saved_at'] as String)
            : DateTime.now(),
      );
}

class ManagedBiopayProfile {
  final String biopayId;
  final String displayName;
  final String ussdString;
  final String status;
  final String? managementCodeHint;
  final DateTime? createdAt;

  const ManagedBiopayProfile({
    required this.biopayId,
    required this.displayName,
    required this.ussdString,
    required this.status,
    this.managementCodeHint,
    this.createdAt,
  });

  factory ManagedBiopayProfile.fromJson(Map<String, dynamic> json) =>
      ManagedBiopayProfile(
        biopayId: json['biopay_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        ussdString: json['ussd_string'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        managementCodeHint: json['management_code_hint'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  bool get isActive => status == 'active';
}
