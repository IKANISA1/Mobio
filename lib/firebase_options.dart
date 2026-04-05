import 'package:firebase_core/firebase_core.dart';
import 'package:mobi_app/core/config/firebase_runtime_config.dart';

/// Manual FlutterFire options wrapper for the Mobio Firebase project.
///
/// Android is checked in and ready. iOS and Web require either a successful
/// `flutterfire configure` run or the platform app IDs passed through
/// `--dart-define`.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions? get currentPlatform =>
      FirebaseRuntimeConfig.currentPlatformOptions;
}
