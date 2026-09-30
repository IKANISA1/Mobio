import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/admin_trips_screen.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'old admin confirmation cannot dispatch after generation changes',
    (tester) async {
      final service = _TripFixture();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: AdminTripsScreen(onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      AccountContext.changes.value++;
      await tester.tap(find.widgetWithText(InkWell, 'Cancel trip'));
      await tester.pumpAndSettle();
      expect(service.cancellations, 0);
      expect(service.queries, 1);
      expect(find.text('Trip cancelled.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('unconfirmed admin cancellation preserves reconciliation copy', (
    tester,
  ) async {
    final service = _TripFixture()
      ..cancelError = const MutationOutcomeUnknownException(
        operation: 'cancel_trip',
        message: 'Cancellation is unconfirmed. Refresh before trying again.',
      );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: AdminTripsScreen(onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Cancel trip'));
    await tester.pumpAndSettle();
    expect(service.cancellations, 1);
    expect(service.queries, 1);
    expect(
      find.text('Cancellation is unconfirmed. Refresh before trying again.'),
      findsOneWidget,
    );
    expect(find.text('Trip cancelled.'), findsNothing);
    expect(find.textContaining('Cancel failed'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _TripFixture implements AdminService {
  int queries = 0;
  int cancellations = 0;
  Object? cancelError;

  @override
  Future<List<AdminTripListItem>> listTrips({
    String? status,
    String? role,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    queries++;
    return const [
      AdminTripListItem(
        id: 'trip',
        authorId: 'owner',
        authorName: 'Fixture driver',
        origin: 'Kigali',
        destination: 'Huye',
        role: 'driver',
        vehicleType: 'cab',
        status: 'active',
        isActive: true,
      ),
    ];
  }

  @override
  Future<void> cancelTrip({required String tripId, String? reason}) async {
    cancellations++;
    if (cancelError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
