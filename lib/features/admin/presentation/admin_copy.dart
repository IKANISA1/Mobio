import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/l10n/app_localizations.dart';

/// Presentation only. Never changes reviewed identities, receipts or authority.
class AdminCopy {
  const AdminCopy(this.localizations);
  final AppLocalizations localizations;
  static AdminCopy of(BuildContext context) => AdminCopy(
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en')),
  );
  String get locale => localizations.localeName;
  String get cancel => localizations.cancel;
  String get retry => localizations.tryAgain;
  String get loading => localizations.loading;

  // Intl 0.20.2 has no rw date/number symbols. Use neutral numeric dates and
  // ungrouped digits for rw; never substitute English task copy or month names.
  String get _intlLocale => locale.startsWith('rw') ? 'en' : locale;
  String number(int value) => locale.startsWith('rw')
      ? NumberFormat('0', _intlLocale).format(value)
      : NumberFormat.decimalPattern(_intlLocale).format(value);
  String date(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) return '—';
    return locale.startsWith('rw')
        ? DateFormat('yyyy-MM-dd', _intlLocale).format(parsed)
        : DateFormat.yMMMd(_intlLocale).format(parsed);
  }

  String timestamp(DateTime value) {
    final utc = value.toUtc();
    final format = locale.startsWith('rw')
        ? DateFormat('yyyy-MM-dd', _intlLocale).add_Hms()
        : DateFormat.yMMMd(_intlLocale).add_Hms();
    final fraction =
        '${utc.millisecond.toString().padLeft(3, '0')}'
        '${utc.microsecond.toString().padLeft(3, '0')}';
    return '${format.format(utc)}.$fraction UTC';
  }

  String get usersTitle => localizations.adminUsersTitle;
  String get usersSubtitle => localizations.adminUsersSubtitle;
  String get refresh => localizations.adminRefresh;
  String get close => localizations.adminClose;
  String get clear => localizations.adminClear;
  String get directory => localizations.adminDirectory;
  String get searchAndFilter => localizations.adminSearchAndFilter;
  String get searchUsers => localizations.adminSearchUsers;
  String get filterAll => localizations.adminFilterAll;
  String get filterAdmins => localizations.adminFilterAdmins;
  String get filterDrivers => localizations.adminFilterDrivers;
  String get filterPassengers => localizations.adminFilterPassengers;
  String get roleAdmin => localizations.adminRoleAdmin;
  String get roleDriver => localizations.adminRoleDriver;
  String get rolePassenger => localizations.adminRolePassenger;
  String get roleUnknown => localizations.adminRoleUnknown;
  String messageReviewRole(String role) => localizations.adminReviewRole(role);
  String get unavailable => localizations.adminUnavailable;
  String get online => localizations.adminOnline;
  String get offline => localizations.adminOffline;
  String get phone => localizations.adminPhone;
  String get vehicle => localizations.adminVehicle;
  String get notAssigned => localizations.adminNotAssigned;
  String get joined => localizations.adminJoined;
  String get driverProfile => localizations.adminDriverProfile;
  String get passengerProfile => localizations.adminPassengerProfile;
  String get matchingUsers => localizations.adminMatchingUsers;
  String get adminProfiles => localizations.adminAdminProfiles;
  String get pageAtSnapshot => localizations.adminPageAtSnapshot;
  String get countUnavailable => localizations.adminCountUnavailable;
  String get matchingCountUnavailable =>
      localizations.adminMatchingCountUnavailable;
  String get usersUnavailable => localizations.adminUsersUnavailable;
  String get usersLoadFailed => localizations.adminUsersLoadFailed;
  String get accountChangedTitle => localizations.adminAccountChangedTitle;
  String get accountChangedBody => localizations.adminAccountChangedBody;
  String get accountPanelChanged => localizations.adminAccountPanelChanged;
  String get noUsers => localizations.adminNoUsers;
  String get tryFilter => localizations.adminTryFilter;
  String get queryFailed => localizations.adminQueryFailed;
  String get userUpdateFailed => localizations.adminUserUpdateFailed;
  String get reviewUnavailable => localizations.adminReviewUnavailable;
  String get reviewShowFailed => localizations.adminReviewShowFailed;
  String get reviewContinueFailed => localizations.adminReviewContinueFailed;
  String get statusUnconfirmed => localizations.adminStatusUnconfirmed;
  String get closeBatchTitle => localizations.adminCloseBatchTitle;
  String get closeBatchBody => localizations.adminCloseBatchBody;
  String get closeBatch => localizations.adminCloseBatch;
  String get closeThisBatch => localizations.adminCloseThisBatch;
  String get closureUnconfirmed => localizations.adminClosureUnconfirmed;
  String get reviewTitle => localizations.adminReviewTitle;
  String get reviewDisclosure => localizations.adminReviewDisclosure;
  String get trustedAccessDisclosure =>
      localizations.adminTrustedAccessDisclosure;
  String get reviewExpired => localizations.adminReviewExpired;
  String get allExcluded => localizations.adminAllExcluded;
  String get reviewUnavailableRefresh =>
      localizations.adminReviewUnavailableRefresh;
  String get confirming => localizations.adminConfirming;
  String get outcomesTitle => localizations.adminOutcomesTitle;
  String get reservationClosedEmpty =>
      localizations.adminReservationClosedEmpty;
  String get batchClosed => localizations.adminBatchClosed;
  String get unknownGuidance => localizations.adminUnknownGuidance;
  String get unsealedGuidance => localizations.adminUnsealedGuidance;
  String get checkStatus => localizations.adminCheckStatus;
  String get ownExcluded => localizations.adminOwnExcluded;
  String get sameRoleExcluded => localizations.adminSameRoleExcluded;
  String get ownProfileExcluded => localizations.adminOwnProfileExcluded;
  String get reviewProfileRole => localizations.adminReviewProfileRole;
  String get enabled => localizations.adminEnabled;
  String get disabled => localizations.adminDisabled;
  String get statusConfirmed => localizations.adminStatusConfirmed;
  String get statusKnownRejected => localizations.adminStatusKnownRejected;
  String get statusUnknown => localizations.adminStatusUnknown;
  String get statusNotStarted => localizations.adminStatusNotStarted;
  String get statusSkipped => localizations.adminStatusSkipped;
  String get statusSubmitting => localizations.adminStatusSubmitting;
  String get phaseChecking => localizations.adminPhaseChecking;
  String get phaseReady => localizations.adminPhaseReady;
  String get phaseReserving => localizations.adminPhaseReserving;
  String get phaseSubmitting => localizations.adminPhaseSubmitting;
  String get phaseReconciling => localizations.adminPhaseReconciling;
  String get phaseSealing => localizations.adminPhaseSealing;
  String get phaseUnresolved => localizations.adminPhaseUnresolved;
  String get phaseBlocked => localizations.adminPhaseBlocked;
  String get rejectChanged => localizations.adminRejectChanged;
  String get rejectMissing => localizations.adminRejectMissing;
  String get rejectReauthenticate => localizations.adminRejectReauthenticate;
  String get rejectGeneric => localizations.adminRejectGeneric;
  String get snapshotExpired => localizations.adminSnapshotExpired;
  String get sortOnline => localizations.adminSortOnline;
  String get sortNameAsc => localizations.adminSortNameAsc;
  String get sortNameDesc => localizations.adminSortNameDesc;
  String get sortRole => localizations.adminSortRole;
  String get sortNewest => localizations.adminSortNewest;
  String get member => localizations.adminMember;
  String get status => localizations.adminStatus;
  String get clearVisibleSelection => localizations.adminClearVisibleSelection;
  String get selectVisibleUsers => localizations.adminSelectVisibleUsers;
  String get clearSearch => localizations.adminClearSearch;
  String get sortRows => localizations.adminSortRows;
  String get rows => localizations.adminRows;
  String get previousPage => localizations.adminPreviousPage;
  String get nextPage => localizations.adminNextPage;
  String get back => localizations.adminBack;
  String get navOps => localizations.adminNavOps;
  String get navFleet => localizations.adminNavFleet;
  String get navAgencies => localizations.adminNavAgencies;
  String get navEv => localizations.adminNavEv;
  String get navPlans => localizations.adminNavPlans;
  String get navTrips => localizations.adminNavTrips;
  String get navReports => localizations.adminNavReports;
  String get navHealth => localizations.adminNavHealth;
  String get navAudit => localizations.adminNavAudit;
  String get navBroadcasts => localizations.adminNavBroadcasts;
  String get navAccount => localizations.adminNavAccount;
  String get rewardTitle => localizations.adminRewardTitle;
  String messageRewardAction(String amount) =>
      localizations.adminRewardAction(amount);
  String messageRewardConfirm(String amount, String name) =>
      localizations.adminRewardConfirm(amount, name);
  String messageRewardAdded(String amount, String name) =>
      localizations.adminRewardAdded(amount, name);
  String get rewardSubmit => localizations.adminRewardSubmit;
  String messageAccountReference(String id) =>
      localizations.adminAccountReference(id);
  String messageMemberReference(String id) =>
      localizations.adminMemberReference(id);
  String messageRoleChange(String before, String after) =>
      localizations.adminRoleChange(before, after);
  String messageReviewedRoleChange(String before, String after) =>
      localizations.adminReviewedRoleChange(before, after);
  String messageDriverStateChange(String before, String after) =>
      localizations.adminDriverStateChange(before, after);
  String messageStatusCount(String status, String count) =>
      localizations.adminStatusCount(status, count);
  String messageSnapshotAt(String date) => localizations.adminSnapshotAt(date);
  String messageSnapshotRange(String date, String expiry) =>
      localizations.adminSnapshotRange(date, expiry);
  String messageSortBy(String label) => localizations.adminSortBy(label);
  String messagePagination(String start, String end, String total) =>
      localizations.adminPagination(start, end, total);
  String messageClearSelectionFor(String name) =>
      localizations.adminClearSelectionFor(name);
  String messageSelectPerson(String name) =>
      localizations.adminSelectPerson(name);
  String messagePersonSemantics(String name, String role, String status) =>
      localizations.adminPersonSemantics(name, role, status);
  String get errorSignIn => localizations.adminErrorSignIn;
  String get errorSessionUnavailable =>
      localizations.adminErrorSessionUnavailable;
  String get errorLoadMembers => localizations.adminErrorLoadMembers;
  String get errorSessionChanged => localizations.adminErrorSessionChanged;
  String get errorReleaseSnapshot => localizations.adminErrorReleaseSnapshot;
  String get errorMemberSnapshotExpired =>
      localizations.adminErrorMemberSnapshotExpired;
  String get errorPageExpired => localizations.adminErrorPageExpired;
  String get errorReviewBusy => localizations.adminErrorReviewBusy;
  String get errorSelectPage => localizations.adminErrorSelectPage;
  String get errorReviewExpired => localizations.adminErrorReviewExpired;
  String get errorJournalBefore => localizations.adminErrorJournalBefore;
  String get errorReserveUnknown => localizations.adminErrorReserveUnknown;
  String get errorReserveFailed => localizations.adminErrorReserveFailed;
  String get errorBatchExpired => localizations.adminErrorBatchExpired;
  String get errorJournalRemaining => localizations.adminErrorJournalRemaining;
  String get errorChangeUnconfirmed =>
      localizations.adminErrorChangeUnconfirmed;
  String get errorRequestRejected => localizations.adminErrorRequestRejected;
  String get errorChangeUnknown => localizations.adminErrorChangeUnknown;
  String get errorReviewOutcomes => localizations.adminErrorReviewOutcomes;
  String get errorEarlierUncertain => localizations.adminErrorEarlierUncertain;
  String get errorDelayedReservation =>
      localizations.adminErrorDelayedReservation;
  String get errorOutstanding => localizations.adminErrorOutstanding;
  String get errorRecoveryUnverified =>
      localizations.adminErrorRecoveryUnverified;
  String get errorClosureUnverified =>
      localizations.adminErrorClosureUnverified;
  String get errorMemberBusy => localizations.adminErrorMemberBusy;
  String get errorGeneric => localizations.adminErrorGeneric;
  String get errorMutationUnknown => localizations.adminErrorMutationUnknown;
  String get errorNetwork => localizations.adminErrorNetwork;
  String get errorForbidden => localizations.adminErrorForbidden;
  String messageConfirmCount(int count, String countText) =>
      localizations.adminConfirmCount(count, countText);
  String messageReviewSummary(
    int eligible,
    String eligibleText,
    int excluded,
    String excludedText,
  ) => localizations.adminReviewSummary(
    eligible,
    eligibleText,
    excluded,
    excludedText,
  );
  String messageMatchingCount(int count, String countText) =>
      localizations.adminMatchingCount(count, countText);
  String messageSelectedCount(int count, String countText) =>
      localizations.adminSelectedCount(count, countText);
  String messageSnapshotAgeUpper(int seconds, String secondsText) =>
      localizations.adminSnapshotAgeUpper(seconds, secondsText);
  String messageSnapshotAgeExact(int seconds, String secondsText) =>
      localizations.adminSnapshotAgeExact(seconds, secondsText);
  String messageSnapshotRemaining(int seconds, String secondsText) =>
      localizations.adminSnapshotRemaining(seconds, secondsText);
  String messageReviewRemaining(String duration) =>
      localizations.adminReviewRemaining(duration);
  String messageDurationSeconds(int seconds, String secondsText) =>
      localizations.adminDurationSeconds(seconds, secondsText);
  String messageDurationMinutesSeconds(
    int minutes,
    String minutesText,
    int seconds,
    String secondsText,
  ) => localizations.adminDurationMinutesSeconds(
    minutes,
    minutesText,
    seconds,
    secondsText,
  );

  String roleLabel(String role) => switch (role) {
    'admin' => roleAdmin,
    'driver' => roleDriver,
    'passenger' => rolePassenger,
    _ => roleUnknown,
  };
  String reviewRole(String role) => messageReviewRole(roleLabel(role));
  String statusLabel(AdminRoleOutcomeStatus status) => switch (status) {
    AdminRoleOutcomeStatus.confirmed => statusConfirmed,
    AdminRoleOutcomeStatus.knownRejected => statusKnownRejected,
    AdminRoleOutcomeStatus.unknown => statusUnknown,
    AdminRoleOutcomeStatus.notStarted => statusNotStarted,
    AdminRoleOutcomeStatus.skipped => statusSkipped,
    AdminRoleOutcomeStatus.submitting => statusSubmitting,
  };
  String phaseText(AdminRoleRecoveryPhase phase) => switch (phase) {
    AdminRoleRecoveryPhase.checking => phaseChecking,
    AdminRoleRecoveryPhase.ready => phaseReady,
    AdminRoleRecoveryPhase.reserving => phaseReserving,
    AdminRoleRecoveryPhase.submitting => phaseSubmitting,
    AdminRoleRecoveryPhase.reconciling => phaseReconciling,
    AdminRoleRecoveryPhase.sealing => phaseSealing,
    AdminRoleRecoveryPhase.unresolved => phaseUnresolved,
    AdminRoleRecoveryPhase.blocked => phaseBlocked,
  };
  String rejectionText(String? code) => switch (code) {
    'target_changed' ||
    'ROLE_CONFLICT' ||
    'EXPECTED_ROLE_MISMATCH' => rejectChanged,
    'target_not_found' ||
    'TARGET_NOT_FOUND' ||
    'USER_NOT_FOUND' => rejectMissing,
    'reauthentication_required' ||
    'ADMIN_REAUTHENTICATION_REQUIRED' => rejectReauthenticate,
    'SELF_ROLE_CHANGE' || 'SELF_DEMOTION_FORBIDDEN' => ownProfileExcluded,
    _ => rejectGeneric,
  };
  String statusCount(AdminRoleOutcomeStatus status, int count) =>
      messageStatusCount(statusLabel(status), number(count));
  String confirmCount(int count) => messageConfirmCount(count, number(count));
  String matchingCount(int count) => messageMatchingCount(count, number(count));
  String selectedCount(int count) => messageSelectedCount(count, number(count));
  String reviewSummary(int eligible, int excluded) => messageReviewSummary(
    eligible,
    number(eligible),
    excluded,
    number(excluded),
  );
  String snapshotAge(Duration value, {required bool upperBound}) {
    final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    return upperBound
        ? messageSnapshotAgeUpper(seconds, number(seconds))
        : messageSnapshotAgeExact(seconds, number(seconds));
  }

  String snapshotRemaining(Duration value) {
    final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    return messageSnapshotRemaining(seconds, number(seconds));
  }

  String duration(Duration value) {
    final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    return seconds < 60
        ? messageDurationSeconds(seconds, number(seconds))
        : messageDurationMinutesSeconds(
            seconds ~/ 60,
            number(seconds ~/ 60),
            seconds % 60,
            number(seconds % 60),
          );
  }

  String roleChange(String before, String after, {required bool reviewed}) =>
      reviewed
      ? messageReviewedRoleChange(roleLabel(before), roleLabel(after))
      : messageRoleChange(roleLabel(before), roleLabel(after));
  String driverStateChange(bool before, bool after) => messageDriverStateChange(
    before ? enabled : disabled,
    after ? enabled : disabled,
  );
  String navigation(String route) => switch (route) {
    '/admin' => navOps,
    '/admin/users' => usersTitle,
    '/admin/vehicle-types' => navFleet,
    '/admin/agencies' => navAgencies,
    '/admin/ev-chargers' => navEv,
    '/admin/subscriptions' => navPlans,
    '/admin/trips' => navTrips,
    '/admin/reports' => navReports,
    '/admin/biopay' => 'BioPay',
    '/admin/health' => navHealth,
    '/admin/audit' => navAudit,
    '/admin/broadcasts' => navBroadcasts,
    '/profile' => navAccount,
    _ => unavailable,
  };
  String controlledMessage(String? value) =>
      reason(adminReasonForControlledMessage(value));
  String error(
    Object value, {
    AdminCopyReason fallback = AdminCopyReason.errorGeneric,
  }) {
    if (value is AdminReauthenticationRequiredException) {
      return rejectReauthenticate;
    }
    if (value is MutationOutcomeUnknownException) return errorMutationUnknown;
    if (value is NetworkException) return errorNetwork;
    if (value is AuthException) return errorSignIn;
    if (value is ForbiddenException) return errorForbidden;
    if (value is ValidationException) {
      final mapped = adminReasonForControlledMessage(value.message);
      return reason(mapped == AdminCopyReason.errorGeneric ? fallback : mapped);
    }
    // SDK/server/debug messages and unknown mutation replies never become copy.
    return reason(fallback);
  }

  String reason(AdminCopyReason value) => switch (value) {
    AdminCopyReason.errorSignIn => errorSignIn,
    AdminCopyReason.errorSessionUnavailable => errorSessionUnavailable,
    AdminCopyReason.errorLoadMembers => errorLoadMembers,
    AdminCopyReason.errorSessionChanged => errorSessionChanged,
    AdminCopyReason.errorReleaseSnapshot => errorReleaseSnapshot,
    AdminCopyReason.errorMemberSnapshotExpired => errorMemberSnapshotExpired,
    AdminCopyReason.errorPageExpired => errorPageExpired,
    AdminCopyReason.errorReviewBusy => errorReviewBusy,
    AdminCopyReason.errorSelectPage => errorSelectPage,
    AdminCopyReason.errorReviewExpired => errorReviewExpired,
    AdminCopyReason.errorJournalBefore => errorJournalBefore,
    AdminCopyReason.errorReserveUnknown => errorReserveUnknown,
    AdminCopyReason.errorReserveFailed => errorReserveFailed,
    AdminCopyReason.errorBatchExpired => errorBatchExpired,
    AdminCopyReason.errorJournalRemaining => errorJournalRemaining,
    AdminCopyReason.errorChangeUnconfirmed => errorChangeUnconfirmed,
    AdminCopyReason.errorRequestRejected => errorRequestRejected,
    AdminCopyReason.errorChangeUnknown => errorChangeUnknown,
    AdminCopyReason.errorReviewOutcomes => errorReviewOutcomes,
    AdminCopyReason.errorEarlierUncertain => errorEarlierUncertain,
    AdminCopyReason.errorDelayedReservation => errorDelayedReservation,
    AdminCopyReason.errorOutstanding => errorOutstanding,
    AdminCopyReason.errorRecoveryUnverified => errorRecoveryUnverified,
    AdminCopyReason.errorClosureUnverified => errorClosureUnverified,
    AdminCopyReason.errorMemberBusy => errorMemberBusy,
    AdminCopyReason.errorGeneric => errorGeneric,
    AdminCopyReason.errorMutationUnknown => errorMutationUnknown,
    AdminCopyReason.errorNetwork => errorNetwork,
    AdminCopyReason.errorForbidden => errorForbidden,
    AdminCopyReason.queryFailed => queryFailed,
    AdminCopyReason.userUpdateFailed => userUpdateFailed,
    AdminCopyReason.reviewUnavailable => reviewUnavailable,
    AdminCopyReason.reservationClosedEmpty => reservationClosedEmpty,
  };
}

