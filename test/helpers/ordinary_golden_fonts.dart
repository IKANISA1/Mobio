import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Explicit test-engine fallback families. Product Inter remains primary.
/// These names describe a portable test contract, not native font selection.
const ordinaryGoldenFallbackFamilies = <String>['MobioOrdinarySymbols'];

const ordinaryGoldenFontLimitations = <String>[
  'Bundled Inter 400, 500, 600 and 700 remain the primary product faces; MaterialIcons and Lucide are unchanged.',
  'Named DejaVu Sans 2.37 is declared only in ordinary test theme copies for unsupported route-arrow glyphs. No Ahem alias or global AppTypography mutation is used.',
  'The test engine disables implicit platform fallback. These pinned explicit families provide a deterministic test contract, not proof of Android API36, iOS or browser per-glyph font equivalence.',
  'No ordinary-test emoji fallback is declared. Raw country-flag cases remain held; the retired SDK CBDT and lossless SBIX experiments did not demonstrate colour flag paint on the observed host.',
  'Ordinary comparisons retain the existing golden comparator and DPR. Explicit candidate export mode stages images without accepting them.',
];

const _fixtureDirectory = 'test/fixtures/fonts/ordinary';
const _fontSpecs =
    <({String family, String file, String hash, String version})>[
      (
        family: 'MobioOrdinarySymbols',
        file: 'DejaVuSans.ttf',
        hash:
            '7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954',
        version: 'DejaVu Sans 2.37 regular',
      ),
      (
        family: 'MobioOrdinarySymbols',
        file: 'DejaVuSans-Bold.ttf',
        hash:
            'e6476c1b80502924294eed40894c5b18e06c181444ca953e5334262df9c27724',
        version: 'DejaVu Sans 2.37 bold',
      ),
    ];

bool _loaded = false;
final _provenance = <Map<String, Object?>>[];

List<Map<String, Object?>> get ordinaryGoldenFontProvenance =>
    List<Map<String, Object?>>.unmodifiable(
      _provenance.map(Map<String, Object?>.unmodifiable),
    );

/// Loads repository fixtures, so Linux CI does not depend on host font paths.
/// Failure to read, verify or decode a font fails the suite; no substitution is
/// attempted. Product and icon fonts are still loaded by the existing harness.
Future<void> loadOrdinaryGoldenFallbackFonts() async {
  if (_loaded) return;
  final loaders = <String, FontLoader>{};
  final records = <Map<String, Object?>>[];
  for (final spec in _fontSpecs) {
    final path = '$_fixtureDirectory/${spec.file}';
    final bytes = await File(path).readAsBytes();
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != spec.hash) {
      throw StateError('Ordinary golden font hash mismatch: $path');
    }
    (loaders[spec.family] ??= FontLoader(
      spec.family,
    )).addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    records.add({
      'test_family': spec.family,
      'path': path,
      'bytes': bytes.length,
      'sha256': actualHash,
      'version': spec.version,
      'scope': 'explicit ordinary-test fallback only',
    });
  }
  for (final loader in loaders.values) {
    await loader.load();
  }
  _provenance
    ..clear()
    ..addAll(records);
  _loaded = true;
}

TextStyle? _withOrdinaryFallbacks(TextStyle? style) => style?.copyWith(
  fontFamilyFallback: <String>{
    ...?style.fontFamilyFallback,
    ...ordinaryGoldenFallbackFamilies,
  }.toList(growable: false),
);

