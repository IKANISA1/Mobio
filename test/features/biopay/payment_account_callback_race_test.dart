import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_library_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

class _HeldGateway extends PaymentDiscoveryFixture {
  _HeldGateway(this.action);
  final String? action;
  final pending = Completer<Map<String, dynamic>>();
  final contactReply = Completer<Map<String, String>?>();
  bool held = false;
  @override
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> data) {
    if (action == this.action && !held) {
      held = true;
      calls.add(action);
      return pending.future;
    }
    return super.call(action, data);
  }

  @override
  Future<Map<String, String>?> pickPhone() => contactReply.future;
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child,
    _HeldGateway service,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentDiscoveryServiceProvider.overrideWithValue(service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: child),
      ),
    );
    await tester.pump();
  }

  void replace(_HeldGateway service) {
    service.generation++;
    AccountContext.changes.value++;
  }

  for (final screen in ['composer', 'library', 'request']) {
    testWidgets('$screen rejects old workspace after same-owner replacement', (
      tester,
    ) async {
      final service = _HeldGateway('workspace');
      final child = switch (screen) {
        'composer' => const PaymentComposerScreen(entry: '+250788000002'),
        'library' => const PaymentLibraryScreen(),
        _ => const PaymentRequestEditor(),
      };
      await mount(tester, child, service);
      replace(service);
      service.pending.complete(service.workspace);
      await tester.pumpAndSettle();
      expect(find.text('My MoMo'), findsNothing);
      expect(find.text('Lunch request'), findsNothing);
      expect(service.calls, ['workspace']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('old contact result cannot populate a replacement session', (
    tester,
  ) async {
    final service = _HeldGateway(null);
    await mount(tester, const PaymentComposerScreen(), service);
    await tester.pumpAndSettle();
    final contact = find.text('Choose from contacts');
    await tester.ensureVisible(contact);
    await tester.tap(contact);
    await tester.pump();
    replace(service);
    service.contactReply.complete({'phone': '+250788000002'});
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(service.calls, isNot(contains('resolve')));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'manual recipient modal hides private input on session replacement',
    (tester) async {
      final service = _HeldGateway(null);
      await mount(tester, const PaymentComposerScreen(), service);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enter receiving details'));
      await tester.tap(find.text('Enter receiving details'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      replace(service);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Account changed. Close this view.'), findsOneWidget);
      expect(service.calls, isNot(contains('resolve')));
    },
  );
  testWidgets('late pay-again cannot remember or navigate an old draft', (
    tester,
  ) async {
    final service = _HeldGateway('pay_again');
    await mount(
      tester,
      const PaymentLibraryScreen(section: 'activity'),
      service,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pay again'));
    await tester.tap(find.text('Pay again'));
    await tester.pump();
    expect(service.held, isTrue);
    replace(service);
    service.pending.complete({'id': 'old', 'owner_id': service.ownerId});
    await tester.pumpAndSettle();
    expect(service.remembered, isNull);
    expect(find.text('Shared receiving details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late request creation cannot expose the previous session link', (
    tester,
  ) async {
    final service = _HeldGateway('create_link');
    await mount(tester, PaymentRequestEditor(template: service.link), service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create request').last);
    await tester.pump();
    expect(service.held, isTrue);
    replace(service);
    service.pending.complete(service.link);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Lunch request'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('open request share sheet hides its token on account change', (
    tester,
  ) async {
    final service = _HeldGateway(null);
    await mount(tester, const PaymentLibraryScreen(), service);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View as payer'));
    await tester.tap(find.text('View as payer'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    replace(service);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Account changed. Close this view.'), findsOneWidget);
  });
}
