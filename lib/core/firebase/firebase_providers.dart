import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';
import 'package:mobi_app/core/firebase/firebase_auth_service.dart';
import 'package:mobi_app/core/firebase/firebase_remote_config_service.dart';

final firebaseAnalyticsServiceProvider = Provider(
  (ref) => FirebaseAnalyticsService.instance,
);

final firebaseAuthServiceProvider = Provider(
  (ref) => FirebaseAuthService.instance,
);

final firebaseRemoteConfigServiceProvider = Provider(
  (ref) => FirebaseRemoteConfigService.instance,
);
