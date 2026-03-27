// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AppLocalizationsRw extends AppLocalizations {
  AppLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appTitle => 'Mobio';

  @override
  String get tabDiscover => 'Shakisha';

  @override
  String get tabBioPay => 'BioPay';

  @override
  String get tabProfile => 'Umwirondoro';

  @override
  String get tabDashboard => 'Ikibaho';

  @override
  String get tabUsers => 'Abakoresha';

  @override
  String get modePassenger => 'Ugendesha';

  @override
  String get modeDriver => 'Umushoferi';

  @override
  String get errorGeneric => 'Hari ikibazo cyabaye';

  @override
  String get errorNoNetwork => 'Nta murandasi';

  @override
  String get tryAgain => 'Ongera ugerageze';

  @override
  String get cancel => 'Hagarika';

  @override
  String get save => 'Bika';

  @override
  String get done => 'Byarangiye';

  @override
  String get loading => 'Gutegereza…';

  @override
  String get noResults => 'Nta bisubizo byabonetse';

  @override
  String get darkMode => 'Uburyo bwijimye';

  @override
  String get editProfile => 'Hindura umwirondoro';

  @override
  String get configErrorTitle => 'Ntibishoboye gutangira Mobio';

  @override
  String get configErrorBody =>
      'Iyi APK yubatswe nta SUPABASE_URL na SUPABASE_ANON_KEY.';

  @override
  String get configErrorAction =>
      'Ongera wubake porogaramu ukoresheje --dart-define byombi.';

  @override
  String get whatsappOpenChat => 'Fungura WhatsApp';

  @override
  String get scheduleTrip => 'Teganya urugendo';

  @override
  String get viewBookings => 'Amategurwa';

  @override
  String get nearby => 'Hafi';
}
