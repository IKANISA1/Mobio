import 'dart:convert';

import 'package:mobi_app/features/admin/domain/admin_role_change.dart';
import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';
import 'package:mobi_app/features/admin/domain/admin_user_query.dart';

const fixtureActor = '11111111-1111-4111-8111-111111111111';
const fixtureSession = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const fixtureNextSession = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const fixtureSnapshot = '33333333-3333-4333-8333-333333333333';
const fixtureReservation = '44444444-4444-4444-8444-444444444444';
const fixtureBatch = '55555555-5555-4555-8555-555555555555';
final fixtureNow = DateTime.utc(2026, 10, 2);

String fixtureTarget(int index) =>
    '22222222-2222-4222-8222-${index.toString().padLeft(12, '0')}';
String fixtureOperation(int index) =>
    '66666666-6666-4666-8666-${index.toString().padLeft(12, '0')}';

Map<String, dynamic> fixtureUser(
  int index, {
  String role = 'passenger',
  String? name,
  String? id,
}) => {
  'id': id ?? fixtureTarget(index),
  'name': name ?? 'Member $index',
  'display_name': null,
  'phone': '',
  'role': role,
  'is_driver': role == 'driver',
  'vehicle_type': 'cab',
  'member_id': '${100000 + index}',
  'has_face_id': false,
  'is_online': false,
  'created_at': fixtureNow.toIso8601String(),
  'role_revision': 0,
};

Map<String, dynamic> fixturePageJson(
  AdminUserQuery query, {
  List<Map<String, dynamic>>? rows,
  int? total,
  String snapshot = fixtureSnapshot,
}) {
  final records = rows ?? [fixtureUser(1), fixtureUser(2), fixtureUser(3)];
  return {
    'protocol': AdminUserProtocol.version,
    'actor_id': fixtureActor,
    'session_id': fixtureSession,
    'server_now': fixtureNow.toIso8601String(),
    'snapshot_id': snapshot,
    'as_of': fixtureNow.toIso8601String(),
    'expires_at': fixtureNow.add(const Duration(minutes: 10)).toIso8601String(),
    'role_filter': query.role,
    'search': query.search,
    'sort': query.sort,
    'page_size': query.pageSize,
    'offset': query.offset,
    'total_exact': total ?? records.length,
    'has_next_page': query.offset + records.length < (total ?? records.length),
    'rows': records,
  };
}

Map<String, dynamic> fixtureReleaseJson(
  String snapshot, {
  bool absent = false,
  String session = fixtureSession,
}) => {
  'protocol': AdminUserProtocol.version,
  'actor_id': fixtureActor,
  'session_id': session,
  'server_now': fixtureNow.toIso8601String(),
  'snapshot_id': snapshot,
  'released': !absent,
  'already_absent': absent,
};

AdminRoleReview fixtureReview({
  String reservation = fixtureReservation,
  String snapshot = fixtureSnapshot,
  String session = fixtureSession,
  List<Map<String, dynamic>>? users,
  String requestedRole = 'driver',
}) {
  final records = users ?? [fixtureUser(1), fixtureUser(2), fixtureUser(3)];
  final page = AdminUserPage.parse(
    fixturePageJson(AdminUserQuery(), rows: records, snapshot: snapshot),
    actorId: fixtureActor,
    sessionId: fixtureSession,
    request: AdminUserQuery(),
  );
  return AdminRoleReview(
    reviewId: reservation,
    reservationId: reservation,
    actorId: fixtureActor,
    sessionId: session,
    snapshotId: snapshot,
    requestedRole: requestedRole,
    entries: page.rows
        .map(
          (row) => AdminRoleReviewEntry(
            targetId: row.user.id,
            displayLabel: row.user.name,
            memberId: row.user.memberId,
            expectedRole: row.user.role,
            expectedRevision: row.roleRevision,
            expectedIsDriver: row.user.isDriver,
            requestedRole: requestedRole,
            requestedIsDriver: requestedRole == 'driver',
            skipReason: row.user.id == fixtureActor
                ? AdminRoleSkipReason.self
                : row.user.role == requestedRole
                ? AdminRoleSkipReason.sameRole
                : null,
          ),
        )
        .toList(),
  );
}

