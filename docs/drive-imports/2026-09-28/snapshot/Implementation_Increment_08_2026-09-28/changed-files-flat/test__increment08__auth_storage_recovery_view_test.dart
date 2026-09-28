import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/auth_storage_recovery_view.dart';

void main() {
  testWidgets('reset requires confirmation and cancelled dialog does not delete', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: AuthStorageRecoveryView(canReset: true,
      resetSavedLogin: () async { calls++; })));
    await tester.tap(find.text('Reset saved login')); await tester.pumpAndSettle();
    expect(find.text('Reset saved login?'), findsOneWidget); expect(calls, 0);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(calls, 0);
  });
  testWidgets('confirmed reset requests restart without automatic login', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: AuthStorageRecoveryView(canReset: true,
      resetSavedLogin: () async { calls++; })));
    await tester.tap(find.text('Reset saved login')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset saved login').last); await tester.pumpAndSettle();
    expect(calls, 1); expect(find.text('Saved login reset'), findsOneWidget);
    expect(find.text('Close and reopen Mobio, then request a new login code.'), findsOneWidget);
  });
  testWidgets('native failure displays safe error without exception details', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthStorageRecoveryView(canReset: true,
      resetSavedLogin: () async { throw StateError('SYNTHETIC_SECRET_MUST_NOT_DISPLAY'); })));
    await tester.tap(find.text('Reset saved login')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset saved login').last); await tester.pumpAndSettle();
    expect(find.textContaining('Unable to reset saved login.'), findsOneWidget);
    expect(find.textContaining('SYNTHETIC_SECRET'), findsNothing);
  });
  testWidgets('unconfigured backend does not offer reset', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthStorageRecoveryView(canReset: false,
      resetSavedLogin: () async { fail('Must not reset unconfigured storage'); })));
    expect(find.widgetWithText(FilledButton, 'Reset saved login'), findsNothing);
  });
}
