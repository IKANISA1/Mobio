import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app/router/app_page_transitions.dart';
import 'package:mobi_app/app/router/deferred_route_loader.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  test('route transition timings stay short enough for app navigation', () {
    expect(mobiRouteTransitionDuration, const Duration(milliseconds: 220));
    expect(
      mobiRouteReverseTransitionDuration,
      const Duration(milliseconds: 170),
    );
  });

  testWidgets('shows skeleton while a deferred route loads, then content', (
    tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DeferredRouteLoader(
          loadLibrary: () => completer.future,
          builder: (_) => const Text('Deferred route loaded'),
        ),
      ),
    );

    expect(find.byType(LoadingSkeleton), findsWidgets);
    expect(find.text('Deferred route loaded'), findsNothing);

    completer.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.text('Deferred route loaded'), findsOneWidget);
  });

  testWidgets('failed download can retry once and then open the screen', (
    tester,
  ) async {
    var attempts = 0;
    final retryResult = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DeferredRouteLoader(
          loadLibrary: () {
            attempts++;
            return attempts == 1
                ? Future.error(StateError('fixture download failure'))
                : retryResult.future;
          },
          builder: (_) => const Text('Recovered screen'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    final retry = tester
        .widget<MobiButton>(find.widgetWithText(MobiButton, 'Try again'))
        .onPressed!;
    retry();
    retry();
    await tester.pump();
    expect(
      attempts,
      2,
      reason: 'Repeated callbacks must not start overlapping loads.',
    );
    expect(find.byType(LoadingSkeleton), findsWidgets);
    retryResult.complete();
    await tester.pumpAndSettle();
    expect(find.text('Recovered screen'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error recovery hides raw diagnostics and fits enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DeferredRouteLoader(
          loadLibrary: () =>
              Future.error(StateError('fixture-private-diagnostic')),
          builder: (_) => const Text('Unreachable content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('fixture-private-diagnostic'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed direct route can return to Home', (tester) async {
    final router = GoRouter(
      initialLocation: '/broken',
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/home'),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home fixture')),
        ),
        GoRoute(
          path: '/broken',
          builder: (_, _) => DeferredRouteLoader(
            loadLibrary: () =>
                Future.error(StateError('fixture download failure')),
            builder: (_) => const Text('Unreachable content'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Go back'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('Home fixture'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('a pending direct route has an immediate return action', (
    tester,
  ) async {
    final download = Completer<void>();
    final router = GoRouter(
      initialLocation: '/pending',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home fixture')),
        ),
        GoRoute(
          path: '/pending',
          builder: (_, _) => DeferredRouteLoader(
            loadLibrary: () => download.future,
            builder: (_) => const Text('Loaded later'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Home fixture'), findsOneWidget);
    download.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loaded later'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
