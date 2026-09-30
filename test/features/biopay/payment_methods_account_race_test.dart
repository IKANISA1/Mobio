import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_methods_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    _HeldGateway service,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentDiscoveryServiceProvider.overrideWithValue(service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: screen),
      ),
    );
    await tester.pump();
  }

  void replaceSession(_HeldGateway service) {
    service.generation++;
    AccountContext.changes.value++;
  }

  VoidCallback callback(WidgetTester tester, String action) {
    if (action == 'add' || action == 'refresh') {
      return tester
          .widgetList<PaymentAction>(find.byType(PaymentAction))
          .singleWhere(
            (widget) =>
                widget.label ==
                (action == 'add' ? 'Add payment method' : 'Refresh details'),
          )
          .onPressed!;
    }
    if (action == 'edit') {
      return tester
          .widget<ListTile>(
            find
                .ancestor(
                  of: find.text('My MoMo'),
                  matching: find.byType(ListTile),
                )
                .first,
          )
          .onTap!;
    }
    return tester
        .widget<TextButton>(
          find
              .ancestor(
                of: find.text('View as payer'),
                matching: find.byType(TextButton),
              )
              .first,
        )
        .onPressed!;
  }

  for (final action in ['refresh', 'add', 'edit', 'sharing']) {
    testWidgets(
      'retained methods $action cannot capture a replacement session',
      (tester) async {
        final service = _RetainedGateway(failWorkspace: action == 'refresh');
        await mount(tester, const PaymentMethodsScreen(), service);
        await tester.pumpAndSettle();
        final retained = callback(tester, action);
        service.failWorkspace = false;
        replaceSession(service);
        await tester.pumpAndSettle();
        final callsBeforeOldAction = List<String>.from(service.calls);
        retained();
        await tester.pumpAndSettle();
        expect(service.calls, callsBeforeOldAction);
        expect(find.byType(PaymentMethodEditor), findsNothing);
        expect(find.text('Share with this account'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('current methods $action remains usable', (tester) async {
      final service = _RetainedGateway(failWorkspace: action == 'refresh');
      await mount(tester, const PaymentMethodsScreen(), service);
      await tester.pumpAndSettle();
      final retained = callback(tester, action);
      service.failWorkspace = false;
      final workspaceCalls = service.calls
          .where((item) => item == 'workspace')
          .length;
      retained();
      await tester.pumpAndSettle();
      if (action == 'refresh') {
        expect(
          service.calls.where((item) => item == 'workspace'),
          hasLength(workspaceCalls + 1),
        );
        expect(find.text('My MoMo'), findsOneWidget);
      } else if (action == 'sharing') {
        expect(service.calls.where((item) => item == 'sharing'), hasLength(1));
        expect(find.text('Share with this account'), findsOneWidget);
      } else {
        expect(find.byType(PaymentMethodEditor), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('same-owner session replacement discards an old methods reply', (
    tester,
  ) async {
    final service = _HeldGateway('workspace');
    await mount(tester, const PaymentMethodsScreen(), service);
    final oldWorkspace = service.workspace;
    replaceSession(service);
    await tester.pumpAndSettle();
    expect(find.text('My MoMo'), findsNothing);
    service.pending.complete(oldWorkspace);
    await tester.pumpAndSettle();
    expect(find.text('My MoMo'), findsNothing);
    expect(service.calls.where((call) => call == 'workspace'), hasLength(2));
  });

  testWidgets('late sharing reply cannot open a modal for another session', (
    tester,
  ) async {
    final service = _HeldGateway('sharing');
    await mount(tester, const PaymentMethodsScreen(), service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View as payer'));
    await tester.pump();
    replaceSession(service);
    service.pending.complete({'grants': [], 'links': []});
    await tester.pumpAndSettle();
    expect(find.text('Share with this account'), findsNothing);
    expect(find.text('My MoMo'), findsNothing);
  });

  testWidgets(
    'account replacement closes an open grant dialog without granting',
    (tester) async {
      final service = _HeldGateway(null);
      await mount(tester, const PaymentMethodsScreen(), service);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View as payer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with this account'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      replaceSession(service);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.calls, isNot(contains('grant')));
      expect(find.text('My MoMo'), findsNothing);
    },
  );

  testWidgets(
    'late method save cannot navigate or expose the old account form',
    (tester) async {
      final service = _HeldGateway('save_method');
      await mount(tester, PaymentMethodEditor(method: service.source), service);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        service.calls.where((call) => call == 'save_method'),
        hasLength(1),
      );
      replaceSession(service);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(
        tester.widget<PaymentAction>(find.byType(PaymentAction)).onPressed,
        isNull,
      );
      service.pending.complete(service.source.toJson());
      await tester.pumpAndSettle();
      expect(find.byType(PaymentMethodEditor), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        service.calls.where((call) => call == 'save_method'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _HeldGateway extends PaymentDiscoveryFixture {
  _HeldGateway(this.heldAction);
  final String? heldAction;
  final pending = Completer<Map<String, dynamic>>();
  bool held = false;

  @override
  Map<String, dynamic> get workspace => {
    ...super.workspace,
    'methods': generation == 0 ? [source.toJson()] : [],
  };

  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data) {
    if (action == heldAction && !held) {
      held = true;
      calls.add(action);
      return pending.future;
    }
    return super.call(action, data);
  }
}

class _RetainedGateway extends _HeldGateway {
  _RetainedGateway({required this.failWorkspace}) : super(null);
  bool failWorkspace;
  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data) {
    if (action == 'workspace' && failWorkspace) {
      calls.add(action);
      return Future<Map<String, dynamic>>.error(
        StateError('Unavailable fixture'),
      );
    }
    return super.call(action, data);
  }
}
