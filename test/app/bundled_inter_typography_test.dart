import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

void main() {
  testWidgets('bundled Inter selects real faces after caller weight overrides', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final families = manifest.where((entry) => entry['family'] == 'Inter');
    expect(families, hasLength(1));
    final fonts = families.single['fonts'] as List<dynamic>;
    expect(
      fonts.map((font) => font['weight']),
      unorderedEquals([400, 500, 600, 700]),
    );
    final inter = FontLoader('Inter');
    for (final font in fonts) {
      final data = await rootBundle.load(font['asset'] as String);
      inter.addFont(Future.value(data));
      final independentFace = FontLoader('ExpectedInter${font['weight']}')
        ..addFont(Future.value(data));
      await independentFace.load();
    }
    await inter.load();

    double width(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'MW Hamburg 12345 éç',
          style: style.copyWith(
            fontSize: 24,
            fontFeatures: const [ui.FontFeature.disable('kern')],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    // Real callers override body/title weight. The family must retain all faces
    // rather than pinning every override to one GoogleFonts variant alias.
    expect(AppTypography.bodyMd.fontFamily, 'Inter');
    final widths = <double>[];
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      final actual = AppTypography.bodyMd.copyWith(fontWeight: weight);
      final expected = TextStyle(
        fontFamily: 'ExpectedInter${weight.value}',
        fontWeight: weight,
        height: actual.height,
        letterSpacing: actual.letterSpacing,
      );
      final measured = width(actual);
      widths.add(measured);
      expect(measured, closeTo(width(expected), 0.01));
    }
    expect(widths.toSet(), hasLength(4));

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final style in [
        theme.textTheme.displayLarge,
        theme.textTheme.displaySmall,
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleMedium,
        theme.textTheme.titleSmall,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
      ]) {
        expect(style!.fontFamily, 'Inter');
      }
      expect(theme.textTheme.displayLarge!.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w500);
    }
  });
}
