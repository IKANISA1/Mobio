import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_library_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

import '../../helpers/payment_discovery_fixture.dart';

const _otherOwner = '00000000-0000-4000-8000-000000000002';

class _Gateway extends PaymentDiscoveryFixture {
  final dispatches = <(String?, int, String)>[];
  bool incoming = false;
  int contacts = 0;

  @override
  Map<String, dynamic> get workspace {
    final value = super.workspace;
    value['methods'] = [
      {...source.toJson(), 'owner_id': ownerId},
    ];
    value['drafts'] = drafts
        .where((draft) => draft['owner_id'] == ownerId)
        .toList();
    if (incoming) {
      final row = (value['activity'] as List).single as Map<String, dynamic>;
      row['payer_id'] = _otherOwner;
      row['payee_id'] = ownerId;
    }
    return value;
  }

  @override
  Map<String, dynamic> get quote {
    final value = super.quote;
    final option = (value['options'] as List).single as Map<String, dynamic>;
    option['source'] = {...source.toJson(), 'owner_id': ownerId};
    return value;
  }

  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async {
    dispatches.add((ownerId, generation, action));
    if (action == 'pay_again') {
      calls.add(action);
      return PaymentDraft(id: newBioPayUuid(), ownerId: ownerId!).toJson();
    }
    return super.call(action, data);
  }

  @override
  Future<Map<String, String>?> pickPhone() async {
    contacts++;
    return {'phone': '+250788000003'};
  }
}

class _Navigation extends NavigatorObserver {
  int changes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    changes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    changes++;
  }
}

class _MalformedWorkspaceGateway extends _Gateway {
  _MalformedWorkspaceGateway(this.malform);
  final void Function(Map<String, dynamic>) malform;
  bool invalid = true;
  @override
  Map<String, dynamic> get workspace {
    final response = super.workspace;
    if (invalid) malform(response);
    return response;
  }
}

