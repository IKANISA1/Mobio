import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart'
    show AdminService;
import 'package:mobi_app/features/admin/presentation/admin_reports_screen.dart';
import 'package:mobi_app/features/admin/presentation/admin_trips_screen.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class _Query {
  _Query({
    required this.search,
    required this.limit,
    required this.offset,
    this.status,
    this.role,
  });

  final String? search;
  final int limit;
  final int offset;
  final String? status;
  final String? role;
  final reply = Completer<List<Object>>();
}

class _Admin extends Fake implements AdminService {
  _Admin({required this.isReports});

  final bool isReports;
  final queries = <_Query>[];

  Future<List<Object>> _query(
    String? search,
    int limit,
    int offset, {
    String? status,
    String? role,
  }) {
    final query = _Query(
      search: search,
      limit: limit,
      offset: offset,
      status: status,
      role: role,
    );
    queries.add(query);
    return query.reply.future;
  }

  @override
  Future<List<AdminUserReportItem>> listUserReports({
    String status = 'open',
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => (await _query(
    search,
    limit,
    offset,
    status: status,
  )).cast<AdminUserReportItem>();

  @override
  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async => (await _query(
    search,
    limit,
    offset,
    status: status,
    role: role,
  )).cast<AdminTripListItem>();

  void succeed(int index, String label, {int count = 1}) {
    final query = queries[index];
    query.reply.complete(
      List<Object>.generate(count, (rowIndex) {
        final rowLabel = count == 1 ? label : '$label $rowIndex';
        if (isReports) {
          return AdminUserReportItem(
            id: rowLabel,
            reporterId: 'reporter',
            reporterName: 'Fixture reporter',
            reportedId: 'reported',
            reportedName: 'Fixture reported user',
            category: 'other',
            details: rowLabel,
            status: query.status ?? 'open',
          );
        }
        return AdminTripListItem(
          id: rowLabel,
          authorId: 'author',
          authorName: rowLabel,
          origin: 'Kigali',
          destination: 'Huye',
          role: query.role ?? 'driver',
          vehicleType: 'cab',
          status: query.status ?? 'active',
          isActive: query.status != 'cancelled',
        );
      }),
    );
  }

  void fail(int index, String message) {
    queries[index].reply.completeError(StateError(message));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester,
    _Admin service, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 1100);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: service.isReports
              ? AdminReportsScreen(onBack: () {})
              : AdminTripsScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(service.queries, hasLength(1));
    expect(service.queries.single.limit, 26);
    expect(service.queries.single.offset, 0);
  }

  Future<void> search(WidgetTester tester, _Admin service) async {
    await tester.enterText(find.byType(TextField), 'Newer');
    await tester.pump();
    expect(service.queries, hasLength(2));
    expect(service.queries.last.search, 'Newer');
  }

  for (final language in ['en', 'fr']) {
    final unavailable = language == 'fr' ? 'Indisponible' : 'Unavailable';
    for (final contacts
        in <({String name, String? reporterPhone, String? reportedPhone})>[
          (name: 'absent', reporterPhone: null, reportedPhone: null),
          (
            name: 'whitespace-only',
            reporterPhone: ' \t ',
            reportedPhone: '\n  ',
          ),
          (
            name: 'real',
            reporterPhone: ' +250788111222 ',
            reportedPhone: '+250788333444',
          ),
        ]) {
      testWidgets(
        'reports ${contacts.name} phones preserve safe localized contacts '
        'in row and Details ($language)',
        (tester) async {
          final service = _Admin(isReports: true);
          await mount(tester, service, locale: Locale(language));
          service.queries.single.reply.complete([
            AdminUserReportItem(
              id: 'contact-report',
              reporterId: 'internal-reporter-id',
              reporterName: 'Fixture reporter',
              reporterPhone: contacts.reporterPhone,
              reportedId: 'internal-reported-id',
              reportedName: 'Fixture reported user',
              reportedPhone: contacts.reportedPhone,
              category: 'other',
              details: 'Contact fallback regression',
              status: 'open',
            ),
          ]);
          await tester.pumpAndSettle();

          void expectContacts(Finder scope) {
            for (final contact in [
              (label: 'Reporter', phone: contacts.reporterPhone),
              (label: 'Reported', phone: contacts.reportedPhone),
            ]) {
              final field = find.descendant(
                of: scope,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is AdminFieldPair && widget.label == contact.label,
                ),
              );
              expect(field, findsOneWidget);
              final expectedPhone = contacts.name == 'real'
                  ? contact.phone!.trim()
                  : unavailable;
              expect(
                find.descendant(of: field, matching: find.text(expectedPhone)),
                findsOneWidget,
              );
            }
            expect(find.textContaining('internal-reporter-id'), findsNothing);
            expect(find.textContaining('internal-reported-id'), findsNothing);
          }

          expectContacts(find.byType(AdminReportsScreen));
          final details = find.widgetWithText(AdminActionChip, 'Details');
          await tester.ensureVisible(details);
          await tester.pumpAndSettle();
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(find.text('Report details'), findsOneWidget);
          expectContacts(find.byType(BottomSheet));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final isReports in [true, false]) {
    final screen = isReports ? 'reports' : 'trips';

    testWidgets('$screen pagination requests retain the selected filters', (
      tester,
    ) async {
      final service = _Admin(isReports: isReports);
      await mount(tester, service);
      service.succeed(0, 'Initial result');
      await tester.pumpAndSettle();

      await search(tester, service);
      service.succeed(1, 'Newer search result');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          AdminFilterChip,
          isReports ? 'Reviewing' : 'Cancelled',
        ),
      );
      await tester.pump();
      expect(service.queries, hasLength(3));
      service.succeed(2, 'Newer status result');
      await tester.pumpAndSettle();

      if (!isReports) {
        await tester.tap(find.widgetWithText(AdminFilterChip, 'Drivers'));
        await tester.pump();
        expect(service.queries, hasLength(4));
        service.succeed(3, 'Newer role result');
        await tester.pumpAndSettle();
      }

      void expectRetainedFilters(_Query query) {
        expect(query.search, 'Newer');
        expect(query.status, isReports ? 'reviewing' : 'cancelled');
        expect(query.role, isReports ? null : 'driver');
      }

      final pagination = find.byType(AdminPaginationBar);
      final rowsMenu = find.descendant(
        of: pagination,
        matching: find.byType(DropdownButton<int>),
      );
      await tester.ensureVisible(rowsMenu);
      await tester.pumpAndSettle();
      await tester.tap(rowsMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();
      final rowsQueryIndex = isReports ? 3 : 4;
      expect(service.queries, hasLength(rowsQueryIndex + 1));
      final rowsQuery = service.queries.last;
      expect(rowsQuery.limit, 11);
      expect(rowsQuery.offset, 0);
      expectRetainedFilters(rowsQuery);

      service.succeed(rowsQueryIndex, 'Newer page', count: 11);
      await tester.pumpAndSettle();
      expect(find.text('Newer page 0'), findsOneWidget);
      expect(find.text('Newer page 10'), findsNothing);
      final nextPage = find.byWidgetPredicate(
        (widget) => widget is AdminIconButton && widget.label == 'Next page',
      );
      expect(tester.widget<AdminIconButton>(nextPage).onPressed, isNotNull);
      await tester.ensureVisible(nextPage);
      await tester.pumpAndSettle();
      await tester.tap(nextPage);
      await tester.pump();
      expect(service.queries, hasLength(rowsQueryIndex + 2));
      final nextQuery = service.queries.last;
      expect(nextQuery.limit, 11);
      expect(nextQuery.offset, 10);
      expectRetainedFilters(nextQuery);

      service.succeed(rowsQueryIndex + 1, 'Newer second page');
      await tester.pumpAndSettle();
      final secondPage = tester.widget<AdminPaginationBar>(pagination);
      expect(secondPage.page, 1);
      expect(secondPage.rowsPerPage, 10);

      await tester.ensureVisible(rowsMenu);
      await tester.pumpAndSettle();
      await tester.tap(rowsMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(service.queries, hasLength(rowsQueryIndex + 3));
      final resetQuery = service.queries.last;
      expect(resetQuery.limit, 26);
      expect(resetQuery.offset, 0);
      expectRetainedFilters(resetQuery);
      service.succeed(rowsQueryIndex + 2, 'Newer reset result');
      await tester.pumpAndSettle();
      expect(tester.widget<AdminPaginationBar>(pagination).page, 0);
      expect(tester.takeException(), isNull);
    });

    for (final staleFails in [false, true]) {
      final outcome = staleFails ? 'failure' : 'success';

      testWidgets('$screen ignores older $outcome after newer query succeeds', (
        tester,
      ) async {
        final service = _Admin(isReports: isReports);
        await mount(tester, service);
        await search(tester, service);
        service.succeed(1, 'Newer result');
        await tester.pumpAndSettle();
        expect(find.text('Newer result'), findsOneWidget);

        if (staleFails) {
          service.fail(0, 'Older failure');
        } else {
          service.succeed(0, 'Older result');
        }
        await tester.pumpAndSettle();
        expect(find.text('Newer result'), findsOneWidget);
        expect(find.text('Older result'), findsNothing);
        expect(find.textContaining('Older failure'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$screen older $outcome cannot finish newer query loading', (
        tester,
      ) async {
        final service = _Admin(isReports: isReports);
        await mount(tester, service);
        await search(tester, service);
        if (staleFails) {
          service.fail(0, 'Older failure');
        } else {
          service.succeed(0, 'Older result');
        }
        await tester.pump();
        expect(find.byType(LoadingSkeleton), findsWidgets);
        expect(find.textContaining('Older failure'), findsNothing);

        service.succeed(1, 'Newer result');
        await tester.pumpAndSettle();
        expect(find.byType(LoadingSkeleton), findsNothing);
        expect(find.text('Newer result'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$screen retains newer query failure after older success', (
      tester,
    ) async {
      final service = _Admin(isReports: isReports);
      await mount(tester, service);
      await search(tester, service);
      service.fail(1, 'Newer failure');
      await tester.pumpAndSettle();
      expect(find.textContaining('Newer failure'), findsOneWidget);

      service.succeed(0, 'Older result');
      await tester.pumpAndSettle();
      expect(find.textContaining('Newer failure'), findsOneWidget);
      expect(find.text('Older result'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$screen newer successful search clears previous query error', (
      tester,
    ) async {
      final service = _Admin(isReports: isReports);
      await mount(tester, service);
      service.fail(0, 'Previous failure');
      await tester.pumpAndSettle();
      expect(find.textContaining('Previous failure'), findsOneWidget);

      await search(tester, service);
      service.succeed(1, 'Newer result');
      await tester.pumpAndSettle();
      expect(find.textContaining('Previous failure'), findsNothing);
      expect(find.text('Newer result'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$screen rejects late query after account replacement', (
      tester,
    ) async {
      final service = _Admin(isReports: isReports);
      await mount(tester, service);
      await search(tester, service);
      AccountContext.changes.value++;
      service
        ..succeed(1, 'Newer result')
        ..succeed(0, 'Older result');
      await tester.pump();
      expect(find.text('Newer result'), findsNothing);
      expect(find.text('Older result'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
