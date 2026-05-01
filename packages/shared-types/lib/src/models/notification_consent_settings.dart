class NotificationConsentSettings {
  final bool promotionalInApp;
  final bool promotionalPush;

  const NotificationConsentSettings({
    this.promotionalInApp = false,
    this.promotionalPush = false,
  });

  bool get hasAnyPromotionalConsent => promotionalInApp || promotionalPush;

  NotificationConsentSettings copyWith({
    bool? promotionalInApp,
    bool? promotionalPush,
  }) {
    return NotificationConsentSettings(
      promotionalInApp: promotionalInApp ?? this.promotionalInApp,
      promotionalPush: promotionalPush ?? this.promotionalPush,
    );
  }

  factory NotificationConsentSettings.fromRows(List<dynamic> rows) {
    var inApp = false;
    var push = false;

    for (final row in rows) {
      if (row is! Map) continue;
      final consentType = row['consent_type'] as String?;
      final channel = row['channel'] as String?;
      final status = row['status'] as String?;
      if (consentType != 'promotional') continue;

      final isGranted = status == 'granted';
      if (channel == 'in_app') inApp = isGranted;
      if (channel == 'push') push = isGranted;
    }

    return NotificationConsentSettings(
      promotionalInApp: inApp,
      promotionalPush: push,
    );
  }
}
