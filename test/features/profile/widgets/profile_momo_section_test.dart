import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_momo_section.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('ProfileMomoSection captures MoMo number and pay code', (
    tester,
  ) async {
    final numberController = TextEditingController(text: '0788767816');
    final codeController = TextEditingController(text: '123456');
    addTearDown(numberController.dispose);
    addTearDown(codeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ProfileMomoSection(
            momoNumberController: numberController,
            momoPayCodeController: codeController,
          ),
        ),
      ),
    );

    expect(find.text('MoMo'), findsOneWidget);
    expect(find.text('MoMo number'), findsOneWidget);
    expect(find.text('MoMo Pay code'), findsOneWidget);
    expect(find.text('0788767816'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
  });
}
