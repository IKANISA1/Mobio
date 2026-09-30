import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/presentation/widgets/privacy_health_card.dart';
import 'package:mobi_app/features/admin/presentation/widgets/push_delivery_health_card.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

Map<String, Object?> reply(bool privacy) => privacy
    ? {
        'protocol': 'mobio.privacy.health.v1',
        'counts': {'requested': 7},
        'intake_enabled': true,
        'processing_enabled': true,
        'automatic_erasure_implemented': false,
        'oldest_pending_seconds': 10,
        'retention_reviews_due': 0,
      }
    : {
        'enabled': true,
        'counts': {'queued': 7},
        'not_queued_24h': <String, int>{},
        'accepted_means': 'provider_accepted_not_device_delivered',
      };
void main() {
  for (final privacy in [true, false]) {
    final label = privacy ? 'privacy' : 'push';
    final tooltip = privacy
        ? 'Refresh privacy request health'
        : 'Refresh push delivery health';
    var generation = 0;
    var reads = 0;
    late Future<Object?> Function() load;
    AccountSnapshot capture() =>
        AccountSnapshot('same-owner', 'session-$generation', generation);
    Widget card() => privacy
        ? PrivacyHealthCard.test(
            captureAccount: capture,
            loadHealth: () => load(),
          )
        : PushDeliveryHealthCard.test(
            captureAccount: capture,
            loadHealth: () => load(),
          );
    Future<void> mount(WidgetTester tester) async {
      generation = 0;
      reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: card()),
        ),
      );
      await tester.pump();
    }

    void replace() {
      generation++;
      AccountContext.changes.value++;
    }

    testWidgets(
      '$label retained refresh cannot dispatch in same-owner new session',
      (tester) async {
        load = () async {
          reads++;
          return reply(privacy);
        };
        await mount(tester);
        await tester.pumpAndSettle();
        final retained = tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == tooltip,
              ),
            )
            .onPressed!;
        expect(reads, 1);
        replace();
        await tester.pumpAndSettle();
        retained();
        await tester.pumpAndSettle();
        expect(reads, 1);
        expect(find.text(privacy ? 'requested: 7' : 'Queued: 7'), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) => widget is IconButton && widget.tooltip == tooltip,
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );
    testWidgets('$label late private reply stays cleared after replacement', (
      tester,
    ) async {
      final pending = Completer<Object?>();
      load = () {
        reads++;
        return pending.future;
      };
      await mount(tester);
      replace();
      pending.complete(reply(privacy));
      await tester.pumpAndSettle();
      expect(find.text(privacy ? 'requested: 7' : 'Queued: 7'), findsNothing);
      expect(reads, 1);
    });
    testWidgets('$label current refresh reads and displays verified fixture', (
      tester,
    ) async {
      load = () async {
        reads++;
        return reply(privacy);
      };
      await mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text(privacy ? 'requested: 7' : 'Queued: 7'), findsOneWidget);
    });
  }
}
