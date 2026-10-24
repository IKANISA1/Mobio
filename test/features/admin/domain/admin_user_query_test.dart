import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';
import 'package:mobi_app/features/admin/domain/admin_user_query.dart';

import '../fixtures/admin_user_protocol_fixture.dart';

void main() {
  test(
    'exact page preserves displayed name fallback, row revisions and server order',
    () {
      final query = AdminUserQuery();
      final raw = fixturePageJson(
        query,
        rows: [
          {...fixtureUser(1), 'name': 'Fallback', 'display_name': ' Display '},
          {...fixtureUser(2), 'name': '', 'display_name': null},
        ],
      );
      final page = AdminUserPage.parse(
        raw,
        actorId: fixtureActor,
        sessionId: fixtureSession,
        request: query,
      );
      expect(page.rows.map((row) => row.user.name), [
        ' Display ',
        'Unnamed member',
      ]);
      expect(page.rows.map((row) => row.roleRevision), [0, 0]);
      expect(page.totalExact, 2);
      expect(page.hasNextPage, false);
    },
  );
  for (final mutation in [
    'actor',
    'session',
    'protocol',
    'count',
    'next',
    'snapshot',
    'duplicate',
    'revision',
    'sort',
  ]) {
    test('rejects inconsistent page evidence: $mutation', () {
      final query = AdminUserQuery(snapshotId: fixtureSnapshot);
      final raw = fixturePageJson(query);
      switch (mutation) {
        case 'actor':
          raw['actor_id'] = fixtureTarget(8);
        case 'session':
          raw['session_id'] = fixtureNextSession;
        case 'protocol':
          raw['protocol'] = 'other';
        case 'count':
          raw['total_exact'] = 8;
        case 'next':
          raw['has_next_page'] = true;
        case 'snapshot':
          raw['snapshot_id'] = fixtureReservation;
        case 'duplicate':
          (raw['rows'] as List)[1] = (raw['rows'] as List)[0];
        case 'revision':
          ((raw['rows'] as List)[0] as Map).remove('role_revision');
        case 'sort':
          raw['sort'] = 'name_asc';
      }
      expect(
        () => AdminUserPage.parse(
          raw,
          actorId: fixtureActor,
          sessionId: fixtureSession,
          request: query,
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'zero total is exact while empty later offset cannot fabricate a count',
    () {
      final zero = AdminUserPage.parse(
        fixturePageJson(AdminUserQuery(), rows: [], total: 0),
        actorId: fixtureActor,
        sessionId: fixtureSession,
        request: AdminUserQuery(),
      );
      expect(zero.totalExact, 0);
      final query = AdminUserQuery(
        snapshotId: fixtureSnapshot,
        pageSize: 25,
        offset: 50,
      );
      expect(
        () => AdminUserPage.parse(
          fixturePageJson(query, rows: [], total: 2),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          request: query,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'query normalization and bounded sorts use the new server parameters',
    () {
      final query = AdminUserQuery(
        role: 'all',
        search: '  100001 ',
        sort: 'name_asc',
      );
      expect(query.toRpcParameters(), {
        'p_role': null,
        'p_search': '100001',
        'p_sort': 'name_asc',
        'p_page_size': 25,
        'p_snapshot_id': null,
        'p_offset': 0,
      });
      for (final build in [
        () => AdminUserQuery(sort: 'other'),
        () => AdminUserQuery(pageSize: 101),
        () => AdminUserQuery(offset: 1),
      ]) {
        expect(build, throwsFormatException);
      }
    },
  );
  test(
    'snapshot release requires exact binding and one authoritative absence flag',
    () {
      for (final absent in [false, true]) {
        final release = AdminUserSnapshotRelease.parse(
          fixtureReleaseJson(fixtureSnapshot, absent: absent),
          actorId: fixtureActor,
          sessionId: fixtureSession,
          snapshotId: fixtureSnapshot,
        );
        expect(release.released, !absent);
        expect(release.alreadyAbsent, absent);
      }
      for (final altered in [
        {'actor_id': fixtureTarget(9)},
        {'session_id': fixtureNextSession},
        {'snapshot_id': fixtureReservation},
        {'released': false, 'already_absent': false},
        {'released': true, 'already_absent': true},
        {'server_now': 'invalid'},
      ]) {
        expect(
          () => AdminUserSnapshotRelease.parse(
            {...fixtureReleaseJson(fixtureSnapshot), ...altered},
            actorId: fixtureActor,
            sessionId: fixtureSession,
            snapshotId: fixtureSnapshot,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'deadline deducts full round trip and monotonic elapsed; reset cannot revive it',
    () {
      var elapsed = const Duration(seconds: 12);
      final deadline = AdminMonotonicDeadline(
        serverNow: fixtureNow,
        expiresAt: fixtureNow.add(const Duration(minutes: 10)),
        requestStarted: Duration.zero,
        responseReceived: elapsed,
        elapsed: () => elapsed,
      );
      expect(deadline.remaining, const Duration(minutes: 9, seconds: 48));
      expect(deadline.ageUpperBound(fixtureNow), const Duration(seconds: 12));
      elapsed = const Duration(minutes: 10);
      expect(deadline.expired, true);
      elapsed = const Duration(seconds: 1);
      expect(deadline.expired, true);
    },
  );
}
