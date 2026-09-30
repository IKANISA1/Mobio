import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/admin_session_boundary.dart';

void main() {
  testWidgets(
    'account invalidation masks an open admin view before timer tick',
    (tester) async {
      final changes = ValueNotifier(0);
      var authorized = true;
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const Text('route')),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(changes.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSessionBoundary(
            router: router,
            accountChanges: changes,
            canAccess: () => authorized,
            child: const Text('Protected content'),
          ),
        ),
      );
      expect(find.text('Protected content'), findsOneWidget);
      authorized = false;
      changes.value++;
      await tester.pump();
      expect(find.text('Protected content'), findsNothing);
      expect(find.text('Admin session locked'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'timer does not touch a lease and only authorized input touches',
    (tester) async {
      final changes = ValueNotifier(0);
      var authorized = true;
      final calls = <bool>[];
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const Text('route')),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(changes.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSessionBoundary(
            router: router,
            accountChanges: changes,
            canAccess: () => authorized,
            synchronize: ({required userActivity}) async {
              calls.add(userActivity);
            },
            child: const SizedBox.expand(
              child: Center(child: Text('Protected content')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(calls, isEmpty);
      await tester.tap(find.text('Protected content'));
      await tester.pump();
      expect(calls, [true]);
      authorized = false;
      changes.value++;
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(calls, [true]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
