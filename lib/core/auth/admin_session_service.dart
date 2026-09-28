import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSessionService {
  AdminSessionService._();
  static Future<bool>? _inFlight;
  static Future<bool> synchronize({bool userActivity=false}) {
    // A status in flight is not promoted into a touch; waiting until another
    // interaction is conservative and prevents automatic idle extension.
    return _inFlight ??= _read(userActivity).whenComplete(()=>_inFlight=null);
  }
  static Future<bool> _read(bool userActivity) async {
    final elapsed=Stopwatch()..start();
    try {
      final snapshot=AccountContext.capture();
      final response=await Supabase.instance.client.rpc<dynamic>('rpc_admin_session',
        params:{'p_action':userActivity?'touch':'status'}).timeout(const Duration(seconds:8));
      AccountContext.requireCurrent(snapshot);
      if (response is! Map || response['active']!=true || response['user_id']!=snapshot.userId ||
        response['session_id']!=snapshot.sessionId) throw StateError('ADMIN_LEASE_INACTIVE');
      final serverNow=DateTime.parse(response['server_now'] as String);
      final idle=DateTime.parse(response['idle_expires_at'] as String).difference(serverNow)-elapsed.elapsed;
      final absolute=DateTime.parse(response['absolute_expires_at'] as String).difference(serverNow)-elapsed.elapsed;
      AdminSessionGuard.acceptServerLease(userId:snapshot.userId,sessionId:snapshot.sessionId,
        idleRemaining:idle,absoluteRemaining:absolute);
      return true;
    } on Object { AdminSessionGuard.revoke();return false; }
  }
  static Future<void> revoke() async {
    AdminSessionGuard.revoke();
    try {
      await Supabase.instance.client.rpc<dynamic>('rpc_admin_session',params:{'p_action':'revoke'})
        .timeout(const Duration(seconds:3));
    } on Object { /* Local navigation is already locked; Auth logout follows. */ }
  }
}
