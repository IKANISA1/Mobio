import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_design_system/theme/app_typography.dart';

/// Rendering adapters for local capture evidence only. They are not runtime
/// assets or authority for Mobio's production typography or native fallback.
const designCaptureFallbackFamilies = <String>[
  'MobioCaptureArialUnicode',
  'MobioCaptureAppleEmoji',
];

const designCaptureFontLimitations = <String>[
  'MaterialIcons and Lucide are loaded from existing bundled font assets.',
  'Production Inter is retained. Named local macOS Unicode and emoji fallbacks are appended only to capture themes and the capture process AppTypography styles; all original styles are restored at suite teardown.',
  'The test engine Ahem fallback is aliased to pinned-SDK Roboto-Regular for text without a production font family.',
  'Local font files are read in place, hashed and never copied to runtime assets or redistributed.',
  'Capture fallback choices establish legible test rendering, not installed iOS, Android or browser font equivalence.',
  'After font readiness, capture paint is flushed with a zero-duration frame and a 16ms frame; logo paint checks flush one zero-duration frame. Pending progress animations remain active. These bounded frames do not establish idle state, task completion or native motion timing.',
  'A successful font load does not by itself verify every glyph; inspect the actual captured images.',
];

final _fontProvenance = <Map<String, Object?>>[];
bool _loaded = false;
Map<String, TextStyle>? _originalTypography;
final _typographyFallbackProvenance = <Map<String, Object?>>[];
final _logoPaintProvenance = <Map<String, Object?>>[];
Map<String, Object?>? _logoDecodeProvenance;

const _logoAsset = 'icon/mobi_logo_transparent.png';

List<Map<String, Object?>> get designCaptureFontProvenance =>
    List<Map<String, Object?>>.unmodifiable(
      _fontProvenance.map(Map<String, Object?>.unmodifiable),
    );

List<Map<String, Object?>> get designCaptureTypographyFallbackProvenance =>
    List<Map<String, Object?>>.unmodifiable(
      _typographyFallbackProvenance.map(Map<String, Object?>.unmodifiable),
    );

Map<String, Object?>? get designCaptureLogoDecodeProvenance =>
    _logoDecodeProvenance == null
    ? null
    : Map<String, Object?>.unmodifiable(_logoDecodeProvenance!);

List<Map<String, Object?>> get designCaptureLogoPaintProvenance =>
    List<Map<String, Object?>>.unmodifiable(
      _logoPaintProvenance.map(Map<String, Object?>.unmodifiable),
    );

class _CaptureStyleBinding {
  const _CaptureStyleBinding(this.name, this.read, this.write);

  final String name;
  final TextStyle Function() read;
  final void Function(TextStyle) write;
}

final _typographyBindings = <_CaptureStyleBinding>[
  _CaptureStyleBinding(
    'displayLg',
    () => AppTypography.displayLg,
    (s) => AppTypography.displayLg = s,
  ),
  _CaptureStyleBinding(
    'displayMd',
    () => AppTypography.displayMd,
    (s) => AppTypography.displayMd = s,
  ),
  _CaptureStyleBinding(
    'headlineLg',
    () => AppTypography.headlineLg,
    (s) => AppTypography.headlineLg = s,
  ),
  _CaptureStyleBinding(
    'headlineMd',
    () => AppTypography.headlineMd,
    (s) => AppTypography.headlineMd = s,
  ),
  _CaptureStyleBinding(
    'headlineSm',
    () => AppTypography.headlineSm,
    (s) => AppTypography.headlineSm = s,
  ),
  _CaptureStyleBinding(
    'titleLg',
    () => AppTypography.titleLg,
    (s) => AppTypography.titleLg = s,
  ),
  _CaptureStyleBinding(
    'titleMd',
    () => AppTypography.titleMd,
    (s) => AppTypography.titleMd = s,
  ),
  _CaptureStyleBinding(
    'bodyLg',
    () => AppTypography.bodyLg,
    (s) => AppTypography.bodyLg = s,
  ),
  _CaptureStyleBinding(
    'bodyMd',
    () => AppTypography.bodyMd,
    (s) => AppTypography.bodyMd = s,
  ),
  _CaptureStyleBinding(
    'bodySm',
    () => AppTypography.bodySm,
    (s) => AppTypography.bodySm = s,
  ),
  _CaptureStyleBinding(
    'labelSm',
    () => AppTypography.labelSm,
    (s) => AppTypography.labelSm = s,
  ),
  _CaptureStyleBinding(
    'labelMd',
    () => AppTypography.labelMd,
    (s) => AppTypography.labelMd = s,
  ),
  _CaptureStyleBinding(
    'labelLg',
    () => AppTypography.labelLg,
    (s) => AppTypography.labelLg = s,
  ),
  _CaptureStyleBinding(
    'heroNumber',
    () => AppTypography.heroNumber,
    (s) => AppTypography.heroNumber = s,
  ),
  _CaptureStyleBinding(
    'chipText',
    () => AppTypography.chipText,
    (s) => AppTypography.chipText = s,
  ),
  _CaptureStyleBinding(
    'badgeText',
    () => AppTypography.badgeText,
    (s) => AppTypography.badgeText = s,
  ),
];

