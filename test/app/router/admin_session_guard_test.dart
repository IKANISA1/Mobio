import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';

void main() {
  group('AdminSessionGuard', () {
    setUp(AdminSessionGuard.revoke);

    test('isAdmin is false by default', () {
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('legacy client grant cannot create admin access', () {
      AdminSessionGuard.grant('admin-user');
      expect(AdminSessionGuard.isAdmin, isFalse);
      expect(AdminSessionGuard.isAdminFor('admin-user'), isFalse);
    });

    test('revoke() sets isAdmin to false', () {
      AdminSessionGuard.acceptServerLease(
        userId: 'admin-user', sessionId: 'session-1',
        idleRemaining: const Duration(minutes: 15),
        absoluteRemaining: const Duration(hours: 1),
      );
      expect(AdminSessionGuard.isAdminFor('admin-user', sessionId: 'session-1'), isTrue);
      AdminSessionGuard.revoke();
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('legacy touch cannot grant access', () {
      AdminSessionGuard.touch('admin-user');
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('server lease binds access to owner and session', () {
      AdminSessionGuard.acceptServerLease(
        userId: 'admin-user', sessionId: 'session-1',
        idleRemaining: const Duration(minutes: 15),
        absoluteRemaining: const Duration(hours: 1),
      );
      expect(AdminSessionGuard.isAdmin, isTrue);
      expect(AdminSessionGuard.isAdminFor('admin-user', sessionId: 'session-1'), isTrue);
      expect(AdminSessionGuard.isAdminFor('admin-user', sessionId: 'session-2'), isFalse);
      expect(AdminSessionGuard.isAdminFor('other-user', sessionId: 'session-1'), isFalse);
    });

    test('touch() is a no-op when not admin', () {
      AdminSessionGuard.touch('admin-user');
      expect(AdminSessionGuard.isAdmin, isFalse);
    });

    test('different user revokes stale admin fallback', () {
      AdminSessionGuard.acceptServerLease(
        userId: 'admin-user', sessionId: 'session-1',
        idleRemaining: const Duration(minutes: 15),
        absoluteRemaining: const Duration(hours: 1),
      );
      expect(AdminSessionGuard.isAdminFor('other-user', sessionId: 'session-1'), isFalse);
      expect(AdminSessionGuard.isAdmin, isTrue);
    });

    test('sessionTimeout is 15 minutes', () {
      expect(AdminSessionGuard.sessionTimeout, const Duration(minutes: 15));
    });
  });
}
