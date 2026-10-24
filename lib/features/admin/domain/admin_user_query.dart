import 'package:mobi_app/features/admin/domain/admin_user_protocol.dart';
import 'package:mobi_app/features/admin/domain/admin_wire_record.dart';
import 'package:mobi_shared_types/models/admin/admin_models.dart';

class AdminUserQuery {
  AdminUserQuery({
    String? role,
    String? search,
    this.sort = 'online',
    this.pageSize = 25,
    this.snapshotId,
    this.offset = 0,
  }) : role = role == null || role == 'all' || role.trim().isEmpty
           ? null
           : role.trim(),
       search = search == null || search.trim().isEmpty ? null : search.trim() {
    if ((this.role != null && !AdminUserProtocol.roles.contains(this.role)) ||
        !sorts.contains(sort) ||
        pageSize < 1 ||
        pageSize > 100 ||
        offset < 0 ||
        offset % pageSize != 0 ||
        (this.search?.length ?? 0) > 120 ||
        (snapshotId == null && offset != 0)) {
      throw const FormatException('Invalid Admin member query.');
    }
  }

  static const sorts = {'online', 'name_asc', 'name_desc', 'role', 'newest'};
  final String? role;
  final String? search;
  final String sort;
  final int pageSize;
  final String? snapshotId;
  final int offset;

  Map<String, Object?> toRpcParameters() => {
    'p_role': role,
    'p_search': search,
    'p_sort': sort,
    'p_page_size': pageSize,
    'p_snapshot_id': snapshotId,
    'p_offset': offset,
  };
}

class AdminUserSnapshotRow {
  const AdminUserSnapshotRow({required this.user, required this.roleRevision});
  final AdminUserListItem user;
  final int roleRevision;
}

/// A release removes only this captured query cache, never role work or receipts.
class AdminUserSnapshotRelease {
  const AdminUserSnapshotRelease({
    required this.actorId,
    required this.sessionId,
    required this.serverNow,
    required this.snapshotId,
    required this.released,
    required this.alreadyAbsent,
  });

  final String actorId;
  final String sessionId;
  final DateTime serverNow;
  final String snapshotId;
  final bool released;
  final bool alreadyAbsent;

  factory AdminUserSnapshotRelease.parse(
    Object? value, {
    required String actorId,
    required String sessionId,
    required String snapshotId,
  }) {
    final row = AdminUserProtocol.object(value, 'snapshot release');
    AdminUserProtocol.header(row, actorId: actorId, sessionId: sessionId);
    final returnedId = AdminUserProtocol.id(row, 'snapshot_id');
    final released = AdminUserProtocol.flag(row, 'released');
    final alreadyAbsent = AdminUserProtocol.flag(row, 'already_absent');
    if (returnedId != snapshotId.toLowerCase() || released == alreadyAbsent) {
      throw const FormatException('Admin snapshot release evidence mismatch.');
    }
    return AdminUserSnapshotRelease(
      actorId: actorId.toLowerCase(),
      sessionId: sessionId.toLowerCase(),
      serverNow: AdminUserProtocol.date(row, 'server_now'),
      snapshotId: returnedId,
      released: released,
      alreadyAbsent: alreadyAbsent,
    );
  }
}

class AdminUserPage {
  AdminUserPage({
    required this.actorId,
    required this.sessionId,
    required this.serverNow,
    required this.snapshotId,
    required this.asOf,
    required this.expiresAt,
    required this.query,
    required this.totalExact,
    required this.hasNextPage,
    required List<AdminUserSnapshotRow> rows,
  }) : rows = List.unmodifiable(rows);

  final String actorId;
  final String sessionId;
  final DateTime serverNow;
  final String snapshotId;
  final DateTime asOf;
  final DateTime expiresAt;
  final AdminUserQuery query;
  final int totalExact;
  final bool hasNextPage;
  final List<AdminUserSnapshotRow> rows;

  factory AdminUserPage.parse(
    Object? value, {
    required String actorId,
    required String sessionId,
    required AdminUserQuery request,
  }) {
    final row = AdminUserProtocol.object(value, 'member page');
    AdminUserProtocol.header(row, actorId: actorId, sessionId: sessionId);
    final snapshotId = AdminUserProtocol.id(row, 'snapshot_id');
    final serverNow = AdminUserProtocol.date(row, 'server_now');
    final asOf = AdminUserProtocol.date(row, 'as_of');
    final expiresAt = AdminUserProtocol.date(row, 'expires_at');
    final role = AdminUserProtocol.nullableText(row, 'role_filter');
    final search = AdminUserProtocol.nullableText(row, 'search');
    final sort = AdminUserProtocol.choice(row, 'sort', AdminUserQuery.sorts);
    final size = AdminUserProtocol.integer(
      row,
      'page_size',
      minimum: 1,
      maximum: 100,
    );
    final offset = AdminUserProtocol.integer(row, 'offset', maximum: 10000);
    final total = AdminUserProtocol.integer(row, 'total_exact', maximum: 10000);
    final next = AdminUserProtocol.flag(row, 'has_next_page');
    final records = AdminUserProtocol.objects(row, 'rows');
    final rows = records
        .map(
          (record) => AdminUserSnapshotRow(
            user: AdminWireRecord.user(record),
            roleRevision: AdminUserProtocol.integer(record, 'role_revision'),
          ),
        )
        .toList(growable: false);
    final remaining = total > offset ? total - offset : 0;
    final expectedRows = remaining < size ? remaining : size;
    if ((request.snapshotId != null && snapshotId != request.snapshotId) ||
        role != request.role ||
        search != request.search ||
        sort != request.sort ||
        size != request.pageSize ||
        offset != request.offset ||
        offset > total ||
        rows.length != expectedRows ||
        next != (offset + rows.length < total) ||
        rows.map((item) => item.user.id).toSet().length != rows.length ||
        asOf.isAfter(serverNow) ||
        !expiresAt.isAfter(serverNow) ||
        expiresAt.difference(asOf) > const Duration(minutes: 10)) {
      throw const FormatException('Admin member page evidence mismatch.');
    }
    return AdminUserPage(
      actorId: actorId.toLowerCase(),
      sessionId: sessionId.toLowerCase(),
      serverNow: serverNow,
      snapshotId: snapshotId,
      asOf: asOf,
      expiresAt: expiresAt,
      query: AdminUserQuery(
        role: role,
        search: search,
        sort: sort,
        pageSize: size,
        snapshotId: snapshotId,
        offset: offset,
      ),
      totalExact: total,
      hasNextPage: next,
      rows: rows,
    );
  }
}
