import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:mobi_app/features/notifications/presentation/notifications_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

const _row = AppNotification(
  id: 'synthetic-notification',
  userId: 'synthetic-user',
  type: 'chat_message',
  title: 'Synthetic account alert',
  metadata: {'route': '/chat'},
  createdAt: '2026-09-15T00:00:00Z',
);

class _Service extends Fake implements NotificationService {
  Future<List<AppNotification>> Function()? load;
  Future<void> Function()? write;
  List<AppNotification> rows = [_row];
  int reads = 0;
  int writes = 0;

  @override
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    reads++;
    return load == null ? rows : await load!();
  }

  @override
  Future<void> markAsRead(String id) async {
    writes++;
    await write?.call();
  }

  @override
  Future<void> markAllAsRead() async {
    writes++;
    await write?.call();
  }
}

class _Authority {
  int generation = 0;
  String userId = _row.userId;
  bool available = true;
  AccountSnapshot capture() {
    if (!available) throw const StaleAccountWork();
    return AccountSnapshot(userId, 'same-session', generation);
  }

  bool current(AccountSnapshot account) =>
      available && account.userId == userId && account.generation == generation;
  void change() {
    generation++;
    AccountContext.changes.value++;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Service service, {
  double scale = 1,
  _Authority? authority,
}) async {
  final account = authority ?? _Authority();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => Scaffold(
          body: NotificationsScreen.test(
            onBack: () {},
            captureAccount: account.capture,
            isCurrent: account.current,
          ),
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const Scaffold(body: Text('Chat destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationUiPreviewProvider.overrideWithValue(false),
        notificationServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'cached inbox clears immediately while a new account load is pending',
    (tester) async {
      final authority = _Authority();
      final service = _Service();
      await _pump(tester, service, authority: authority);
      expect(find.text(_row.title), findsOneWidget);
      final pending = Completer<List<AppNotification>>();
      service.load = () => pending.future;
      authority.change();
      await tester.pump();
      expect(find.text(_row.title), findsNothing);
      expect(service.reads, 2);
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an old already-read row callback cannot navigate after same-user relogin',
    (tester) async {
      final authority = _Authority();
      final service = _Service()
        ..rows = const [
          AppNotification(
            id: 'read-row',
            userId: 'synthetic-user',
            type: 'chat_message',
            title: 'Read session alert',
            metadata: {'route': '/chat'},
            isRead: true,
            createdAt: '2026-09-15T00:00:00Z',
          ),
        ];
      await _pump(tester, service, authority: authority);
      final tile = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Read session alert'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final callback = tile.onTap!;
      authority.change();
      callback();
      await tester.pumpAndSettle();
      expect(find.text('Chat destination'), findsNothing);
      expect(service.writes, 0);
      expect(service.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late row acknowledgement cannot navigate or refresh a new session',
    (tester) async {
      final authority = _Authority();
      final acknowledgement = Completer<void>();
      final service = _Service()..write = () => acknowledgement.future;
      await _pump(tester, service, authority: authority);
      await tester.tap(find.text(_row.title));
      await tester.pump();
      expect(service.writes, 1);
      authority.change();
      await tester.pumpAndSettle();
      acknowledgement.complete();
      await tester.pumpAndSettle();
      expect(find.text('Chat destination'), findsNothing);
      expect(service.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late mark-all acknowledgement cannot reload the next session', (
    tester,
  ) async {
    final authority = _Authority();
    final acknowledgement = Completer<void>();
    final service = _Service()..write = () => acknowledgement.future;
    await _pump(tester, service, authority: authority);
    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pump();
    authority.change();
    await tester.pumpAndSettle();
    acknowledgement.complete();
    await tester.pumpAndSettle();
    expect(service.reads, 2);
    expect(service.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session invalidation clears private inbox without a new service call',
    (tester) async {
      final authority = _Authority();
      final service = _Service();
      await _pump(tester, service, authority: authority);
      authority
        ..available = false
        ..change();
      await tester.pumpAndSettle();
      expect(find.text(_row.title), findsNothing);
      expect(find.text('Sign in to view notifications.'), findsOneWidget);
      expect(service.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed load shows an error and retry restores the inbox', (
    tester,
  ) async {
    final service = _Service()
      ..load = () async => throw const NetworkException();
    await _pump(tester, service);
    expect(find.text('No notifications'), findsNothing);
    expect(find.text('Couldn’t load notifications'), findsOneWidget);
    service.load = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(_row.title), findsOneWidget);
    expect(service.reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty successful response shows the empty state', (
    tester,
  ) async {
    await _pump(tester, _Service()..rows = []);
    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text('Couldn’t load notifications'), findsNothing);
  });

  testWidgets('failed mark all retains the inbox and permits retry', (
    tester,
  ) async {
    final service = _Service()
      ..write = () async => throw const NetworkException();
    await _pump(tester, service);
    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_row.title), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(service.reads, 1);
    service.write = null;
    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();
    expect(service.writes, 2);
    expect(service.reads, 2);
  });

  testWidgets('a failed single update prevents navigation', (tester) async {
    final service = _Service()
      ..write = () async => throw const NetworkException();
    await _pump(tester, service);
    await tester.tap(find.text(_row.title));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Chat destination'), findsNothing);
    expect(find.text(_row.title), findsOneWidget);
    service.write = null;
    await tester.tap(find.text(_row.title));
    await tester.pumpAndSettle();
    expect(find.text('Chat destination'), findsOneWidget);
  });

  testWidgets(
    'pending mark all prevents duplicate writes and survives closing',
    (tester) async {
      final acknowledgement = Completer<void>();
      final service = _Service()..write = () => acknowledgement.future;
      await _pump(tester, service);
      await tester.tap(find.byTooltip('Mark all read'));
      await tester.pump();
      await tester.tap(find.byTooltip('Mark all read'));
      await tester.pump();
      expect(service.writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      acknowledgement.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.reads, 1);
    },
  );

  testWidgets(
    'refresh failure is rendered without an unhandled callback error',
    (tester) async {
      final service = _Service();
      await _pump(tester, service);
      service.load = () async => throw const NetworkException();
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Couldn’t load notifications'), findsOneWidget);
      expect(find.text('No notifications'), findsNothing);
    },
  );

  testWidgets('error recovery remains reachable at enlarged text', (
    tester,
  ) async {
    final service = _Service()
      ..load = () async => throw const NetworkException();
    await _pump(tester, service, scale: 2);
    expect(find.text('Couldn’t load notifications'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    service.load = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(_row.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
