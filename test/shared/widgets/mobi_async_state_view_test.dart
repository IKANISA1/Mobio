import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/mobi_async_state_view.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('MobiAsyncStateView renders friendly error and retry action', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MobiAsyncStateView<int>(
            value: AsyncValue.error(
              Exception('Network unavailable'),
              StackTrace.current,
            ),
            data: (value) => Text('$value'),
            errorTitle: 'Unable to load',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Unable to load'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    expect(retries, 1);
  });
}
