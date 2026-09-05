import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/widgets/connectivity_overlay.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
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
}
