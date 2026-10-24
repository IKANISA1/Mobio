import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';
import 'package:mobi_app/shared/widgets/country_flag.dart';

const _flagBoundary = ValueKey('painted-national-content');

Future<void> _settleFlagPaint(WidgetTester tester) async {
  await tester.runAsync(() => vg.waitForPendingDecodes());
  await tester.pumpAndSettle();
}

Future<ByteData> _paintedPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_flagBoundary),
  );
  expect(boundary.size, const Size(40, 40));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  return bytes!;
}

Color _pixel(ByteData bytes, int x, int y) {
  final offset = (y * 40 + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bundle delivers exact national content for every existing ISO',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/country_flags/manifest.json',
                ),
              )
              as Map<String, dynamic>;
      final files = (manifest['files'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final isoCodes = globalPhoneCountryCodes
          .map((country) => country.isoCode)
          .toSet();
      expect(files.map((file) => file['iso_code']).toSet(), isoCodes);
      expect(files.length, isoCodes.length);

      final bundled = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        bundled
            .listAssets()
            .where(
              (path) =>
                  path.startsWith('assets/country_flags/') &&
                  path.endsWith('.svg'),
            )
            .toSet(),
        files.map((file) => file['path']).toSet(),
      );
      for (final file in files) {
        expect(
          file['path'],
          'assets/country_flags/${(file['iso_code'] as String).toLowerCase()}.svg',
        );
        final data = await rootBundle.load(file['path'] as String);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        expect(bytes.length, file['bytes']);
        expect(sha256.convert(bytes).toString(), file['sha256']);
      }
      final license = manifest['license'] as Map<String, dynamic>;
      final data = await rootBundle.load(license['path'] as String);
      expect(
        sha256
            .convert(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            )
            .toString(),
        license['sha256'],
      );
    },
  );

  testWidgets(
    'a standard Rwanda flag paints filled circular national content',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: _flagBoundary,
              child: CountryFlag(isoCode: 'RW', flag: '🇷🇼'),
            ),
          ),
        ),
      );
      await _settleFlagPaint(tester);
      expect(find.text('🇷🇼'), findsNothing);
      final pixels = await _paintedPixels(tester);

      // These samples come from the bundled Rwanda national artwork, not UI
      // colour tokens. Filled cardinal edges distinguish a circle from a waving
      // rectangular emoji sitting inside an otherwise empty circular canvas.
      for (final point in [(20, 2), (2, 20), (37, 20), (20, 37)]) {
        expect(_pixel(pixels, point.$1, point.$2).a, greaterThan(0.98));
      }
      expect(_pixel(pixels, 0, 0).a, 0);
      expect(_pixel(pixels, 20, 5), const Color(0xFF338AF3));
      expect(_pixel(pixels, 20, 25), const Color(0xFFFFDA44));
      expect(_pixel(pixels, 20, 35), const Color(0xFF496E2D));
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in [
    (name: 'custom', iso: 'RW', flag: '🚌'),
    (name: 'mismatched regional', iso: 'RW', flag: '🇰🇪'),
    (name: 'unknown ISO', iso: 'XX', flag: '🏁'),
  ]) {
    testWidgets('${entry.name} content preserves its provided flag fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: CountryFlag(isoCode: entry.iso, flag: entry.flag),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.flag), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
