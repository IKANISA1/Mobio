import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';

typedef _Query = ({String? role, String? search, int limit, int offset});

AdminUserListItem _user(String id, {String role = 'passenger'}) =>
    AdminUserListItem(
      id: id,
      name: 'Fixture $id',
      phone: 'No phone',
      memberId: id,
      role: role,
      isDriver: role == 'driver',
      hasFaceId: false,
      isOnline: false,
    );

class _AdminFixture implements AdminService {
  List<AdminUserListItem> users = [
    for (var i = 1; i <= 6; i++) _user('10000$i'),
  ];
  final queries = <_Query>[];
  final updates = <({String id, String role})>[];
  Future<List<AdminUserListItem>> Function(_Query query)? onList;
  Future<void> Function(String id, String role)? onUpdate;

  @override
  String? get currentUserId => '999999';

  @override
  Future<List<AdminUserListItem>> listUsers({
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = (role: role, search: search, limit: limit, offset: offset);
    queries.add(query);
    if (onList != null) return onList!(query);
    return users.skip(offset).take(limit).toList();
  }

  @override
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    updates.add((id: userId, role: role));
    await onUpdate?.call(userId, role);
    users = [
      for (final user in users)
        if (user.id == userId) _user(user.id, role: role) else user,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected fixture operation');
}

Future<({ProviderContainer container, AdminUsersController controller})> _open(
  _AdminFixture service,
) async {
  final container = ProviderContainer(
    overrides: [adminServiceProvider.overrideWithValue(service)],
  );
  final subscription = container.listen(adminUsersProvider, (_, _) {});
  addTearDown(() {
    subscription.close();
    container.dispose();
  });
  await container.read(adminUsersProvider.future);
  return (
    container: container,
    controller: container.read(adminUsersProvider.notifier),
  );
}

Future<void> _observe(Future<Object?> operation) async {
  try {
    await operation;
  } on Object {
    // Some fixtures deliberately fail the server operation. Assert its state
    // outcome separately instead of allowing an unhandled asynchronous error.
  }
}

void main() {
  test(
    'nullable state fields can be cleared without clearing omitted fields',
    () {
      const before = AdminUsersState(
        loadError: 'Unavailable',
        updatingUserId: '100001',
        bulkUpdatingRole: 'driver',
      );
      final after = before.copyWith(
        updatingUserId: null,
        bulkUpdatingRole: null,
      );
      expect(after.updatingUserId, isNull);
      expect(after.bulkUpdatingRole, isNull);
      expect(after.loadError, 'Unavailable');
      expect(after.copyWith(loadError: null).loadError, isNull);
    },
  );

  test(
    'page and page-size changes retain role, search and local sort',
    () async {
      final service = _AdminFixture();
      final f = await _open(service);
      await f.controller.onRoleFilterChanged('driver');
      f.controller.setSortKey('name_desc');
      final searched = Completer<void>();
      service.onList = (query) async {
        if (!searched.isCompleted) searched.complete();
        return service.users.skip(query.offset).take(query.limit).toList();
      };
      f.controller.onSearchChanged('Fixture');
      await searched.future;
      await f.container.read(adminUsersProvider.future);
      await f.controller.setRowsPerPage(2);
      await f.controller.setPage(1);
      expect(service.queries.last, (
        role: 'driver',
        search: 'Fixture',
        limit: 3,
        offset: 2,
      ));
      final state = f.container.read(adminUsersProvider).requireValue;
      expect(state.sortKey, 'name_desc');
      expect(state.page, 1);
      expect(state.rowsPerPage, 2);
      expect(state.hasNextPage, isTrue);
      expect(state.paginationTotal, 5);
    },
  );

  test(
    'sorting the current page does not relabel it as the first page',
    () async {
      final f = await _open(_AdminFixture());
      await f.controller.setRowsPerPage(2);
      await f.controller.setPage(1);
      f.controller.setSortKey('name_desc');
      final state = f.container.read(adminUsersProvider).requireValue;
      expect(state.page, 1);
      expect(state.users.map((u) => u.id), ['100004', '100003']);
    },
  );

  test('an older role request cannot replace the newer result', () async {
    final service = _AdminFixture();
    final f = await _open(service);
    final driver = Completer<List<AdminUserListItem>>();
    final passenger = Completer<List<AdminUserListItem>>();
    service.onList = (query) =>
        query.role == 'driver' ? driver.future : passenger.future;
    final older = f.controller.onRoleFilterChanged('driver');
    final newer = f.controller.onRoleFilterChanged('passenger');
    passenger.complete([_user('100002')]);
    await newer;
    driver.complete([_user('100001', role: 'driver')]);
    await older;
    final state = f.container.read(adminUsersProvider).requireValue;
    expect(state.roleFilter, 'passenger');
    expect(state.users.single.id, '100002');
  });

  test('search typing while a request is pending still takes effect', () async {
    final service = _AdminFixture();
    final f = await _open(service);
    final firstStarted = Completer<void>();
    final firstResult = Completer<List<AdminUserListItem>>();
    service.onList = (query) async {
      if (query.search == 'older') {
        firstStarted.complete();
        return firstResult.future;
      }
      return [_user('100002')];
    };
    f.controller.onSearchChanged('older');
    await firstStarted.future;
    f.controller.onSearchChanged('newer');
    await Future<void>.delayed(const Duration(milliseconds: 330));
    firstResult.complete([_user('100001')]);
    await Future<void>.delayed(Duration.zero);
    final state = f.container.read(adminUsersProvider).requireValue;
    expect(state.searchQuery, 'newer');
    expect(state.users.single.id, '100002');
  });

  test('failed single role update releases its busy indicator', () async {
    final service = _AdminFixture()
      ..onUpdate = (_, _) async => throw StateError('Fixture denial');
    final f = await _open(service);
    await _observe(
      f.controller.updateSingleUserRole(service.users.first, 'driver'),
    );
    final state = f.container.read(adminUsersProvider).requireValue;
    expect(state.updatingUserId, isNull);
    expect(state.users.first.role, 'passenger');
  });

  test(
    'partial bulk failure refreshes successes and retains only failed rows',
    () async {
      final service = _AdminFixture()
        ..onUpdate = (id, _) async {
          if (id == '100002') throw StateError('Fixture denial');
        };
      final f = await _open(service);
      f.controller.toggleSelectionFor(['100001', '100002'], true);
      await _observe(f.controller.applyRoleToSelected('driver'));
      final state = f.container.read(adminUsersProvider).requireValue;
      expect(state.bulkUpdatingRole, isNull);
      expect(state.selectedIds, {'100002'});
      expect(state.users.firstWhere((u) => u.id == '100001').role, 'driver');
      expect(state.users.firstWhere((u) => u.id == '100002').role, 'passenger');
    },
  );

  test('a duplicate bulk callback cannot issue a second batch', () async {
    final gate = Completer<void>();
    final service = _AdminFixture()..onUpdate = (_, _) => gate.future;
    final f = await _open(service);
    f.controller.toggleSelection('100001', true);
    final first = _observe(f.controller.applyRoleToSelected('driver'));
    final second = _observe(f.controller.applyRoleToSelected('admin'));
    final submitted = List.of(service.updates);
    gate.complete();
    await Future.wait([first, second]);
    expect(submitted, [(id: '100001', role: 'driver')]);
  });

  test(
    'selection is scoped to the displayed page and clears on filter change',
    () async {
      final service = _AdminFixture();
      final f = await _open(service);
      await f.controller.setRowsPerPage(2);
      f.controller.toggleSelectionFor(['100001', '100006'], true);
      expect(f.container.read(adminUsersProvider).requireValue.selectedIds, {
        '100001',
      });
      await f.controller.onRoleFilterChanged('driver');
      expect(
        f.container.read(adminUsersProvider).requireValue.selectedIds,
        isEmpty,
      );
    },
  );

  test(
    'bulk result counts successes, failures, own account and no-op roles',
    () async {
      final service = _AdminFixture()
        ..users = [
          _user('999999', role: 'admin'),
          _user('100001', role: 'driver'),
          _user('100002'),
          _user('100003'),
        ]
        ..onUpdate = (id, _) async {
          if (id == '100002') throw StateError('Fixture denial');
        };
      final f = await _open(service);
      f.controller.toggleSelectAll(true);
      final result = await f.controller.applyRoleToSelected('driver');
      expect(result.updatedCount, 1);
      expect(result.failedIds, {'100002'});
      expect(result.skippedCount, 2);
      expect(service.updates.map((u) => u.id).toSet(), {'100002', '100003'});
    },
  );

  test('single update remains busy until its refreshed data returns', () async {
    final service = _AdminFixture();
    final f = await _open(service);
    final refreshing = Completer<void>();
    final refreshed = Completer<List<AdminUserListItem>>();
    service.onList = (_) {
      if (!refreshing.isCompleted) refreshing.complete();
      return refreshed.future;
    };
    final first = f.controller.updateSingleUserRole(
      service.users.first,
      'driver',
    );
    await refreshing.future;
    final busyId = f.container.read(adminUsersProvider).value?.updatingUserId;
    final second = _observe(
      f.controller.updateSingleUserRole(_user('100001'), 'admin'),
    );
    refreshed.complete(service.users);
    await Future.wait([first, second]);
    expect(busyId, '100001');
    expect(service.updates, [(id: '100001', role: 'driver')]);
    expect(
      f.container.read(adminUsersProvider).requireValue.updatingUserId,
      isNull,
    );
  });

  test(
    'bulk denial is retryable and a failed refresh has safe error text',
    () async {
      final service = _AdminFixture()
        ..onUpdate = (_, _) async => throw StateError('Fixture denial');
      final f = await _open(service);
      f.controller.toggleSelection('100001', true);
      final first = await f.controller.applyRoleToSelected('driver');
      expect(first.failedIds, {'100001'});
      expect(
        f.container.read(adminUsersProvider).requireValue.bulkUpdatingRole,
        isNull,
      );
      service
        ..onUpdate = null
        ..onList = (_) async => throw StateError('fixture-private-diagnostic');
      final retry = await f.controller.applyRoleToSelected('driver');
      expect(retry.updatedCount, 1);
      final state = f.container.read(adminUsersProvider).requireValue;
      expect(state.bulkUpdatingRole, isNull);
      expect(
        state.loadError,
        'Unable to load users. Check your connection and try again.',
      );
      expect(state.loadError, isNot(contains('fixture-private-diagnostic')));
    },
  );

  test(
    'leaving the directory during a request does not write disposed state',
    () async {
      final service = _AdminFixture();
      final container = ProviderContainer(
        overrides: [adminServiceProvider.overrideWithValue(service)],
      );
      final subscription = container.listen(adminUsersProvider, (_, _) {});
      await container.read(adminUsersProvider.future);
      final controller = container.read(adminUsersProvider.notifier);
      final response = Completer<List<AdminUserListItem>>();
      service.onList = (_) => response.future;
      final pending = controller.onRoleFilterChanged('driver');
      subscription.close();
      container.dispose();
      response.complete([_user('100001')]);
      await pending;
    },
  );
}
