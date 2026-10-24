import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';
import 'package:mobi_app/shared/widgets/connectivity_overlay.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets('offline status remains accessible above routed content', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = StreamController<List<ConnectivityResult>>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => ConnectivityOverlay(
            checkConnectivity: () async => [ConnectivityResult.none],
            connectivityStream: controller.stream,
            offlineDebounce: const Duration(milliseconds: 20),
            child: child!,
          ),
          home: const Scaffold(body: Text('Routed task')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      final nodes = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        nodes.add(node);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      final status = nodes.where(
        (node) => node.getSemanticsData().label == 'No internet connection',
      );
      expect(status, hasLength(1));
      expect(
        status.single,
        isSemantics(label: 'No internet connection', isLiveRegion: true),
      );
      expect(find.text('Routed task'), findsOneWidget);
      await controller.close();
    } finally {
      semantics.dispose();
    }
  });

  Widget buildSubject({
    required Stream<List<ConnectivityResult>> stream,
    required Future<List<ConnectivityResult>> Function() checkConnectivity,
    Duration offlineDebounce = const Duration(milliseconds: 20),
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: ConnectivityOverlay(
        checkConnectivity: checkConnectivity,
        connectivityStream: stream,
        offlineDebounce: offlineDebounce,
        child: const Scaffold(body: Text('Login')),
      ),
    );
  }

  testWidgets('does not show offline banner for empty connectivity results', (
    tester,
  ) async {
    final controller = StreamController<List<ConnectivityResult>>();

    await tester.pumpWidget(
      buildSubject(
        stream: controller.stream,
        checkConnectivity: () async => <ConnectivityResult>[],
      ),
    );
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('No internet connection'), findsNothing);

    controller.add(<ConnectivityResult>[]);
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('No internet connection'), findsNothing);

    await controller.close();
  });

  testWidgets('debounces offline state and clears it when connection returns', (
    tester,
  ) async {
    final controller = StreamController<List<ConnectivityResult>>();

    await tester.pumpWidget(
      buildSubject(
        stream: controller.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
      ),
    );
    await tester.pump();

    controller.add([ConnectivityResult.none]);
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('No internet connection'), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('No internet connection'), findsOneWidget);

    controller.add([ConnectivityResult.mobile]);
    await tester.pump();

    expect(find.text('No internet connection'), findsNothing);

    await controller.close();
  });

  testWidgets('cancels pending offline banner when connectivity recovers', (
    tester,
  ) async {
    final controller = StreamController<List<ConnectivityResult>>();

    await tester.pumpWidget(
      buildSubject(
        stream: controller.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
      ),
    );
    await tester.pump();

    controller.add([ConnectivityResult.none]);
    await tester.pump(const Duration(milliseconds: 10));
    controller.add([ConnectivityResult.wifi]);
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('No internet connection'), findsNothing);

    await controller.close();
  });

  testWidgets(
    'offline banner leaves Back and recovery reachable at 200% text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = StreamController<List<ConnectivityResult>>();
      var backs = 0;
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: ConnectivityOverlay(
            checkConnectivity: () async => [ConnectivityResult.wifi],
            connectivityStream: controller.stream,
            offlineDebounce: const Duration(milliseconds: 20),
            child: PaymentTaskScaffold(
              title: 'Payment requests',
              onBack: () => backs++,
              children: [
                const TextField(
                  decoration: InputDecoration(labelText: 'Draft'),
                ),
                const PaymentError('Something went wrong'),
                PaymentAction(label: 'Try again', onPressed: () => retries++),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      controller.add([ConnectivityResult.none]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      final back = find.byTooltip('Back');
      expect(back.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text('No internet connection')).bottom,
        lessThanOrEqualTo(tester.getRect(back).top),
      );
      await tester.tap(back);
      expect(backs, 1);
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again').hitTestable());
      expect(retries, 1);
      expect(tester.takeException(), isNull);

      controller.add([ConnectivityResult.wifi]);
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Keep my draft',
      );
      expect(tester.takeException(), isNull);
      await controller.close();
    },
  );
}
