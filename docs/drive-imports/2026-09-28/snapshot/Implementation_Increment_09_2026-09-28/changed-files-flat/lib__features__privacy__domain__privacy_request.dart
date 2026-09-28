/// Request tracking is not evidence that a provider has erased any data.
class PrivacyRequest {
  const PrivacyRequest({required this.id, required this.status, required this.revision,
    required this.noticeVersion, required this.requestedAt, required this.updatedAt,
    required this.canCancel, required this.retainedCategories});
  final String id, status, noticeVersion;
  final int revision;
  final DateTime requestedAt, updatedAt;
  final bool canCancel;
  final List<String> retainedCategories;
  static const states = {'requested','processing','blocked','cancelled','completed','completed_with_retention'};
  bool get terminal => {'cancelled','completed','completed_with_retention'}.contains(status);
  String get label => switch (status) {
    'requested' => 'Request received', 'processing' => 'Processing',
    'blocked' => 'Needs review', 'cancelled' => 'Request cancelled',
    'completed' => 'Completion evidence recorded',
    'completed_with_retention' => 'Completed with documented retention',
    _ => 'Status unavailable',
  };
  factory PrivacyRequest.fromJson(Object? value) {
    if (value is! Map || !validUuid(value['request_id']) || !states.contains(value['status']) ||
        value['revision'] is! int || (value['revision'] as int)<0 || value['can_cancel'] is! bool ||
        value['notice_version'] is! String || !validNotice(value['notice_version'] as String) ||
        value['retained_categories'] is! List || (value['retained_categories'] as List).length>12 ||
        !(value['retained_categories'] as List).every((v)=>v is String && RegExp(r'^[a-z_]{1,40}$').hasMatch(v))) {
      throw const FormatException('Invalid privacy response');
    }
    final status=value['status'] as String;
    if ((value['can_cancel']==true && !{'requested','blocked'}.contains(status)) ||
      (status=='requested' && value['can_cancel']!=true) ||
      value['completion_evidence_recorded'] != {'completed','completed_with_retention'}.contains(status)) {
      throw const FormatException('Inconsistent privacy status');
    }
    DateTime stamp(String key) {
      final raw=value[key];
      if (raw is! String || raw.length>40 || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(raw)) {
        throw const FormatException('Invalid timestamp');
      }
      return DateTime.parse(raw).toUtc();
    }
    return PrivacyRequest(id:(value['request_id'] as String).toLowerCase(),status:status,
      revision:value['revision'] as int,noticeVersion:value['notice_version'] as String,
      requestedAt:stamp('requested_at'),updatedAt:stamp('updated_at'),canCancel:value['can_cancel'] as bool,
      retainedCategories:List<String>.unmodifiable((value['retained_categories'] as List).cast<String>()));
  }
}
bool validUuid(Object? value) => value is String && value.length==36 && RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value);
bool validNotice(String value) => value==value.trim() && RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$').hasMatch(value);
class PrivacyPolicy {
  const PrivacyPolicy(this.enabled,this.noticeVersion,this.reauthSeconds);
  final bool enabled;
  final String? noticeVersion;
  final int reauthSeconds;
  factory PrivacyPolicy.fromJson(Map<String,dynamic> value) {
    final version=value['notice_version']; final seconds=value['reauth_seconds'];
    if(value['enabled'] is! bool || (version!=null && (version is! String || !validNotice(version))) ||
      (value['enabled']==true && version==null) || seconds is! int || seconds<30 || seconds>900 ||
      value['submission_means']!='request_received_not_data_deleted') throw const FormatException('Invalid privacy policy');
    return PrivacyPolicy(value['enabled'] as bool,version as String?,seconds);
  }
}
class PrivacyFailure implements Exception {
  const PrivacyFailure(this.code);
  final String code;
  String get message => switch(code) {
    'REAUTHENTICATION_REQUIRED' => 'Sign out and sign in again with WhatsApp before making this request.',
    'INTAKE_UNAVAILABLE' => 'In-app requests are unavailable. The existing account-deletion contact page is available below.',
    'NOTICE_CHANGED' => 'The notice changed. Refresh and review the current notice before submitting.',
    'ACTIVE_REQUEST_EXISTS' => 'An active request already exists. Refresh to see its status.',
    'NOT_CANCELLABLE' => 'This request can no longer be cancelled here. Refresh for its current status.',
    'RATE_LIMITED' => 'Too many requests were submitted recently. Review your existing request.',
    'AUTHENTICATION_REQUIRED' => 'Your session must be renewed before viewing this information.',
    _ => 'The result could not be confirmed. Refresh the request status before trying again.',
  };
  @override String toString() => 'PrivacyFailure($code)';
}
