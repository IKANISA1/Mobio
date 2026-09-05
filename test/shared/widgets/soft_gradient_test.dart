import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('overview wash scrolls away and returns with the content', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SoftGradient(
            tone: SoftGradientTone.biopay,
            child: ListView(
              controller: controller,
              children: const [SizedBox(height: 2400)],
            ),
          ),
        ),
      ),
    );
    Positioned wash() => tester.widget<Positioned>(
      find
          .descendant(
            of: find.byType(SoftGradient),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(wash().top, 0);
    controller.jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(wash().top, -300);
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(wash().top, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