TextTheme _ordinaryTextTheme(TextTheme theme) => theme.copyWith(
  displayLarge: _withOrdinaryFallbacks(theme.displayLarge),
  displayMedium: _withOrdinaryFallbacks(theme.displayMedium),
  displaySmall: _withOrdinaryFallbacks(theme.displaySmall),
  headlineLarge: _withOrdinaryFallbacks(theme.headlineLarge),
  headlineMedium: _withOrdinaryFallbacks(theme.headlineMedium),
  headlineSmall: _withOrdinaryFallbacks(theme.headlineSmall),
  titleLarge: _withOrdinaryFallbacks(theme.titleLarge),
  titleMedium: _withOrdinaryFallbacks(theme.titleMedium),
  titleSmall: _withOrdinaryFallbacks(theme.titleSmall),
  bodyLarge: _withOrdinaryFallbacks(theme.bodyLarge),
  bodyMedium: _withOrdinaryFallbacks(theme.bodyMedium),
  bodySmall: _withOrdinaryFallbacks(theme.bodySmall),
  labelLarge: _withOrdinaryFallbacks(theme.labelLarge),
  labelMedium: _withOrdinaryFallbacks(theme.labelMedium),
  labelSmall: _withOrdinaryFallbacks(theme.labelSmall),
);

/// Copies theme styles without changing primary faces, metrics or production
/// style objects. Text with an explicit non-inheriting style is not rewritten.
ThemeData ordinaryGoldenTheme(ThemeData productionTheme) =>
    productionTheme.copyWith(
      textTheme: _ordinaryTextTheme(productionTheme.textTheme),
      primaryTextTheme: _ordinaryTextTheme(productionTheme.primaryTextTheme),
    );

typedef _GlyphPaint = ({int width, int height, String hash, int opaquePixels});

Future<_GlyphPaint> _paintGlyph(String text, TextStyle style) async {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  final width = painter.width.ceil() + 16;
  // Align the actual alphabetic baseline so the arrow comparison tests glyph
  // pixels rather than the primary family's otherwise valid line metrics.
  const height = 128;
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset(8, 64 - baseline));
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(width, height);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(pixels, isNotNull, reason: 'Glyph paint must produce pixels: $text');
    final bytes = pixels!.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );
    var opaque = 0;
    for (var offset = 0; offset < bytes.length; offset += 4) {
      if (bytes[offset + 3] != 255) continue;
      opaque++;
    }
    return (
      width: width,
      height: height,
      hash: sha256.convert(bytes).toString(),
      opaquePixels: opaque,
    );
  } finally {
    image?.dispose();
    picture.dispose();
    painter.dispose();
  }
}

/// Requires an actual route arrow painted through Inter fallback to match the
/// named symbols face. This guard accepts no UI baseline or native family.
Future<void> expectOrdinaryGoldenGlyphPaint() async {
  const fallbackStyle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ordinaryGoldenFallbackFamilies,
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );
  final arrow = await _paintGlyph('\u2192', fallbackStyle);
  final expectedArrow = await _paintGlyph(
    '\u2192',
    fallbackStyle.copyWith(fontFamily: ordinaryGoldenFallbackFamilies.first),
  );
  expect(arrow.opaquePixels, greaterThan(0));
  expect(
    (arrow.width, arrow.height),
    (expectedArrow.width, expectedArrow.height),
  );
  expect(
    arrow.hash,
    expectedArrow.hash,
    reason: 'Inter arrow fallback must paint the declared symbols face.',
  );
}

/// Checks the actual span styles supplied to RenderParagraph, after inherited
/// styles resolve. It neither mutates paragraphs nor treats registration as
/// proof of glyph paint. Reviewed candidate pixels must supply that evidence.
void expectOrdinaryGoldenGlyphFallbacks(WidgetTester tester) {
  void inspect(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return;
    final effective = inherited?.merge(span.style) ?? span.style;
    final text = span.text;
    if (text != null && text.runes.any((rune) => rune == 0x2192)) {
      expect(
        effective?.fontFamilyFallback,
        containsAll(ordinaryGoldenFallbackFamilies),
        reason: 'Glyph-bearing paragraph must declare test fallbacks: $text',
      );
      expect(
        effective?.fontFamily,
        'Inter',
        reason: 'Glyph fallback must retain the primary Inter face: $text',
      );
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      inspect(child, effective);
    }
  }

  for (final element in find.byType(RichText, skipOffstage: false).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is RenderParagraph) inspect(paragraph.text, null);
  }
}