TextStyle? _withCaptureFallbacks(TextStyle? style) => style?.copyWith(
  fontFamilyFallback: <String>{
    ...?style.fontFamilyFallback,
    ...designCaptureFallbackFamilies,
  }.toList(growable: false),
);

/// Explicit Inter styles carry their own fallback list, which overrides the
/// theme fallback. Change only that list within this capture process. This is
/// not a production font substitution or proof of native fallback behaviour.
void enableDesignCaptureTypographyFallbacks() {
  if (!_loaded) {
    throw StateError('Load capture fonts before enabling fallbacks.');
  }
  if (_originalTypography != null) return;
  _originalTypography = {
    for (final binding in _typographyBindings) binding.name: binding.read(),
  };
  _typographyFallbackProvenance.clear();
  try {
    for (final binding in _typographyBindings) {
      final original = _originalTypography![binding.name]!;
      final adapted = _withCaptureFallbacks(original)!;
      // copyWith(null) preserves the old list. Normalize this one permitted
      // field on both sides so a null original fallback is checked correctly.
      // Every other style field must remain identical.
      expect(
        adapted.copyWith(fontFamilyFallback: const []),
        original.copyWith(fontFamilyFallback: const []),
        reason: 'The capture adapter may change only fallback fonts.',
      );
      binding.write(adapted);
      _typographyFallbackProvenance.add({
        'style': 'AppTypography.${binding.name}',
        'primary_family_before': original.fontFamily,
        'primary_family_after': adapted.fontFamily,
        'weight_before': original.fontWeight?.value,
        'weight_after': adapted.fontWeight?.value,
        'size_before': original.fontSize,
        'size_after': adapted.fontSize,
        'fallback_before': original.fontFamilyFallback,
        'fallback_after': adapted.fontFamilyFallback,
        'capture_only': true,
        'only_fallback_changed': true,
        'restored': false,
      });
    }
  } on Object catch (_) {
    restoreDesignCaptureTypographyFallbacks();
    rethrow;
  }
}

void restoreDesignCaptureTypographyFallbacks() {
  final originals = _originalTypography;
  if (originals == null) return;
  for (final binding in _typographyBindings) {
    binding.write(originals[binding.name]!);
    expect(identical(binding.read(), originals[binding.name]), isTrue);
  }
  for (final record in _typographyFallbackProvenance) {
    record['restored'] = true;
  }
  _originalTypography = null;
}

Future<void> loadDesignCaptureFonts() async {
  if (_loaded) return;
  GoogleFonts.config.allowRuntimeFetching = false;

  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  final registeredInter =
      manifest.singleWhere((family) => family['family'] == 'Inter')['fonts']
          as List<dynamic>;
  final inter = FontLoader('Inter');
  final interRecords = <Map<String, Object?>>[];
  for (final face in registeredInter) {
    final path = face['asset'] as String;
    final data = await rootBundle.load(path);
    inter.addFont(Future.value(data));
    interRecords.add({
      'family': 'Inter',
      'path': path,
      'declared_weight': face['weight'],
      'sha256': sha256
          .convert(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          )
          .toString(),
      'bytes': data.lengthInBytes,
      'role': 'production Inter face from the application font manifest',
      'capture_only': true,
      'source': 'existing bundled asset',
    });
  }
  await inter.load().timeout(const Duration(seconds: 30));
  _fontProvenance.addAll([
    for (final record in interRecords) {...record, 'loaded': true},
  ]);

  Future<void> load(
    String family,
    String path, {
    required bool localFile,
    required String role,
  }) async {
    final data = localFile
        ? ByteData.sublistView(File(path).readAsBytesSync())
        : await rootBundle.load(path);
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load().timeout(const Duration(seconds: 30));
    _fontProvenance.add({
      'family': family,
      'path': path,
      'sha256': sha256
          .convert(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          )
          .toString(),
      'bytes': data.lengthInBytes,
      'role': role,
      'loaded': true,
      'capture_only': true,
      'source': localFile
          ? 'local font, read in place'
          : 'existing bundled asset',
    });
  }

  await load(
    'MaterialIcons',
    'fonts/MaterialIcons-Regular.otf',
    localFile: false,
    role: 'production Material icon glyphs',
  );
  await load(
    'packages/lucide_icons/Lucide',
    'packages/lucide_icons/assets/lucide.ttf',
    localFile: false,
    role: 'production Lucide icon glyphs',
  );
  await load(
    'Ahem',
    '/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
    localFile: true,
    role: 'test-engine default text alias only',
  );
  await load(
    designCaptureFallbackFamilies[0],
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    localFile: true,
    role: 'named capture-only Unicode fallback, including U+2192',
  );
  await load(
    designCaptureFallbackFamilies[1],
    '/System/Library/Fonts/Apple Color Emoji.ttc',
    localFile: true,
    role: 'named capture-only colour emoji fallback',
  );
  _loaded = true;
}

