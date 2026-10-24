import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mobi_app/features/admin/domain/admin_role_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AdminRoleJournal {
  Future<AdminRoleRecoveryPointer?> load(AdminRoleRecoveryOwner owner);
  Future<void> save(
    AdminRoleRecoveryPointer pointer, {
    required bool Function() ownerIsCurrent,
  });
  Future<void> clear(
    AdminRoleRecoveryOwner owner,
    String reservationId, {
    required bool Function() ownerIsCurrent,
  });
}

/// Minimal verified pointers scoped to exact project and actor. No target
/// requests, names, phones or credentials are persisted. The private server
/// unresolved slot remains authority against storage loss/multiple processes;
/// preferences alone cannot provide a cross-process compare-and-set.
class AdminRoleChangeJournal implements AdminRoleJournal {
  static final _tails = <String, Future<void>>{};
  static const prefix = 'mobio.admin.role-recovery.v1.';

  static String storageKey(AdminRoleRecoveryOwner owner) =>
      '$prefix${base64Url.encode(utf8.encode(owner.hostIdentity))}.${owner.actorId}';

  static String newReservationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<T> _serialized<T>(String key, Future<T> Function() action) {
    final work = (_tails[key] ?? Future<void>.value()).then((_) => action());
    final tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _tails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return work;
  }

  @override
  Future<AdminRoleRecoveryPointer?> load(AdminRoleRecoveryOwner owner) =>
      _serialized(storageKey(owner), () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final raw = prefs.getString(storageKey(owner));
        return raw == null
            ? null
            : AdminRoleRecoveryPointer.parse(jsonDecode(raw), owner: owner);
      });

  @override
  Future<void> save(
    AdminRoleRecoveryPointer pointer, {
    required bool Function() ownerIsCurrent,
  }) => _serialized(storageKey(pointer.owner), () async {
    if (!ownerIsCurrent()) throw StateError('ADMIN_RECOVERY_OWNER_CHANGED');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!ownerIsCurrent()) throw StateError('ADMIN_RECOVERY_OWNER_CHANGED');
    final key = storageKey(pointer.owner);
    final before = prefs.getString(key);
    if (before != null) {
      final previous = AdminRoleRecoveryPointer.parse(
        jsonDecode(before),
        owner: pointer.owner,
      );
      if (previous.reservationId != pointer.reservationId) {
        throw StateError('ADMIN_RECOVERY_POINTER_PENDING');
      }
    }
    final encoded = jsonEncode(pointer.toJson());
    if (!await prefs.setString(key, encoded)) {
      throw StateError('ADMIN_RECOVERY_POINTER_WRITE_FAILED');
    }
    await prefs.reload();
    if (!ownerIsCurrent()) throw StateError('ADMIN_RECOVERY_OWNER_CHANGED');
    if (prefs.getString(key) != encoded) {
      throw StateError('ADMIN_RECOVERY_POINTER_VERIFY_FAILED');
    }
  });

  @override
  Future<void> clear(
    AdminRoleRecoveryOwner owner,
    String reservationId, {
    required bool Function() ownerIsCurrent,
  }) => _serialized(storageKey(owner), () async {
    if (!ownerIsCurrent()) throw StateError('ADMIN_RECOVERY_OWNER_CHANGED');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!ownerIsCurrent()) throw StateError('ADMIN_RECOVERY_OWNER_CHANGED');
    final key = storageKey(owner);
    final raw = prefs.getString(key);
    if (raw == null) return;
    final current = AdminRoleRecoveryPointer.parse(
      jsonDecode(raw),
      owner: owner,
    );
    if (current.reservationId != reservationId) return;
    if (!await prefs.remove(key)) {
      throw StateError('ADMIN_RECOVERY_POINTER_CLEAR_FAILED');
    }
    await prefs.reload();
    if (prefs.getString(key) == raw) {
      throw StateError('ADMIN_RECOVERY_POINTER_CLEAR_VERIFY_FAILED');
    }
  });
}