void main() {
  final copy = lookupAppLocalizations(const Locale('en'));
  int clipboardWrites = 0;

  setUp(() {
    clipboardWrites = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardWrites++;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<_Navigation> mount(
    WidgetTester tester,
    Widget child,
    _Gateway service,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigation = _Navigation();
    final router = GoRouter(
      observers: [navigation],
      initialLocation: '/task',
      routes: [
        GoRoute(path: '/task', builder: (_, _) => child),
        for (final path in [
          '/biopay',
          '/biopay/send',
          '/biopay/activity',
          '/profile/payment-methods',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('Destination: $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentDiscoveryServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.darkTheme,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigation;
  }

  VoidCallback action(WidgetTester tester, String label) => tester
      .widget<PaymentAction>(find.widgetWithText(PaymentAction, label).last)
      .onPressed!;

  VoidCallback button(WidgetTester tester, String label) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, label).last)
      .onPressed!;

  List<VoidCallback> renderedCallbacks(WidgetTester tester) => [
    for (final widget in tester.widgetList<PaymentAction>(
      find.byType(PaymentAction),
    ))
      if (widget.onPressed != null) widget.onPressed!,
    for (final widget in tester.widgetList<TextButton>(find.byType(TextButton)))
      if (widget.onPressed != null) widget.onPressed!,
    for (final widget in tester.widgetList<IconButton>(find.byType(IconButton)))
      if (widget.onPressed != null) widget.onPressed!,
    for (final widget in tester.widgetList<ListTile>(find.byType(ListTile)))
      if (widget.onTap != null) widget.onTap!,
    tester.widget<PaymentTaskScaffold>(find.byType(PaymentTaskScaffold)).onBack,
  ];

  void replace(_Gateway service, {required bool sameOwner}) {
    if (!sameOwner) service.ownerId = _otherOwner;
    service.generation++;
    AccountContext.changes.value++;
  }

  Future<void> refreshReplacement(
    WidgetTester tester,
    _Gateway service, {
    bool sameOwner = false,
  }) async {
    replace(service, sameOwner: sameOwner);
    await tester.pumpAndSettle();
    action(tester, copy.bpRefresh)();
    await tester.pumpAndSettle();
    expect(service.dispatches.where((x) => x.$3 == 'workspace').last, (
      service.ownerId,
      service.generation,
      'workspace',
    ));
    expect(find.byType(PaymentError), findsNothing);
  }

  Future<void> rejectRetained(
    WidgetTester tester,
    _Gateway service,
    _Navigation navigation,
    List<VoidCallback> retained,
  ) async {
    final before = List.of(service.dispatches);
    final routes = navigation.changes;
    final contacts = service.contacts;
    final opens = service.opens;
    final copies = clipboardWrites;
    for (final callback in retained) {
      callback();
      await tester.pumpAndSettle();
    }
    expect(service.dispatches, before);
    expect(navigation.changes, routes);
    expect(service.contacts, contacts);
    expect(service.opens, opens);
    expect(clipboardWrites, copies);
    expect(tester.takeException(), isNull);
  }

  Future<void> compare(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '1000');
    action(tester, copy.bpCompare)();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, copy.bpReview), findsOneWidget);
  }

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'missing workspace section': (value) => value.remove('templates'),
    'missing activity currency': (value) {
      ((value['activity'] as List).single as Map).remove('currency');
    },
    'wrong method owner': (value) {
      ((value['methods'] as List).single as Map)['owner_id'] = _otherOwner;
    },
  };
  for (final entry in malformed.entries) {
    testWidgets('composer validates injected ${entry.key} before publication', (
      tester,
    ) async {
      final service = _MalformedWorkspaceGateway(entry.value);
      await mount(tester, const PaymentComposerScreen(), service);
      expect(find.byType(PaymentError), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('My contact label'), findsNothing);
      service.invalid = false;
      action(tester, copy.bpRefresh)();
      await tester.pumpAndSettle();
      expect(find.byType(PaymentError), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(service.calls, ['workspace', 'workspace']);
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in ['composer', 'library']) {
    for (final sameOwner in [false, true]) {
      testWidgets(
        '$screen retained refresh rejects ${sameOwner ? 'same-owner generation' : 'different owner'} before and after fresh recovery',
        (tester) async {
          final service = _Gateway()..failAction = 'workspace';
          final navigation = await mount(
            tester,
            screen == 'composer'
                ? const PaymentComposerScreen()
                : const PaymentLibraryScreen(),
            service,
          );
          final old = renderedCallbacks(tester);
          service.failAction = null;
          replace(service, sameOwner: sameOwner);
          await tester.pumpAndSettle();
          await rejectRetained(tester, service, navigation, old);
          action(tester, copy.bpRefresh)();
          await tester.pumpAndSettle();
          expect(service.calls, ['workspace', 'workspace']);
          expect(find.byType(PaymentError), findsNothing);
          await rejectRetained(tester, service, navigation, old);
        },
      );
    }
  }

  for (final section in [
    'requests',
    'templates',
    'recents',
    'activity',
    'incoming',
  ]) {
    testWidgets(
      'library $section retains no previous-owner dispatch after fresh load',
      (tester) async {
        final service = _Gateway()..incoming = section == 'incoming';
        // An incoming request is always sent by a separate account.
        if (service.incoming) {
          service.ownerId = '00000000-0000-4000-8000-000000000003';
        }
        final navigation = await mount(
          tester,
          PaymentLibraryScreen(
            section: section == 'incoming' ? 'activity' : section,
          ),
          service,
        );
        final retained = renderedCallbacks(tester);
        expect(retained.length, greaterThan(2));
        await refreshReplacement(
          tester,
          service,
          sameOwner: section == 'incoming',
        );
        await rejectRetained(tester, service, navigation, retained);
        final before = service.dispatches.length;
        switch (section) {
          case 'requests':
            action(tester, copy.bpCreateRequest)();
            await tester.pumpAndSettle();
            expect(find.byType(PaymentRequestEditor), findsOneWidget);
            expect(service.dispatches.length, before + 1);
          case 'templates':
            button(tester, copy.bpUseTemplate)();
            await tester.pumpAndSettle();
            expect(find.byType(PaymentRequestEditor), findsOneWidget);
            expect(service.dispatches.length, before + 1);
          case 'recents':
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == copy.bpFavorite,
                  ),
                )
                .onPressed!();
            await tester.pumpAndSettle();
            expect(service.dispatches.skip(before).map((x) => x.$3), [
              'save_recent',
              'workspace',
            ]);
          case 'activity':
            button(tester, copy.bpPayAgain)();
            await tester.pumpAndSettle();
            expect(service.dispatches.last.$3, 'pay_again');
            expect(service.remembered, isNotNull);
            expect(find.text('Destination: /biopay/send'), findsOneWidget);
          case 'incoming':
            button(tester, copy.bpAcknowledge)();
            await tester.pumpAndSettle();
            expect(service.dispatches.skip(before).map((x) => x.$3), [
              'acknowledge',
              'workspace',
            ]);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'composer recipient closures remain tied to their rendered account',
    (tester) async {
      final service = _Gateway();
      final navigation = await mount(
        tester,
        const PaymentComposerScreen(),
        service,
      );
      final retained = renderedCallbacks(tester);
      final onPhone = tester
          .widget<TextField>(find.byType(TextField).first)
          .onChanged!;
      await refreshReplacement(tester, service, sameOwner: true);
      onPhone('0788000002');
      await rejectRetained(tester, service, navigation, retained);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      action(tester, copy.bpContacts)();
      await tester.pumpAndSettle();
      expect(service.contacts, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '+250788000003',
      );
      action(tester, copy.bpContinue)();
      await tester.pumpAndSettle();
      expect(service.dispatches.last.$3, 'resolve');
      expect(tester.takeException(), isNull);
    },
  );

  for (final step in ['options', 'review', 'outcome']) {
    testWidgets(
      'composer $step rejects retained callbacks after replacement and supports current actions',
      (tester) async {
        final service = _Gateway();
        final navigation = await mount(
          tester,
          const PaymentComposerScreen(entry: '+250788000002'),
          service,
        );
        await compare(tester);
        if (step != 'options') {
          button(tester, copy.bpReview)();
          await tester.pumpAndSettle();
        }
        if (step == 'outcome') {
          action(tester, copy.bpOpenMomo)();
          await tester.pumpAndSettle();
          expect(service.opens, 1);
        }
        final retained = renderedCallbacks(tester);
        await refreshReplacement(tester, service);
        await rejectRetained(tester, service, navigation, retained);
        await compare(tester);
        await rejectRetained(tester, service, navigation, retained);
        if (step == 'options') {
          action(tester, copy.bpSaveDraft)();
          await tester.pumpAndSettle();
          expect(service.dispatches.last.$3, 'save_draft');
          expect(find.text(copy.bpSaved), findsOneWidget);
        } else {
          button(tester, copy.bpReview)();
          await tester.pumpAndSettle();
          action(tester, copy.bpOpenMomo)();
          await tester.pumpAndSettle();
          expect(service.opens, step == 'outcome' ? 2 : 1);
          if (step == 'outcome') {
            action(tester, copy.bpReportDone)();
            await tester.pumpAndSettle();
            expect(find.text(copy.bpUserReported), findsOneWidget);
            final routes = navigation.changes;
            action(tester, copy.bpActivity)();
            await tester.pumpAndSettle();
            expect(navigation.changes, greaterThan(routes));
            expect(find.text('Destination: /biopay/activity'), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'retained source-sheet methods navigation cannot act after account replacement',
    (tester) async {
      final service = _Gateway();
      final navigation = await mount(
        tester,
        const PaymentComposerScreen(entry: '+250788000002'),
        service,
      );
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, copy.bpFrom))
          .onTap!();
      await tester.pumpAndSettle();
      final methods = action(tester, copy.bpMethods);
      replace(service, sameOwner: true);
      await tester.pumpAndSettle();
      await rejectRetained(tester, service, navigation, [methods]);
      expect(find.text('Account changed. Close this view.'), findsOneWidget);
    },
  );

  for (final sameOwner in [false, true]) {
    testWidgets(
      'request editor rejects retained create/date/navigation after ${sameOwner ? 'relogin' : 'owner change'}',
      (tester) async {
        final service = _Gateway();
        final navigation = await mount(
          tester,
          PaymentRequestEditor(template: service.link),
          service,
        );
        final retained = renderedCallbacks(tester);
        final method = tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged!;
        replace(service, sameOwner: sameOwner);
        await tester.pumpAndSettle();
        method(true);
        await rejectRetained(tester, service, navigation, retained);
        expect(find.byType(TextField), findsNothing);
        expect(service.calls, ['workspace']);
      },
    );
  }

  testWidgets(
    'current request editor create and date callbacks remain functional',
    (tester) async {
      final service = _Gateway();
      await mount(
        tester,
        PaymentRequestEditor(template: service.link),
        service,
      );
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, copy.bpExpiry))
          .onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      action(tester, copy.bpCreateRequest)();
      // Create remains busy until its sharing sheet closes; that spinner is
      // intentional, so wait for the sheet animation rather than idle frames.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.dispatches.last.$3, 'create_link');
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
