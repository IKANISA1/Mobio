import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_nav.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  Widget buildSubject({
    required int currentIndex,
    required ValueChanged<int> onTap,
    bool isAdmin = false,
    bool disableAnimations = false,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data:
            MediaQueryData.fromView(
              WidgetsBinding.instance.platformDispatcher.views.first,
            ).copyWith(
              disableAnimations: disableAnimations,
              textScaler: TextScaler.linear(textScale),
            ),
        child: Scaffold(
          body: Stack(
            children: [
              MobiBottomNav(
                currentIndex: currentIndex,
                onTap: onTap,
                isAdmin: isAdmin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'passenger nav exposes accessible tab semantics and tap targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var tappedIndex = -1;

      await tester.pumpWidget(
        buildSubject(currentIndex: 1, onTap: (index) => tappedIndex = index),
      );

      expect(find.bySemanticsLabel('Home tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Trips tab'), findsOneWidget);
      expect(find.bySemanticsLabel('BioPay tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Profile tab'), findsOneWidget);
      final tripsSemantics = tester.getSemantics(
        find.bySemanticsLabel('Trips tab'),
      );
      expect(tripsSemantics.label, 'Trips tab');
      expect(tripsSemantics.hint, 'Current tab');
      expect(tripsSemantics.flagsCollection.isButton, isTrue);
      expect(
        tripsSemantics.flagsCollection.isSelected.toString(),
        'Tristate.isTrue',
      );
      expect(
        tripsSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      for (final label in [
        'Home tab',
        'Trips tab',
        'BioPay tab',
        'Profile tab',
      ]) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }

      await tester.tap(find.bySemanticsLabel('Profile tab'));
      expect(tappedIndex, 3);
      semantics.dispose();
    },
  );

  testWidgets('admin nav exposes accessible labels with reduced motion', (
    tester,
  ) async {
    var tappedIndex = -1;

    await tester.pumpWidget(
      buildSubject(
        currentIndex: 0,
        onTap: (index) => tappedIndex = index,
        isAdmin: true,
        disableAnimations: true,
      ),
    );

    expect(find.bySemanticsLabel('Ops tab'), findsOneWidget);
    expect(find.bySemanticsLabel('Users tab'), findsOneWidget);
    expect(find.bySemanticsLabel('BioPay tab'), findsOneWidget);
    expect(find.bySemanticsLabel('Account tab'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Users tab'));
    expect(tappedIndex, 1);
  });

  testWidgets('consumer tabs remain operable with keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <int>[];
    await tester.pumpWidget(
      buildSubject(currentIndex: 0, onTap: selected.add, textScale: 2),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(selected, [0, 1]);
    for (final label in [
      'Home tab',
      'Trips tab',
      'BioPay tab',
      'Profile tab',
    ]) {
      final target = find.bySemanticsLabel(label);
      expect(target, findsOneWidget);
      expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });
}
