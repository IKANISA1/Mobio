import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_library_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

class _Gateway extends PaymentDiscoveryFixture {
  bool secondMethod = false;
  Completer<Map<String, dynamic>>? workspaceReply, createReply;

  @override
  Map<String, dynamic> get workspace {
    final result = super.workspace;
    if (secondMethod) {
      result['methods'] = [
        source.toJson(),
        {...source.toJson(), 'id': 'second', 'label': 'Other MoMo'},
      ];
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data) {
    final pending = action == 'workspace'
        ? workspaceReply
        : action == 'create_link'
        ? createReply
        : null;
    if (pending != null) {
      calls.add(action);
      return pending.future;
    }
    return super.call(action, data);
  }
}

void main() {
  final copy = lookupAppLocalizations(const Locale('en'));

  Future<void> mount(
    WidgetTester tester,
    _Gateway gateway, {
    Map<String, dynamic>? template,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentDiscoveryServiceProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: PaymentRequestEditor(template: template),
        ),
      ),
    );
    await tester.pump();
  }

  PaymentAction create(WidgetTester tester) => tester.widget<PaymentAction>(
    find.widgetWithText(PaymentAction, copy.bpCreateRequest),
  );

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  testWidgets('Create follows label, method and amount validity reactively', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final gateway = _Gateway();
      await mount(tester, gateway);
      expect(create(tester).onPressed, isNull);
      final createSemantics = find
          .ancestor(
            of: find.widgetWithText(PaymentAction, copy.bpCreateRequest),
            matching: find.byType(MergeSemantics),
          )
          .first;
      final guidance = tester.getSemantics(createSemantics).getSemanticsData();
      expect(guidance.label, copy.bpCreateRequest);
      expect(guidance.hint, contains(copy.bpLabel));
      expect(guidance.hint, contains(copy.bpMethods));
      expect(guidance.hint, contains(copy.bpWholeAmount));

      await tester.enterText(field(copy.bpLabel), 'Lunch');
      await tester.pump();
      expect(create(tester).onPressed, isNull);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'My MoMo'));
      await tester.pump();
      expect(create(tester).onPressed, isNull);
      await tester.enterText(field(copy.bpAmount), '1000');
      await tester.pump();
      expect(create(tester).onPressed, isNotNull);
      expect(
        tester.getSemantics(createSemantics).getSemanticsData().hint,
        isEmpty,
      );

      for (final invalid in ['0', '10000001', '']) {
        await tester.enterText(field(copy.bpAmount), invalid);
        await tester.pump();
        expect(create(tester).onPressed, isNull);
      }
      await tester.enterText(field(copy.bpAmount), '10000000');
      await tester.pump();
      expect(create(tester).onPressed, isNotNull);
      await tester.enterText(field(copy.bpLabel), '   ');
      await tester.pump();
      expect(create(tester).onPressed, isNull);
      await tester.enterText(field(copy.bpLabel), 'Lunch');
      await tester.pump();
      expect(create(tester).onPressed, isNotNull);

      await tester.ensureVisible(
        find.widgetWithText(CheckboxListTile, 'My MoMo'),
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'My MoMo'));
      await tester.pump();
      expect(create(tester).onPressed, isNull);
      expect(gateway.calls, ['workspace']);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('payer-entered amount keeps the existing amount exemption', (
    tester,
  ) async {
    final gateway = _Gateway();
    await mount(
      tester,
      gateway,
      template: {...gateway.link, 'amount_rwf': null},
    );
    expect(create(tester).onPressed, isNotNull);
    expect(field(copy.bpAmount), findsNothing);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(create(tester).onPressed, isNull);
    expect(field(copy.bpAmount), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(create(tester).onPressed, isNotNull);
    expect(gateway.calls, ['workspace']);
    expect(tester.takeException(), isNull);
  });

  for (final scope in ['profile', 'method']) {
    testWidgets('$scope keeps its existing receiving-method cardinality', (
      tester,
    ) async {
      final gateway = _Gateway()..secondMethod = true;
      await mount(
        tester,
        gateway,
        template: {
          ...gateway.link,
          'scope': scope,
          'method_ids': ['source', 'second'],
          'amount_rwf': null,
        },
      );
      expect(create(tester).onPressed, scope == 'profile' ? isNotNull : isNull);
      expect(field(copy.bpAmount), findsNothing);
      if (scope == 'method') {
        await tester.tap(find.widgetWithText(CheckboxListTile, 'My MoMo'));
        await tester.pump();
        expect(create(tester).onPressed, isNull);
        await tester.tap(find.widgetWithText(CheckboxListTile, 'My MoMo'));
        await tester.pump();
        expect(create(tester).onPressed, isNotNull);
      }
      expect(gateway.calls, ['workspace']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('busy and stale Create retain submit-time and account guards', (
    tester,
  ) async {
    final gateway = _Gateway()
      ..workspaceReply = Completer()
      ..createReply = Completer();
    await mount(tester, gateway, template: gateway.link);
    expect(create(tester).onPressed, isNull);
    gateway.workspaceReply!.complete(gateway.workspace);
    await tester.pumpAndSettle();
    final retained = create(tester).onPressed!;

    await tester.enterText(field(copy.bpLabel), '   ');
    await tester.pump();
    expect(create(tester).onPressed, isNull);
    retained();
    await tester.pump();
    expect(gateway.calls, ['workspace']);
    expect(find.text(copy.bpCheckFields), findsOneWidget);

    await tester.enterText(field(copy.bpLabel), 'Current request');
    await tester.pump();
    create(tester).onPressed!();
    retained();
    await tester.pump();
    expect(create(tester).onPressed, isNull);
    expect(gateway.calls, ['workspace', 'create_link']);

    gateway.generation++;
    AccountContext.changes.value++;
    await tester.pump();
    retained();
    gateway.createReply!.complete(gateway.link);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PaymentAction), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(gateway.calls, ['workspace', 'create_link']);
    expect(tester.takeException(), isNull);
  });
}