/// Retains each production font family, weight and size while declaring the
/// local capture fallback chain for unsupported Unicode and emoji glyphs.
ThemeData designCaptureTheme(ThemeData productionTheme) =>
    productionTheme.copyWith(
      textTheme: _captureTextTheme(productionTheme.textTheme),
      primaryTextTheme: _captureTextTheme(productionTheme.primaryTextTheme),
    );

TextTheme _captureTextTheme(TextTheme theme) => theme.copyWith(
  displayLarge: _withCaptureFallbacks(theme.displayLarge),
  displayMedium: _withCaptureFallbacks(theme.displayMedium),
  displaySmall: _withCaptureFallbacks(theme.displaySmall),
  headlineLarge: _withCaptureFallbacks(theme.headlineLarge),
  headlineMedium: _withCaptureFallbacks(theme.headlineMedium),
  headlineSmall: _withCaptureFallbacks(theme.headlineSmall),
  titleLarge: _withCaptureFallbacks(theme.titleLarge),
  titleMedium: _withCaptureFallbacks(theme.titleMedium),
  titleSmall: _withCaptureFallbacks(theme.titleSmall),
  bodyLarge: _withCaptureFallbacks(theme.bodyLarge),
  bodyMedium: _withCaptureFallbacks(theme.bodyMedium),
  bodySmall: _withCaptureFallbacks(theme.bodySmall),
  labelLarge: _withCaptureFallbacks(theme.labelLarge),
  labelMedium: _withCaptureFallbacks(theme.labelMedium),
  labelSmall: _withCaptureFallbacks(theme.labelSmall),
);

/// Await bundled Inter, then flush font layout and paint at a fixed phase.
/// Intentional busy fixtures keep their progress animations running, so this
/// must not wait for every scheduled animation frame to stop.
Future<void> settleDesignCaptureFonts(WidgetTester tester) async {
  final fontsReady = await tester.runAsync(() async {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 30));
    return true;
  });
  expect(fontsReady, isTrue, reason: 'Capture fonts must finish loading.');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

/// Resolve the actual production ImageProvider before mounting its widget, so
/// decode completion cannot be stranded in the widget test's fake-async zone.
/// No substitute image or pixels are injected. Unlike plain precacheImage,
/// this fails on an asset/decode error and checks that decoded artwork exists.
Future<void> preloadDesignCaptureLogo(WidgetTester tester) async {
  final record = await tester.runAsync(() async {
    final assetBytes = await rootBundle
        .load(_logoAsset)
        .timeout(const Duration(seconds: 30));
    final imageReady = Completer<ImageInfo>();
    final stream = const AssetImage(_logoAsset).resolve(
      ImageConfiguration(
        devicePixelRatio: tester.view.devicePixelRatio,
        locale: const Locale('en'),
      ),
    );
    final listener = ImageStreamListener(
      (image, _) {
        if (imageReady.isCompleted) {
          image.dispose();
        } else {
          imageReady.complete(image);
        }
      },
      onError: (Object error, StackTrace? stack) {
        if (!imageReady.isCompleted) imageReady.completeError(error, stack);
      },
    );
    ImageInfo? decoded;
    stream.addListener(listener);
    try {
      decoded = await imageReady.future.timeout(const Duration(seconds: 30));
      final pixels = await decoded.image
          .toByteData(format: ui.ImageByteFormat.rawRgba)
          .timeout(const Duration(seconds: 30));
      if (pixels == null) {
        throw StateError('Logo decode produced no pixel bytes.');
      }
      var nontransparent = 0;
      final artworkColours = <int>{};
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        if (pixels.getUint8(i + 3) == 0) continue;
        nontransparent++;
        artworkColours.add(pixels.getUint32(i));
      }
      expect(nontransparent, greaterThan(0), reason: 'Logo artwork is empty.');
      expect(artworkColours.length, greaterThan(1));
      return <String, Object?>{
        'asset': _logoAsset,
        'asset_sha256': sha256
            .convert(
              assetBytes.buffer.asUint8List(
                assetBytes.offsetInBytes,
                assetBytes.lengthInBytes,
              ),
            )
            .toString(),
        'asset_bytes': assetBytes.lengthInBytes,
        'decoded_width': decoded.image.width,
        'decoded_height': decoded.image.height,
        'decoded_nontransparent_pixels': nontransparent,
        'decoded_artwork_colours': artworkColours.length,
        'actual_production_asset': true,
        'capture_only_preload': true,
        'replacement_pixels': false,
      };
    } finally {
      stream.removeListener(listener);
      decoded?.dispose();
    }
  });
  if (record == null) throw StateError('Logo preload did not complete.');
  _logoDecodeProvenance = record;
}

