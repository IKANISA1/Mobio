import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

enum MobiVisualFamily {
  neutral,
  home,
  teal,
  payments,
  value,
  rewards,
  authentication,
}

/// sRGB screenshot observations from DESK-001/003–007, 5 September 2026.
/// Sample positions are interpolated adapters, not exported native stops.
class MobiFamilyPalette {
  const MobiFamilyPalette(this.colors);
  final List<Color> colors;
  static const stops = [0.0, .14, .216, .373, .449, .718, .852, 1.0];

  static MobiFamilyPalette resolve(MobiVisualFamily family, Brightness mode) {
    final values = switch (family) {
      MobiVisualFamily.home => [
        0xFF3453FC,
        0xFF182BE2,
        0xFF0B1CC7,
        0xFF03108D,
        0xFF04086A,
        0xFF000545,
        0xFF00043C,
        0xFF00043C,
      ],
      MobiVisualFamily.teal => [
        0xFF36A9BE,
        0xFF1E7389,
        0xFF125063,
        0xFF0D3442,
        0xFF082A35,
        0xFF051C23,
        0xFF021920,
        0xFF021920,
      ],
      MobiVisualFamily.payments => [
        0xFF673CDC,
        0xFF221546,
        0xFF1B123A,
        0xFF17133A,
        0xFF17133A,
        0xFF17123A,
        0xFF16133A,
        0xFF16133A,
      ],
      MobiVisualFamily.value => [
        0xFF8398EF,
        0xFF5F6EBA,
        0xFF405093,
        0xFF27336C,
        0xFF202A5C,
        0xFF161A37,
        0xFF121732,
        0xFF121732,
      ],
      MobiVisualFamily.rewards => [
        0xFF943FF6,
        0xFF7E4DF5,
        0xFF7351F3,
        0xFF644AF2,
        0xFF5650E5,
        0xFF342B7D,
        0xFF302B7D,
        0xFF302B7D,
      ],
      MobiVisualFamily.authentication => [
        0xFF435E8E,
        0xFF374C8D,
        0xFF2C3D8E,
        0xFF18227D,
        0xFF151D74,
        0xFF0F164C,
        0xFF0E113D,
        0xFF0E113D,
      ],
      MobiVisualFamily.neutral => List.filled(8, 0xFF000000),
    };
    final dark = values.map(Color.new).toList(growable: false);
    // Paired light washes are target adaptations; native light is unverified.
    return MobiFamilyPalette(
      mode == Brightness.dark
          ? dark
          : [
              for (var i = 0; i < dark.length; i++)
                Color.lerp(
                  dark[i],
                  Colors.white,
                  .84 + .12 * i / (dark.length - 1),
                )!,
            ],
    );
  }

  ThemeData apply(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final canvas = colors.last;
    Color tint(double opacity) => dark
        ? Color.alphaBlend(Colors.white.withValues(alpha: opacity), canvas)
        : Color.lerp(canvas, Colors.white, .86)!;
    final low = tint(.10), high = tint(.17), highest = tint(.24);
    final ext = base.extension<MobiThemeExtension>()!;
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: base.colorScheme.copyWith(
        surface: canvas,
        onSurfaceVariant: dark
            ? Color.alphaBlend(Colors.white.withValues(alpha: .70), canvas)
            : base.colorScheme.onSurfaceVariant,
        surfaceContainerLowest: canvas,
        surfaceContainerLow: low,
        surfaceContainer: low,
        surfaceContainerHigh: high,
        surfaceContainerHighest: highest,
      ),
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! MobiThemeExtension) extension,
        ext.copyWith(
          surfaceContainerLowest: canvas,
          surfaceContainerLow: low,
          surfaceContainer: low,
          surfaceContainerHigh: high,
          surfaceContainerHighest: highest,
          backgroundGradientTop: colors.first,
          backgroundGradientMid: colors[3],
          backgroundGradientBottom: canvas,
        ),
      ],
    );
  }
}
