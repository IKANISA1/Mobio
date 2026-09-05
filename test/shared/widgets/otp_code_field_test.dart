import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/otp_code_field.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('OTP field uses native numeric text fields', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    final changes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: MobiOtpCodeField(
            controller: controller,
            enabled: true,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(6));
    expect(fields.every((field) => field.maxLines == 1), isTrue);
    for (var i = 1; i <= 6; i++) {
      expect(find.bySemanticsLabel('Digit $i of 6'), findsOneWidget);
    }
    expect(
      fields.every((field) => field.keyboardType == TextInputType.number),
      isTrue,
    );
    expect(fields.every((field) => field.autofocus == false), isTrue);
    expect(fields.first.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(find.byType(TextButton), findsNothing);
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);

    for (var i = 0; i < 6; i += 1) {
      await tester.enterText(
        find.byKey(ValueKey('mobi_otp_digit_$i')),
        '${i + 1}',
      );
      await tester.pump();
    }

    expect(controller.text, '123456');
    expect(changes.last, '123456');
    semantics.dispose();
  });
  testWidgets(
    'full code paste replaces all cells and backspace revisits the previous cell',
    (tester) async {
      final controller = TextEditingController(text: '111111');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MobiOtpCodeField(
              controller: controller,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('mobi_otp_digit_2')),
        '987654',
      );
      await tester.pump();
      expect(controller.text, '987654');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mobi_otp_digit_0')))
            .controller!
            .text,
        '9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('mobi_otp_digit_5')),
        '',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, '9876');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mobi_otp_digit_4')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
