import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/account_action_token.dart';
import 'package:mobi_app/core/auth/account_context.dart';

void main() {
  test('same owner and session with new generation invalidates a dialog', () {
    AccountSnapshot? account = const AccountSnapshot('owner', 'session', 1);
    var revision = 0;
    final token = AccountActionToken.capture(
      captureAccount: () => account,
      readRevision: () => revision,
    );
    expect(token.isCurrent, isTrue);
    account = const AccountSnapshot('owner', 'session', 2);
    expect(token.isCurrent, isFalse);
    account = const AccountSnapshot('owner', 'session', 1);
    revision++;
    expect(token.isCurrent, isFalse);
  });
  test('an unauthenticated callback cannot acquire a later account', () {
    AccountSnapshot? account;
    final token = AccountActionToken.capture(
      captureAccount: () => account,
      readRevision: () => 0,
    );
    expect(token.isCurrent, isTrue);
    account = const AccountSnapshot('owner', 'session', 1);
    expect(token.isCurrent, isFalse);
  });
}
