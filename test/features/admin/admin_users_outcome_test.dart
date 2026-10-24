import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/application/admin_users_provider.dart';
import 'package:mobi_app/features/admin/application/admin_users_state.dart'
    show AdminUsersState;
import 'package:mobi_app/features/admin/data/admin_service.dart'
    show AdminService;
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/features/admin/presentation/admin_users_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_role_change_review.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_bulk_actions.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_filter_bar.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_widgets.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

const _actor = '00000000-0000-4000-8000-000000000003';
const _snapshot = '50000000-0000-4000-8000-000000000001';
const _reservation = '20000000-0000-4000-8000-000000000001';
const _users = [
  AdminUserListItem(
    id: '00000000-0000-4000-8000-000000000001',
    name: 'Amina Rider',
    phone: 'No phone',
    memberId: '482013',
    role: 'passenger',
    isDriver: false,
    hasFaceId: false,
    isOnline: true,
  ),
  AdminUserListItem(
    id: '00000000-0000-4000-8000-000000000002',
    name: 'Bosco Rider',
    phone: 'No phone',
    memberId: '482014',
    role: 'passenger',
    isDriver: false,
    hasFaceId: false,
    isOnline: false,
  ),
  AdminUserListItem(
    id: _actor,
    name: 'Current operator',
    phone: 'No phone',
    memberId: '482015',
    role: 'admin',
    isDriver: false,
    hasFaceId: false,
    isOnline: false,
  ),
];

// This fixture tests presentation and callbacks. It does not grant Auth or
// validate server receipts; those remain separate controller/SQL tests.
class _ViewAdminService implements AdminService {
  @override
  String? get currentUserId => _actor;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected service call: ${invocation.memberName}');
}

class _OutcomeController extends AdminUsersController {
  int prepares = 0, confirms = 0, cancels = 0, statusChecks = 0, closures = 0;
  List<AdminRoleReviewEntry> confirmedEntries = const [];
  final bool unknownOutcome;
  final List<String> queryActions = [];
  bool rejectPageChange = false;
  _OutcomeController({this.unknownOutcome = false});

  @override
  Future<AdminUsersState> build() async => AdminUsersState(
    users: _users,
    selectedIds: _users.map((row) => row.id).toSet(),
    roleRevisions: {for (final row in _users) row.id: 7},
    isLoading: false,
    snapshotId: _snapshot,
    asOf: DateTime.utc(2026, 10, 2, 8),
    expiresAt: DateTime.utc(2026, 10, 2, 8, 10),
    totalExact: 73,
    page: 7,
    rowsPerPage: 10,
    snapshotExpired: false,
    snapshotAge: const Duration(seconds: 14),
    reviewRemaining: const Duration(minutes: 9, seconds: 46),
    recoveryPhase: AdminRoleRecoveryPhase.ready,
  );

  @override
  AdminRoleReview prepareRoleReview(String role, {Set<String>? targetIds}) {
    prepares++;
    final current = state.requireValue;
    final ids = targetIds ?? current.selectedIds;
    final review = AdminRoleReview(
      reviewId: '10000000-0000-4000-8000-000000000001',
      reservationId: _reservation,
      actorId: _actor,
      sessionId: '40000000-0000-4000-8000-000000000001',
      snapshotId: _snapshot,
      requestedRole: role,
      entries: [
        for (final row in current.users.where((row) => ids.contains(row.id)))
          AdminRoleReviewEntry(
            targetId: row.id,
            displayLabel: row.name,
            memberId: row.memberId,
            expectedRole: row.role,
            expectedRevision: 7,
            expectedIsDriver: row.isDriver,
            requestedRole: role,
            requestedIsDriver: role == 'driver',
            skipReason: row.id == _actor
                ? AdminRoleSkipReason.self
                : row.role == role
                ? AdminRoleSkipReason.sameRole
                : null,
          ),
      ],
    );
    state = AsyncValue.data(current.copyWith(roleReview: review));
    return review;
  }

  @override
  void cancelRoleReview(String reviewId) {
    cancels++;
    expect(state.requireValue.roleReview?.reviewId, reviewId);
    state = AsyncValue.data(state.requireValue.copyWith(roleReview: null));
  }

