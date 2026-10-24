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

  /// No description provided for @faceRegister.
  ///
  /// In en, this message translates to:
  /// **'Register my face'**
  String get faceRegister;

  /// No description provided for @faceScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay'**
  String get faceScanTitle;

  /// No description provided for @faceScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the person you want to pay.'**
  String get faceScanInstruction;

  /// No description provided for @faceRegisterInstruction.
  ///
  /// In en, this message translates to:
  /// **'Place your face in the frame.'**
  String get faceRegisterInstruction;

  /// No description provided for @faceConsent.
  ///
  /// In en, this message translates to:
  /// **'Let people find your receiving MoMo number by scanning your face. You can remove this at any time.'**
  String get faceConsent;

  /// No description provided for @faceReceivingMethod.
  ///
  /// In en, this message translates to:
  /// **'Receiving MoMo number'**
  String get faceReceivingMethod;

  /// No description provided for @faceManageMethods.
  ///
  /// In en, this message translates to:
  /// **'Add or edit receiving numbers'**
  String get faceManageMethods;

  /// No description provided for @faceStartCamera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get faceStartCamera;

  /// No description provided for @faceCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture once'**
  String get faceCapture;

  /// No description provided for @faceScanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan recipient'**
  String get faceScanAction;

  /// No description provided for @faceUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update face'**
  String get faceUpdate;

  /// No description provided for @facePause.
  ///
  /// In en, this message translates to:
  /// **'Pause face lookup'**
  String get facePause;

  /// No description provided for @faceResume.
  ///
  /// In en, this message translates to:
  /// **'Resume face lookup'**
  String get faceResume;

  /// No description provided for @faceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove my face'**
  String get faceRemove;

  /// No description provided for @faceReady.
  ///
  /// In en, this message translates to:
  /// **'Face setup saved'**
  String get faceReady;

  /// No description provided for @faceProcessing.
  ///
  /// In en, this message translates to:
  /// **'Saving your face setup…'**
  String get faceProcessing;

  /// No description provided for @facePaused.
  ///
  /// In en, this message translates to:
  /// **'Face lookup is paused'**
  String get facePaused;

  /// No description provided for @faceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Your face setup is removed'**
  String get faceRemoved;

  /// No description provided for @faceReenroll.
  ///
  /// In en, this message translates to:
  /// **'Update your face setup to continue using Scan to pay.'**
  String get faceReenroll;

  /// No description provided for @faceOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening MoMo…'**
  String get faceOpening;

  /// No description provided for @faceOpened.
  ///
  /// In en, this message translates to:
  /// **'Continue in your dialer. MoMo handles the amount and PIN.'**
  String get faceOpened;

  /// No description provided for @faceManualPlatform.
  ///
  /// In en, this message translates to:
  /// **'Automatic USSD opening is available on Android. Copy this code and use a supported phone.'**
  String get faceManualPlatform;

  /// No description provided for @faceCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy USSD code'**
  String get faceCopyCode;

  /// No description provided for @faceCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get faceCopied;

  /// No description provided for @faceNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching recipient. Try again or use a number or QR.'**
  String get faceNoMatch;

  /// No description provided for @faceAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'No clear match. Try another capture or use a number or QR.'**
  String get faceAmbiguous;

  /// No description provided for @faceNoFace.
  ///
  /// In en, this message translates to:
  /// **'No face found. Keep the face inside the frame.'**
  String get faceNoFace;

  /// No description provided for @faceMultiple.
  ///
  /// In en, this message translates to:
  /// **'Keep only one face in the frame.'**
  String get faceMultiple;

  /// No description provided for @facePoorCapture.
  ///
  /// In en, this message translates to:
  /// **'Use more light and hold the camera steady.'**
  String get facePoorCapture;

  /// No description provided for @faceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Face lookup is unavailable. Try again or use a number or QR.'**
  String get faceUnavailable;

  /// No description provided for @faceRecipientUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This recipient has no available receiving number. Use a number or QR.'**
  String get faceRecipientUnavailable;

  /// No description provided for @faceCameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check permission, then try again.'**
  String get faceCameraError;

  /// No description provided for @faceTimeout.
  ///
  /// In en, this message translates to:
  /// **'This is taking too long. Try again.'**
  String get faceTimeout;

  /// No description provided for @faceOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The result is unconfirmed. Check the current status or activity before trying again.'**
  String get faceOutcomeUnknown;

  /// No description provided for @faceSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get faceSignIn;

  /// No description provided for @faceSelectMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a receiving MoMo number first.'**
  String get faceSelectMethod;

  /// No description provided for @faceDialFailed.
  ///
  /// In en, this message translates to:
  /// **'The dialer could not open. Copy the code or try another method.'**
  String get faceDialFailed;

  /// No description provided for @faceManual.
  ///
  /// In en, this message translates to:
  /// **'Use a number'**
  String get faceManual;

  /// No description provided for @faceQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get faceQr;

  /// No description provided for @faceTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get faceTryAgain;

  /// No description provided for @faceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get faceDone;

  /// No description provided for @faceWorking.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get faceWorking;

  /// No description provided for @faceSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get faceSetUp;

  /// No description provided for @faceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check setup status'**
  String get faceRefresh;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsersTitle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Directory and roles.'**
  String get adminUsersSubtitle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminClear;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get adminDirectory;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Search and filter'**
  String get adminSearchAndFilter;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get adminSearchUsers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFilterAll;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get adminFilterAdmins;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get adminFilterDrivers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get adminFilterPassengers;

  /// Profile role label only. This does not confer trusted administrative access.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get adminRoleDriver;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get adminRolePassenger;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Role unavailable'**
  String get adminRoleUnknown;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Review {role}'**
  String adminReviewRole(String role);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get adminUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get adminOnline;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get adminOffline;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get adminPhone;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get adminVehicle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get adminNotAssigned;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get adminJoined;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Driver profile'**
  String get adminDriverProfile;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Passenger profile'**
  String get adminPassengerProfile;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Matching users'**
  String get adminMatchingUsers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Admin profiles'**
  String get adminAdminProfiles;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This page at snapshot time'**
  String get adminPageAtSnapshot;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Exact count unavailable'**
  String get adminCountUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Exact matching count unavailable'**
  String get adminMatchingCountUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Users unavailable'**
  String get adminUsersUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to load users. Check your connection and try again.'**
  String get adminUsersLoadFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This account changed'**
  String get adminAccountChangedTitle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Open the user directory again with the current account.'**
  String get adminAccountChangedBody;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This account changed. Close this panel.'**
  String get adminAccountPanelChanged;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get adminNoUsers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Try another filter.'**
  String get adminTryFilter;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the directory. Try again.'**
  String get adminQueryFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to update this user. Refresh and try again.'**
  String get adminUserUpdateFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This review is no longer available.'**
  String get adminReviewUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to show this review. Refresh users before reviewing again.'**
  String get adminReviewShowFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue this review. Check its recorded status before starting another.'**
  String get adminReviewContinueFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Status could not be confirmed. This batch remains unresolved.'**
  String get adminStatusUnconfirmed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Close this role change batch?'**
  String get adminCloseBatchTitle;

  /// Explicit server seal; confirmed effects stay. Cancellation of a local unsent review is a separate action.
  ///
  /// In en, this message translates to:
  /// **'Stop remaining changes and record final status. Confirmed changes remain. Another review becomes available after the server confirms closure.'**
  String get adminCloseBatchBody;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Close batch'**
  String get adminCloseBatch;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Close this batch'**
  String get adminCloseThisBatch;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Closure could not be confirmed. Check this batch before starting another.'**
  String get adminClosureUnconfirmed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Review profile role changes'**
  String get adminReviewTitle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'These recipients and requested roles are fixed for this review. Changing the Admin profile role does not grant trusted admin access.'**
  String get adminReviewDisclosure;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Changing the Admin profile role does not grant trusted admin access.'**
  String get adminTrustedAccessDisclosure;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This snapshot has expired. Cancel and refresh users for a new review.'**
  String get adminReviewExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Every selected profile is excluded. No role changes will be submitted.'**
  String get adminAllExcluded;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This review is no longer available. Cancel and refresh users.'**
  String get adminReviewUnavailableRefresh;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get adminConfirming;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Role change outcomes'**
  String get adminOutcomesTitle;

  /// Server proven seal-before-reserve. Zero operations submitted; do not use for unknown/missing batch.
  ///
  /// In en, this message translates to:
  /// **'Reservation closed. No role changes were submitted.'**
  String get adminReservationClosedEmpty;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This batch is closed. Its recorded outcomes remain available.'**
  String get adminBatchClosed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Some changes have an unknown outcome. Check their status and close this batch before starting another review. No change will be resent automatically.'**
  String get adminUnknownGuidance;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Check this reservation’s status and close this batch before starting another review. No change will be resent automatically.'**
  String get adminUnsealedGuidance;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get adminCheckStatus;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Excluded: your own profile'**
  String get adminOwnExcluded;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Excluded: already has the requested role'**
  String get adminSameRoleExcluded;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Your own profile is excluded from role changes.'**
  String get adminOwnProfileExcluded;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Review a profile role change'**
  String get adminReviewProfileRole;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminEnabled;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminDisabled;

  /// Authoritative server receipt confirms that this recipient change committed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get adminStatusConfirmed;

  /// Authoritative rejection is known; distinguish from an uncertain network result.
  ///
  /// In en, this message translates to:
  /// **'Known rejected'**
  String get adminStatusKnownRejected;

  /// Outcome may already have committed. Never translate this as rejected, pending-safe-retry or failed.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get adminStatusUnknown;

  /// Target operation was not started, distinct from a self/no-op exclusion.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get adminStatusNotStarted;

  /// Reviewed recipient intentionally excluded, such as self or same requested role.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get adminStatusSkipped;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get adminStatusSubmitting;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Checking previous role changes…'**
  String get adminPhaseChecking;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The recorded outcomes are shown below.'**
  String get adminPhaseReady;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Preparing the confirmed batch…'**
  String get adminPhaseReserving;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Submitting the reviewed changes…'**
  String get adminPhaseSubmitting;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Checking authoritative status…'**
  String get adminPhaseReconciling;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Closing this batch…'**
  String get adminPhaseSealing;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This batch still needs status checking and closure.'**
  String get adminPhaseUnresolved;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Role changes are currently unavailable.'**
  String get adminPhaseBlocked;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This profile changed after the snapshot. Refresh it for a new review.'**
  String get adminRejectChanged;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The reviewed profile is no longer available.'**
  String get adminRejectMissing;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Sign in again before reviewing another role change.'**
  String get adminRejectReauthenticate;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this change. It was not confirmed.'**
  String get adminRejectGeneric;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Snapshot expired. Refresh users before changing roles or opening another page.'**
  String get adminSnapshotExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Online first'**
  String get adminSortOnline;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Name A-Z'**
  String get adminSortNameAsc;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Name Z-A'**
  String get adminSortNameDesc;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminSortRole;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get adminSortNewest;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get adminMember;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminStatus;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Clear visible user selection'**
  String get adminClearVisibleSelection;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Select visible users'**
  String get adminSelectVisibleUsers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get adminClearSearch;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Sort rows'**
  String get adminSortRows;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get adminRows;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get adminPreviousPage;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get adminNextPage;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get adminBack;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Ops'**
  String get adminNavOps;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get adminNavFleet;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Agencies'**
  String get adminNavAgencies;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'EV'**
  String get adminNavEv;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get adminNavPlans;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get adminNavTrips;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminNavReports;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get adminNavHealth;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get adminNavAudit;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts'**
  String get adminNavBroadcasts;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminNavAccount;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Add insurance reward'**
  String get adminRewardTitle;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} TOKENS'**
  String adminRewardAction(String amount);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Credit {amount} TOKENS to {name}. Motor insurance purchase reward.'**
  String adminRewardConfirm(String amount, String name);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{amount} TOKENS added to {name}.'**
  String adminRewardAdded(String amount, String name);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Add TOKENS'**
  String get adminRewardSubmit;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Account reference: {id}'**
  String adminAccountReference(String id);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Member {id}'**
  String adminMemberReference(String id);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{before} → {after}'**
  String adminRoleChange(String before, String after);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Reviewed request: {before} → {after}'**
  String adminReviewedRoleChange(String before, String after);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Driver profile: {before} → {after}'**
  String adminDriverStateChange(String before, String after);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{status}: {count}'**
  String adminStatusCount(String status, String count);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Snapshot {date}'**
  String adminSnapshotAt(String date);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Snapshot {date} · expires {expiry}'**
  String adminSnapshotRange(String date, String expiry);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Sort by {label}'**
  String adminSortBy(String label);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{start}-{end} of {total}'**
  String adminPagination(String start, String end, String total);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Clear selection for {name}'**
  String adminClearSelectionFor(String name);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Select {name}'**
  String adminSelectPerson(String name);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {role}, {status}'**
  String adminPersonSemantics(String name, String role, String status);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to load members.'**
  String get adminErrorSignIn;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Your account session is unavailable.'**
  String get adminErrorSessionUnavailable;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to load members. Refresh and try again.'**
  String get adminErrorLoadMembers;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Your account session changed. Sign in again.'**
  String get adminErrorSessionChanged;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to release the previous member snapshot. Refresh to retry.'**
  String get adminErrorReleaseSnapshot;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This member snapshot expired. Refresh to load current results.'**
  String get adminErrorMemberSnapshotExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Refresh this member snapshot before navigating.'**
  String get adminErrorPageExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Refresh or finish the current review before changing roles.'**
  String get adminErrorReviewBusy;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Select members from this snapshot page.'**
  String get adminErrorSelectPage;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This review expired. Close its reservation before a new review.'**
  String get adminErrorReviewExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Recovery storage could not be verified. No role changes were submitted.'**
  String get adminErrorJournalBefore;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The reservation outcome is unknown. Reconcile or close it before another review.'**
  String get adminErrorReserveUnknown;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The reservation could not be completed. Reconcile or close it before another review.'**
  String get adminErrorReserveFailed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This batch expired. Close it before another review.'**
  String get adminErrorBatchExpired;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Recovery storage could not be verified. Remaining role changes were not submitted.'**
  String get adminErrorJournalRemaining;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This role change is not confirmed. Reconcile or close the batch.'**
  String get adminErrorChangeUnconfirmed;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This request was rejected. Close the batch before another review.'**
  String get adminErrorRequestRejected;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'A role change outcome is unknown. Reconcile or close the batch.'**
  String get adminErrorChangeUnknown;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Review the recipient outcomes, then close this batch before another review.'**
  String get adminErrorReviewOutcomes;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'An earlier reservation is uncertain and another batch is open. Close the earlier reservation first.'**
  String get adminErrorEarlierUncertain;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'The reservation outcome is unknown. Close it to prevent a delayed submission.'**
  String get adminErrorDelayedReservation;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'An outstanding batch was found. Review its outcomes and close it before another review.'**
  String get adminErrorOutstanding;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Recovery could not be verified. No role changes will be replayed.'**
  String get adminErrorRecoveryUnverified;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Closure could not be verified. Reconcile or close this reservation again.'**
  String get adminErrorClosureUnverified;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current member update.'**
  String get adminErrorMemberBusy;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'This action could not be completed. Check the recorded status before continuing.'**
  String get adminErrorGeneric;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your internet and try again.'**
  String get adminErrorNetwork;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get adminErrorForbidden;

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Confirm 0 changes} one{Confirm 1 change} other{Confirm {countText} changes}}'**
  String adminConfirmCount(int count, String countText);

  /// Independent eligible and excluded counts from the exact immutable reviewed recipients, not all query matches.
  ///
  /// In en, this message translates to:
  /// **'{eligible, plural, =0{0 changes} one{1 change} other{{eligibleText} changes}} · {excluded, plural, =0{0 excluded} one{1 excluded} other{{excludedText} excluded}}'**
  String adminReviewSummary(
    int eligible,
    String eligibleText,
    int excluded,
    String excludedText,
  );

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 matching users} one{1 matching user} other{{countText} matching users}}'**
  String adminMatchingCount(int count, String countText);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 selected on this page} one{1 selected on this page} other{{countText} selected on this page}}'**
  String adminSelectedCount(int count, String countText);

  /// Conservative age upper bound. Preserve up to / at most meaning; never minimum age.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =0{Snapshot age up to 0s.} one{Snapshot age up to 1s.} other{Snapshot age up to {secondsText}s.}}'**
  String adminSnapshotAgeUpper(int seconds, String secondsText);

  /// Exact age wording only when caller explicitly supplies upperBound=false.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =0{Snapshot age 0s.} one{Snapshot age 1s.} other{Snapshot age {secondsText}s.}}'**
  String adminSnapshotAgeExact(int seconds, String secondsText);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =0{Snapshot review remains available for 0s.} one{Snapshot review remains available for 1s.} other{Snapshot review remains available for {secondsText}s.}}'**
  String adminSnapshotRemaining(int seconds, String secondsText);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'Snapshot review expires in {duration}.'**
  String adminReviewRemaining(String duration);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =0{0s} one{1s} other{{secondsText}s}}'**
  String adminDurationSeconds(int seconds, String secondsText);

  /// Admin users/review/recovery presentation. Translate copy only; preserve immutable IDs, role/status/sort protocol and no-replay/explicit closure semantics.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{0m} one{1m} other{{minutesText}m}} {seconds, plural, =0{0s} one{1s} other{{secondsText}s}}'**
  String adminDurationMinutesSeconds(
    int minutes,
    String minutesText,
    int seconds,
    String secondsText,
  );

  /// A mutation may already have committed. Never imply failure or safe resend; check recorded authoritative status first.
  ///
  /// In en, this message translates to:
  /// **'The result could not be confirmed. Check its recorded status before another submission.'**
  String get adminErrorMutationUnknown;
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
