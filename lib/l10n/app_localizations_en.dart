// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mobio';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabBioPay => 'BioPay';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabUsers => 'Users';

  @override
  String get modePassenger => 'Passenger';

  @override
  String get modeDriver => 'Driver';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNoNetwork => 'No internet connection';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading…';

  @override
  String get noResults => 'No results found';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get configErrorTitle => 'Unable to start Mobio';

  @override
  String get configErrorBody =>
      'This APK was built without SUPABASE_URL and SUPABASE_ANON_KEY.';

  @override
  String get configErrorAction =>
      'Rebuild the app with --dart-define values for both keys before running device UAT.';

  @override
  String get whatsappOpenChat => 'Open WhatsApp';

  @override
  String get scheduleTrip => 'Schedule trip';

  @override
  String get viewBookings => 'Bookings';

  @override
  String get nearby => 'Nearby';
}
