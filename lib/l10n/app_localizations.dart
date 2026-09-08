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

  /// No description provided for @bpPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get bpPay;

  /// No description provided for @bpRecipient.
  ///
  /// In en, this message translates to:
  /// **'Who are you paying?'**
  String get bpRecipient;

  /// No description provided for @bpPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get bpPhone;

  /// No description provided for @bpContacts.
  ///
  /// In en, this message translates to:
  /// **'Choose from contacts'**
  String get bpContacts;

  /// No description provided for @bpManual.
  ///
  /// In en, this message translates to:
  /// **'Enter receiving details'**
  String get bpManual;

  /// No description provided for @bpContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bpContinue;

  /// No description provided for @bpMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get bpMethods;

  /// No description provided for @bpAddMethod.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get bpAddMethod;

  /// No description provided for @bpSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bpSave;

  /// No description provided for @bpSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get bpSaved;

  /// No description provided for @bpNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes are not saved yet'**
  String get bpNotSaved;

  /// No description provided for @bpSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get bpSaveDraft;

  /// No description provided for @bpProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get bpProvider;

  /// No description provided for @bpMethodKind.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get bpMethodKind;

  /// No description provided for @bpIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Receiving number or account'**
  String get bpIdentifier;

  /// No description provided for @bpLabel.
  ///
  /// In en, this message translates to:
  /// **'Your label'**
  String get bpLabel;

  /// No description provided for @bpLoginPhone.
  ///
  /// In en, this message translates to:
  /// **'Banking login phone (optional)'**
  String get bpLoginPhone;

  /// No description provided for @bpSim.
  ///
  /// In en, this message translates to:
  /// **'SIM label (optional)'**
  String get bpSim;

  /// No description provided for @bpSendRole.
  ///
  /// In en, this message translates to:
  /// **'Pay from this account'**
  String get bpSendRole;

  /// No description provided for @bpReceiveRole.
  ///
  /// In en, this message translates to:
  /// **'Receive here'**
  String get bpReceiveRole;

  /// No description provided for @bpDiscoverable.
  ///
  /// In en, this message translates to:
  /// **'Share with people who know my verified phone'**
  String get bpDiscoverable;

  /// No description provided for @bpPreferred.
  ///
  /// In en, this message translates to:
  /// **'Use as my preferred source'**
  String get bpPreferred;

  /// No description provided for @bpPrivateDefault.
  ///
  /// In en, this message translates to:
  /// **'Private until you choose to share'**
  String get bpPrivateDefault;

  /// No description provided for @bpAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (RWF)'**
  String get bpAmount;

  /// No description provided for @bpWholeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–10,000,000 whole RWF'**
  String get bpWholeAmount;

  /// No description provided for @bpPurpose.
  ///
  /// In en, this message translates to:
  /// **'Payment purpose'**
  String get bpPurpose;

  /// No description provided for @bpTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer to a person'**
  String get bpTransfer;

  /// No description provided for @bpMerchant.
  ///
  /// In en, this message translates to:
  /// **'Pay a merchant'**
  String get bpMerchant;

  /// No description provided for @bpReference.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get bpReference;

  /// No description provided for @bpFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get bpFrom;

  /// No description provided for @bpMyAccounts.
  ///
  /// In en, this message translates to:
  /// **'My accounts'**
  String get bpMyAccounts;

  /// No description provided for @bpAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'Compare my accounts'**
  String get bpAllAccounts;

  /// No description provided for @bpCompare.
  ///
  /// In en, this message translates to:
  /// **'Find payment options'**
  String get bpCompare;

  /// No description provided for @bpOptions.
  ///
  /// In en, this message translates to:
  /// **'Payment options'**
  String get bpOptions;

  /// No description provided for @bpMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get bpMore;

  /// No description provided for @bpNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No validated option for these details. Check your source account, SIM label and receiving details.'**
  String get bpNoOptions;

  /// No description provided for @bpNoShared.
  ///
  /// In en, this message translates to:
  /// **'No receiving details are shared with you. Enter the details or ask the recipient to share them.'**
  String get bpNoShared;

  /// No description provided for @bpUnverified.
  ///
  /// In en, this message translates to:
  /// **'Entered details — check with the recipient'**
  String get bpUnverified;

  /// No description provided for @bpShared.
  ///
  /// In en, this message translates to:
  /// **'Receiving details shared through Mobio'**
  String get bpShared;

  /// No description provided for @bpFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get bpFee;

  /// No description provided for @bpFeeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Fee unknown'**
  String get bpFeeUnknown;

  /// No description provided for @bpFeeCap.
  ///
  /// In en, this message translates to:
  /// **'Fee up to'**
  String get bpFeeCap;

  /// No description provided for @bpPartialFee.
  ///
  /// In en, this message translates to:
  /// **'Provider fee only; other fees unknown'**
  String get bpPartialFee;

  /// No description provided for @bpTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bpTotal;

  /// No description provided for @bpTotalCap.
  ///
  /// In en, this message translates to:
  /// **'Total up to'**
  String get bpTotalCap;

  /// No description provided for @bpReview.
  ///
  /// In en, this message translates to:
  /// **'Review payment'**
  String get bpReview;

  /// No description provided for @bpChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get bpChange;

  /// No description provided for @bpOpenProvider.
  ///
  /// In en, this message translates to:
  /// **'Open provider instructions'**
  String get bpOpenProvider;

  /// No description provided for @bpOpenMomo.
  ///
  /// In en, this message translates to:
  /// **'Open MoMo'**
  String get bpOpenMomo;

  /// No description provided for @bpOpenBank.
  ///
  /// In en, this message translates to:
  /// **'Open bank menu'**
  String get bpOpenBank;

  /// No description provided for @bpCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get bpCopy;

  /// No description provided for @bpCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get bpCopied;

  /// No description provided for @bpCopyInstructions.
  ///
  /// In en, this message translates to:
  /// **'Copy instructions'**
  String get bpCopyInstructions;

  /// No description provided for @bpSimGuidance.
  ///
  /// In en, this message translates to:
  /// **'Choose the SIM linked to your source account in the phone’s dialer.'**
  String get bpSimGuidance;

  /// No description provided for @bpExternalOnly.
  ///
  /// In en, this message translates to:
  /// **'Complete payment with your provider. Enter your PIN only there.'**
  String get bpExternalOnly;

  /// No description provided for @bpOutcome.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get bpOutcome;

  /// No description provided for @bpOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmation unavailable'**
  String get bpOutcomeUnknown;

  /// No description provided for @bpOutcomeHelp.
  ///
  /// In en, this message translates to:
  /// **'Returning to Mobio does not confirm payment. Check your provider before trying again.'**
  String get bpOutcomeHelp;

  /// No description provided for @bpUserReported.
  ///
  /// In en, this message translates to:
  /// **'You reported completion'**
  String get bpUserReported;

  /// No description provided for @bpReportDone.
  ///
  /// In en, this message translates to:
  /// **'I completed the provider steps'**
  String get bpReportDone;

  /// No description provided for @bpPrepared.
  ///
  /// In en, this message translates to:
  /// **'Ready for provider handoff'**
  String get bpPrepared;

  /// No description provided for @bpHandoff.
  ///
  /// In en, this message translates to:
  /// **'Provider handoff opened'**
  String get bpHandoff;

  /// No description provided for @bpOperatorReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by an operator'**
  String get bpOperatorReviewed;

  /// No description provided for @bpReceiverAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Recipient acknowledged'**
  String get bpReceiverAcknowledged;

  /// No description provided for @bpProviderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Provider confirmation received'**
  String get bpProviderConfirmed;

  /// No description provided for @bpRefreshRequired.
  ///
  /// In en, this message translates to:
  /// **'Reconnect, refresh the details and review again.'**
  String get bpRefreshRequired;

  /// No description provided for @bpRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh details'**
  String get bpRefresh;

  /// No description provided for @bpRequests.
  ///
  /// In en, this message translates to:
  /// **'Payment requests'**
  String get bpRequests;

  /// No description provided for @bpCreateRequest.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get bpCreateRequest;

  /// No description provided for @bpShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get bpShare;

  /// No description provided for @bpScope.
  ///
  /// In en, this message translates to:
  /// **'Share scope'**
  String get bpScope;

  /// No description provided for @bpProfileScope.
  ///
  /// In en, this message translates to:
  /// **'Selected receiving methods'**
  String get bpProfileScope;

  /// No description provided for @bpMethodScope.
  ///
  /// In en, this message translates to:
  /// **'One receiving method'**
  String get bpMethodScope;

  /// No description provided for @bpRequestScope.
  ///
  /// In en, this message translates to:
  /// **'Amount request'**
  String get bpRequestScope;

  /// No description provided for @bpAnyAmount.
  ///
  /// In en, this message translates to:
  /// **'Let the payer enter the amount'**
  String get bpAnyAmount;

  /// No description provided for @bpExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires on'**
  String get bpExpiry;

  /// No description provided for @bpActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get bpActive;

  /// No description provided for @bpExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bpExpired;

  /// No description provided for @bpRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get bpRevoked;

  /// No description provided for @bpRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get bpRevoke;

  /// No description provided for @bpViewAsPayer.
  ///
  /// In en, this message translates to:
  /// **'View as payer'**
  String get bpViewAsPayer;

  /// No description provided for @bpSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing controls'**
  String get bpSharing;

  /// No description provided for @bpGrantee.
  ///
  /// In en, this message translates to:
  /// **'Mobio ID (6 digits)'**
  String get bpGrantee;

  /// No description provided for @bpGrant.
  ///
  /// In en, this message translates to:
  /// **'Share with this account'**
  String get bpGrant;

  /// No description provided for @bpRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bpRemove;

  /// No description provided for @bpActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get bpActivity;

  /// No description provided for @bpRecents.
  ///
  /// In en, this message translates to:
  /// **'Recent recipients'**
  String get bpRecents;

  /// No description provided for @bpFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get bpFavorite;

  /// No description provided for @bpNickname.
  ///
  /// In en, this message translates to:
  /// **'Private nickname'**
  String get bpNickname;

  /// No description provided for @bpPayAgain.
  ///
  /// In en, this message translates to:
  /// **'Pay again'**
  String get bpPayAgain;

  /// No description provided for @bpTemplates.
  ///
  /// In en, this message translates to:
  /// **'Request templates'**
  String get bpTemplates;

  /// No description provided for @bpSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as a template'**
  String get bpSaveTemplate;

  /// No description provided for @bpUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create a fresh request'**
  String get bpUseTemplate;

  /// No description provided for @bpEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get bpEmpty;

  /// No description provided for @bpSupport.
  ///
  /// In en, this message translates to:
  /// **'Get help'**
  String get bpSupport;

  /// No description provided for @bpSupportSummary.
  ///
  /// In en, this message translates to:
  /// **'Review support summary'**
  String get bpSupportSummary;

  /// No description provided for @bpSupportNotice.
  ///
  /// In en, this message translates to:
  /// **'Only share this summary if you want support to see it.'**
  String get bpSupportNotice;

  /// No description provided for @bpScan.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get bpScan;

  /// No description provided for @bpPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste a payment link'**
  String get bpPaste;

  /// No description provided for @bpGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose QR image'**
  String get bpGallery;

  /// No description provided for @bpInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'This is not a supported Mobio payment code.'**
  String get bpInvalidQr;

  /// No description provided for @bpCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bpCancel;

  /// No description provided for @bpBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get bpBack;

  /// No description provided for @bpSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get bpSignIn;

  /// No description provided for @bpLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Request unavailable. Ask the recipient for a new link.'**
  String get bpLinkUnavailable;

  /// No description provided for @bpUsePhone.
  ///
  /// In en, this message translates to:
  /// **'Open this link on your phone to use your provider.'**
  String get bpUsePhone;

  /// No description provided for @bpManualDevice.
  ///
  /// In en, this message translates to:
  /// **'This device uses manual instructions.'**
  String get bpManualDevice;

  /// No description provided for @bpSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not enabled for sending, or missing a required SIM label'**
  String get bpSourceUnavailable;

  /// No description provided for @bpCheckFields.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted payment details.'**
  String get bpCheckFields;

  /// No description provided for @bpResume.
  ///
  /// In en, this message translates to:
  /// **'Resume saved payment'**
  String get bpResume;

  /// No description provided for @bpNewPayment.
  ///
  /// In en, this message translates to:
  /// **'New payment'**
  String get bpNewPayment;

  /// No description provided for @bpBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get bpBankAccount;

  /// No description provided for @bpBankAlias.
  ///
  /// In en, this message translates to:
  /// **'Provider-supported bank alias'**
  String get bpBankAlias;

  /// No description provided for @bpRoutes.
  ///
  /// In en, this message translates to:
  /// **'Provider routes'**
  String get bpRoutes;

  /// No description provided for @bpRouteEvidence.
  ///
  /// In en, this message translates to:
  /// **'Provider and tariff evidence'**
  String get bpRouteEvidence;

  /// No description provided for @bpAddRoute.
  ///
  /// In en, this message translates to:
  /// **'Add a route for review'**
  String get bpAddRoute;

  /// No description provided for @bpDraftRoute.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get bpDraftRoute;

  /// No description provided for @bpTestedRoute.
  ///
  /// In en, this message translates to:
  /// **'Device tests recorded'**
  String get bpTestedRoute;

  /// No description provided for @bpApprovedRoute.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get bpApprovedRoute;

  /// No description provided for @bpDisabledRoute.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get bpDisabledRoute;

  /// No description provided for @bpRecordTest.
  ///
  /// In en, this message translates to:
  /// **'Record completed device tests'**
  String get bpRecordTest;

  /// No description provided for @bpApproveRoute.
  ///
  /// In en, this message translates to:
  /// **'Approve tested version'**
  String get bpApproveRoute;

  /// No description provided for @bpDisableRoute.
  ///
  /// In en, this message translates to:
  /// **'Disable this route'**
  String get bpDisableRoute;

  /// No description provided for @bpRouteNotice.
  ///
  /// In en, this message translates to:
  /// **'Entry roots are research evidence. A complete tested instruction and independent review are required before activation.'**
  String get bpRouteNotice;

  /// No description provided for @bpDestinationProvider.
  ///
  /// In en, this message translates to:
  /// **'Receiving provider'**
  String get bpDestinationProvider;

  /// No description provided for @bpRail.
  ///
  /// In en, this message translates to:
  /// **'Payment rail'**
  String get bpRail;

  /// No description provided for @bpMinAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum RWF'**
  String get bpMinAmount;

  /// No description provided for @bpMaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Maximum RWF'**
  String get bpMaxAmount;

  /// No description provided for @bpExactFee.
  ///
  /// In en, this message translates to:
  /// **'Exact fee'**
  String get bpExactFee;

  /// No description provided for @bpCappedFee.
  ///
  /// In en, this message translates to:
  /// **'Fee ceiling'**
  String get bpCappedFee;

  /// No description provided for @bpAllInFee.
  ///
  /// In en, this message translates to:
  /// **'Includes all fees'**
  String get bpAllInFee;

  /// No description provided for @bpSteps.
  ///
  /// In en, this message translates to:
  /// **'Verified step count (optional)'**
  String get bpSteps;

  /// No description provided for @bpInstruction.
  ///
  /// In en, this message translates to:
  /// **'Validated instruction template'**
  String get bpInstruction;

  /// No description provided for @bpInstructionHelp.
  ///
  /// In en, this message translates to:
  /// **'Use recipient and amount placeholders. Never include a PIN or credential.'**
  String get bpInstructionHelp;

  /// No description provided for @bpDeviceEvidence.
  ///
  /// In en, this message translates to:
  /// **'Device test evidence URL'**
  String get bpDeviceEvidence;

  /// No description provided for @bpTariffEvidence.
  ///
  /// In en, this message translates to:
  /// **'Tariff evidence URL'**
  String get bpTariffEvidence;

  /// No description provided for @bpRequiresSim.
  ///
  /// In en, this message translates to:
  /// **'Requires a linked SIM'**
  String get bpRequiresSim;

  /// No description provided for @bpRequiresLoginPhone.
  ///
  /// In en, this message translates to:
  /// **'Requires banking login phone'**
  String get bpRequiresLoginPhone;

  /// No description provided for @bpDialMode.
  ///
  /// In en, this message translates to:
  /// **'User-controlled dialer'**
  String get bpDialMode;

  /// No description provided for @bpManualMode.
  ///
  /// In en, this message translates to:
  /// **'Manual instructions'**
  String get bpManualMode;

  /// No description provided for @bpReviewVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get bpReviewVersion;

  /// No description provided for @bpNfcWrite.
  ///
  /// In en, this message translates to:
  /// **'Write NFC card'**
  String get bpNfcWrite;

  /// No description provided for @bpNfcHold.
  ///
  /// In en, this message translates to:
  /// **'Hold the card near your phone'**
  String get bpNfcHold;

  /// No description provided for @bpNfcScoped.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved payment link. Revoking it also disables this card’s payment link.'**
  String get bpNfcScoped;

  /// No description provided for @bpNfcRecovery.
  ///
  /// In en, this message translates to:
  /// **'Check NFC is enabled and retry, or share the payment link.'**
  String get bpNfcRecovery;

  /// No description provided for @bpNfcVerified.
  ///
  /// In en, this message translates to:
  /// **'Card written and read back successfully'**
  String get bpNfcVerified;

  /// No description provided for @bpBearerScope.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can view these receiving details after signing in, until the link expires or is revoked.'**
  String get bpBearerScope;

  /// No description provided for @bpFeeReviewed.
  ///
  /// In en, this message translates to:
  /// **'Fee evidence reviewed'**
  String get bpFeeReviewed;

  /// No description provided for @bpCheckProviderFee.
  ///
  /// In en, this message translates to:
  /// **'Check the fee with your provider'**
  String get bpCheckProviderFee;

  /// No description provided for @bpValidFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from (UTC)'**
  String get bpValidFrom;

  /// No description provided for @bpValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until (UTC)'**
  String get bpValidUntil;

  /// No description provided for @bpTestEvidence.
  ///
  /// In en, this message translates to:
  /// **'Device test evidence URL'**
  String get bpTestEvidence;

  /// No description provided for @bpRecipientFormat.
  ///
  /// In en, this message translates to:
  /// **'Provider recipient format'**
  String get bpRecipientFormat;

  /// No description provided for @bpOriginalIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Original identifier'**
  String get bpOriginalIdentifier;

  /// No description provided for @bpReferenceLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'This route does not send the reference. It stays in your Mobio activity.'**
  String get bpReferenceLocalOnly;

  /// No description provided for @bpLeaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save this draft to continue later. If saving fails, your entries stay on this screen.'**
  String get bpLeaveDraft;

  /// No description provided for @bpDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get bpDiscard;

  /// No description provided for @bpDetailsChanged.
  ///
  /// In en, this message translates to:
  /// **'Receiving details changed. Create a new link.'**
  String get bpDetailsChanged;

  /// No description provided for @bpSaveQr.
  ///
  /// In en, this message translates to:
  /// **'Save QR image'**
  String get bpSaveQr;

  /// No description provided for @bpRecipientChanged.
  ///
  /// In en, this message translates to:
  /// **'Receiving details changed. Compare the options again.'**
  String get bpRecipientChanged;

  /// No description provided for @bpSourceChanged.
  ///
  /// In en, this message translates to:
  /// **'Your payment source changed. Compare the options again.'**
  String get bpSourceChanged;

  /// No description provided for @bpFeeChanged.
  ///
  /// In en, this message translates to:
  /// **'The fee evidence changed. Compare the options again.'**
  String get bpFeeChanged;

  /// No description provided for @bpRouteChanged.
  ///
  /// In en, this message translates to:
  /// **'This option or its sharing permission changed. Compare again.'**
  String get bpRouteChanged;

  /// No description provided for @bpNfcLock.
  ///
  /// In en, this message translates to:
  /// **'Make card read-only'**
  String get bpNfcLock;

  /// No description provided for @bpNfcLockNotice.
  ///
  /// In en, this message translates to:
  /// **'This permanently prevents rewriting the card. The payment link can still expire or be revoked, after which this card will no longer open a usable request. Lock only after checking the saved link.'**
  String get bpNfcLockNotice;

  /// No description provided for @bpNfcLocked.
  ///
  /// In en, this message translates to:
  /// **'Card is read-only'**
  String get bpNfcLocked;

  /// No description provided for @bpAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I received this payment'**
  String get bpAcknowledge;

  /// No description provided for @bpRecordEvidence.
  ///
  /// In en, this message translates to:
  /// **'Record external evidence'**
  String get bpRecordEvidence;

  /// No description provided for @bpEvidenceReference.
  ///
  /// In en, this message translates to:
  /// **'Evidence reference (at least 6 characters)'**
  String get bpEvidenceReference;

  /// No description provided for @bpOperatorNotice.
  ///
  /// In en, this message translates to:
  /// **'Enter the reference of evidence you reviewed. This records an operator review, not a provider-confirmed receipt.'**
  String get bpOperatorNotice;

  /// No description provided for @bpMissingSim.
  ///
  /// In en, this message translates to:
  /// **'Set this account’s SIM label in Payment methods, then compare again.'**
  String get bpMissingSim;

  /// No description provided for @bpMissingLogin.
  ///
  /// In en, this message translates to:
  /// **'Add this bank account’s login phone in Payment methods, then compare again.'**
  String get bpMissingLogin;
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
