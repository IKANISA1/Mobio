import 'dart:async';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSessionService {
  SupabaseSessionService._();
  static SupabaseClient get _client=>Supabase.instance.client;
  static Future<bool>? _exit;
  /// Explicit bootstrap-only operation. Startup and logout no longer await or
  /// launch anonymous network authentication, which could overwrite a later OTP
  /// login. Do not call this concurrently with an interactive login transition.
  static Future<bool> ensureAnonymousSession() async {
    if(AccountContext.exitRequested)return false;
    if(_client.auth.currentSession!=null)return true;
    try{return await AccountContext.bootstrapAnonymous();}
    on Object{return false;}
  }
  /// Compatibility name: success means local verified credentials are gone, not
  /// that a new anonymous network session exists. Offline logout never silently
  /// treats a surviving authenticated session as the anonymous baseline.
  static Future<bool> signOutToAnonymous({Future<void> Function()? beforeSignOut}) =>
    _exit ??= _performExit(beforeSignOut).whenComplete(()=>_exit=null);
  static Future<bool> _performExit(Future<void> Function()? cleanup) async {
    AccountContext.beginLogoutOperation();
    try {
    AdminSessionGuard.revoke();
    var markerSaved=false;
    try{await AccountContext.beginExit().timeout(const Duration(seconds:4));markerSaved=true;}
    on Object{AppLogger.warning('Local exit marker could not be verified; access remains locked.');}
    try{if(cleanup!=null)await cleanup().timeout(const Duration(seconds:5));}
    on Object{AppLogger.warning('Account cleanup incomplete; continuing local credential removal.');}
    try{await AccountContext.signOutSdkLocally().timeout(const Duration(seconds:8));}
    on Object{AppLogger.warning('Sign-out did not confirm completion; retained access remains locked.');}
    final remaining=_client.auth.currentSession;
    return markerSaved && (remaining==null || remaining.user.isAnonymous);
    } finally { AccountContext.endLogoutOperation(); }
  }
}
