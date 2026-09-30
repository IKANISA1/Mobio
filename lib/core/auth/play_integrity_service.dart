import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/config/supabase_config.dart';

class PlayIntegrityService {
  PlayIntegrityService({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

  static const _channel = MethodChannel('rw.mobi.app/play_integrity');

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        baseUrl: SupabaseConfig.functionsBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<Map<String, dynamic>?> evidenceForAction(String action) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !SupabaseConfig.isConfigured) {
      return null;
    }

    final challenge = await _requestChallenge(action);
    final nonce = challenge?['nonce'] as String?;
    if (nonce == null || nonce.isEmpty) {
      return {
        'action': action,
        'supported': true,
        'status': 'challenge_unavailable',
      };
    }

    try {
      final response = await _channel
          .invokeMapMethod<Object?, Object?>('requestIntegrityToken', {
            'nonce': nonce,
          })
          .timeout(const Duration(seconds: 15));
      final token = response?['token'] as String?;
      if (token == null || token.isEmpty) {
        return {
          'action': action,
          'nonce': nonce,
          'supported': true,
          'status': 'token_unavailable',
          'errorCode': response?['errorCode'],
        };
      }

      return {
        'action': action,
        'nonce': nonce,
        'token': token,
        'supported': true,
        'status': 'token_ready',
      };
    } on MissingPluginException {
      return {
        'action': action,
        'nonce': nonce,
        'supported': false,
        'status': 'native_channel_missing',
      };
    } on PlatformException catch (error) {
      return {
        'action': action,
        'nonce': nonce,
        'supported': true,
        'status': 'token_error',
        'errorCode': error.code,
      };
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('PlayIntegrityService.evidenceForAction: $error');
      }
      return {
        'action': action,
        'nonce': nonce,
        'supported': true,
        'status': 'token_error',
      };
    }
  }

  Future<Map<String, dynamic>?> _requestChallenge(String action) async {
    try {
      final response = await _dio
          .post(
            '/play-integrity',
            data: {'operation': 'challenge', 'action': action},
          )
          .timeout(const Duration(seconds: 15));
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('PlayIntegrityService._requestChallenge: $error');
      }
    }
    return null;
  }
}
