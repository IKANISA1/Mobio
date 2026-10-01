import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal local recovery pointer, not financial authority. The server also
/// retains an unresolved owner slot, protecting against storage loss and multiple
/// app processes. No note, phone, access token or raw request is persisted here.
class WalletOperationJournal {
  static const observationTimeout = Duration(seconds: 4);

  // SharedPreferences reload replaces its whole cache, so serialize across
  // owners as well as operations. Callers may stop waiting at their deadline;
  // the queue still waits for the original native Future to settle. Releasing
  // it on timeout could let a late remove erase a newer recovery pointer.
  static Future<void> _tail = Future<void>.value();

  static Future<void> _serialize(Future<void> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  static String newOperationId() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String _key(String owner) => 'mobio.wallet.operation.v2.$owner';
  static Future<void>
  assertNoUnattributedLegacyRequest() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getKeys().any(
      (key) =>
          key.startsWith('mobio.pending.wallet-transfer:') ||
          key.startsWith('mobio.pending.wallet-redeem:'),
    )) {
      // Version-one keys have no owner and may contain a note. Never attribute
      // them to the current account, print them, clear them, or replay blindly.
      throw StateError('LEGACY_WALLET_REVIEW_REQUIRED');
    }
  });
  static Future<void> save(WalletOperationRecord operation) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        final encoded = jsonEncode({
          'version': 2,
          'owner_id': operation.ownerId,
          'operation_id': operation.operationId,
          'kind': operation.kind,
        });
        if (!await prefs.setString(_key(operation.ownerId), encoded)) {
          throw StateError('WALLET_JOURNAL_WRITE_FAILED');
        }
        await prefs.reload();
        if (prefs.getString(_key(operation.ownerId)) != encoded) {
          throw StateError('WALLET_JOURNAL_VERIFY_FAILED');
        }
      });
  static Future<void> clear(String owner, String operationId) =>
      _serialize(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final raw = prefs.getString(_key(owner));
        if (raw == null) return;
        try {
          final record = jsonDecode(raw);
          // Never erase a newer or another operation's recovery pointer.
          if (record is! Map ||
              record['owner_id'] != owner ||
              record['operation_id'] != operationId) {
            return;
          }
        } on Object {
          return;
        }
        if (!await prefs.remove(_key(owner))) {
          throw StateError('WALLET_JOURNAL_CLEAR_FAILED');
        }
      });
}