/// Verify the mounted logo's RenderImage and the painted pixels from its real
/// ancestor layer. A decoded cache entry alone must not pass a blank emblem.
/// Only logos in the captured viewport are checked; hidden/offscreen logos do
/// not establish a painted-identity claim.
Future<List<Map<String, Object?>>> verifyDesignCaptureLogoPaints(
  WidgetTester tester, {
  required String capture,
  bool requireVisibleLogo = false,
}) async {
  // Asset decoding has an explicit readiness check. Flush its actual paint,
  // without waiting for unrelated indefinite progress animations to stop.
  await tester.pump();
  final logos = find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == _logoAsset,
  );
  final records = <Map<String, Object?>>[];
  for (final element in logos.evaluate()) {
    final rawImage = find.descendant(
      of: find.byElementPredicate((candidate) => identical(candidate, element)),
      matching: find.byType(RawImage),
    );
    expect(rawImage, findsOneWidget, reason: 'The real logo needs a RawImage.');
    final render = tester.renderObject<RenderImage>(rawImage);
    expect(render.image, isNotNull, reason: 'The mounted logo is undecoded.');
    expect(render.image!.width, greaterThan(0));
    expect(render.image!.height, greaterThan(0));
    expect(render.size.isEmpty, isFalse);
    RenderObject boundary = render;
    while (!boundary.isRepaintBoundary) {
      boundary = boundary.parent!;
    }
    expect(boundary.debugNeedsPaint, isFalse);
    final bounds = Rect.fromPoints(
      render.localToGlobal(render.paintBounds.topLeft, ancestor: boundary),
      render.localToGlobal(render.paintBounds.bottomRight, ancestor: boundary),
    ).shift(-boundary.paintBounds.topLeft);
    final viewport = Offset.zero & boundary.paintBounds.size;
    final visible = bounds.intersect(viewport);
    if (visible.isEmpty) continue;
    final paintRecord = await tester.runAsync(() async {
      final frame = await captureImage(
        element,
      ).timeout(const Duration(seconds: 30));
      try {
        final pixels = await frame
            .toByteData(format: ui.ImageByteFormat.rawRgba)
            .timeout(const Duration(seconds: 30));
        if (pixels == null) {
          throw StateError('Logo frame has no painted bytes.');
        }
        final left = visible.left.floor().clamp(0, frame.width).toInt();
        final top = visible.top.floor().clamp(0, frame.height).toInt();
        final right = visible.right.ceil().clamp(0, frame.width).toInt();
        final bottom = visible.bottom.ceil().clamp(0, frame.height).toInt();
        final paintedColours = <int>{};
        for (var y = top; y < bottom; y++) {
          for (var x = left; x < right; x++) {
            paintedColours.add(pixels.getUint32((y * frame.width + x) * 4));
          }
        }
        expect(
          paintedColours.length,
          greaterThan(1),
          reason: 'The actual logo region painted a uniform blank area.',
        );
        return <String, Object?>{
          'capture': capture,
          'asset': _logoAsset,
          'asset_sha256': _logoDecodeProvenance?['asset_sha256'],
          'render_image_width': render.image!.width,
          'render_image_height': render.image!.height,
          'visible_rect': {
            'left': visible.left,
            'top': visible.top,
            'width': visible.width,
            'height': visible.height,
          },
          'painted_pixels_checked': (right - left) * (bottom - top),
          'painted_colours': paintedColours.length,
          'decoded_and_painted': true,
          'replacement_pixels': false,
          'installed_identity_verified': false,
        };
      } finally {
        frame.dispose();
      }
    });
    if (paintRecord == null) {
      throw StateError('Logo paint check did not complete.');
    }
    records.add(paintRecord);
  }
  if (requireVisibleLogo) {
    expect(
      records,
      isNotEmpty,
      reason: 'This desktop frame must paint its logo.',
    );
  }
  _logoPaintProvenance.addAll(records);
  return records;
}
