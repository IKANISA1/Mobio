import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/utils/app_logger.dart';

class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService._();

  static final instance = FirebaseRemoteConfigService._();

  FirebaseRemoteConfig? _remoteConfig;

  bool get isReady => _remoteConfig != null;

  Future<void> initialize() async {
    if (_remoteConfig != null) {
      return;
    }

    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 20),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 6),
      ),
    );
    await remoteConfig.setDefaults(_defaults);

    try {
      await remoteConfig.fetchAndActivate();
    } on Object catch (error, stackTrace) {
      AppLogger.warning(
        'Firebase Remote Config fetch failed. Falling back to defaults.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    _remoteConfig = remoteConfig;
  }

  bool get analyticsEnabled => _getBool('analytics_enabled', fallback: true);

  bool get crashlyticsEnabled =>
      _getBool('crashlytics_enabled', fallback: true);

  bool get pushNotificationsEnabled =>
      _getBool('push_notifications_enabled', fallback: true);

  bool get maintenanceModeEnabled =>
      _getBool('maintenance_mode_enabled', fallback: false);

  String get maintenanceModeMessage => _getString(
    'maintenance_mode_message',
    fallback: 'Mobio is temporarily unavailable. Please try again shortly.',
  );

  String get landingDownloadAndroidUrl =>
      _getString('landing_download_android_url');

  String get landingDownloadIosUrl => _getString('landing_download_ios_url');

  String get supportWhatsappNumber => _getString('support_whatsapp_number');

  bool get ledgerEnabled => _getBool('feature_ledger_enabled', fallback: false);

  bool get biopayEnabled => _getBool('feature_biopay_enabled', fallback: false);

  bool get qrEnabled => _getBool('feature_qr_enabled', fallback: false);

  bool get nfcEnabled => _getBool('feature_nfc_enabled', fallback: false);

  bool get ussdEnabled => _getBool('feature_ussd_enabled', fallback: false);

  bool get facePayEnabled =>
      _getBool('feature_face_pay_enabled', fallback: false);

  bool _getBool(String key, {required bool fallback}) {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return fallback;
    }

    return remoteConfig.getBool(key);
  }

  String _getString(String key, {String fallback = ''}) {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return fallback;
    }

    final value = remoteConfig.getString(key);
    return value.isEmpty ? fallback : value;
  }

  static const Map<String, Object> _defaults = <String, Object>{
    'analytics_enabled': true,
    'crashlytics_enabled': true,
    'push_notifications_enabled': true,
    'maintenance_mode_enabled': false,
    'maintenance_mode_message':
        'Mobio is temporarily unavailable. Please try again shortly.',
    'landing_download_android_url': '',
    'landing_download_ios_url': '',
    'support_whatsapp_number': '+250000000000',
    'feature_ledger_enabled': false,
    'feature_biopay_enabled': false,
    'feature_qr_enabled': false,
    'feature_nfc_enabled': false,
    'feature_ussd_enabled': false,
    'feature_face_pay_enabled': false,
  };
}
