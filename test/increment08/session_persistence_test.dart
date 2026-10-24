import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/session_persistence.dart';

const origin = 'https://synthetic.supabase.co/auth/v1';
const owner = '11111111-1111-4111-8111-111111111111';
const sid = '22222222-2222-4222-8222-222222222222';
const otherSid = '33333333-3333-4333-8333-333333333333';

String session({
  String user = owner,
  String sessionId = sid,
  int issuedAt = 100,
  String issuer = origin,
  String provider = 'whatsapp_cloud_otp',
  bool anonymous = false,
}) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // Parser fixtures only: this is deliberately NOT a valid signed JWT.
  final claims = {
    'iss': issuer,
    'sub': user,
    'role': 'authenticated',
    'session_id': sessionId,
    'iat': issuedAt,
    'is_anonymous': anonymous,
  };
  return jsonEncode({
    'access_token': '${b64({'alg': 'none'})}.${b64(claims)}.synthetic',
    'refresh_token': 'synthetic-$issuedAt',
    'user': {
      'id': user,
      'is_anonymous': anonymous,
      'app_metadata': {'provider': provider},
    },
  });
}

class Store implements SessionValueStore {
  String? value;
  bool badRead = false;
  bool badWrite = false;
  bool badClear = false;
  bool loseWrite = false;
  int writes = 0;
  int clears = 0;
  Completer<void>? gate;
  Completer<void>? started;
  @override
  Future<String?> read() async {
    if (badRead) throw StateError('native failure');
    return value;
  }

  @override
  Future<void> write(String next) async {
    writes++;
    started?.complete();
    started = null;
    if (gate != null) await gate!.future;
    if (badWrite) throw StateError('native failure');
    if (!loseWrite) value = next;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (badClear) throw StateError('native failure');
    value = null;
  }

  @override
  Future<void> reset() async {
    badRead = false;
    badWrite = false;
    badClear = false;
    value = null;
  }
}

