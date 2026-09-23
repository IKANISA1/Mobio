import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

void main() {
  testWidgets('icon action supports assistive tap and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TappableIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onTap: () => taps++,
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Back'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 2);
    } finally {
      semantics.dispose();
    }
  });
}
