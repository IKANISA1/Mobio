import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/router/error_screens.dart';
import 'package:mobi_app/core/theme/app_theme.dart';

void main() {
  testWidgets('ConfigErrorScreen fits narrow mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const ConfigErrorScreen()),
    );
    await tester.pump();

    expect(find.text('Unable to start Mobio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
