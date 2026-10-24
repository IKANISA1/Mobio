import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_link_arrival_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

class _PreviewGateway extends PaymentDiscoveryFixture {
  _PreviewGateway(this.response);

  Future<Map<String, dynamic>> Function(String) response;
  final tokens = <String>[];

  @override
  Future<Map<String, dynamic>> previewLink(String token) {
    tokens.add(token);
    return response(token);
  }
}

Widget _app(_PreviewGateway gateway, {String token = 'request'}) =>
    ProviderScope(
      overrides: [paymentDiscoveryServiceProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: PaymentLinkArrivalScreen(token: token),
      ),
    );

void main() {
  final copy = lookupAppLocalizations(const Locale('en'));

  Future<void> mount(WidgetTester tester, _PreviewGateway gateway) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(gateway));
    await tester.pump();
  }

  testWidgets('failed preview can retry once and recover its actual request', (
    tester,
  ) async {
    final gateway = _PreviewGateway(
      (_) async => throw TimeoutException('Synthetic provider details'),
    );
    await mount(tester, gateway);
    expect(find.text(copy.errorGeneric), findsOneWidget);
    expect(find.text(copy.bpLinkUnavailable), findsNothing);
    expect(find.text('Synthetic provider details'), findsNothing);
    expect(find.text(copy.bpManual), findsOneWidget);
    expect(find.byTooltip(copy.bpBack), findsOneWidget);
    expect(find.text(copy.bpContinue), findsNothing);
    expect(find.text(copy.bpSignIn), findsNothing);

    final pending = Completer<Map<String, dynamic>>();
    gateway.response = (_) => pending.future;
    final retry = tester
        .widget<PaymentAction>(
          find.widgetWithText(PaymentAction, copy.tryAgain),
        )
        .onPressed!;
    await tester.tap(find.text(copy.tryAgain));
    // Even a retained callback cannot start a second in-flight read.
    retry();
    await tester.pump();
    expect(gateway.tokens, ['request', 'request']);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(copy.errorGeneric), findsNothing);
    expect(find.text(copy.tryAgain), findsNothing);
    expect(find.text(copy.bpContinue), findsNothing);

    pending.complete({'available': true, ...gateway.link});
    await tester.pumpAndSettle();
    expect(find.text('Lunch request'), findsOneWidget);
    expect(find.text('1000 RWF'), findsOneWidget);
    expect(find.text(copy.bpContinue), findsOneWidget);
    expect(find.byType(PaymentError), findsNothing);
    expect(find.text(copy.tryAgain), findsNothing);
    expect(gateway.tokens, ['request', 'request']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genuinely unavailable request keeps its privacy-safe recovery', (
    tester,
  ) async {
    final gateway = _PreviewGateway((_) async => {'available': false});
    await mount(tester, gateway);
    expect(find.text(copy.bpLinkUnavailable), findsOneWidget);
    expect(find.text(copy.errorGeneric), findsNothing);
    expect(find.text(copy.tryAgain), findsNothing);
    expect(find.text(copy.bpContinue), findsNothing);
    expect(find.text(copy.bpSignIn), findsNothing);
    expect(find.text(copy.bpManual), findsOneWidget);
    expect(find.byTooltip(copy.bpBack), findsOneWidget);
    expect(
      tester
          .widget<PaymentAction>(
            find.widgetWithText(PaymentAction, copy.bpManual),
          )
          .onPressed,
      isNotNull,
    );
    expect(gateway.tokens, ['request']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('token replacement clears prior content and ignores late reads', (
    tester,
  ) async {
    final request = PaymentDiscoveryFixture().link;
    final gateway = _PreviewGateway(
      (_) async => {'available': true, ...request, 'label': 'Original request'},
    );
    await mount(tester, gateway);
    expect(find.text('Original request'), findsOneWidget);

    final replaced = Completer<Map<String, dynamic>>();
    gateway.response = (_) => replaced.future;
    await tester.pumpWidget(_app(gateway, token: 'replaced'));
    await tester.pump();
    expect(find.text('Original request'), findsNothing);
    expect(find.text(copy.bpContinue), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gateway.response = (_) async => {
      'available': true,
      ...request,
      'label': 'Current request',
    };
    await tester.pumpWidget(_app(gateway, token: 'current'));
    await tester.pumpAndSettle();
    expect(find.text('Current request'), findsOneWidget);
    replaced.complete({'available': false});
    await tester.pumpAndSettle();
    expect(find.text('Current request'), findsOneWidget);
    expect(find.text(copy.bpContinue), findsOneWidget);
    expect(find.text(copy.bpLinkUnavailable), findsNothing);
    expect(gateway.tokens, ['request', 'replaced', 'current']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during a preview safely discards its late failure', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final gateway = _PreviewGateway((_) => pending.future);
    await mount(tester, gateway);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('Synthetic offline response'));
    await tester.pump();
    expect(gateway.tokens, ['request']);
    expect(tester.takeException(), isNull);
  });
}