void main() {
  late Store store;
  late SessionPersistence persistence;
  late int purges;
  setUp(() {
    store = Store();
    purges = 0;
    persistence = SessionPersistence(
      store: store,
      issuer: origin,
      purgeLegacy: () async {
        purges++;
      },
    );
  });
  Future<void> accept([String? value]) async {
    await persistence.initialize();
    await persistence.acceptVerified(
      value ?? session(),
      expectedGeneration: persistence.generation,
    );
  }

  test(
    'empty startup removes legacy credentials without creating a session',
    () async {
      await persistence.initialize();
      expect(await persistence.read(), isNull);
      expect(purges, 1);
      expect(store.writes, 0);
    },
  );
  test('initialization is single-flight and idempotent', () async {
    await Future.wait([persistence.initialize(), persistence.initialize()]);
    expect(purges, 1);
  });
  test('existing valid stored login restores matching identity', () async {
    store.value = session();
    await persistence.initialize();
    expect(persistence.accepts(owner, sid), isTrue);
  });
  test('exit marker discards even a valid saved session', () async {
    store.value = session();
    await persistence.initialize(discardSavedSession: true);
    expect(await persistence.read(), isNull);
    expect(store.value, isNull);
  });
  test('read failure never falls back to another backend', () async {
    store.badRead = true;
    await expectLater(
      persistence.initialize(),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(persistence.failed, isTrue);
    expect(persistence.acceptedIdentity, isNull);
  });
  test('corrupt saved JSON requires explicit recovery', () async {
    store.value = '{';
    await expectLater(
      persistence.initialize(),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(store.value, '{');
    expect(persistence.failed, isTrue);
  });
  test('legacy purge failure prevents SDK restore', () async {
    final vault = SessionPersistence(
      store: store,
      issuer: origin,
      purgeLegacy: () async {
        throw StateError('failure');
      },
    );
    store.value = session();
    await expectLater(
      vault.initialize(),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(vault.acceptedIdentity, isNull);
  });
  test('SDK event cannot create initial login trust', () async {
    await persistence.initialize();
    await persistence.persistRefresh(session());
    expect(store.writes, 0);
    expect(persistence.acceptedIdentity, isNull);
  });
  test('explicit commit persists and verifies readback', () async {
    await accept();
    expect(store.value, session());
    expect(await persistence.read(), session());
  });
  test('write failure blocks explicit login success', () async {
    await persistence.initialize();
    store.badWrite = true;
    await expectLater(
      persistence.acceptVerified(
        session(),
        expectedGeneration: persistence.generation,
      ),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(persistence.acceptedIdentity, isNull);
  });
  test('lost write acknowledgement/readback blocks login success', () async {
    await persistence.initialize();
    store.loseWrite = true;
    await expectLater(
      persistence.acceptVerified(
        session(),
        expectedGeneration: persistence.generation,
      ),
      throwsA(isA<SessionStorageFailure>()),
    );
  });
  test('matching session refresh is persisted', () async {
    await accept();
    await persistence.persistRefresh(session(issuedAt: 101));
    expect(store.value, session(issuedAt: 101));
  });
  test('older issued-at refresh does not replace newer session', () async {
    await accept(session(issuedAt: 101));
    await persistence.persistRefresh(session(issuedAt: 100));
    expect(store.value, session(issuedAt: 101));
  });
  test('different session event cannot silently switch account', () async {
    await accept();
    await persistence.persistRefresh(session(sessionId: otherSid));
    expect(store.value, session());
  });
  test('provider drift cannot silently escalate login class', () async {
    await accept();
    await persistence.persistRefresh(session(provider: 'admin_whatsapp_otp'));
    expect(store.value, session());
  });
  test(
    'review storage accepts transport shape and same SID refresh only',
    () async {
      await accept(session(provider: 'store_review'));
      await persistence.persistRefresh(
        session(provider: 'store_review', issuedAt: 101),
      );
      expect(store.value, session(provider: 'store_review', issuedAt: 101));
      await persistence.persistRefresh(
        session(provider: 'whatsapp_cloud_otp', issuedAt: 102),
      );
      expect(store.value, session(provider: 'store_review', issuedAt: 101));
      await persistence.persistRefresh(
        session(provider: 'store_review', sessionId: otherSid, issuedAt: 102),
      );
      expect(store.value, session(provider: 'store_review', issuedAt: 101));
    },
  );
  test('refresh I/O failure quarantines existing identity', () async {
    await accept();
    store.badWrite = true;
    await persistence.persistRefresh(session(issuedAt: 101));
    expect(persistence.failed, isTrue);
    expect(persistence.accepts(owner, sid), isFalse);
  });
  test('logout removes both secure and legacy stores', () async {
    await accept();
    await persistence.lockAndClear();
    expect(store.value, isNull);
    expect(purges, 2);
  });
  test('logout invalidates trust synchronously', () async {
    await accept();
    final work = persistence.lockAndClear();
    expect(persistence.accepts(owner, sid), isFalse);
    await work;
  });
  test('failed deletion is not successful logout persistence', () async {
    await accept();
    store.badClear = true;
    await expectLater(
      persistence.lockAndClear(),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(persistence.accepts(owner, sid), isFalse);
  });
  test('late SDK write after logout does not recreate saved login', () async {
    await accept();
    await persistence.lockAndClear();
    await persistence.persistRefresh(session(issuedAt: 101));
    expect(store.value, isNull);
  });
  test('in-flight write is followed by durable clear', () async {
    await accept();
    store.gate = Completer<void>();
    store.started = Completer<void>();
    final began = store.started!.future;
    final write = persistence.persistRefresh(session(issuedAt: 101));
    await began;
    final clear = persistence.lockAndClear();
    expect(persistence.acceptedIdentity, isNull);
    store.gate!.complete();
    await write;
    await clear;
    expect(store.value, isNull);
  });
  test('old explicit commit ticket is rejected after logout', () async {
    await accept();
    final revision = persistence.generation;
    await persistence.lockAndClear();
    await expectLater(
      persistence.acceptVerified(session(), expectedGeneration: revision),
      throwsA(isA<SessionStorageFailure>()),
    );
    expect(store.value, isNull);
  });
  test('fresh ticket can log in after completed logout', () async {
    await accept();
    await persistence.lockAndClear();
    await persistence.acceptVerified(
      session(sessionId: otherSid),
      expectedGeneration: persistence.generation,
    );
    expect(persistence.accepts(owner, otherSid), isTrue);
  });
  test(
    'interleaved refresh cannot overwrite a different accepted session',
    () async {
      await accept();
      await persistence.lockAndClear();
      await persistence.acceptVerified(
        session(sessionId: otherSid),
        expectedGeneration: persistence.generation,
      );
      await persistence.persistRefresh(session(issuedAt: 200));
      expect(persistence.accepts(owner, otherSid), isTrue);
      expect(store.value, session(sessionId: otherSid));
    },
  );
  test('reset is explicit and remains locked until restart', () async {
    await accept();
    await persistence.resetSavedLogin();
    expect(store.value, isNull);
    expect(persistence.failed, isTrue);
  });
  test('memory-only backend does not survive a new instance', () async {
    final memory = MemorySessionValueStore();
    await memory.write(session());
    expect(await memory.read(), session());
    expect(await MemorySessionValueStore().read(), isNull);
  });
  for (final invalid in [
    '{}',
    '[]',
    'null',
    session(user: 'wrong'),
    session(user: '$owner\n'),
    session(sessionId: 'wrong'),
    session(sessionId: '$sid\n'),
    session(issuer: 'https://other/auth/v1'),
    session(provider: 'email'),
    session(anonymous: true),
    session(issuedAt: -1),
    'x' * 65537,
  ]) {
    test(
      'invalid record rejected without exposing input (${invalid.length}/${invalid.hashCode})',
      () {
        expect(
          () => StoredSessionIdentity.parse(invalid, issuer: origin),
          throwsA(isA<InvalidStoredSession>()),
        );
        expect(
          const InvalidStoredSession().toString(),
          'INVALID_STORED_SESSION',
        );
      },
    );
  }
}