  @override
  Future<void> confirmRoleReview(String reviewId) async {
    confirms++;
    final current = state.requireValue;
    expect(current.roleReview?.reviewId, reviewId);
    confirmedEntries = current.roleReview!.entries;
    final outcomes = [
      for (var i = 0; i < confirmedEntries.length; i++)
        AdminRoleRecipientOutcome(
          entry: confirmedEntries[i],
          status: confirmedEntries[i].skipReason != null
              ? AdminRoleOutcomeStatus.skipped
              : unknownOutcome && i == 1
              ? AdminRoleOutcomeStatus.unknown
              : AdminRoleOutcomeStatus.confirmed,
        ),
    ];
    state = AsyncValue.data(
      current.copyWith(
        roleReview: null,
        roleOutcomes: outcomes,
        outstandingReservationId: _reservation,
        recoveryPhase: AdminRoleRecoveryPhase.unresolved,
      ),
    );
  }

  @override
  Future<void> reconcileOutstanding() async {
    statusChecks++;
  }

  @override
  Future<void> closeOutstanding() async {
    closures++;
  }

  @override
  void onSearchChanged(String value) => queryActions.add('search:$value');

  @override
  Future<void> onRoleFilterChanged(String value) async =>
      queryActions.add('filter:$value');

  @override
  Future<void> setSortKey(String value) async =>
      queryActions.add('sort:$value');

  @override
  Future<void> setPage(int value) async {
    if (rejectPageChange) {
      throw const ValidationException(
        message: 'Refresh this member snapshot before navigating.',
      );
    }
    queryActions.add('page:$value');
  }

  @override
  Future<void> setRowsPerPage(int value) async =>
      queryActions.add('pageSize:$value');

  @override
  Future<void> refresh() async => queryActions.add('refresh');

  void queryState({
    AdminRoleRecoveryPhase phase = AdminRoleRecoveryPhase.ready,
    String? updatingUserId,
    bool isLoading = false,
  }) => state = AsyncValue.data(
    state.requireValue.copyWith(
      recoveryPhase: phase,
      updatingUserId: updatingUserId,
      isLoading: isLoading,
    ),
  );

  void expireReview() => state = AsyncValue.data(
    state.requireValue.copyWith(
      snapshotExpired: true,
      reviewRemaining: Duration.zero,
    ),
  );
}

