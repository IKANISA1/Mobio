import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_methods_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    PaymentDiscoveryFixture? service,
    String language = 'en',
    bool clock24 = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (service != null)
            paymentDiscoveryServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...rwPlatformLocalizationDelegates,
            ...AppLocalizations.localizationsDelegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: clock24),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dismissal in ['Close', 'scrim', 'Back', 'Escape', 'drag']) {
    testWidgets(
      'sharing $dismissal restores trigger without changing methods',
      (tester) async {
        final service = PaymentDiscoveryFixture();
        await mount(tester, const PaymentMethodsScreen(), service: service);
        final trigger = find.widgetWithText(TextButton, 'View as payer');
        final triggerFocus = tester.widget<TextButton>(trigger).focusNode!;
        triggerFocus.requestFocus();
        await tester.pump();
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        final close = find.byTooltip('Close');
        expect(close, findsOneWidget);
        if (dismissal == 'Close') {
          await tester.tap(close);
        } else if (dismissal == 'scrim') {
          await tester.tapAt(const Offset(4, 100));
        } else if (dismissal == 'Back') {
          await tester.binding.handlePopRoute();
        } else if (dismissal == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.drag(close, const Offset(0, 650));
        }
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(triggerFocus.hasFocus, isTrue);
        expect(service.calls, ['workspace', 'sharing']);
        expect(find.text('My MoMo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('sharing grant continuation keeps the member field focusable', (
    tester,
  ) async {
    final service = PaymentDiscoveryFixture();
    await mount(tester, const PaymentMethodsScreen(), service: service);
    await tester.tap(find.widgetWithText(TextButton, 'View as payer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share with this account'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '123456');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '123456',
    );
    expect(service.calls, ['workspace', 'sharing']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'fr', 'rw']) {
    testWidgets(
      'activity time keeps year and device-local clock for $language',
      (tester) async {
        final local = DateTime(2026, 9, 8, 14);
        late String localLabel;
        late String utcLabel;
        await mount(
          tester,
          Builder(
            builder: (context) {
              localLabel = paymentDateTimeLabel(context, local);
              utcLabel = paymentDateTimeLabel(context, local.toUtc());
              return Text(localLabel);
            },
          ),
          language: language,
          clock24: true,
        );
        expect(localLabel, utcLabel);
        expect(localLabel, contains('2026'));
        expect(localLabel, contains('14:00'));
        expect(localLabel, isNot(contains('.000')));
        expect(localLabel, isNot(contains('2026-09-08')));
        if (language == 'fr') expect(localLabel, contains('sept.'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'equivalent ISO offsets cross midnight without changing activity',
    (tester) async {
      late String offsetLabel;
      late String utcLabel;
      await mount(
        tester,
        Builder(
          builder: (context) {
            offsetLabel = paymentDateTimeLabel(
              context,
              DateTime.parse('2026-09-08T23:30:00-03:00'),
            );
            utcLabel = paymentDateTimeLabel(
              context,
              DateTime.parse('2026-09-09T02:30:00Z'),
            );
            return Text(offsetLabel);
          },
        ),
      );
      expect(offsetLabel, utcLabel);
      expect(offsetLabel, contains('2026'));
      expect(offsetLabel, isNot(contains('23:30:00')));
    },
  );

  testWidgets('activity clock follows the English 12-hour preference', (
    tester,
  ) async {
    late String label;
    await mount(
      tester,
      Builder(
        builder: (context) {
          label = paymentDateTimeLabel(context, DateTime(2026, 9, 8, 14));
          return Text(label);
        },
      ),
    );
    expect(label, contains('2:00 PM'));
  });
}
