import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/bookings/trip_details_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/ev_chargers/ev_charger_locator_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

void main() {
  Future<void> pumpPreview(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ScheduleTripScreen local preview does not require Supabase', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      ScheduleTripScreen(
        mode: 'passenger',
        onModeChanged: (_) {},
        onBack: () {},
      ),
    );

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Kigali Heights, KG 7 Ave, Kigali'), findsOneWidget);
    expect(find.text('Departure location'), findsNothing);
    expect(find.text('Drop off location'), findsOneWidget);
    expect(find.text('Destination location'), findsNothing);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Airport'), findsWidgets);
    final pickupField = tester.widget<TextField>(find.byType(TextField).first);
    expect(pickupField.controller?.text, 'Kigali Heights, KG 7 Ave, Kigali');
    expect(
      pickupField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
    final dropOffField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(
      dropOffField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
    final scheduleButton = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Schedule').last,
    );
    expect(scheduleButton.onPressed, isNull);
    expect(find.text('Requirements or details'), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note').last);
    await tester.pumpAndSettle();
    expect(find.text('Requirements or details'), findsOneWidget);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen local preview does not require Supabase', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      ProfileScreen(
        isDarkMode: true,
        onDarkModeChanged: (_) {},
        onEditProfile: () {},
        onNfcWriteCard: () {},
        onAdminGateway: () {},
      ),
    );

    expect(find.text('482013'), findsWidgets);
    expect(find.text('BioPay Face'), findsOneWidget);
    expect(find.text('Write NFC Card'), findsOneWidget);
    expect(find.text('Enroll AWS face identity'), findsNothing);
    expect(find.text('Set up'), findsWidgets);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EditProfileScreen local preview shows bus onboarding details', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      EditProfileScreen(isFirstRun: true, onBack: () {}),
    );

    expect(find.text('Set up profile'), findsWidgets);
    expect(find.text('Bus details'), findsOneWidget);
    expect(find.text('Volcano Express'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TripChatScreen local preview does not require Supabase', (
    tester,
  ) async {
    await pumpPreview(tester, TripChatScreen(onBack: () {}));

    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Private'), findsNothing);
    expect(find.text('TRIP CONTEXT'), findsNothing);
    expect(find.text('TRIP'), findsOneWidget);
    expect(find.text('In-app'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TripDetailsScreen keeps scheduled coordination note', (
    tester,
  ) async {
    await pumpPreview(tester, TripDetailsScreen(tripId: 't1', onBack: () {}));

    expect(
      find.text(
        'Coordinate pick up, timing, luggage, fare, and seats, directly via chat',
      ),
      findsOneWidget,
    );
    expect(find.text('Pick up'), findsOneWidget);
    expect(find.text('Drop off'), findsOneWidget);
    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('Seats'), findsOneWidget);
    expect(find.text('Fare'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
    final chatButton = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Chat'),
    );
    expect(chatButton.onPressed, isNotNull);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EvChargerLocatorScreen local preview lists top chargers', (
    tester,
  ) async {
    await pumpPreview(tester, EvChargerLocatorScreen(onBack: () {}));

    expect(find.text('EV Charger'), findsWidgets);
    expect(find.text('Find nearby EV Chargers'), findsOneWidget);
    expect(find.text('Kigali Heights, KG 7 Ave, Kigali'), findsOneWidget);
    expect(find.text('Kigali Heights EV Hub'), findsOneWidget);
    expect(find.text('Open on Google Maps'), findsOneWidget);
    expect(find.text('Find EV chargers'), findsOneWidget);
    final mapsButton = tester.widget<MobiButton>(
      find.widgetWithText(MobiButton, 'Open on Google Maps'),
    );
    expect(mapsButton.onPressed, isNotNull);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
