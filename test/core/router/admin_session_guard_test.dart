import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';

void main() {
  group('AdminSessionGuard', () {
    setUp(AdminSessionGuard.revoke);

    test('isAdmin is false by default', () {
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('grant() sets isAdmin to true for the granted user', () {
      AdminSessionGuard.grant('admin-user');
      expect(AdminSessionGuard.isAdmin, isTrue);
      expect(AdminSessionGuard.isAdminFor('admin-user'), isTrue);
    });

    test('revoke() sets isAdmin to false', () {
      AdminSessionGuard.grant('admin-user');
      AdminSessionGuard.revoke();
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('touch() extends the session', () {
      AdminSessionGuard.grant('admin-user');
      AdminSessionGuard.touch('admin-user'); // Should not throw or change state
      expect(AdminSessionGuard.isAdmin, isTrue);
    });

    test('touch() is a no-op when not admin', () {
      AdminSessionGuard.touch('admin-user');
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('different user revokes stale admin fallback', () {
      AdminSessionGuard.grant('admin-user');
      expect(AdminSessionGuard.isAdminFor('other-user'), isFalse);
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('sessionTimeout is 15 minutes', () {
      expect(AdminSessionGuard.sessionTimeout, const Duration(minutes: 15));
    });
  });
}
