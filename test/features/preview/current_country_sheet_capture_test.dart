import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/shared/widgets/country_flag.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:mobi_shared_types/models/country.dart';

import '../../helpers/design_capture_fonts.dart';
import '../../helpers/ui_source_manifest.dart';

// Isolated production input/sheet fixtures. This file does not render a full
// Login route, use a native keyboard, or compare/modify historical baselines.
const _boundary = ValueKey('country-sheet-component-full-viewport');
const _viewport = Size(390, 844);
const _phone = '0788123456'; // Synthetic, local-only; never submitted.
const _closeLabel = 'Close country selector';

enum _SheetState { unfilteredFocus, nameSearch, isoDialFilter, insetLargeText }

Finder get _search => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'Search country or code',
);

Map<String, num> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Future<void> _settleCountryFlagPaints(WidgetTester tester) async {
  // This package API awaits actual vector decoding; pumpAndSettle alone can
  // leave asynchronous SVG placeholders in a falsely "settled" screenshot.
  await tester.runAsync(() => vg.waitForPendingDecodes());
  await tester.pumpAndSettle();
  final flags = tester
      .widgetList<CountryFlag>(find.byType(CountryFlag))
      .toList();
  expect(flags, isNotEmpty);
  for (final flag in flags) {
    final scope = find.byWidget(flag);
    expect(
      find.descendant(of: scope, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    // This fixture uses existing standard national flags. A retained emoji
    // here is the production loading/error fallback, not decoded SVG paint.
    expect(
      find.descendant(of: scope, matching: find.text(flag.flag)),
      findsNothing,
    );
  }
  expect(tester.takeException(), isNull);
}

class _CountryFixtureService implements CountryService {
  final _countries = Country.fallbackCountries
      .where((country) => country.id == 'RW')
      .toList();

  // WhatsAppInput merges these real model defaults into its production global
  // calling-code list. No custom country rows or private backend are supplied.
  @override
  Future<List<Country>> getCountries() async => _countries;
  @override
  Future<List<Country>> getAfricanCountries() async => _countries;
  @override
  Future<Country?> findById(String id) async =>
      _countries.where((country) => country.id == id).firstOrNull;
  @override
  Country? findByDialingCodeSync(String code) =>
      _countries.where((country) => country.dialingCode == code).firstOrNull;
  @override
  Future<Country> findByDialingCode(String code) async =>
      findByDialingCodeSync(code) ?? _countries.first;
  @override
  String currencyForCodeSync(String code) =>
      findByDialingCodeSync(code)?.currency ?? 'RWF';
  @override
  Future<String> currencyForCode(String code) async =>
      currencyForCodeSync(code);
  @override
  String momoBrandForCodeSync(String code) =>
      findByDialingCodeSync(code)?.momoBrand ?? 'MoMo';
  @override
  String buildUssdForNumber(String code, String phone, [String? amount]) =>
      findByDialingCodeSync(code)?.buildUssdForNumber(phone, amount) ?? '';
  @override
  String buildUssdForCode(String countryCode, String code, [String? amount]) =>
      findByDialingCodeSync(countryCode)?.buildUssdForCode(code, amount) ?? '';
  @override
  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) => rawValue.replaceAll(RegExp(r'[^0-9]'), '');
  @override
  Future<void> warmCache() async {}
  @override
  void clearCache() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory(
    Platform.environment['MOBIO_CURRENT_COUNTRY_SHEET_CAPTURE_DIR'] ??
        'build/qa/design-review/current-country-sheet-anatomy-20261001',
  );
  final captures = <Map<String, dynamic>>[];
  late Map<String, dynamic> sourceBefore;
  late UiSourceManifest sourceBinding;

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await directory.create(recursive: true);
    sourceBinding = UiSourceManifest.fromEnvironment();
    sourceBefore = sourceBinding.fingerprint();
    await loadDesignCaptureFonts();
  });

  tearDownAll(() async {
    final sourceAfter = sourceBinding.fingerprint(requireManifestHashes: false);
    final unchanged =
        sourceBefore['source_sha256'] == sourceAfter['source_sha256'];
    final manifest = {
      'schema_version': 1,
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'source_sha256': sourceBefore['source_sha256'],
      'source_before': sourceBefore,
      'source_after': sourceAfter,
      'source_unchanged_during_capture': unchanged,
      'harness':
          'test/features/preview/current_country_sheet_capture_test.dart',
      'harness_sha256': sha256
          .convert(
            await File(
              'test/features/preview/current_country_sheet_capture_test.dart',
            ).readAsBytes(),
          )
          .toString(),
      'capture_method': 'RepaintBoundary.toImage at DPR1; file export only',
      'capture_kind': 'isolated production component widget fixture',
      'golden_baselines_read_or_updated': false,
      'visual_comparison_performed': false,
      'visual_acceptance': 'unverified',
      'accepted_complete_route_state_obligations': 0,
      'full_login_route_rendered': false,
      'actual_android_keyboard_rendered': false,
      'backend_or_otp_calls': false,
      'capture_font_provenance': designCaptureFontProvenance,
      'national_content_manifest': {
        'path': 'assets/country_flags/manifest.json',
        'sha256': sha256
            .convert(
              await File('assets/country_flags/manifest.json').readAsBytes(),
            )
            .toString(),
        'classification':
            'national-symbol content only; not a design authority',
      },
      'font_helper_sha256': sha256
          .convert(
            await File('test/helpers/design_capture_fonts.dart').readAsBytes(),
          )
          .toString(),
      'limitations': [
        'Production WhatsAppInput opens its actual MobiBottomSheet inside an authentication-family MaterialApp test host.',
        'The full Login screen, bootstrap, router, guards, Supabase, WhatsApp/OTP/provider outcomes and installed lifecycle are bypassed.',
        'CountryService uses the real RW fallback model; production global ISO/name/dial rows are retained and merged by WhatsAppInput.',
        'Phone content is synthetic and local-only. Country selection checks callbacks, not network authorization.',
        'The compact viewport is 390x844 logical pixels at DPR1 with zero safe-area padding and English.',
        'Insets of 300 logical pixels and text 1.3 are test MediaQuery inputs, not a real OS keyboard or platform large-text setting.',
        'A blank host region below the inset is not Android IME pixel proof.',
        ...designCaptureFontLimitations,
        'Only declared visible specimen states are exported. Offscreen rows, other widths/themes/locales and source-native motion remain unverified.',
        'The export harness contains no Revolut image comparator and cannot accept visual fidelity.',
      ],
      'capture_count': captures.length,
      'captures': captures,
    };
    await File('${directory.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
    expect(unchanged, isTrue, reason: 'UI source changed during capture.');
    expect(
      captures.length,
      8,
      reason: 'All eight declared specimens are required.',
    );
  });

  for (final brightness in Brightness.values) {
    for (final state in _SheetState.values) {
      testWidgets('country sheet ${brightness.name} ${state.name}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.binding.setSurfaceSize(_viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = _viewport;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);

          final largeText = state == _SheetState.insetLargeText;
          final textScale = largeText ? 1.3 : 1.0;
          final inset = largeText ? 300.0 : 0.0;
          var phone = '';
          var countryCode = '+250';
          var countryChanges = 0;
          var phoneChanges = 0;
          final base = brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme;
          final authentication = MobiFamilyPalette.resolve(
            MobiVisualFamily.authentication,
            brightness,
          ).apply(base);

          await tester.pumpWidget(
            RepaintBoundary(
              key: _boundary,
              child: ProviderScope(
                overrides: [
                  countryServiceProvider.overrideWithValue(
                    _CountryFixtureService(),
                  ),
                ],
                child: MaterialApp(
                  theme: designCaptureTheme(authentication),
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 120, 18, 18),
                        child: StatefulBuilder(
                          builder: (context, setState) => WhatsAppInput(
                            value: phone,
                            onChanged: (value) => setState(() {
                              phone = value;
                              phoneChanges++;
                            }),
                            countryCode: countryCode,
                            onCountryCodeChanged: (value) => setState(() {
                              countryCode = value;
                              countryChanges++;
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await settleDesignCaptureFonts(tester);
          expect(find.text('RW'), findsOneWidget);
          final phoneField = find.descendant(
            of: find.byType(WhatsAppInput),
            matching: find.byType(TextField),
          );
          expect(
            tester.widget<TextField>(phoneField).keyboardType,
            TextInputType.phone,
          );
          await tester.enterText(phoneField, '0788 123 456');
          await tester.pumpAndSettle();
          expect(phone, _phone);
          expect(phoneChanges, 1);
          expect(find.text(_phone), findsOneWidget);

          // Set only an explicit simulated view inset; no IME screenshot or plugin.
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.tap(find.text('RW'));
          await tester.pumpAndSettle();
          await settleDesignCaptureFonts(tester);
          expect(_search, findsOneWidget);
          final editable = find.descendant(
            of: _search,
            matching: find.byType(EditableText),
          );
          expect(
            tester.widget<EditableText>(editable).focusNode.hasFocus,
            isTrue,
          );

          final actions = <String>[
            'RW default shown; real phone TextField normalizes input to $_phone without submission.',
            'Actual country picker opened; search autofocus verified.',
          ];
          var query = '';
          if (state == _SheetState.nameSearch) {
            query = 'rwanda';
            await tester.enterText(_search, query);
            await tester.pumpAndSettle();
            expect(find.byType(ListTile), findsOneWidget);
            expect(find.widgetWithText(ListTile, 'Rwanda'), findsOneWidget);
            expect(find.text('+250'), findsWidgets);
            actions.add('Name search yields the real Rwanda row and +250.');
          } else if (state == _SheetState.isoDialFilter) {
            await tester.enterText(_search, 'ke');
            await tester.pumpAndSettle();
            expect(find.widgetWithText(ListTile, 'Kenya'), findsOneWidget);
            query = '+254';
            await tester.enterText(_search, query);
            await tester.pumpAndSettle();
            expect(find.byType(ListTile), findsOneWidget);
            expect(find.widgetWithText(ListTile, 'Kenya'), findsOneWidget);
            actions.add(
              'ISO query ke and then dial-code query +254 both resolve the real Kenya row.',
            );
          } else {
            expect(
              find.widgetWithText(ListTile, 'Afghanistan'),
              findsOneWidget,
            );
            actions.add(
              'Unfiltered production country list begins with Afghanistan.',
            );
          }

          await _settleCountryFlagPaints(tester);

          final title = find.text('Country code');
          final close = find.byTooltip(_closeLabel);
          expect(title, findsOneWidget);
          expect(close, findsOneWidget);
          final closeData = tester.getSemantics(close).getSemanticsData();
          expect(closeData.label, contains(_closeLabel));
          expect(closeData.hasAction(ui.SemanticsAction.tap), isTrue);
          final frame = Offset.zero & _viewport;
          expect(frame.contains(tester.getRect(close).center), isTrue);
          expect(frame.contains(tester.getRect(title).bottomRight), isTrue);
          final titleSize = tester.widget<Text>(title).style!.fontSize!;
          final firstTile = find.byType(ListTile).first;
          final rowText = tester.widget<ListTile>(firstTile).title! as Text;
          expect(titleSize, greaterThan(rowText.style!.fontSize! * 1.5));

          final list = find.byType(CustomScrollView);
          expect(list, findsOneWidget);
          final decorations = tester
              .widgetList<DecoratedSliver>(
                find.descendant(
                  of: list,
                  matching: find.byType(DecoratedSliver),
                ),
              )
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .where((decoration) => decoration.borderRadius != null)
              .toList();
          final roundedColors = decorations
              .map((decoration) => decoration.color)
              .whereType<Color>()
              .toList();
          expect(roundedColors, isNotEmpty);
          if (brightness == Brightness.dark) {
            expect(roundedColors, contains(const Color(0xFF242527)));
          } else {
            expect(roundedColors, contains(const Color(0xFFF7F7F7)));
          }
          final sheetTheme = Theme.of(tester.element(_search));
          final ext = sheetTheme.extension<MobiThemeExtension>()!;
          final sheetBody = find
              .ancestor(
                of: title,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).color ==
                          ext.surfaceContainerLowest,
                ),
              )
              .first;
          final flag = find
              .descendant(of: firstTile, matching: find.byType(ClipOval))
              .first;
          final firstRow = tester.widget<ListTile>(firstTile);
          final isoText = firstRow.subtitle! as Text;
          expect(
            Theme.of(
              tester.element(find.byType(WhatsAppInput)),
            ).colorScheme.surface,
            authentication.colorScheme.surface,
          );
          expect(
            MediaQuery.viewInsetsOf(tester.element(_search)).bottom,
            inset,
          );
          expect(
            MediaQuery.textScalerOf(tester.element(_search)).scale(10),
            textScale * 10,
          );
          expect(countryChanges, 0);
          expect(tester.takeException(), isNull);
          actions.add(
            'Accessible Close is present; dominant title and rounded tonal list layer are visible.',
          );

          // Export one settled component specimen without a golden comparator.
          final render = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_boundary),
          );
          final bytes = await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data == null) throw StateError('PNG encoding failed.');
              return data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              );
            } finally {
              image.dispose();
            }
          });
          expect(bytes, isNotNull);
          final pngBytes = bytes!;
          final pngHeader = ByteData.sublistView(pngBytes);
          expect(pngHeader.getUint32(16), 390);
          expect(pngHeader.getUint32(20), 844);
          final file = File(
            '${directory.path}/${state.name}_${brightness.name}_390x844.png',
          );
          await tester.runAsync(() => file.writeAsBytes(pngBytes, flush: true));
          final metadata = <String, dynamic>{
            'name': state.name,
            'widget_class': 'WhatsAppInput + MobiBottomSheet',
            'mapped_current_route': '/login country-selector component only',
            'full_login_route_rendered': false,
            'fixture_state':
                '${state.name}; search="$query"; synthetic phone retained; RW selected until cancellation.',
            'theme': brightness.name,
            'viewport': {'width': 390, 'height': 844},
            'device_pixel_ratio': 1,
            'text_scale': textScale,
            'simulated_keyboard_inset': inset,
            'actual_os_keyboard': false,
            'search_has_focus_at_capture': true,
            'svg_decoding_wait':
                'tester.runAsync(vg.waitForPendingDecodes), followed by pumpAndSettle',
            'visible_standard_flag_pictures': find
                .byType(CountryFlag)
                .evaluate()
                .length,
            'loading_or_error_emoji_placeholders_at_capture': 0,
            'country_callback_count_at_capture': countryChanges,
            'sheet_body_rect': _rect(tester.getRect(sheetBody)),
            'title_rect': _rect(tester.getRect(title)),
            'close_rect': _rect(tester.getRect(close)),
            'search_control_rect': _rect(tester.getRect(_search)),
            'row_list_rect': _rect(tester.getRect(list)),
            'first_country_row_rect': _rect(tester.getRect(firstTile)),
            'first_country_flag_rect': _rect(tester.getRect(flag)),
            'first_country_name_rect': _rect(
              tester.getRect(find.byWidget(rowText)),
            ),
            'first_country_iso_rect': _rect(
              tester.getRect(find.byWidget(isoText)),
            ),
            'first_country_dial_rect': _rect(
              tester.getRect(find.byWidget(firstRow.trailing!)),
            ),
            'geometry_units':
                'widget-test logical pixels; no native token claim',
            'resolved_sheet_body': _hex(ext.surfaceContainerLowest),
            'resolved_search_surface': _hex(ext.surfaceContainerLow),
            'rounded_ancestor_colors': roundedColors.map(_hex).toList(),
            'title_to_row_declared_font_size_ratio':
                titleSize / rowText.style!.fontSize!,
            'visible_state_checks': actions,
            'path': file.absolute.path,
            'bytes': pngBytes.length,
            'png_width': pngHeader.getUint32(16),
            'png_height': pngHeader.getUint32(20),
            'sha256': sha256.convert(pngBytes).toString(),
            'visual_comparison_performed': false,
            'visual_acceptance': 'unverified',
          };

          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(title, findsNothing);
          expect(countryCode, '+250');
          expect(countryChanges, 0);
          expect(phone, _phone);
          expect(find.text(_phone), findsOneWidget);

          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          await tester.tap(find.text('RW'));
          await tester.pumpAndSettle();
          await tester.enterText(_search, '+254');
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'Kenya'));
          await tester.pumpAndSettle();
          expect(title, findsNothing);
          expect(countryCode, '+254');
          expect(countryChanges, 1);
          expect(find.text('KE'), findsOneWidget);
          expect(phone, _phone);
          expect(phoneChanges, 1);
          expect(find.text(_phone), findsOneWidget);
          expect(tester.takeException(), isNull);
          metadata['post_capture_interaction_checks'] = [
            'Accessible Close cancels without country callback or phone mutation.',
            'Reopening and choosing real Kenya +254 closes the modal and emits exactly one callback.',
            'Phone input remains $_phone; no OTP/provider call.',
          ];
          captures.add(metadata);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
