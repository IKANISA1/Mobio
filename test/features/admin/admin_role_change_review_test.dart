import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_role_change_review.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_user_bulk_actions.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/l10n/platform_localization_fallbacks.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

// Synthetic presentation tests. Constructor fixtures are not real Auth,
// server receipt validation, or evidence that a role mutation was authorized.
AdminRoleReviewEntry _entry({
  String id = '00000000-0000-4000-8000-000000000001',
  String name = 'Amina Rider',
  String memberId = '482013',
  String before = 'passenger',
  String after = 'driver',
  AdminRoleSkipReason? skip,
}) => AdminRoleReviewEntry(
  targetId: id,
  displayLabel: name,
  memberId: memberId,
  expectedRole: before,
  expectedRevision: 7,
  expectedIsDriver: before == 'driver',
  requestedRole: after,
  requestedIsDriver: after == 'driver',
  skipReason: skip,
);

AdminRoleReview _review(List<AdminRoleReviewEntry> entries) => AdminRoleReview(
  reviewId: '10000000-0000-4000-8000-000000000001',
  reservationId: '20000000-0000-4000-8000-000000000001',
  actorId: '30000000-0000-4000-8000-000000000001',
  sessionId: '40000000-0000-4000-8000-000000000001',
  snapshotId: '50000000-0000-4000-8000-000000000001',
  requestedRole: 'driver',
  entries: entries,
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double width = 760,
  double textScale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 850);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...rwPlatformLocalizationDelegates,
        ...AppLocalizations.localizationsDelegates,
      ],
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 850),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: 820, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'review shows exact frozen recipients, role effects and exclusions',
    (tester) async {
      final review = _review([
        _entry(),
        _entry(
          id: '00000000-0000-4000-8000-000000000002',
          name: 'Current operator',
          memberId: '482014',
          before: 'admin',
          skip: AdminRoleSkipReason.self,
        ),
        _entry(
          id: '00000000-0000-4000-8000-000000000003',
          name: 'Existing driver',
          memberId: '482015',
          before: 'driver',
          skip: AdminRoleSkipReason.sameRole,
        ),
      ]);
      await _mount(
        tester,
        AdminRoleChangeReview(
          review: review,
          remaining: const Duration(minutes: 3),
          canConfirm: true,
          onCancel: () {},
          onConfirm: () {},
        ),
      );
      expect(find.text('1 change · 2 excluded'), findsOneWidget);
      expect(find.text('Amina Rider'), findsOneWidget);
      expect(find.text('Member 482013'), findsOneWidget);
      expect(find.text('Passenger → Driver'), findsOneWidget);
      await tester.ensureVisible(find.text('Excluded: your own profile'));
      expect(find.text('Excluded: your own profile'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Excluded: already has the requested role'),
      );
      expect(
        find.text('Excluded: already has the requested role'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not grant trusted admin access'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancel performs no confirmation', (tester) async {
    var cancelled = 0;
    var confirmed = 0;
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([_entry()]),
        remaining: const Duration(minutes: 3),
        canConfirm: true,
        onCancel: () => cancelled++,
        onConfirm: () => confirmed++,
      ),
    );
    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
    expect(confirmed, 0);
  });

  testWidgets('rapid Confirm activation calls the owner only once', (
    tester,
  ) async {
    var confirmed = 0;
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([_entry()]),
        remaining: const Duration(minutes: 3),
        canConfirm: true,
        onCancel: () {},
        onConfirm: () => confirmed++,
      ),
    );
    final button = find.text('Confirm 1 change');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(confirmed, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('all excluded recipients keep Confirm disabled', (tester) async {
    var confirmed = 0;
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([
          _entry(before: 'driver', skip: AdminRoleSkipReason.sameRole),
        ]),
        remaining: const Duration(minutes: 3),
        canConfirm: true,
        onCancel: () {},
        onConfirm: () => confirmed++,
      ),
    );
    expect(find.text('0 changes · 1 excluded'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(confirmed, 0);
  });

  testWidgets('expired snapshot explains disabled Confirm', (tester) async {
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([_entry()]),
        remaining: Duration.zero,
        canConfirm: false,
        onCancel: () {},
        onConfirm: () => fail('Expired review must not confirm'),
      ),
    );
    expect(find.textContaining('This snapshot has expired'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('unavailable authority explains disabled Confirm before expiry', (
    tester,
  ) async {
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([_entry()]),
        remaining: const Duration(minutes: 3),
        canConfirm: false,
        onCancel: () {},
        onConfirm: () => fail('Unavailable review must not confirm'),
      ),
    );
    expect(
      find.text(
        'This review is no longer available. Cancel and refresh users.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('long review has reachable footer at narrow enlarged text', (
    tester,
  ) async {
    await _mount(
      tester,
      AdminRoleChangeReview(
        review: _review([
          for (var i = 0; i < 12; i++)
            _entry(
              id: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
              name: 'Reviewed member $i',
              memberId: (482013 + i).toString(),
            ),
        ]),
        remaining: const Duration(minutes: 3),
        canConfirm: true,
        onCancel: () {},
        onConfirm: () {},
      ),
      width: 375,
      textScale: 1.5,
    );
    await tester.ensureVisible(find.text('Reviewed member 11'));
    expect(
      tester.getRect(find.text('Confirm 12 changes')).bottom,
      lessThanOrEqualTo(850),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'review retains its immutable recipients after input list changes',
    (tester) async {
      final entries = [_entry()];
      final review = _review(entries);
      entries.clear();
      await _mount(
        tester,
        AdminRoleChangeReview(
          review: review,
          remaining: const Duration(minutes: 3),
          canConfirm: true,
          onCancel: () {},
          onConfirm: () {},
        ),
      );
      expect(find.text('Amina Rider'), findsOneWidget);
      expect(find.text('Confirm 1 change'), findsOneWidget);
    },
  );

  testWidgets(
    'outcomes keep all six statuses distinct and never provide retry',
    (tester) async {
      var checked = 0;
      var closed = 0;
      await _mount(
        tester,
        SingleChildScrollView(
          child: AdminRoleChangeOutcome(
            outcomes: [
              for (final status in AdminRoleOutcomeStatus.values)
                AdminRoleRecipientOutcome(
                  entry: _entry(name: 'Recipient ${status.name}'),
                  status: status,
                ),
            ],
            phase: AdminRoleRecoveryPhase.unresolved,
            workSealed: false,
            canReconcile: true,
            canClose: true,
            onReconcile: () => checked++,
            onClose: () => closed++,
          ),
        ),
      );
      for (final label in [
        'Confirmed: 1',
        'Known rejected: 1',
        'Unknown: 1',
        'Not started: 1',
        'Skipped: 1',
        'Submitting: 1',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('unknown outcome'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(checked, 0);
      expect(closed, 0);
      await tester.ensureVisible(find.text('Check status'));
      await tester.tap(find.text('Check status'));
      await tester.tap(find.text('Close this batch'));
      expect(checked, 1);
      expect(closed, 1);
    },
  );

  testWidgets('missing batch and ready phase cannot claim proven closure', (
    tester,
  ) async {
    await _mount(
      tester,
      AdminRoleChangeOutcome(
        outcomes: const [],
        phase: AdminRoleRecoveryPhase.ready,
        workSealed: false,
        canReconcile: false,
        canClose: false,
        onReconcile: () {},
        onClose: () {},
      ),
    );
    expect(find.textContaining('Reservation closed'), findsNothing);
  });

  testWidgets('proven seal before reservation shows zero submitted changes', (
    tester,
  ) async {
    await _mount(
      tester,
      AdminRoleChangeOutcome(
        outcomes: const [],
        phase: AdminRoleRecoveryPhase.ready,
        workSealed: true,
        canReconcile: false,
        canClose: false,
        onReconcile: () {},
        onClose: () {},
      ),
    );
    expect(
      find.text('Reservation closed. No role changes were submitted.'),
      findsOneWidget,
    );
  });

  testWidgets('reconciliation in progress disables both recovery actions', (
    tester,
  ) async {
    await _mount(
      tester,
      AdminRoleChangeOutcome(
        outcomes: const [],
        phase: AdminRoleRecoveryPhase.reconciling,
        workSealed: false,
        canReconcile: true,
        canClose: true,
        onReconcile: () => fail('Do not duplicate status call'),
        onClose: () => fail('Do not close while checking'),
      ),
    );
    await tester.tap(find.text('Close this batch'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'known conflict has useful controlled copy without raw backend code',
    (tester) async {
      await _mount(
        tester,
        AdminRoleChangeOutcome(
          outcomes: [
            AdminRoleRecipientOutcome(
              entry: _entry(),
              status: AdminRoleOutcomeStatus.knownRejected,
              rejectionCode: 'target_changed',
            ),
          ],
          phase: AdminRoleRecoveryPhase.unresolved,
          workSealed: false,
          canReconcile: false,
          canClose: false,
          onReconcile: () {},
          onClose: () {},
        ),
      );
      expect(find.textContaining('changed after the snapshot'), findsOneWidget);
      expect(find.text('target_changed'), findsNothing);
      expect(find.textContaining('unknown outcome'), findsNothing);
      expect(find.textContaining('close this batch before'), findsOneWidget);
      expect(find.text('Reviewed request: Passenger → Driver'), findsOneWidget);
    },
  );

  testWidgets(
    'bulk controls describe page scope and disabled review has no callback',
    (tester) async {
      await _mount(
        tester,
        AdminUserBulkActions(
          selectedCount: 3,
          bulkUpdatingRole: null,
          reviewEnabled: false,
          onReviewRole: (_) => fail('Unavailable review must not start'),
          onClear: () {},
        ),
      );
      expect(find.text('3 selected on this page'), findsOneWidget);
      await tester.tap(find.text('Review Driver'));
      expect(tester.takeException(), isNull);
    },
  );
}
