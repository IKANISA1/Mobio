import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/bookings/presentation/widgets/trip_repeat_picker.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';
import 'package:mobi_app/shared/widgets/mobi_motion.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/scrolled_tap_target_guideline.dart';

void main() {
  testWidgets('admin controls expose one name and retain assistive actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Row(
              children: [
                AdminFilterChip(
                  label: 'Users',
                  isSelected: true,
                  onTap: () => actions.add('users'),
                ),
                AdminActionChip(
                  label: 'Refresh',
                  onTap: () => actions.add('refresh'),
                ),
                const AdminActionChip(label: 'Saving', isBusy: true),
              ],
            ),
          ),
        ),
      );
      for (final label in ['Users', 'Refresh']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.label, label);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
      }
      expect(actions, ['users', 'refresh']);
      final busy = tester.getSemantics(find.bySemanticsLabel('Saving'));
      expect(busy.value, 'Loading…');
      expect(busy.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('custom discovery actions support Tab, Enter and Space', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final actions = <String>[];
      final types = VehicleTypeModel.fallbackTypes.take(2).toList();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                HomeHeroCard(
                  isDriver: false,
                  nearbyCount: 2,
                  onTap: () => actions.add('nearby'),
                ),
                MobiInfoChip(
                  label: 'Tomorrow',
                  onTap: () => actions.add('tomorrow'),
                ),
                VehicleFilterChips(
                  selectedId: types.first.id,
                  vehicleTypes: types,
                  onSelected: actions.add,
                ),
              ],
            ),
          ),
        ),
      );
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
      ]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(actions, ['nearby', 'tomorrow', types.first.id]);
      final filter = tester.getSemantics(
        find.bySemanticsLabel('${types.first.label} vehicle filter'),
      );
      expect(filter.label, '${types.first.label} vehicle filter');
      expect(filter.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        filter.id,
        SemanticsAction.tap,
      );
      expect(actions.last, types.first.id);
      expect(actions.length, 4);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'repeat days wrap at 200 percent and remain named 48-point targets',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final chosen = <int>[];
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: TripRepeatPicker(
                      isRecurring: true,
                      recurringDays: const [0],
                      onToggleRecurring: () {},
                      onToggleDay: chosen.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.ensureVisible(find.bySemanticsLabel('Sunday'));
        await tester.tap(find.bySemanticsLabel('Sunday'));
        expect(chosen, [6]);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'a populated field keeps its accessible name and editable value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'Alice');
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MobiInputField(
                label: 'Display name',
                controller: controller,
              ),
            ),
          ),
        );
        final field = tester.getSemantics(find.byType(EditableText));
        expect(field.flagsCollection.isTextField, isTrue);
        expect(field.label, contains('Display name'));
        expect(field.value, 'Alice');
        await tester.enterText(find.byType(TextField), 'Alice B');
        expect(controller.text, 'Alice B');
        expect(field.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'reduced motion reveals entry effects and stops loading shimmer',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const Text(
                      'Single',
                    ).animateAccessible(context).fadeIn().slideY(begin: .2),
                    ...[
                      const Text('First'),
                      const Text('Second'),
                    ].animateAccessible(context, interval: 100.ms).fadeIn(),
                    const LoadingSkeleton(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final fade in tester.widgetList<FadeTransition>(
        find.byType(FadeTransition),
      )) {
        expect(fade.opacity.value, 1);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('scrolled target check still rejects a genuinely small control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 48,
                height: 24,
                child: InkWell(onTap: () {}, child: const Text('Small')),
              ),
            ),
          ),
        ),
      );
      final evaluation = await ScrolledTapTargetGuideline().evaluate(tester);
      expect(evaluation.passed, isFalse);
    } finally {
      semantics.dispose();
    }
  });
}
