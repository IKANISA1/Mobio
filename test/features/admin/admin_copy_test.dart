import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:mobi_app/features/admin/presentation/admin_copy.dart';
import 'package:mobi_app/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  for (final language in ['en', 'fr', 'rw']) {
    final copy = AdminCopy(lookupAppLocalizations(Locale(language)));
    final confirms = switch (language) {
      'fr' => [
        'Confirmer 0 changement',
        'Confirmer 1 changement',
        'Confirmer 2 changements',
      ],
      'rw' => ['Emeza impinduka 0', 'Emeza impinduka 1', 'Emeza impinduka 2'],
      _ => ['Confirm 0 changes', 'Confirm 1 change', 'Confirm 2 changes'],
    };
    for (final count in [0, 1, 2]) {
      test('$language confirm plural $count', () {
        expect(copy.confirmCount(count), confirms[count]);
      });
    }
    test('$language eligible and exclusions remain independent', () {
      expect(copy.reviewSummary(0, 2), isNot(copy.reviewSummary(2, 0)));
      expect(copy.reviewSummary(1, 1), contains('1'));
      expect(copy.selectedCount(1000), contains(copy.number(1000)));
      expect(copy.matchingCount(1000), contains(copy.number(1000)));
      expect(copy.confirmCount(1000), contains(copy.number(1000)));
    });
    test(
      '$language all recipient and recovery states remain distinguishable',
      () {
        expect(
          AdminRoleOutcomeStatus.values.map(copy.statusLabel).toSet(),
          hasLength(6),
        );
        expect(
          AdminRoleRecoveryPhase.values.map(copy.phaseText).toSet(),
          hasLength(8),
        );
        expect(
          copy.statusLabel(AdminRoleOutcomeStatus.unknown),
          isNot(copy.statusLabel(AdminRoleOutcomeStatus.knownRejected)),
        );
        expect(
          copy.statusLabel(AdminRoleOutcomeStatus.notStarted),
          isNot(copy.statusLabel(AdminRoleOutcomeStatus.skipped)),
        );
      },
    );
    test('$language unrecognized server/debug text never becomes copy', () {
      const raw = 'private SDK diagnostic: credential-like-untrusted-value';
      expect(
        copy.error(const ServerException(message: raw)),
        copy.errorGeneric,
      );
      expect(
        copy.error(const ValidationException(message: raw)),
        copy.errorGeneric,
      );
      expect(
        copy.error(
          const MutationOutcomeUnknownException(
            operation: 'reward',
            message: raw,
          ),
          fallback: AdminCopyReason.userUpdateFailed,
        ),
        copy.errorMutationUnknown,
      );
      expect(copy.controlledMessage(raw), copy.errorGeneric);
      expect(
        copy.error(
          const ValidationException(message: raw),
          fallback: AdminCopyReason.queryFailed,
        ),
        copy.queryFailed,
      );
      expect(
        copy.error(const AdminReauthenticationRequiredException(message: raw)),
        copy.rejectReauthenticate,
      );
      expect(
        copy.rejectionText('reauthentication_required'),
        copy.rejectReauthenticate,
      );
      expect(copy.rejectionText(raw), copy.rejectGeneric);
      expect(copy.error(FormatException(raw)), isNot(contains(raw)));
    });
    test('$language controlled journal failures preserve submitted distinction', () {
      expect(
        copy.controlledMessage(
          'Recovery storage could not be verified. No role changes were submitted.',
        ),
        copy.errorJournalBefore,
      );
      expect(
        copy.controlledMessage(
          'Recovery storage could not be verified. Remaining role changes were not submitted.',
        ),
        copy.errorJournalRemaining,
      );
      expect(copy.errorJournalBefore, isNot(copy.errorJournalRemaining));
      expect(
        copy.controlledMessage(
          'The reservation outcome is unknown. Close it to prevent a delayed submission.',
        ),
        copy.errorDelayedReservation,
      );
      expect(
        copy.controlledMessage(
          'Reservation closed. No role changes were submitted.',
        ),
        copy.reservationClosedEmpty,
      );
    });
    test('$language exact IDs and timestamp precision are preserved', () {
      const uuid = '12345678-1234-4234-8234-123456789abc';
      expect(copy.messageAccountReference(uuid), contains(uuid));
      expect(copy.messageMemberReference('001234'), contains('001234'));
      final instant = DateTime.utc(2026, 10, 2, 8, 9, 10, 123, 456);
      expect(copy.timestamp(instant), endsWith('.123456 UTC'));
      expect(copy.timestamp(instant.toLocal()), copy.timestamp(instant));
      expect(copy.date('invalid-source-date'), '—');
      if (language == 'rw') {
        expect(copy.timestamp(instant), startsWith('2026-10-02'));
      }
    });
    test('$language countdown clamps negatives and keeps conservative age', () {
      if (language == 'rw') {
        expect(copy.duration(const Duration(seconds: 1)), 'Isegonda 1');
        expect(
          copy.duration(const Duration(seconds: 61)),
          'Umunota 1 isegonda 1',
        );
      }
      expect(
        copy.duration(const Duration(seconds: -1)),
        copy.duration(Duration.zero),
      );
      expect(
        copy.snapshotAge(const Duration(seconds: 14), upperBound: true),
        isNot(copy.snapshotAge(const Duration(seconds: 14), upperBound: false)),
      );
      expect(
        copy.snapshotRemaining(const Duration(seconds: -1)),
        copy.snapshotRemaining(Duration.zero),
      );
      expect(
        copy.duration(const Duration(seconds: 61)),
        isNot(copy.duration(const Duration(seconds: 1))),
      );
    });
  }
  test('Intl grouping and explicit neutral RW numeric fallback', () {
    expect(
      AdminCopy(lookupAppLocalizations(const Locale('en'))).number(1000),
      '1,000',
    );
    expect(
      AdminCopy(lookupAppLocalizations(const Locale('fr'))).number(1000),
      matches(RegExp(r'^1[\s\u00a0\u202f]000$')),
    );
    expect(
      AdminCopy(lookupAppLocalizations(const Locale('rw'))).number(1000),
      '1000',
    );
  });
}
