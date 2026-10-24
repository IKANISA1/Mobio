import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/home/presentation/home_screen.dart';
import 'package:mobi_app/features/home/presentation/widgets/scheduled_trip_card.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // Match the bundled product faces; the tester disables asset-font loading.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final fonts =
        manifest.singleWhere((entry) => entry['family'] == 'Inter')['fonts']
            as List<dynamic>;
    final inter = FontLoader('Inter');
    for (final font in fonts) {
      inter.addFont(rootBundle.load(font['asset'] as String));
    }
    await inter.load();
  });

  testWidgets('HomeScreen local preview fits narrow mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HomeScreen(
              mode: 'passenger',
              onModeChanged: (_) {},
              onChat: (_) {},
              onChatPerson: (_) {},
              onTripDetails: (_) {},
              onViewNearby: () {},
              onViewBookings: () {},
              onSchedule: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby'), findsWidgets);
    expect(find.text('Driver supply'), findsNothing);
    expect(find.text('Passenger demand'), findsNothing);
    expect(find.textContaining('Coordinate pick up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
      testWidgets('Home scheduled titles stay readable and complete at '
          '${brightness.name} ${width.toInt()}px ${scale}x text', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: brightness == Brightness.light
                  ? AppTheme.lightTheme
                  : AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: HomeScreen(
                  mode: 'passenger',
                  onModeChanged: (_) {},
                  onChat: (_) {},
                  onChatPerson: (_) {},
                  onTripDetails: (_) {},
                  onViewNearby: () {},
                  onViewBookings: () {},
                  onSchedule: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byType(ScheduledTripCard);
        expect(cards, findsNWidgets(3));
        for (var index = 0; index < 3; index++) {
          final card = cards.at(index);
          final trip = tester.widget<ScheduledTripCard>(card).trip;
          final title = find.descendant(
            of: card,
            matching: find.text('${trip.origin} → ${trip.destination}'),
          );
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(title);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.text.toPlainText(), contains(trip.destination));
          final foreground = (paragraph.text as TextSpan).style!.color!;
          final ink = tester.widget<Ink>(
            find.descendant(of: card, matching: find.byType(Ink)).first,
          );
          final background = (ink.decoration! as BoxDecoration).color!;
          final foregroundLuminance = foreground.computeLuminance();
          final backgroundLuminance = background.computeLuminance();
          final lighter = foregroundLuminance > backgroundLuminance
              ? foregroundLuminance
              : backgroundLuminance;
          final darker = foregroundLuminance < backgroundLuminance
              ? foregroundLuminance
              : backgroundLuminance;
          expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
          final badge = find.descendant(
            of: card,
            matching: find.byType(MobiStatusBadge),
          );
          final label = tester.renderObject<RenderParagraph>(
            find.descendant(of: badge, matching: find.text('Upcoming')),
          );
          final painter = TextPainter(
            text: label.text,
            textDirection: label.textDirection,
            textScaler: label.textScaler,
          );
          try {
            painter.layout(maxWidth: label.size.width);
            expect(
              painter.computeLineMetrics(),
              hasLength(1),
              reason: 'The status word must not split inside its capsule.',
            );
          } finally {
            painter.dispose();
          }
          final badgeBounds = tester.getRect(badge);
          final cardBounds = tester.getRect(card);
          expect(badgeBounds.left, greaterThanOrEqualTo(cardBounds.left));
          expect(badgeBounds.right, lessThanOrEqualTo(cardBounds.right));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
