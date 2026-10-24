import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';

const identity = ReviewTransportIdentity(
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
);
const other = ReviewTransportIdentity(
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
);

Map<String, Object> status({ReviewTransportIdentity owner = identity}) => {
  'active': true,
  'mode': 'synthetic_review',
  'user_id': owner.userId,
  'session_id': owner.sessionId,
  'role': 'driver',
  'generation': 3,
  'fixture_version': ReviewSessionLease.supportedFixtureVersion,
  'authenticated_at': '2026-10-01T10:00:00Z',
  'server_now': '2026-10-01T10:01:00Z',
  'expires_at': '2026-10-01T10:02:00Z',
};

void main() {
  late ReviewTransportIdentity? transport;
  late Duration elapsed;
  late ReviewSessionContext context;
  setUp(() {
    transport = identity;
    elapsed = Duration.zero;
    context = ReviewSessionContext(
      readTransport: () => transport,
      elapsedTime: () => elapsed,
    );
  });
  tearDown(() => context.dispose());

  void activate({ReviewTransportIdentity owner = identity}) {
    context.acceptStatus(context.beginValidation(), status(owner: owner));
  }

  test(
    'transport alone and pending validation authorize no synthetic task',
    () {
      expect(context.hasAccess, false);
      expect(context.capture, throwsA(isA<ReviewAccessUnavailable>()));
      context.beginValidation();
      expect(context.pending, true);
      expect(context.hasAccess, false);
    },
  );
  test('matching fresh status admits only the supported fixture lease', () {
    activate();
    expect(context.lease?.identity.key, identity.key);
    expect(context.lease?.generation, 3);
    expect(context.lease?.role, 'driver');
    expect(context.capture().isCurrent, true);
    expect(context.lease?.serverNow, DateTime.utc(2026, 10, 1, 10, 1));
  });
  test('composition duration decreases and server time stays conservative', () {
    final ticket = context.beginValidation();
    elapsed = const Duration(seconds: 10);
    context.acceptStatus(ticket, status());
    expect(context.remaining, const Duration(seconds: 50));
    expect(context.lease?.responseElapsed, const Duration(seconds: 10));
    expect(context.serverTimeUpperBound, DateTime.utc(2026, 10, 1, 10, 1, 10));
    elapsed = const Duration(seconds: 17);
    expect(context.remaining, const Duration(seconds: 43));
    expect(context.serverTimeUpperBound, DateTime.utc(2026, 10, 1, 10, 1, 17));
    elapsed = const Duration(minutes: 1);
    expect(context.remaining, Duration.zero);
    expect(context.serverTimeUpperBound, isNull);
  });
  test(
    'authority owners quarantine before previously registered UI listeners',
    () {
      activate();
      final oldAction = context.capture();
      final order = <String>[];
      context.addListener(() => order.add('ui:${context.pending}'));
      context.addAuthorityListener(() {
        expect(oldAction.isCurrent, false);
        order.add('owner:${context.pending}');
      });
      final ticket = context.beginValidation();
      expect(order, ['owner:true', 'ui:true']);
      context.acceptStatus(ticket, status());
      expect(order, ['owner:true', 'ui:true', 'owner:false', 'ui:false']);
    },
  );
  test(
    'terminal authority clearing precedes UI and removed owners stay detached',
    () {
      activate();
      final order = <String>[];
      void detached() => order.add('detached');
      context.addListener(() {
        expect(context.hasAccess, false);
        order.add('ui');
      });
      context.addAuthorityListener(detached);
      context.removeAuthorityListener(detached);
      context.addAuthorityListener(() {
        expect(context.hasAccess, false);
        order.add('owner');
      });
      context.invalidate();
      expect(order, ['owner', 'ui']);
    },
  );
  test(
    'transport loss clears volatile owners before deferred UI notification',
    () {
      activate();
      final action = context.capture();
      var cleared = false;
      context.addAuthorityListener(() => cleared = !context.hasAccess);
      transport = other;
      expect(action.isCurrent, false);
      expect(cleared, true);
    },
  );
  test('backwards elapsed time revokes the lease and its old actions', () {
    elapsed = const Duration(seconds: 20);
    activate();
    final action = context.capture();
    elapsed = const Duration(seconds: 21);
    expect(context.remaining, const Duration(seconds: 59));
    elapsed = const Duration(seconds: 20);
    expect(action.isCurrent, false);
    expect(context.remaining, Duration.zero);
    expect(context.serverTimeUpperBound, isNull);
    expect(context.beginValidation, throwsA(isA<ReviewAccessUnavailable>()));
    elapsed = const Duration(seconds: 22);
    activate();
    expect(context.capture().isCurrent, true);
    expect(action.isCurrent, false);
  });
  test('generation outside the supported server integer range is refused', () {
    final ticket = context.beginValidation();
    expect(
      () => context.acceptStatus(ticket, status()..['generation'] = 2147483648),
      throwsA(isA<ReviewAccessUnavailable>()),
    );
    context.rejectStatus(ticket);
    expect(context.hasAccess, false);
  });
  for (final entry in <String, Object>{
    'active': false,
    'mode': 'ordinary',
    'user_id': other.userId,
    'session_id': other.sessionId,
    'role': 'admin',
    'generation': 0,
    'fixture_version': 'unknown',
    'authenticated_at': '2026-10-01T10:03:00Z',
    'server_now': '2026-10-01T10:02:00Z',
    'expires_at': '2026-10-01T12:00:00Z',
  }.entries) {
    test('rejects invalid or mismatched ${entry.key}', () {
      final ticket = context.beginValidation();
      final response = status()..[entry.key] = entry.value;
      expect(
        () => context.acceptStatus(ticket, response),
        throwsA(isA<ReviewAccessUnavailable>()),
      );
      context.rejectStatus(ticket);
      expect(context.hasAccess, false);
      expect(context.pending, false);
    });
  }
  test('request elapsed time conservatively reduces the server lease', () {
    final ticket = context.beginValidation();
    elapsed = const Duration(seconds: 10);
    context.acceptStatus(ticket, status());
    expect(context.lease?.remaining, const Duration(seconds: 50));
    elapsed = const Duration(seconds: 59);
    expect(context.hasAccess, true);
    elapsed = const Duration(seconds: 60);
    expect(context.hasAccess, false);
  });
  test('status arriving after its lease cannot activate', () {
    final ticket = context.beginValidation();
    elapsed = const Duration(minutes: 2);
    expect(
      () => context.acceptStatus(ticket, status()),
      throwsA(isA<ReviewAccessUnavailable>()),
    );
    expect(context.hasAccess, false);
  });
  test('logout fences both old callbacks and old status completion', () {
    activate();
    final action = context.capture();
    final ticket = context.beginValidation();
    context.invalidate();
    expect(action.isCurrent, false);
    expect(
      () => context.acceptStatus(ticket, status()),
      throwsA(isA<ReviewAccessUnavailable>()),
    );
  });
  test(
    'replacement status and late failure cannot revoke the newer account',
    () {
      final old = context.beginValidation();
      transport = other;
      final next = context.beginValidation();
      context.acceptStatus(next, status(owner: other));
      context.rejectStatus(old);
      expect(context.lease?.identity.key, other.key);
      expect(
        () => context.acceptStatus(old, status()),
        throwsA(isA<ReviewAccessUnavailable>()),
      );
      expect(context.lease?.identity.key, other.key);
    },
  );
  test(
    'transport replacement immediately invalidates actions before notification',
    () {
      activate();
      final action = context.capture();
      transport = other;
      expect(action.isCurrent, false);
      expect(context.hasAccess, false);
    },
  );
  test('new validation invalidates callbacks even with the same SID', () {
    activate();
    final action = context.capture();
    final ticket = context.beginValidation();
    expect(action.isCurrent, false);
    context.acceptStatus(ticket, status());
    expect(action.isCurrent, false);
  });
  test('absence of a current review transport cannot start validation', () {
    transport = null;
    expect(context.beginValidation, throwsA(isA<ReviewAccessUnavailable>()));
    expect(context.pending, false);
  });
  test(
    'server disablement revokes the active task instead of retaining stale access',
    () {
      activate();
      final ticket = context.beginValidation();
      expect(
        () => context.acceptStatus(ticket, {'active': false}),
        throwsA(isA<ReviewAccessUnavailable>()),
      );
      context.rejectStatus(ticket);
      expect(context.hasAccess, false);
    },
  );
  testWidgets('timer notifies expiry without a consumer polling the getter', (
    tester,
  ) async {
    final timed = ReviewSessionContext(
      readTransport: () => identity,
      elapsedTime: () => elapsed,
    );
    var notices = 0;
    timed.addListener(() => notices++);
    timed.acceptStatus(timed.beginValidation(), status());
    expect(notices, 2);
    elapsed = const Duration(minutes: 1);
    await tester.pump(const Duration(minutes: 1));
    expect(notices, 3);
    expect(timed.hasAccess, false);
    timed.dispose();
  });
}
