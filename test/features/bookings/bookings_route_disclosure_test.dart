import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/features/bookings/application/booking_services.dart';
import 'package:mobi_app/features/bookings/presentation/bookings_screen.dart';
import 'package:mobi_app/features/bookings/presentation/trip_details_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/mobi_tonal_card.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/ordinary_golden_fonts.dart';

/// Local widget navigation evidence only. This does not exercise production
/// GoRouter, OTP, backend authority, native rendering or reader acceptance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final fonts =
        manifest.singleWhere((entry) => entry['family'] == 'Inter')['fonts']
            as List<dynamic>;
    expect(
      fonts.map((font) => font['weight']),
      unorderedEquals([400, 500, 600, 700]),
    );
    final inter = FontLoader('Inter');
    for (final font in fonts) {
      inter.addFont(rootBundle.load(font['asset'] as String));
    }
    await inter.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons/Lucide')
          ..addFont(rootBundle.load('packages/lucide_icons/assets/lucide.ttf')))
        .load();
    await loadOrdinaryGoldenFallbackFonts();
  });

  for (final light in [true, false]) {
    for (final frame in [
      (size: const Size(390, 844), scale: 1.0),
      (size: const Size(320, 640), scale: 2.0),
    ]) {
      final theme = light ? 'Light' : 'Dark';
      testWidgets('local Mine and Nearby full route disclosure and Back $theme '
          '${frame.size.width.toInt()}px ${frame.scale}x', (tester) async {
        expect(SupabaseConfig.isLocalUiPreview, isTrue);
        final seeds = AppConstants.mockTrips;
        final originalObjects = List.of(seeds);
        final openedIds = <String>[];
        final forbiddenCalls = <String>[];
        var backs = 0;
        Never forbidden(String action) {
          forbiddenCalls.add(action);
          throw StateError('Local route disclosure reached $action');
        }

        const launcher = MethodChannel('plugins.flutter.io/url_launcher');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcher,
          (call) async => forbidden('external ${call.method}'),
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            launcher,
            null,
          ),
        );
        final semantics = tester.ensureSemantics();
        try {
          await tester.binding.setSurfaceSize(frame.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tripServiceProvider.overrideWith(
                  (_) => forbidden('TripService, including cancellation'),
                ),
                publicTransportServiceProvider.overrideWith(
                  (_) => forbidden('PublicTransportService'),
                ),
              ],
              child: MaterialApp(
                theme: ordinaryGoldenTheme(
                  light ? AppTheme.lightTheme : AppTheme.darkTheme,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(frame.scale),
                  ),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: BookingsScreen(
                      mode: 'passenger',
                      onModeChanged: (_) => forbidden('mode change'),
                      onSchedule: () => forbidden('schedule'),
                      onTripDetails: (id) {
                        openedIds.add(id);
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (detailContext) => TripDetailsScreen(
                              tripId: id,
                              onBack: () {
                                backs++;
                                Navigator.of(detailContext).pop();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final originalBookingsState = tester.state(
            find.byType(BookingsScreen),
          );

          for (final tab in [0, 1]) {
            final path = tab == 0 ? 'Mine p3' : 'Nearby t3';
            if (tab == 1) {
              await _showNearbyToggle(tester, path: path);
              await tester.tap(find.text('Nearby').hitTestable());
              await tester.pumpAndSettle();
            }
            expect(find.byType(MobiToggle), findsOneWidget, reason: path);
            expect(
              tester.widget<MobiToggle>(find.byType(MobiToggle)).selectedIndex,
              tab,
              reason: '$path before opening details',
            );
            final role = tab == 0 ? 'passenger' : 'driver';
            final trip = seeds.where((trip) => trip.role == role).elementAt(2);
            expect(trip.id, tab == 0 ? 'p3' : 't3');
            const route = 'Hotel Rwanda → Kigali Convention Center';
            expect('${trip.origin} → ${trip.destination}', route);

            final target = await _showRouteCard(tester, route, path: path);
            expect(
              tester.getSemantics(find.text(route)).label,
              contains(route),
            );
            expectOrdinaryGoldenGlyphFallbacks(tester);
            final scrollable = _bookingsScrollable(tester);
            final position = scrollable.position;
            final offset = position.pixels;

            // Tap card padding, away from the title and nested Cancel control.
            await tester.tapAt(target.point);
            await tester.pumpAndSettle();
            expect(openedIds.last, trip.id, reason: '$path card navigation');
            expect(find.byType(TripDetailsScreen), findsOneWidget);
            expect(
              tester
                  .widget<TripDetailsScreen>(find.byType(TripDetailsScreen))
                  .tripId,
              trip.id,
            );
            final heading = find.descendant(
              of: find.byType(TripDetailsScreen),
              matching: find.text(route),
            );
            expect(heading, findsOneWidget);
            expect(tester.getSemantics(heading).label, contains(route));
            expect(find.text(trip.origin), findsOneWidget);
            final destination = find.text(trip.destination);
            expect(destination, findsOneWidget);
            expect(
              tester.getSemantics(destination).label,
              contains(trip.destination),
            );
            _expectWholeText(tester, heading, route);
            _expectWholeText(tester, destination, trip.destination);
            expectOrdinaryGoldenGlyphFallbacks(tester);
            await _expectChatVisibleThroughBodyDrag(tester, path: path);
            expect(find.text('Cancel trip?'), findsNothing);
            expect(forbiddenCalls, isEmpty);
            expect(tester.takeException(), isNull);

            await tester.tap(find.bySemanticsLabel('Back'));
            await tester.pumpAndSettle();
            expect(find.byType(TripDetailsScreen), findsNothing);
            expect(
              tester.state(find.byType(BookingsScreen)),
              same(originalBookingsState),
              reason: '$path Back must preserve Bookings state',
            );
            expect(
              _bookingsScrollable(tester).position,
              same(position),
              reason: '$path Back must preserve the scroll position object',
            );
            expect(
              position.pixels,
              closeTo(offset, 0.01),
              reason: '$path Back must preserve the actual list offset',
            );
            expect(
              _hitCardAt(tester, target.card, target.point),
              findsOneWidget,
              reason: '$path Back must restore the card padding target',
            );
            // Check the restored view before a user gesture reveals the lazy
            // header, which can be unmounted at the preserved list offset.
            if (find.byType(MobiToggle).evaluate().isEmpty) {
              await _showNearbyToggle(tester, path: path);
            }
            expect(find.byType(MobiToggle), findsOneWidget, reason: path);
            expect(
              tester.widget<MobiToggle>(find.byType(MobiToggle)).selectedIndex,
              tab,
              reason: '$path Back must preserve the selected tab',
            );
            expect(forbiddenCalls, isEmpty);
            expect(tester.takeException(), isNull);
          }
          expect(openedIds, ['p3', 't3']);
          expect(backs, 2);
          expect(seeds.length, originalObjects.length);
          for (var index = 0; index < seeds.length; index++) {
            expect(seeds[index], same(originalObjects[index]));
          }
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      });
    }
  }
}

ScrollableState _bookingsScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(BookingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> _showNearbyToggle(
  WidgetTester tester, {
  required String path,
}) async {
  for (var step = 0; step < 16; step++) {
    if (find.text('Nearby').hitTestable().evaluate().isNotEmpty) return;
    await _dragBookingsBody(tester, 240);
  }
  fail('$path: Nearby must remain reachable through an actual list drag.');
}

Future<void> _dragBookingsBody(WidgetTester tester, double distance) async {
  final viewport = tester.getRect(find.byType(CustomScrollView));
  final start = Offset(
    viewport.left + 12,
    viewport.top + viewport.height * 0.7,
  );
  final scrollRender = _bookingsScrollable(tester).context.findRenderObject();
  expect(
    tester
        .hitTestOnBinding(start)
        .path
        .any((entry) => identical(entry.target, scrollRender)),
    isTrue,
    reason: 'Body-margin drag must hit the Bookings scrollable.',
  );
  await tester.dragFrom(start, Offset(0, distance));
  await tester.pumpAndSettle();
}

Finder _hitCardAt(WidgetTester tester, Finder card, Offset point) {
  final rect = tester.getRect(card);
  return card.hitTestable(
    at: FractionalOffset(
      (point.dx - rect.left) / rect.width,
      (point.dy - rect.top) / rect.height,
    ),
  );
}

Future<({Finder card, Offset point})> _showRouteCard(
  WidgetTester tester,
  String route, {
  required String path,
}) async {
  final view = find.byType(CustomScrollView);
  final trace = <String>[];
  for (var step = 0; step < 16; step++) {
    var drag = -tester.getSize(view).height * 0.35;
    final label = find.text(route);
    final viewport = tester.getRect(view);
    final position = _bookingsScrollable(tester).position;
    String geometry = 'label unmounted';
    if (label.evaluate().isNotEmpty) {
      final card = find
          .ancestor(of: label, matching: find.byType(MobiTonalCard))
          .first;
      final rect = tester.getRect(card);
      final labelRect = tester.getRect(label);
      final visibleLabel = labelRect.intersect(viewport.deflate(24));
      geometry = 'card $rect label $labelRect viewport $viewport';
      if (!visibleLabel.isEmpty) {
        final point = Offset(rect.left + 8, visibleLabel.center.dy);
        if (_hitCardAt(tester, card, point).evaluate().isNotEmpty) {
          return (card: card, point: point);
        }
      }
      if (labelRect.top < viewport.top + 24) {
        drag = viewport.top + 24 - labelRect.top;
      } else if (labelRect.bottom > viewport.bottom - 24) {
        drag = -(labelRect.bottom - viewport.bottom + 24);
      }
    }
    final before = position.pixels;
    await _dragBookingsBody(tester, drag);
    trace.add(
      '$step $geometry offset $before→${position.pixels} '
      'range ${position.minScrollExtent}..${position.maxScrollExtent}',
    );
  }
  fail(
    '$path: The long third route card must expose a hit-testable padding target. '
    '${trace.skip(trace.length > 4 ? trace.length - 4 : 0).join(' | ')}',
  );
}

Future<void> _expectChatVisibleThroughBodyDrag(
  WidgetTester tester, {
  required String path,
}) async {
  final details = find.byType(TripDetailsScreen);
  const noticeText =
      'Coordinate pick up, timing, luggage, and seats directly via chat.';
  final notice = find.descendant(of: details, matching: find.text(noticeText));
  expect(notice, findsOneWidget, reason: '$path full marketplace notice');
  // The pushed-page header has its own enlarged-title scroll view. The
  // marketplace notice identifies the actual Details body instead.
  final view = find.ancestor(
    of: notice,
    matching: find.byType(SingleChildScrollView),
  );
  expect(view, findsOneWidget, reason: '$path actual Details scroll body');
  _expectWholeText(tester, notice, noticeText);
  final chat = find.descendant(of: details, matching: find.text('Chat'));
  expect(chat, findsOneWidget, reason: '$path lower Chat control');
  final button = find
      .ancestor(of: chat, matching: find.byType(MobiButton))
      .first;
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: view, matching: find.byType(Scrollable)),
  );
  final trace = <String>[];
  for (var step = 0; step < 8; step++) {
    final viewport = tester.getRect(view);
    final rect = tester.getRect(button);
    if (rect.left >= viewport.left &&
        rect.right <= viewport.right &&
        rect.top >= viewport.top &&
        rect.bottom <= viewport.bottom &&
        button.hitTestable().evaluate().isNotEmpty) {
      expect(tester.getSemantics(chat).label, contains('Chat'), reason: path);
      _expectWholeText(tester, chat, 'Chat');
      return;
    }
    final start = Offset(
      viewport.left + 12,
      viewport.top + viewport.height * 0.7,
    );
    final scrollRender = scrollable.context.findRenderObject();
    expect(
      tester
          .hitTestOnBinding(start)
          .path
          .any((entry) => identical(entry.target, scrollRender)),
      isTrue,
      reason: '$path body-margin drag must hit the Details scrollable',
    );
    final distance = rect.top < viewport.top
        ? (viewport.top - rect.top + 16).clamp(24.0, viewport.height * 0.5)
        : -(rect.bottom - viewport.bottom + 16).clamp(
            24.0,
            viewport.height * 0.5,
          );
    final before = scrollable.position.pixels;
    await tester.dragFrom(start, Offset(0, distance.toDouble()));
    await tester.pumpAndSettle();
    trace.add(
      '$step Chat $rect viewport $viewport offset '
      '$before→${scrollable.position.pixels} range '
      '${scrollable.position.minScrollExtent}..'
      '${scrollable.position.maxScrollExtent}',
    );
  }
  fail(
    '$path: The whole Chat control must remain reachable through actual body '
    'drags without invoking it. '
    '${trace.skip(trace.length > 4 ? trace.length - 4 : 0).join(' | ')}',
  );
}

void _expectWholeText(WidgetTester tester, Finder text, String expectedText) {
  final richText = find.descendant(of: text, matching: find.byType(RichText));
  expect(richText, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  expect(paragraph.text.toPlainText(), expectedText);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.textSize.width, lessThanOrEqualTo(paragraph.size.width));
  expect(paragraph.textSize.height, lessThanOrEqualTo(paragraph.size.height));
  expect(paragraph.debugHasOverflowShader, isFalse);
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  try {
    expect(painter.didExceedMaxLines, isFalse);
    expect(painter.height, lessThanOrEqualTo(paragraph.size.height));
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: expectedText.length - 1,
          extentOffset: expectedText.length,
        ),
      ),
      isNotEmpty,
      reason:
          'The final character of "$expectedText" must remain in the painted layout.',
    );
  } finally {
    painter.dispose();
  }
}
