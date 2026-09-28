import 'dart:async';
import 'dart:math';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/privacy_request.dart';

class PrivacyService {
  PrivacyService({SupabaseClient? client}) : _client=client??Supabase.instance.client;
  final SupabaseClient _client;
  static String requestId() {
    final random=Random.secure();final bytes=List<int>.generate(16,(_)=>random.nextInt(256));
    bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
    final h=bytes.map((v)=>v.toRadixString(16).padLeft(2,'0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }
  Future<Map<String,dynamic>> _invoke(AccountSnapshot account,Map<String,dynamic> body) async {
    AccountContext.requireCurrent(account);
    // Capture the bearer BEFORE the asynchronous call. A changed SDK account
    // must not substitute its credential for the original operation.
    final bearer=_client.auth.currentSession?.accessToken;
    if (bearer==null) throw const PrivacyFailure('AUTHENTICATION_REQUIRED');
    try {
      final response=await _client.functions.invoke('privacy-requests',body:body,
        headers:{'Authorization':'Bearer $bearer'}).timeout(const Duration(seconds:10));
      AccountContext.requireCurrent(account);
      final data=response.data;
      if(data is Map && data['error'] is String) throw PrivacyFailure(_safeCode(data['error'] as String));
      if(data is! Map || data['protocol']!='mobio.privacy.v1' || data['owner_id']!=account.userId) {
        throw const PrivacyFailure('BACKEND_UNAVAILABLE');
      }
      return Map<String,dynamic>.from(data);
    } on FunctionException catch(error) {
      AccountContext.requireCurrent(account);
      final details=error.details;
      throw PrivacyFailure(details is Map && details['error'] is String ? _safeCode(details['error'] as String) : 'BACKEND_UNAVAILABLE');
    } on TimeoutException { throw const PrivacyFailure('OUTCOME_UNKNOWN'); }
  }
  static String _safeCode(String code) => const {'REAUTHENTICATION_REQUIRED','INTAKE_UNAVAILABLE','NOTICE_CHANGED',
    'ACTIVE_REQUEST_EXISTS','NOT_CANCELLABLE','RATE_LIMITED','AUTHENTICATION_REQUIRED','REQUEST_NOT_FOUND','REQUEST_CONFLICT'}.contains(code)?code:'BACKEND_UNAVAILABLE';
  Future<PrivacyPolicy> policy(AccountSnapshot account) async => PrivacyPolicy.fromJson(await _invoke(account,{'action':'policy'}));
  Future<List<PrivacyRequest>> list(AccountSnapshot account) async {
    final result=await _invoke(account,{'action':'list'});final rows=result['requests'];
    if(rows is! List || rows.length>20) throw const FormatException('Invalid privacy history');
    final requests=rows.map(PrivacyRequest.fromJson).toList(growable:false);
    if(requests.map((r)=>r.id).toSet().length!=requests.length) throw const FormatException('Duplicate privacy history');
    return requests;
  }
  Future<PrivacyRequest> request(AccountSnapshot account,String id,String notice) async {
    if(!validUuid(id)||!validNotice(notice)) throw const FormatException('Invalid request identity');
    final response=await _invoke(account,{'action':'request','request_id':id,'notice_version':notice,'confirmed':true});
    final result=PrivacyRequest.fromJson(response['request']);
    if(result.id!=id) throw const FormatException('Request identity mismatch');
    return result;
  }
  Future<PrivacyRequest> cancel(AccountSnapshot account,String id) async {
    if(!validUuid(id))throw const FormatException('Invalid request identity');
    final result=PrivacyRequest.fromJson((await _invoke(account,{'action':'cancel','request_id':id}))['request']);
    if(result.id!=id)throw const FormatException('Request identity mismatch');
    return result;
  }
}
