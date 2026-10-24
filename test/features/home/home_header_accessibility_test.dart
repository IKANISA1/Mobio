import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/home/presentation/widgets/home_header.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';

const _homeHeaderBoundary = ValueKey('home-header-selection');

Future<({Color fill, Color indicator, Color adjacent})> _selectionPixels(
  WidgetTester tester,
  String label,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_homeHeaderBoundary),
  );
  final rect = tester.getRect(find.bySemanticsLabel(label));
  final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  Color pixel(double verticalInset) {
    final point = boundary.globalToLocal(
      Offset(rect.center.dx, rect.top + verticalInset),
    );
    final offset =
        (point.dy.floor() * boundary.size.width.ceil() + point.dx.floor()) * 4;
    return Color.fromARGB(
      bytes!.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }

  // The visual pill starts five points inside its full-height tap target.
  // At its horizontal centre these samples avoid text and rounded corners.
  return (fill: pixel(9), indicator: pixel(6), adjacent: pixel(3));
}

double _contrast(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
  final darker = aLuminance < bLuminance ? aLuminance : bLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('Light Home keeps the selected mode visible after either tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      var isDriver = false;
      final chosenModes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: MobiFamilyPalette.resolve(
            MobiVisualFamily.home,
            Brightness.light,
          ).apply(AppTheme.lightTheme),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RepaintBoundary(
                key: _homeHeaderBoundary,
                child: HomeHeader(
                  isDriver: isDriver,
                  unreadCount: 0,
                  onModeChanged: (mode) {
                    chosenModes.add(mode);
                    setState(() => isDriver = mode == 'driver');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final selected in ['Passenger', 'Driver', 'Passenger']) {
        if (selected != 'Passenger' || chosenModes.isNotEmpty) {
          await tester.tap(find.bySemanticsLabel(selected));
          await tester.pumpAndSettle();
        }
        final other = selected == 'Passenger' ? 'Driver' : 'Passenger';
        expect(
          tester.getSemantics(find.bySemanticsLabel(selected)),
          matchesSemantics(
            label: selected,
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true,
          ),
        );
        final selectedPixels = await _selectionPixels(tester, selected);
        final otherPixels = await _selectionPixels(tester, other);
        // This guards a visible difference, not source-native Light parity.
        expect(
          selectedPixels.fill.computeLuminance(),
          lessThan(otherPixels.fill.computeLuminance() - 0.15),
        );
        expect(
          _contrast(selectedPixels.indicator, selectedPixels.adjacent),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(selectedPixels.indicator, selectedPixels.fill),
          greaterThanOrEqualTo(3),
        );
      }
      expect(chosenModes, ['driver', 'passenger']);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Home modes expose single names and full-height touch targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        String? chosen;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: HomeHeader(
                isDriver: false,
                unreadCount: 0,
                onModeChanged: (value) => chosen = value,
                onNotifications: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in ['Passenger', 'Driver']) {
          final target = find.bySemanticsLabel(RegExp('^$label\$'));
          expect(target, findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.height, greaterThanOrEqualTo(48));
          // The former five-point visual padding must also receive pointer taps.
          await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
          await tester.pump();
          expect(chosen, label.toLowerCase());
        }
        expect(find.bySemanticsLabel('Passenger Passenger'), findsNothing);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shared account toggle padding accepts taps for both modes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      int? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MobiToggle(
              labels: const ['Passenger', 'Driver'],
              selectedIndex: 0,
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (index, label) in ['Passenger', 'Driver'].indexed) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
        await tester.pump();
        expect(chosen, index);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('driver availability has a named 48-point target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      bool? online;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HomeHeader(
              isDriver: true,
              isDriverOnline: false,
              unreadCount: 0,
              onModeChanged: (_) {},
              onDriverOnlineToggle: (value) => online = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.bySemanticsLabel('Driver availability');
      final rect = tester.getRect(target);
      expect(rect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();
      expect(online, true);
    } finally {
      semantics.dispose();
    }
  });
}
