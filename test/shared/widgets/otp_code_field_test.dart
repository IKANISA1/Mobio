import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/shared/widgets/otp_code_field.dart';

void main() {
  testWidgets('OTP field uses native numeric text fields', (tester) async {
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
  });
}