Map<String, dynamic> fixtureRoleJson(
  AdminRoleReview review, {
  List<String>? statuses,
  bool sealed = false,
  String session = fixtureSession,
  String batch = fixtureBatch,
}) {
  final now = fixtureNow.add(const Duration(seconds: 3));
  return {
    'protocol': AdminUserProtocol.version,
    'actor_id': fixtureActor,
    'session_id': session,
    'server_now': now.toIso8601String(),
    'reservation_id': review.reservationId,
    'reservation_state': sealed ? 'sealed' : 'reserved',
    'batch': {
      'batch_id': batch,
      'reservation_id': review.reservationId,
      'snapshot_id': review.snapshotId,
      'origin_session_id': review.sessionId,
      'reserved_at': fixtureNow.toIso8601String(),
      'execute_expires_at': fixtureNow
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      'input_sha256': List.filled(64, 'a').join(),
      'state': sealed ? 'sealed' : 'open',
      'sealed_at': sealed ? now.toIso8601String() : null,
    },
    'operations': [
      for (var index = 0; index < review.entries.length; index++)
        _operationJson(
          review,
          index,
          statuses?[index] ??
              (review.entries[index].skipReason != null
                  ? 'skipped'
                  : sealed
                  ? 'not_started'
                  : 'prepared'),
          batch,
        ),
    ],
  };
}

Map<String, dynamic> _operationJson(
  AdminRoleReview review,
  int index,
  String state,
  String batch,
) {
  final entry = review.entries[index];
  final decided = state == 'prepared'
      ? null
      : fixtureNow.add(Duration(seconds: state == 'not_started' ? 3 : 1));
  return {
    'operation_id': fixtureOperation(index + 1),
    'ordinal': index + 1,
    'target_id': entry.targetId,
    'display_label': entry.displayLabel,
    'member_id': entry.memberId,
    'expected_role': entry.expectedRole,
    'expected_revision': entry.expectedRevision,
    'expected_is_driver': entry.expectedIsDriver,
    'requested_role': entry.requestedRole,
    'requested_is_driver': entry.requestedIsDriver,
    'status': state,
    'skip_reason': switch (entry.skipReason) {
      AdminRoleSkipReason.self => 'self',
      AdminRoleSkipReason.sameRole => 'same_role',
      _ => null,
    },
    'rejection_code': state == 'known_rejected' ? 'target_changed' : null,
    'decided_at': decided?.toIso8601String(),
    'receipt': state != 'confirmed'
        ? null
        : {
            'actor_id': fixtureActor,
            'session_id': review.sessionId,
            'batch_id': batch,
            'operation_id': fixtureOperation(index + 1),
            'target_id': entry.targetId,
            'before_role': entry.expectedRole,
            'after_role': entry.requestedRole,
            'before_revision': entry.expectedRevision,
            'after_revision': entry.expectedRevision + 1,
            'before_is_driver': entry.expectedIsDriver,
            'after_is_driver': entry.requestedIsDriver,
            'audit_id':
                '77777777-7777-4777-8777-${(index + 1).toString().padLeft(12, '0')}',
            'committed_at': decided!.toIso8601String(),
          },
  };
}

Map<String, dynamic> fixtureEmptyRoleJson({
  String? reservation,
  bool sealed = false,
  String session = fixtureSession,
}) => {
  'protocol': AdminUserProtocol.version,
  'actor_id': fixtureActor,
  'session_id': session,
  'server_now': fixtureNow.toIso8601String(),
  'reservation_id': reservation,
  'reservation_state': sealed ? 'sealed_before_reserve' : 'absent',
  'batch': null,
  'operations': <Object>[],
};

AdminRoleBatchEnvelope fixtureEnvelope(
  AdminRoleReview review, {
  List<String>? statuses,
  bool sealed = false,
  String session = fixtureSession,
  String batch = fixtureBatch,
}) => AdminRoleBatchEnvelope.parse(
  fixtureRoleJson(
    review,
    statuses: statuses,
    sealed: sealed,
    session: session,
    batch: batch,
  ),
  actorId: fixtureActor,
  sessionId: session,
  expectedReservationId: review.reservationId,
  review: review,
);

Map<String, dynamic> copyJson(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
