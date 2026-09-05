import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets(
    'loading preserves button geometry and prevents repeated actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var loading = false;
      var count = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return MobiButton(
                    isLoading: loading,
                    onPressed: () => count++,
                    child: const Text('Send request'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final original = tester.getSize(find.byType(MobiButton));
      await tester.tap(find.text('Send request'));
      expect(count, 1);
      update(() => loading = true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(find.byType(MobiButton)), original);
      await tester.tap(find.byType(MobiButton));
      expect(count, 1);
      expect(find.bySemanticsLabel('Send request'), findsWidgets);
      expect(original.height, lessThan(80));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text remains readable and keyboard can activate a button',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MobiButton(
                    onPressed: () => count++,
                    child: const Text('Confirm this connection'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(count, 1);
      expect(
        tester.getSize(find.byType(MobiButton)).height,
        greaterThanOrEqualTo(52),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
