import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
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
    await RequestDeadline.read(
      remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 20),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 6),
        ),
      ),
      timeout: const Duration(seconds: 5),
    );
    await RequestDeadline.read(
      remoteConfig.setDefaults(_defaults),
      timeout: const Duration(seconds: 5),
    );

    try {
      await RequestDeadline.read(
        remoteConfig.fetchAndActivate(),
        timeout: const Duration(seconds: 20),
      );
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
  };
}
