import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Shared Firebase runtime configuration for the Mobio project.
///
/// Android and iOS use their own Firebase API keys in the shared project.
/// Pass the registered iOS app ID via `--dart-define=FIREBASE_IOS_APP_ID`.
/// Web remains optional and requires its own registered app ID.
class FirebaseRuntimeConfig {
  FirebaseRuntimeConfig._();

  static const projectId = 'gen-lang-client-0172279957';
  static const messagingSenderId = '1074154147498';
  static const storageBucket = 'gen-lang-client-0172279957.firebasestorage.app';
  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBZWg0JT-v2Qpirp63RbsPqzB4JY2onfJw',
  );
  static const androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:1074154147498:android:ba6986f8f1f04787dc4ad3',
  );
  static const iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: 'AIzaSyC8dE6DUHuVTK9tFkNx31EcEqNeNogUpjw',
  );
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const webMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '$projectId.firebaseapp.com',
  );
  static const iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'rw.mobi.app',
  );

  static FirebaseOptions? get currentPlatformOptions {
    if (kIsWeb) {
      return webOptions;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidOptions;
      case TargetPlatform.iOS:
        return iosOptions;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static FirebaseOptions get androidOptions => const FirebaseOptions(
    apiKey: apiKey,
    appId: androidAppId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );

  static FirebaseOptions? get iosOptions {
    if (iosAppId.isEmpty) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: iosApiKey,
      appId: iosAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
    );
  }

  static FirebaseOptions? get webOptions {
    if (webAppId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: webAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      authDomain: authDomain,
      measurementId: webMeasurementId.isEmpty ? null : webMeasurementId,
    );
  }
}
