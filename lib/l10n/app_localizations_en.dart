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

  @override
  String get bpPay => 'Pay';

  @override
  String get bpRecipient => 'Who are you paying?';

  @override
  String get bpPhone => 'Phone number';

  @override
  String get bpContacts => 'Choose from contacts';

  @override
  String get bpManual => 'Enter receiving details';

  @override
  String get bpContinue => 'Continue';

  @override
  String get bpMethods => 'Payment methods';

  @override
  String get bpAddMethod => 'Add payment method';

  @override
  String get bpSave => 'Save';

  @override
  String get bpSaved => 'Saved';

  @override
  String get bpNotSaved => 'Changes are not saved yet';

  @override
  String get bpSaveDraft => 'Save for later';

  @override
  String get bpProvider => 'Provider';

  @override
  String get bpMethodKind => 'Account type';

  @override
  String get bpIdentifier => 'Receiving number or account';

  @override
  String get bpLabel => 'Your label';

  @override
  String get bpLoginPhone => 'Banking login phone (optional)';

  @override
  String get bpSim => 'SIM label (optional)';

  @override
  String get bpSendRole => 'Pay from this account';

  @override
  String get bpReceiveRole => 'Receive here';

  @override
  String get bpDiscoverable => 'Share with people who know my verified phone';

  @override
  String get bpPreferred => 'Use as my preferred source';

  @override
  String get bpPrivateDefault => 'Private until you choose to share';

  @override
  String get bpAmount => 'Amount (RWF)';

  @override
  String get bpWholeAmount => 'Enter 1–10,000,000 whole RWF';

  @override
  String get bpPurpose => 'Payment purpose';

  @override
  String get bpTransfer => 'Transfer to a person';

  @override
  String get bpMerchant => 'Pay a merchant';

  @override
  String get bpReference => 'Reference (optional)';

  @override
  String get bpFrom => 'From';

  @override
  String get bpMyAccounts => 'My accounts';

  @override
  String get bpAllAccounts => 'Compare my accounts';

  @override
  String get bpCompare => 'Find payment options';

  @override
  String get bpOptions => 'Payment options';

  @override
  String get bpMore => 'More options';

  @override
  String get bpNoOptions =>
      'No validated option for these details. Check your source account, SIM label and receiving details.';

  @override
  String get bpNoShared =>
      'No receiving details are shared with you. Enter the details or ask the recipient to share them.';

  @override
  String get bpUnverified => 'Entered details — check with the recipient';

  @override
  String get bpShared => 'Receiving details shared through Mobio';

  @override
  String get bpFee => 'Fee';

  @override
  String get bpFeeUnknown => 'Fee unknown';

  @override
  String get bpFeeCap => 'Fee up to';

  @override
  String get bpPartialFee => 'Provider fee only; other fees unknown';

  @override
  String get bpTotal => 'Total';

  @override
  String get bpTotalCap => 'Total up to';

  @override
  String get bpReview => 'Review payment';

  @override
  String get bpChange => 'Change';

  @override
  String get bpOpenProvider => 'Open provider instructions';

  @override
  String get bpOpenMomo => 'Open MoMo';

  @override
  String get bpOpenBank => 'Open bank menu';

  @override
  String get bpCopy => 'Copy';

  @override
  String get bpCopied => 'Copied';

  @override
  String get bpCopyInstructions => 'Copy instructions';

  @override
  String get bpSimGuidance =>
      'Choose the SIM linked to your source account in the phone’s dialer.';

  @override
  String get bpExternalOnly =>
      'Complete payment with your provider. Enter your PIN only there.';

  @override
  String get bpOutcome => 'Payment status';

  @override
  String get bpOutcomeUnknown => 'Payment confirmation unavailable';

  @override
  String get bpOutcomeHelp =>
      'Returning to Mobio does not confirm payment. Check your provider before trying again.';

  @override
  String get bpUserReported => 'You reported completion';

  @override
  String get bpReportDone => 'I completed the provider steps';

  @override
  String get bpPrepared => 'Ready for provider handoff';

  @override
  String get bpHandoff => 'Provider handoff opened';

  @override
  String get bpOperatorReviewed => 'Reviewed by an operator';

  @override
  String get bpReceiverAcknowledged => 'Recipient acknowledged';

  @override
  String get bpProviderConfirmed => 'Provider confirmation received';

  @override
  String get bpRefreshRequired =>
      'Reconnect, refresh the details and review again.';

  @override
  String get bpRefresh => 'Refresh details';

  @override
  String get bpRequests => 'Payment requests';

  @override
  String get bpCreateRequest => 'Create request';

  @override
  String get bpShare => 'Share';

  @override
  String get bpScope => 'Share scope';

  @override
  String get bpProfileScope => 'Selected receiving methods';

  @override
  String get bpMethodScope => 'One receiving method';

  @override
  String get bpRequestScope => 'Amount request';

  @override
  String get bpAnyAmount => 'Let the payer enter the amount';

  @override
  String get bpExpiry => 'Expires on';

  @override
  String get bpActive => 'Active';

  @override
  String get bpExpired => 'Expired';

  @override
  String get bpRevoked => 'Revoked';

  @override
  String get bpRevoke => 'Revoke link';

  @override
  String get bpViewAsPayer => 'View as payer';

  @override
  String get bpSharing => 'Sharing controls';

  @override
  String get bpGrantee => 'Mobio ID (6 digits)';

  @override
  String get bpGrant => 'Share with this account';

  @override
  String get bpRemove => 'Remove';

  @override
  String get bpActivity => 'Activity';

  @override
  String get bpRecents => 'Recent recipients';

  @override
  String get bpFavorite => 'Favorite';

  @override
  String get bpNickname => 'Private nickname';

  @override
  String get bpPayAgain => 'Pay again';

  @override
  String get bpTemplates => 'Request templates';

  @override
  String get bpSaveTemplate => 'Save as a template';

  @override
  String get bpUseTemplate => 'Create a fresh request';

  @override
  String get bpEmpty => 'Nothing here yet';

  @override
  String get bpSupport => 'Get help';

  @override
  String get bpSupportSummary => 'Review support summary';

  @override
  String get bpSupportNotice =>
      'Only share this summary if you want support to see it.';

  @override
  String get bpScan => 'Scan QR';

  @override
  String get bpPaste => 'Paste a payment link';

  @override
  String get bpGallery => 'Choose QR image';

  @override
  String get bpInvalidQr => 'This is not a supported Mobio payment code.';

  @override
  String get bpCancel => 'Cancel';

  @override
  String get bpBack => 'Back';

  @override
  String get bpSignIn => 'Sign in to continue';

  @override
  String get bpLinkUnavailable =>
      'Request unavailable. Ask the recipient for a new link.';

  @override
  String get bpUsePhone => 'Open this link on your phone to use your provider.';

  @override
  String get bpManualDevice => 'This device uses manual instructions.';

  @override
  String get bpSourceUnavailable =>
      'Not enabled for sending, or missing a required SIM label';

  @override
  String get bpCheckFields => 'Check the highlighted payment details.';

  @override
  String get bpResume => 'Resume saved payment';

  @override
  String get bpNewPayment => 'New payment';

  @override
  String get bpBankAccount => 'Bank account';

  @override
  String get bpBankAlias => 'Provider-supported bank alias';

  @override
  String get bpRoutes => 'Provider routes';

  @override
  String get bpRouteEvidence => 'Provider and tariff evidence';

  @override
  String get bpAddRoute => 'Add a route for review';

  @override
  String get bpDraftRoute => 'Draft';

  @override
  String get bpTestedRoute => 'Device tests recorded';

  @override
  String get bpApprovedRoute => 'Approved';

  @override
  String get bpDisabledRoute => 'Disabled';

  @override
  String get bpRecordTest => 'Record completed device tests';

  @override
  String get bpApproveRoute => 'Approve tested version';

  @override
  String get bpDisableRoute => 'Disable this route';

  @override
  String get bpRouteNotice =>
      'Entry roots are research evidence. A complete tested instruction and independent review are required before activation.';

  @override
  String get bpDestinationProvider => 'Receiving provider';

  @override
  String get bpRail => 'Payment rail';

  @override
  String get bpMinAmount => 'Minimum RWF';

  @override
  String get bpMaxAmount => 'Maximum RWF';

  @override
  String get bpExactFee => 'Exact fee';

  @override
  String get bpCappedFee => 'Fee ceiling';

  @override
  String get bpAllInFee => 'Includes all fees';

  @override
  String get bpSteps => 'Verified step count (optional)';

  @override
  String get bpInstruction => 'Validated instruction template';

  @override
  String get bpInstructionHelp =>
      'Use recipient and amount placeholders. Never include a PIN or credential.';

  @override
  String get bpDeviceEvidence => 'Device test evidence URL';

  @override
  String get bpTariffEvidence => 'Tariff evidence URL';

  @override
  String get bpRequiresSim => 'Requires a linked SIM';

  @override
  String get bpRequiresLoginPhone => 'Requires banking login phone';

  @override
  String get bpDialMode => 'User-controlled dialer';

  @override
  String get bpManualMode => 'Manual instructions';

  @override
  String get bpReviewVersion => 'Version';

  @override
  String get bpNfcWrite => 'Write NFC card';

  @override
  String get bpNfcHold => 'Hold the card near your phone';

  @override
  String get bpNfcScoped =>
      'Choose a saved payment link. Revoking it also disables this card’s payment link.';

  @override
  String get bpNfcRecovery =>
      'Check NFC is enabled and retry, or share the payment link.';

  @override
  String get bpNfcVerified => 'Card written and read back successfully';

  @override
  String get bpBearerScope =>
      'Anyone with this link can view these receiving details after signing in, until the link expires or is revoked.';

  @override
  String get bpFeeReviewed => 'Fee evidence reviewed';

  @override
  String get bpCheckProviderFee => 'Check the fee with your provider';

  @override
  String get bpValidFrom => 'Valid from (UTC)';

  @override
  String get bpValidUntil => 'Valid until (UTC)';

  @override
  String get bpTestEvidence => 'Device test evidence URL';

  @override
  String get bpRecipientFormat => 'Provider recipient format';

  @override
  String get bpOriginalIdentifier => 'Original identifier';

  @override
  String get bpReferenceLocalOnly =>
      'This route does not send the reference. It stays in your Mobio activity.';

  @override
  String get bpLeaveDraft =>
      'Save this draft to continue later. If saving fails, your entries stay on this screen.';

  @override
  String get bpDiscard => 'Discard changes';

  @override
  String get bpDetailsChanged =>
      'Receiving details changed. Create a new link.';

  @override
  String get bpSaveQr => 'Save QR image';

  @override
  String get bpRecipientChanged =>
      'Receiving details changed. Compare the options again.';

  @override
  String get bpSourceChanged =>
      'Your payment source changed. Compare the options again.';

  @override
  String get bpFeeChanged =>
      'The fee evidence changed. Compare the options again.';

  @override
  String get bpRouteChanged =>
      'This option or its sharing permission changed. Compare again.';

  @override
  String get bpNfcLock => 'Make card read-only';

  @override
  String get bpNfcLockNotice =>
      'This permanently prevents rewriting the card. The payment link can still expire or be revoked, after which this card will no longer open a usable request. Lock only after checking the saved link.';

  @override
  String get bpNfcLocked => 'Card is read-only';

  @override
  String get bpAcknowledge => 'I received this payment';

  @override
  String get bpRecordEvidence => 'Record external evidence';

  @override
  String get bpEvidenceReference =>
      'Evidence reference (at least 6 characters)';

  @override
  String get bpOperatorNotice =>
      'Enter the reference of evidence you reviewed. This records an operator review, not a provider-confirmed receipt.';

  @override
  String get bpMissingSim =>
      'Set this account’s SIM label in Payment methods, then compare again.';

  @override
  String get bpMissingLogin =>
      'Add this bank account’s login phone in Payment methods, then compare again.';

  @override
  String get faceRegister => 'Register my face';

  @override
  String get faceScanTitle => 'Scan to pay';

  @override
  String get faceScanInstruction => 'Scan the person you want to pay.';

  @override
  String get faceRegisterInstruction => 'Place your face in the frame.';

  @override
  String get faceConsent =>
      'Let people find your receiving MoMo number by scanning your face. You can remove this at any time.';

  @override
  String get faceReceivingMethod => 'Receiving MoMo number';

  @override
  String get faceManageMethods => 'Add or edit receiving numbers';

  @override
  String get faceStartCamera => 'Open camera';

  @override
  String get faceCapture => 'Capture once';

  @override
  String get faceScanAction => 'Scan recipient';

  @override
  String get faceUpdate => 'Update face';

  @override
  String get facePause => 'Pause face lookup';

  @override
  String get faceResume => 'Resume face lookup';

  @override
  String get faceRemove => 'Remove my face';

  @override
  String get faceReady => 'Face setup saved';

  @override
  String get faceProcessing => 'Saving your face setup…';

  @override
  String get facePaused => 'Face lookup is paused';

  @override
  String get faceRemoved => 'Your face setup is removed';

  @override
  String get faceReenroll =>
      'Update your face setup to continue using Scan to pay.';

  @override
  String get faceOpening => 'Opening MoMo…';

  @override
  String get faceOpened =>
      'Continue in your dialer. MoMo handles the amount and PIN.';

  @override
  String get faceManualPlatform =>
      'Automatic USSD opening is available on Android. Copy this code and use a supported phone.';

  @override
  String get faceCopyCode => 'Copy USSD code';

  @override
  String get faceCopied => 'Code copied';

  @override
  String get faceNoMatch =>
      'No matching recipient. Try again or use a number or QR.';

  @override
  String get faceAmbiguous =>
      'No clear match. Try another capture or use a number or QR.';

  @override
  String get faceNoFace => 'No face found. Keep the face inside the frame.';

  @override
  String get faceMultiple => 'Keep only one face in the frame.';

  @override
  String get facePoorCapture => 'Use more light and hold the camera steady.';

  @override
  String get faceUnavailable =>
      'Face lookup is unavailable. Try again or use a number or QR.';

  @override
  String get faceRecipientUnavailable =>
      'This recipient has no available receiving number. Use a number or QR.';

  @override
  String get faceCameraError =>
      'Camera unavailable. Check permission, then try again.';

  @override
  String get faceTimeout => 'This is taking too long. Try again.';

  @override
  String get faceOutcomeUnknown =>
      'The result is unconfirmed. Check the current status or activity before trying again.';

  @override
  String get faceSignIn => 'Sign in again to continue.';

  @override
  String get faceSelectMethod => 'Choose a receiving MoMo number first.';

  @override
  String get faceDialFailed =>
      'The dialer could not open. Copy the code or try another method.';

  @override
  String get faceManual => 'Use a number';

  @override
  String get faceQr => 'Scan QR';

  @override
  String get faceTryAgain => 'Try again';

  @override
  String get faceDone => 'Done';

  @override
  String get faceWorking => 'Please wait…';

  @override
  String get faceSetUp => 'Set up';

  @override
  String get faceRefresh => 'Check setup status';
}
