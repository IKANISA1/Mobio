import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/app/launch_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final location in [
    '/admin-auth',
    '/admin/users',
    '/login?redirect=%2Fbookings',
  ]) {
    testWidgets('launch preserves incoming route $location', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = location;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async => calls.add(call),
      );
      addTearDown(() {
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        );
      });

      await tester.pumpWidget(const MobiLaunchApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Mobio'), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
      expect(
        calls,
        isEmpty,
        reason: 'The splash must not publish a root route.',
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          for (final path in ['/', '/admin-auth', '/admin/users', '/login'])
            GoRoute(
              path: path,
              builder: (_, state) => Text(state.uri.toString()),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text(location), findsOneWidget);
    });
  }
}