enum AdminCopyReason {
  errorSignIn,
  errorSessionUnavailable,
  errorLoadMembers,
  errorSessionChanged,
  errorReleaseSnapshot,
  errorMemberSnapshotExpired,
  errorPageExpired,
  errorReviewBusy,
  errorSelectPage,
  errorReviewExpired,
  errorJournalBefore,
  errorReserveUnknown,
  errorReserveFailed,
  errorBatchExpired,
  errorJournalRemaining,
  errorChangeUnconfirmed,
  errorRequestRejected,
  errorChangeUnknown,
  errorReviewOutcomes,
  errorEarlierUncertain,
  errorDelayedReservation,
  errorOutstanding,
  errorRecoveryUnverified,
  errorClosureUnverified,
  errorMemberBusy,
  errorGeneric,
  errorMutationUnknown,
  errorNetwork,
  errorForbidden,
  queryFailed,
  userUpdateFailed,
  reviewUnavailable,
  reservationClosedEmpty,
}

// Transitional exact allowlist agreed with the frozen client owner.
// The state keeps controlled English identifiers; presentation renders locale.
// Unrecognized text is never forwarded. A typed client API is a later batch.
AdminCopyReason adminReasonForControlledMessage(
  String? value,
) => switch (value) {
  'Sign in again to load members.' => AdminCopyReason.errorSignIn,
  'Your account session is unavailable.' =>
    AdminCopyReason.errorSessionUnavailable,
  'Unable to load members. Refresh and try again.' =>
    AdminCopyReason.errorLoadMembers,
  'Your account session changed. Sign in again.' =>
    AdminCopyReason.errorSessionChanged,
  'Unable to release the previous member snapshot. Refresh to retry.' =>
    AdminCopyReason.errorReleaseSnapshot,
  'This member snapshot expired. Refresh to load current results.' =>
    AdminCopyReason.errorMemberSnapshotExpired,
  'Refresh this member snapshot before navigating.' =>
    AdminCopyReason.errorPageExpired,
  'Refresh or finish the current review before changing roles.' =>
    AdminCopyReason.errorReviewBusy,
  'Select members from this snapshot page.' => AdminCopyReason.errorSelectPage,
  'This review expired. Close its reservation before a new review.' =>
    AdminCopyReason.errorReviewExpired,
  'Recovery storage could not be verified. No role changes were submitted.' =>
    AdminCopyReason.errorJournalBefore,
  'The reservation outcome is unknown. Reconcile or close it before another review.' =>
    AdminCopyReason.errorReserveUnknown,
  'The reservation could not be completed. Reconcile or close it before another review.' =>
    AdminCopyReason.errorReserveFailed,
  'This batch expired. Close it before another review.' =>
    AdminCopyReason.errorBatchExpired,
  'Recovery storage could not be verified. Remaining role changes were not submitted.' =>
    AdminCopyReason.errorJournalRemaining,
  'This role change is not confirmed. Reconcile or close the batch.' =>
    AdminCopyReason.errorChangeUnconfirmed,
  'This request was rejected. Close the batch before another review.' =>
    AdminCopyReason.errorRequestRejected,
  'A role change outcome is unknown. Reconcile or close the batch.' =>
    AdminCopyReason.errorChangeUnknown,
  'Review the recipient outcomes, then close this batch before another review.' =>
    AdminCopyReason.errorReviewOutcomes,
  'An earlier reservation is uncertain and another batch is open. Close the earlier reservation first.' =>
    AdminCopyReason.errorEarlierUncertain,
  'The reservation outcome is unknown. Close it to prevent a delayed submission.' =>
    AdminCopyReason.errorDelayedReservation,
  'An outstanding batch was found. Review its outcomes and close it before another review.' =>
    AdminCopyReason.errorOutstanding,
  'Recovery could not be verified. No role changes will be replayed.' =>
    AdminCopyReason.errorRecoveryUnverified,
  'Closure could not be verified. Reconcile or close this reservation again.' =>
    AdminCopyReason.errorClosureUnverified,
  'Wait for the current member update.' => AdminCopyReason.errorMemberBusy,
  'This action could not be completed. Check the recorded status before continuing.' =>
    AdminCopyReason.errorGeneric,
  'Unable to connect. Check your internet and try again.' =>
    AdminCopyReason.errorNetwork,
  'You do not have permission for this action.' =>
    AdminCopyReason.errorForbidden,
  'This review is no longer available.' => AdminCopyReason.reviewUnavailable,
  'Reservation closed. No role changes were submitted.' =>
    AdminCopyReason.reservationClosedEmpty,
  'This role review is no longer available.' =>
    AdminCopyReason.reviewUnavailable,
  _ => AdminCopyReason.errorGeneric,
};
