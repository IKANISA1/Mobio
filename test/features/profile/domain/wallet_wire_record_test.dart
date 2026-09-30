import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> summaryRow() => {
  'profile_id': owner,
  'balance_tokens': 0,
  'rwf_equivalent': 0,
  'lifetime_earned_tokens': 100,
  'lifetime_sent_tokens': 100,
  'lifetime_received_tokens': 0,
  'successful_referrals': 1,
  'referral_code': null,
  'share_url': null,
};

Map<String, dynamic> ledgerRow() => {
  'id': other,
  'profile_id': owner,
  'direction': 'credit',
  'amount_tokens': 100,
  'reason': 'referral_reward',
  'created_at': '2026-09-30T08:00:00Z',
  'note': null,
};

void main() {
  test('zero wallet balances and null referral metadata stay valid', () {
    final summary = WalletSummary.fromJson(
      summaryRow(),
      expectedProfileId: owner,
    );
    expect(summary.balanceTokens, 0);
    expect(summary.referralCode, isNull);
  });

  test('missing, fractional and unsafe wallet numbers are rejected', () {
    for (final value in [null, 1.5, '100', -1, 9007199254740992]) {
      expect(
        () =>
            WalletSummary.fromJson({...summaryRow(), 'balance_tokens': value}),
        throwsFormatException,
      );
    }
  });

  test('a summary from another owner cannot be displayed', () {
    expect(
      () => WalletSummary.fromJson({
        ...summaryRow(),
        'profile_id': other,
      }, expectedProfileId: owner),
      throwsFormatException,
    );
  });

  test('ledger entries preserve their backend timestamp and nullable note', () {
    final entry = TokenLedgerEntry.fromJson(
      ledgerRow(),
      expectedProfileId: owner,
    );
    expect(entry.createdAt, DateTime.utc(2026, 9, 30, 8));
    expect(entry.note, isNull);
  });

  test('invalid ledger timestamps and directions never inherit defaults', () {
    for (final row in [
      {...ledgerRow(), 'created_at': null},
      {...ledgerRow(), 'created_at': 'broken'},
      {...ledgerRow(), 'direction': null},
      {...ledgerRow(), 'direction': 'incoming'},
      {...ledgerRow(), 'amount_tokens': 1.9},
      {...ledgerRow(), 'profile_id': other},
    ]) {
      expect(
        () => TokenLedgerEntry.fromJson(row, expectedProfileId: owner),
        throwsFormatException,
      );
    }
  });

  test('transfer replay permits absent optional ledger IDs', () {
    final receipt = WalletTransferReceipt.fromJson({
      'transfer_id': owner,
      'status': 'completed',
    });
    expect(receipt.senderLedgerEntryId, isNull);
  });

  test(
    'missing transfer status and malformed transfer identity cannot claim completion',
    () {
      for (final row in [
        {'transfer_id': owner},
        {'transfer_id': '', 'status': 'completed'},
        {'transfer_id': owner, 'status': 'unknown'},
      ]) {
        expect(
          () => WalletTransferReceipt.fromJson(row),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'redemption preserves valid server state and rejects absent member ID/amount',
    () {
      final row = <String, dynamic>{
        'redemption_id': owner,
        'transfer_id': other,
        'status': 'cash_sent',
        'admin_member_id': '482013',
        'amount_tokens': 5000,
        'amount_rwf': 5000,
        'momo_number': null,
      };
      expect(WalletRedemptionReceipt.fromJson(row).status, 'cash_sent');
      expect(
        () => WalletRedemptionReceipt.fromJson({...row, 'amount_tokens': null}),
        throwsFormatException,
      );
      expect(
        () => WalletRedemptionReceipt.fromJson({
          ...row,
          'admin_member_id': 'M482013',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'empty referral and absent subscription fields cannot produce usable instructions',
    () {
      expect(() => ReferralCode.fromJson({'id': owner}), throwsFormatException);
      expect(
        () => DriverSubscriptionPaymentRequest.fromJson({'id': owner}),
        throwsFormatException,
      );
      expect(
        () => DriverPlusStatus.fromJson({'driver_id': owner, 'exists': false}),
        throwsFormatException,
      );
    },
  );
}
