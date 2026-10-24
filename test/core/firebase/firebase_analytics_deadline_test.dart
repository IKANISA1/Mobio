import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/firebase/firebase_analytics_service.dart';

void main() {
  for (final replacement in ['account-b', 'logout']) {
    testWidgets(
      'late attach applies cached $replacement before current route',
      (tester) async {
        final service = FirebaseAnalyticsService.forTesting();
        await service.setUserContext(userId: 'account-a', role: 'driver');
        await service.setUserContext(
          userId: replacement == 'logout' ? null : 'account-b',
          role: replacement == 'logout' ? null : 'passenger',
        );
        final route = MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/late'),
          builder: (_) => const SizedBox.shrink(),
        );
        service.observers.single.didPush(route, null);
        final analytics = _ScopedAnalytics();
        service.attach(analytics);
        await service.setCollectionEnabled(true);
        await tester.pump();
        expect(
          analytics.contexts,
          replacement == 'logout'
              ? ['id:null', 'role:null']
              : ['id:account-b', 'role:passenger'],
        );
        expect(analytics.screens, [
          replacement == 'logout'
              ? '/late:null:null'
              : '/late:account-b:passenger',
        ]);
      },
    );

    testWidgets(
      'late account-a callback cannot emit before $replacement context',
      (tester) async {
        final service = FirebaseAnalyticsService.forTesting();
        await service.setUserContext(userId: 'account-a', role: 'driver');
        final analytics = _ScopedAnalytics()..heldId = Completer<void>();
        service.observers.single.didPush(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/current'),
            builder: (_) => const SizedBox.shrink(),
          ),
          null,
        );
        service.attach(analytics);
        await service.setCollectionEnabled(true);
        await tester.pump();
        expect(analytics.contexts, ['id:account-a']);
        unawaited(
          service.setUserContext(
            userId: replacement == 'logout' ? null : 'account-b',
            role: replacement == 'logout' ? null : 'passenger',
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(analytics.screens, isEmpty);
        analytics.heldId!.complete();
        await tester.pump();
        expect(
          analytics.contexts,
          replacement == 'logout'
              ? ['id:account-a', 'id:null', 'role:null']
              : ['id:account-a', 'id:account-b', 'role:passenger'],
        );
        expect(analytics.screens, [
          replacement == 'logout'
              ? '/current:null:null'
              : '/current:account-b:passenger',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'late collection enable cannot undo a newer disable or emit a route',
    (tester) async {
      final service = FirebaseAnalyticsService.forTesting();
      final analytics = _ScopedAnalytics()..heldEnable = Completer<void>();
      service.observers.single.didPush(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/collection-race'),
          builder: (_) => const SizedBox.shrink(),
        ),
        null,
      );
      service.attach(analytics);
      unawaited(service.setCollectionEnabled(true).catchError((Object _) {}));
      await tester.pump();
      unawaited(service.setCollectionEnabled(false).catchError((Object _) {}));
      await tester.pump(const Duration(seconds: 5));
      expect(analytics.screens, isEmpty);
      expect(analytics.collection, [true]);
      analytics.heldEnable!.complete();
      await tester.pump();
      expect(analytics.collection, [true, false]);
      expect(analytics.screens, isEmpty);
      await service.setCollectionEnabled(true);
      await tester.pump();
      expect(analytics.screens, ['/collection-race:null:null']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retained navigator observes current and future routes after late attach',
    (tester) async {
      final service = FirebaseAnalyticsService.forTesting();
      final observer = service.observers.single;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: service.observers,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text(settings.name!),
          ),
        ),
      );
      navigator.currentState!.pushNamed('/before-attach');
      await tester.pumpAndSettle();
      final retainedNavigator = navigator.currentState;
      final analytics = _ImmediateAnalytics();
      service.attach(analytics);
      await tester.pump();
      expect(analytics.screens, isEmpty);
      await service.setCollectionEnabled(true);
      expect(service.observers.single, same(observer));
      expect(navigator.currentState, same(retainedNavigator));
      expect(analytics.screens, ['/before-attach']);
      navigator.currentState!.pushNamed('/after-attach');
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(analytics.screens, [
        '/before-attach',
        '/after-attach',
        '/before-attach',
      ]);
      expect(navigator.currentState, same(retainedNavigator));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late attach never emits a route while collection is disabled', (
    tester,
  ) async {
    final service = FirebaseAnalyticsService.forTesting();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: service.observers,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name!),
        ),
      ),
    );
    final analytics = _ImmediateAnalytics();
    service.attach(analytics);
    await service.setCollectionEnabled(false);
    navigator.currentState!.pushNamed('/disabled');
    await tester.pumpAndSettle();
    expect(analytics.screens, isEmpty);
    await service.setCollectionEnabled(true);
    await tester.pump();
    expect(analytics.screens, ['/disabled']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route observer observes late native failure without resending', (
    tester,
  ) async {
    final analytics = _HeldAnalytics();
    final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
    await service.setCollectionEnabled(true);
    await tester.pump();
    final observer = service.observers.single;
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/held-route'),
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(route, null);
    expect(analytics.screens, ['/held-route']);
    await tester.pump(const Duration(seconds: 5));
    analytics.pending.completeError(
      StateError('Synthetic late native failure'),
    );
    await tester.pump();
    observer.didPush(route, null);
    await tester.pump();
    expect(analytics.screens, ['/held-route']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native screen telemetry observer completes at its deadline', (
    tester,
  ) async {
    final analytics = _HeldAnalytics();
    final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
    await service.setCollectionEnabled(true);
    await tester.pump();
    var completed = false;
    unawaited(
      service
          .logScreenView(screenName: '/deadline')
          .then((_) => completed = true),
    );
    await tester.pump();
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(completed, isTrue);
    analytics.pending.complete();
    await tester.pump();
    expect(analytics.screens, ['/deadline']);
  });

  for (final next in ['clear', 'same-owner-role']) {
    testWidgets('late old context cannot overwrite newer $next context', (
      tester,
    ) async {
      final analytics = _HeldContextAnalytics();
      final service = FirebaseAnalyticsService.forTesting()..attach(analytics);
      var oldObserverDone = false;
      unawaited(
        service
            .setUserContext(userId: 'owner', role: 'driver')
            .then((_) => oldObserverDone = true),
      );
      await tester.pump();
      expect(analytics.calls, ['id:owner']);
      final newest = next == 'clear'
          ? service.setUserContext()
          : service.setUserContext(userId: 'owner', role: 'passenger');
      await tester.pump(const Duration(seconds: 5));
      expect(oldObserverDone, isTrue);
      expect(analytics.calls, ['id:owner']);
      analytics.pending.complete();
      await tester.pump();
      await newest;
      expect(
        analytics.calls,
        next == 'clear'
            ? ['id:owner', 'id:null', 'role:null']
            : ['id:owner', 'id:owner', 'role:passenger'],
      );
      expect(analytics.calls, isNot(contains('role:driver')));
      expect(tester.takeException(), isNull);
    });
  }
}

