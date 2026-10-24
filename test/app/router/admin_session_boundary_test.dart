import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/admin_session_boundary.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';

void main() {
  testWidgets(
    'server rejection masks an open admin view before the expiry timer',
    (tester) async {
      AdminSessionGuard.resetForTesting();
      addTearDown(AdminSessionGuard.resetForTesting);
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const Text('route')),
          GoRoute(
            path: '/admin-auth',
            builder: (_, _) => const Text('Verify route'),
          ),
        ],
      );
      addTearDown(router.dispose);
      AdminSessionGuard.acceptServerLease(
        userId: 'admin-user',
        sessionId: 'session-1',
        idleRemaining: const Duration(minutes: 15),
        absoluteRemaining: const Duration(hours: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminSessionBoundary(
            router: router,
            canAccess: () => AdminSessionGuard.isAdminFor(
              'admin-user',
              sessionId: 'session-1',
            ),
            child: const Text('Protected content'),
          ),
        ),
      );
      expect(find.text('Protected content'), findsOneWidget);
      AdminSessionGuard.rejectSession(
        userId: 'admin-user',
        sessionId: 'session-1',
      );
      await tester.pump();
      expect(find.text('Protected content'), findsNothing);
      expect(find.text('Admin session locked'), findsOneWidget);
      await tester.tap(find.text('Verify again'));
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/admin-auth');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
  testWidgets(
    'masked production Router reaches verification and protects re-entry',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => const Text('Protected route'),
          ),
          GoRoute(
            path: '/admin-auth',
            builder: (_, _) => const Text('Verify route'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => AdminSessionBoundary(
            router: router,
            canAccess: () => false,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Admin session locked'), findsOneWidget);
      expect(find.text('Protected route'), findsNothing);
      await tester.tap(find.text('Verify again'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/admin-auth');
      expect(find.text('Verify route'), findsOneWidget);
      expect(find.text('Admin session locked'), findsNothing);
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.text('Admin session locked'), findsOneWidget);
      expect(find.text('Protected route'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
