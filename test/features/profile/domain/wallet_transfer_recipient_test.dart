import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';

void main() {
  group('wallet transfer recipient confirmation', () {
    test('accepts only the exact server-returned six-digit member ID', () {
      final recipient = WalletTransferRecipient.fromLookupJson({
        'member_id': '482913',
        'display_name': 'Recipient',
      }, requestedMemberId: '482913');
      expect(recipient.memberId, '482913');
    });

    test('rejects a different or absent recipient ID before confirmation', () {
      for (final returnedId in ['482914', '', 'M482913']) {
        expect(
          () => WalletTransferRecipient.fromLookupJson({
            'member_id': returnedId,
          }, requestedMemberId: '482913'),
          throwsA(isA<StateError>()),
          reason: 'returned ID: $returnedId',
        );
      }
    });

    test('rejects a malformed requested ID before confirmation', () {
      expect(
        () => WalletTransferRecipient.fromLookupJson({
          'member_id': '482913',
        }, requestedMemberId: 'M482913'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