Future<void> _mountDirectory(
  WidgetTester tester,
  _OutcomeController controller, {
  String language = 'en',
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1440, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminUsersProvider.overrideWith(() => controller),
        adminServiceProvider.overrideWithValue(_ViewAdminService()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...rwPlatformLocalizationDelegates,
          ...AppLocalizations.localizationsDelegates,
        ],
        home: const Scaffold(body: AdminUsersScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openBulk(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Review Driver'));
  await tester.tap(find.text('Review Driver'));
  await tester.pumpAndSettle();
}

Finder _driverFilter({String label = 'Drivers'}) => find.descendant(
  of: find.byType(AdminUserFilterBar),
  matching: find.byWidgetPredicate(
    (widget) => widget is AdminFilterChip && widget.label == label,
  ),
);

// AdminIconButton exposes its label through Semantics, without a Tooltip.
Finder _previousPage({String label = 'Previous page'}) => find.descendant(
  of: find.byType(AdminPaginationBar),
  matching: find.byWidgetPredicate(
    (widget) => widget is AdminIconButton && widget.label == label,
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [1280.0, 1440.0, 375.0]) {
    testWidgets('user table keeps header and row columns aligned at $width', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      const user = AdminUserListItem(
        id: '100001',
        name: 'Chantal Rider',
        memberId: '482013',
        phone: '+250788000001',
        role: 'passenger',
        isDriver: false,
        hasFaceId: false,
        isOnline: true,
      );
      String? selectedId;
      bool? selected;
      bool? allSelected;
      AdminUserListItem? openedUser;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AdminUserTable(
              users: const [user],
              selectedIds: const {},
              updatingUserId: null,
              onToggleSelection: (id, value) {
                selectedId = id;
                selected = value;
              },
              onToggleSelectAll: (value) => allSelected = value,
              onUserTap: (value) => openedUser = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final roleBadge = find.byWidgetPredicate(
        (widget) => widget is MobiStatusBadge && widget.label == 'PASSENGER',
      );
      final statusBadge = find.byWidgetPredicate(
        (widget) => widget is MobiStatusBadge && widget.label == 'Online',
      );
      expect(
        tester.getTopLeft(roleBadge).dx,
        closeTo(tester.getTopLeft(find.text('Role')).dx, 0.01),
      );
      expect(
        tester.getTopLeft(statusBadge).dx,
        closeTo(tester.getTopLeft(find.text('Status')).dx, 0.01),
      );
      expect(
        tester.getTopLeft(find.text(user.name)).dx,
        closeTo(tester.getTopLeft(find.text('Member')).dx, 0.01),
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(allSelected, isTrue);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(selectedId, user.id);
      expect(selected, isTrue);
      await tester.tap(find.text(user.name));
      await tester.pump();
      expect(openedUser, user);
      if (width < 520) {
        final horizontalScroll = find.byType(SingleChildScrollView);
        await tester.drag(horizontalScroll, const Offset(-220, 0));
        await tester.pumpAndSettle();
        expect(tester.getRect(statusBadge).right, lessThanOrEqualTo(width));
        expect(
          tester.getTopLeft(statusBadge).dx,
          closeTo(tester.getTopLeft(find.text('Status')).dx, 0.01),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'bulk role selection reviews frozen rows and Cancel sends no change',
    (tester) async {
      final controller = _OutcomeController();
      await _mountDirectory(tester, controller);
      await _openBulk(tester);
      expect(find.byType(AdminRoleChangeReview), findsOneWidget);
      expect(find.text('2 changes · 1 excluded'), findsOneWidget);
      expect(find.text('Member 482013'), findsOneWidget);
      expect(controller.confirms, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.prepares, 1);
      expect(controller.cancels, 1);
      expect(controller.confirms, 0);
      expect(
        controller.state.requireValue.selectedIds,
        _users.map((row) => row.id).toSet(),
      );
    },
  );

  testWidgets(
    'Confirm submits exactly reviewed entries once and displays true outcomes',
    (tester) async {
      final controller = _OutcomeController(unknownOutcome: true);
      await _mountDirectory(tester, controller);
      await _openBulk(tester);
      final confirm = find.text('Confirm 2 changes');
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(controller.confirms, 1);
      expect(
        controller.confirmedEntries.map((row) => row.targetId),
        _users.map((row) => row.id),
      );
      expect(find.text('Confirmed: 1'), findsOneWidget);
      expect(find.text('Unknown: 1'), findsOneWidget);
      expect(find.text('Skipped: 1'), findsOneWidget);
      expect(find.text('Known rejected: 0'), findsOneWidget);
      final controls = tester.widget<AdminUserBulkActions>(
        find.byType(AdminUserBulkActions),
      );
      expect(controls.reviewEnabled, isFalse);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('single user role change goes through the same frozen review', (
    tester,
  ) async {
    final controller = _OutcomeController();
    await _mountDirectory(tester, controller);
    await tester.ensureVisible(find.text('Amina Rider'));
    await tester.tap(find.text('Amina Rider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review Driver').last);
    await tester.pumpAndSettle();
    final review = tester.widget<AdminRoleChangeReview>(
      find.byType(AdminRoleChangeReview),
    );
    expect(review.review.entries.map((row) => row.targetId), [_users.first.id]);
    expect(controller.confirms, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.confirms, 0);
  });

  testWidgets(
    'snapshot expiry during review prevents Confirm without sending',
    (tester) async {
      final controller = _OutcomeController();
      await _mountDirectory(tester, controller);
      await _openBulk(tester);
      controller.expireReview();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('This snapshot has expired'), findsOneWidget);
      expect(controller.confirms, 0);
    },
  );

  testWidgets(
    'account generation change hides old review and prevents submission',
    (tester) async {
      final controller = _OutcomeController();
      await _mountDirectory(tester, controller);
      await _openBulk(tester);
      // Exercise the real UI action-generation signal, without claiming an
      // unsigned test session is authenticated or server-authorized.
      AccountContext.changes.value++;
      await tester.pump();
      expect(find.byType(AdminRoleChangeReview), findsNothing);
      expect(find.text('This review is no longer available.'), findsOneWidget);
      expect(controller.confirms, 0);
    },
  );

  testWidgets(
    'exact total and snapshot metadata do not imply page metric coverage',
    (tester) async {
      await _mountDirectory(tester, _OutcomeController());
      expect(find.text('73 matching users'), findsOneWidget);
      expect(find.text('Matching users'), findsOneWidget);
      expect(find.text('73'), findsOneWidget);
      expect(find.text('Admin profiles'), findsOneWidget);
      expect(find.text('This page at snapshot time'), findsNWidgets(3));
      expect(find.text('Snapshot age up to 14s.'), findsOneWidget);
      expect(find.text('Live now'), findsNothing);
    },
  );

  testWidgets(
    'unknown outcome requires explicit status check and closure confirmation',
    (tester) async {
      final controller = _OutcomeController(unknownOutcome: true);
      await _mountDirectory(tester, controller);
      await _openBulk(tester);
      await tester.tap(find.text('Confirm 2 changes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check status'));
      await tester.tap(find.text('Check status'));
      await tester.pump();
      expect(controller.statusChecks, 1);
      expect(controller.confirms, 1);
      await tester.tap(find.text('Close this batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.closures, 0);
      await tester.tap(find.text('Close this batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close batch'));
      await tester.pumpAndSettle();
      expect(controller.closures, 1);
      expect(controller.confirms, 1);
    },
  );

  for (final busy in ['reserving', 'submitting', 'member mutation']) {
    testWidgets('query controls block input during $busy', (tester) async {
      final controller = _OutcomeController();
      await _mountDirectory(tester, controller);
      final filterBar = tester.widget<AdminUserFilterBar>(
        find.byType(AdminUserFilterBar),
      );
      final sort = tester.widget<AdminSortMenu>(find.byType(AdminSortMenu));
      final pager = tester.widget<AdminPaginationBar>(
        find.byType(AdminPaginationBar),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      controller.queryState(
        phase: busy == 'reserving'
            ? AdminRoleRecoveryPhase.reserving
            : busy == 'submitting'
            ? AdminRoleRecoveryPhase.submitting
            : AdminRoleRecoveryPhase.ready,
        updatingUserId: busy == 'member mutation' ? _users.first.id : null,
      );
      await tester.pump();

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.tap(search, warnIfMissed: false);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      final driverFilter = _driverFilter();
      await tester.ensureVisible(driverFilter);
      await tester.pump();
      await tester.tap(driverFilter, warnIfMissed: false);
      await tester.ensureVisible(find.byType(AdminSortMenu));
      await tester.tap(find.byType(AdminSortMenu), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      final pageSize = find.byType(DropdownButton<int>);
      await tester.ensureVisible(pageSize);
      await tester.tap(pageSize, warnIfMissed: false);
      final previousPage = _previousPage();
      await tester.ensureVisible(previousPage);
      await tester.pump();
      await tester.tap(previousPage, warnIfMissed: false);
      await tester.pump();
      expect(find.text('25'), findsNothing);
      final refresh = tester.widget<AdminActionChip>(
        find.ancestor(
          of: find.text('Refresh'),
          matching: find.byType(AdminActionChip),
        ),
      );
      expect(refresh.onTap, isNull);

      // A menu or keyboard callback retained before the busy transition also
      // rechecks live state. The fixture intentionally provides no second guard.
      filterBar.onSearchChanged('old callback');
      filterBar.onRoleFilterChanged('driver');
      sort.onChanged('name_asc');
      pager.onPageChanged(6);
      pager.onRowsPerPageChanged!(25);
      await tester.pump();
      expect(controller.queryActions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stopped submission restores every directory query control', (
    tester,
  ) async {
    final controller = _OutcomeController();
    await _mountDirectory(tester, controller);
    controller.queryState(phase: AdminRoleRecoveryPhase.submitting);
    await tester.pump();
    controller.queryState(phase: AdminRoleRecoveryPhase.unresolved);
    await tester.pump();

    final search = find.byType(TextField);
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Amina');
    final driverFilter = _driverFilter();
    await tester.ensureVisible(driverFilter);
    await tester.pumpAndSettle();
    await tester.tap(driverFilter);
    await tester.ensureVisible(find.byType(AdminSortMenu));
    await tester.tap(find.byType(AdminSortMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name A-Z'));
    await tester.pumpAndSettle();
    final pageSize = find.byType(DropdownButton<int>);
    await tester.ensureVisible(pageSize);
    await tester.tap(pageSize);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    final previousPage = _previousPage();
    await tester.ensureVisible(previousPage);
    await tester.pumpAndSettle();
    await tester.tap(previousPage);
    await tester.ensureVisible(find.text('Refresh'));
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(controller.queryActions, [
      'search:Amina',
      'filter:driver',
      'sort:name_asc',
      'pageSize:25',
      'page:6',
      'refresh',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ordinary load keeps fresh-query supersession controls available',
    (tester) async {
      final controller = _OutcomeController();
      await _mountDirectory(tester, controller);
      controller.queryState(isLoading: true);
      await tester.pump();
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'newer search');
      final driverFilter = _driverFilter();
      await tester.ensureVisible(driverFilter);
      await tester.pumpAndSettle();
      await tester.tap(driverFilter);
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(controller.queryActions, [
        'search:newer search',
        'filter:driver',
        'refresh',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'page validation from a tap is caught and shown in the directory',
    (tester) async {
      final controller = _OutcomeController()..rejectPageChange = true;
      await _mountDirectory(tester, controller);
      final previousPage = _previousPage();
      await tester.ensureVisible(previousPage);
      await tester.pumpAndSettle();
      await tester.tap(previousPage);
      await tester.pump();
      expect(
        find.text('Refresh this member snapshot before navigating.'),
        findsOneWidget,
      );
      expect(controller.queryActions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['en', 'fr', 'rw']) {
    testWidgets(
      '$language query labels retain protocol values and busy guards',
      (tester) async {
        final controller = _OutcomeController();
        final copy = AdminCopy(lookupAppLocalizations(Locale(language)));
        final semantics = tester.ensureSemantics();
        try {
          await _mountDirectory(tester, controller, language: language);
          final filterBar = tester.widget<AdminUserFilterBar>(
            find.byType(AdminUserFilterBar),
          );
          final sort = tester.widget<AdminSortMenu>(find.byType(AdminSortMenu));
          final pager = tester.widget<AdminPaginationBar>(
            find.byType(AdminPaginationBar),
          );
          await tester.ensureVisible(find.byType(TextField));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Amina');
          final driver = _driverFilter(label: copy.filterDrivers);
          await tester.ensureVisible(driver);
          await tester.pumpAndSettle();
          await tester.tap(driver);
          await tester.ensureVisible(find.byType(AdminSortMenu));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(AdminSortMenu));
          await tester.pumpAndSettle();
          await tester.tap(find.text(copy.sortNameAsc));
          await tester.pumpAndSettle();
          final size = find.byType(DropdownButton<int>);
          await tester.ensureVisible(size);
          await tester.pumpAndSettle();
          expect(size.hitTestable(), findsOneWidget);
          await tester.tap(size.hitTestable());
          await tester.pumpAndSettle();
          final pageSizeOption = find.text(copy.number(25)).hitTestable();
          expect(pageSizeOption, findsOneWidget);
          await tester.tap(pageSizeOption);
          await tester.pumpAndSettle();
          final previous = _previousPage(label: copy.previousPage);
          await tester.ensureVisible(previous);
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel(copy.previousPage), findsOneWidget);
          await tester.tap(previous);
          await tester.ensureVisible(find.text(copy.refresh));
          await tester.pumpAndSettle();
          await tester.tap(find.text(copy.refresh));
          await tester.pump();
          expect(controller.queryActions, [
            'search:Amina',
            'filter:driver',
            'sort:name_asc',
            'pageSize:25',
            'page:6',
            'refresh',
          ]);
          controller.queryActions.clear();
          controller.queryState(phase: AdminRoleRecoveryPhase.submitting);
          await tester.pump();
          filterBar.onSearchChanged('stale');
          filterBar.onRoleFilterChanged('passenger');
          sort.onChanged('newest');
          pager.onPageChanged(6);
          pager.onRowsPerPageChanged!(25);
          await tester.pump();
          expect(controller.queryActions, isEmpty);
          final refresh = tester.widget<AdminActionChip>(
            find.ancestor(
              of: find.text(copy.refresh),
              matching: find.byType(AdminActionChip),
            ),
          );
          expect(refresh.onTap, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
