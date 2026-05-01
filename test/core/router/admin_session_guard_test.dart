import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';

void main() {
  group('AdminSessionGuard', () {
    setUp(AdminSessionGuard.revoke);

    test('isAdmin is false by default', () {
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('grant() sets isAdmin to true', () {
      AdminSessionGuard.grant();
      expect(AdminSessionGuard.isAdmin, isTrue);
    });

    test('revoke() sets isAdmin to false', () {
      AdminSessionGuard.grant();
      AdminSessionGuard.revoke();
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('touch() extends the session', () {
      AdminSessionGuard.grant();
      AdminSessionGuard.touch(); // Should not throw or change state
      expect(AdminSessionGuard.isAdmin, isTrue);
    });

    test('touch() is a no-op when not admin', () {
      AdminSessionGuard.touch();
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('sessionTimeout is 15 minutes', () {
      expect(AdminSessionGuard.sessionTimeout, const Duration(minutes: 15));
    });
  });
}
