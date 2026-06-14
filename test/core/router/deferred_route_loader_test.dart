import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/router/app_page_transitions.dart';
import 'package:mobi_app/core/router/deferred_route_loader.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

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
}
