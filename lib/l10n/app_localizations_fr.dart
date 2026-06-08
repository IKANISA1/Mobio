// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Mobio';

  @override
  String get tabDiscover => 'Découvrir';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabDashboard => 'Tableau de bord';

  @override
  String get tabUsers => 'Utilisateurs';

  @override
  String get modePassenger => 'Passager';

  @override
  String get modeDriver => 'Chauffeur';

  @override
  String get errorGeneric => 'Quelque chose a mal tourné';

  @override
  String get errorNoNetwork => 'Pas de connexion Internet';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get done => 'Terminé';

  @override
  String get loading => 'Chargement…';

  @override
  String get noResults => 'Aucun résultat trouvé';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get configErrorTitle => 'Impossible de démarrer Mobio';

  @override
  String get configErrorBody =>
      'Cet APK a été compilé sans SUPABASE_URL et SUPABASE_ANON_KEY.';

  @override
  String get configErrorAction =>
      'Recompilez l\'application avec les valeurs --dart-define pour les deux clés.';

  @override
  String get whatsappOpenChat => 'Ouvrir WhatsApp';

  @override
  String get scheduleTrip => 'Planifier un trajet';

  @override
  String get viewBookings => 'Réservations';

  @override
  String get nearby => 'À proximité';
}
