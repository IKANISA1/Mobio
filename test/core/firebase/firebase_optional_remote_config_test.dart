import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/eventual_startup_task.dart';
import 'package:mobi_app/core/async/startup_task.dart';
import 'package:mobi_app/core/firebase/firebase_remote_config_service.dart';

void main() {
  for (final result in ['late-success', 'offline-failure', 'fetch-deadline']) {
    testWidgets('Remote Config $result keeps eventual push installation', (
      tester,
    ) async {
      final remote = _RemoteConfig();
      final config = FirebaseRemoteConfigService.forTesting(remote);
      var initializers = 0, handlers = 0;
      final task = EventualStartupTask<bool>(
        initialize: () async {
          initializers++;
          await config.initialize();
          return true;
        },
        install: (ready) async {
          if (ready && config.pushNotificationsEnabled) handlers++;
        },
      );
      StartupTaskResult<bool>? observation;
      unawaited(
        task.observe(const Duration(seconds: 6)).then((r) => observation = r),
      );
      await tester.pump();
      expect(remote.calls, ['settings', 'defaults', 'fetch']);
      await tester.pump(const Duration(seconds: 6));
      expect(observation!.timedOut, isTrue);
      expect(handlers, 0);
      if (result == 'late-success') {
        remote.heldFetch.complete(true);
      } else if (result == 'offline-failure') {
        remote.heldFetch.completeError(StateError('Synthetic offline fetch'));
      } else {
        await tester.pump(const Duration(seconds: 14));
      }
      await tester.pump();
      expect(await task.work, isTrue);
      expect(config.isReady, isTrue);
      expect(config.analyticsEnabled, isTrue);
      expect(config.pushNotificationsEnabled, isTrue);
      expect(handlers, 1);
      await task.observe(const Duration(seconds: 6));
      expect(initializers, 1);
      expect(handlers, 1);
      if (result == 'fetch-deadline') {
        remote.heldFetch.completeError(
          StateError('Synthetic late fetch failure'),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _RemoteConfig implements FirebaseRemoteConfig {
  final heldFetch = Completer<bool>();
  final calls = <String>[];
  final defaults = <String, Object>{};
  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {
    calls.add('settings');
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> values) async {
    calls.add('defaults');
    defaults.addAll(values.cast<String, Object>());
  }

  @override
  Future<bool> fetchAndActivate() {
    calls.add('fetch');
    return heldFetch.future;
  }

  @override
  bool getBool(String key) => defaults[key] as bool;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
