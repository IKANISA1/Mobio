import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ];

  /// App name shown in title bar
  ///
  /// In en, this message translates to:
  /// **'Mobio'**
  String get appTitle;

  /// Bottom nav tab: Discover
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabDiscover;

  /// Bottom nav tab: Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Admin nav tab: Dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// Admin nav tab: Users
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get tabUsers;

  /// Transport mode: Passenger
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get modePassenger;

  /// Transport mode: Driver
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get modeDriver;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoNetwork;

  /// Retry action label
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Cancel action label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save action label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Done action label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Empty state: search results
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Settings: dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// Profile: edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Config error screen title
  ///
  /// In en, this message translates to:
  /// **'Unable to start Mobio'**
  String get configErrorTitle;

  /// Config error screen body
  ///
  /// In en, this message translates to:
  /// **'This APK was built without SUPABASE_URL and SUPABASE_ANON_KEY.'**
  String get configErrorBody;

  /// Config error screen action text
  ///
  /// In en, this message translates to:
  /// **'Rebuild the app with --dart-define values for both keys before running device UAT.'**
  String get configErrorAction;

  /// WhatsApp modal: open chat button
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get whatsappOpenChat;

  /// Action: schedule a trip
  ///
  /// In en, this message translates to:
  /// **'Schedule trip'**
  String get scheduleTrip;

  /// Action: view bookings
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get viewBookings;

  /// Action: view nearby
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rw':
      return AppLocalizationsRw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
