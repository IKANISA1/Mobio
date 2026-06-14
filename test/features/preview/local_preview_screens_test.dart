import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/bookings/schedule_trip_screen.dart';
import 'package:mobi_app/features/chat/chat_screen.dart';
import 'package:mobi_app/features/profile/edit_profile_screen.dart';
import 'package:mobi_app/features/profile/profile_screen.dart';

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

    expect(find.text('482013'), findsOneWidget);
    expect(find.text('BioPay Face'), findsOneWidget);
    expect(find.text('Write NFC Card'), findsOneWidget);
    expect(find.text('Enroll AWS face identity'), findsNothing);
    expect(find.text('Set up'), findsOneWidget);
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
}