class _ImmediateAnalytics implements FirebaseAnalytics {
  final screens = <String>[];
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}
  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {}
  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {}
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async => screens.add(screenName!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeldAnalytics implements FirebaseAnalytics {
  final pending = Completer<void>();
  final screens = <String>[];
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}
  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {}
  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) {
    screens.add(screenName!);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HeldContextAnalytics implements FirebaseAnalytics {
  final pending = Completer<void>();
  final calls = <String>[];
  bool held = false;

  @override
  Future<void> setUserId({String? id, AnalyticsCallOptions? callOptions}) {
    calls.add('id:$id');
    if (!held) {
      held = true;
      return pending.future;
    }
    return Future.value();
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add('role:$value');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScopedAnalytics implements FirebaseAnalytics {
  final contexts = <String>[];
  final screens = <String>[];
  final collection = <bool>[];
  Completer<void>? heldId, heldEnable;
  bool _idHeld = false, _enableHeld = false;
  String? userId, role;

  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {
    contexts.add('id:$id');
    if (!_idHeld && heldId != null) {
      _idHeld = true;
      await heldId!.future;
    }
    userId = id;
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    contexts.add('role:$value');
    role = value;
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collection.add(enabled);
    if (enabled && !_enableHeld && heldEnable != null) {
      _enableHeld = true;
      await heldEnable!.future;
    }
  }

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    screens.add('$screenName:$userId:$role');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
