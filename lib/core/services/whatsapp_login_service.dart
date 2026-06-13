import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/services/otp_service.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppLoginResult extends OtpResult {
  final AppRole? role;

  const WhatsAppLoginResult({
    required super.success,
    super.message,
    super.retryAfterSeconds,
    super.attemptsRemaining,
    this.role,
  });
}

/// WhatsApp Cloud OTP login for passenger and driver app sessions.
class WhatsAppLoginService {
  WhatsAppLoginService({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

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

  Future<WhatsAppLoginResult> sendLoginOtp({
    required String phone,
    required String countryCode,
    required AppRole role,
  }) async {
    final normalizedPhone = normalizePhoneForCountry(
      phone: phone,
      countryCode: countryCode,
    );

    try {
      final response = await _dio.post(
        '/send-login-otp',
        data: {
          'phone': normalizedPhone,
          'countryCode': countryCode,
          'role': _loginRoleValue(role),
        },
      );
      final body = _asBody(response.data);

      if (body['success'] == true) {
        return WhatsAppLoginResult(
          success: true,
          message: body['message'] as String? ?? 'OTP sent to your WhatsApp',
          retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
        );
      }

      return WhatsAppLoginResult(
        success: false,
        message: body['message'] as String? ?? 'Failed to send OTP',
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('WhatsAppLoginService.sendLoginOtp: $e');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('WhatsAppLoginService.sendLoginOtp: $e');
      return const WhatsAppLoginResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }

  Future<WhatsAppLoginResult> verifyLoginOtp({
    required String phone,
    required String code,
    required AppRole role,
    required String countryCode,
  }) async {
    final normalizedPhone = normalizePhoneForCountry(
      phone: phone,
      countryCode: countryCode,
    );

    try {
      final response = await _dio.post(
        '/verify-login-otp',
        data: {
          'phone': normalizedPhone,
          'code': code,
          'role': _loginRoleValue(role),
          'countryCode': countryCode,
        },
      );
      final body = _asBody(response.data);

      if (body['success'] == true && body['session'] != null) {
        final session = body['session'] as Map<String, dynamic>;
        final refreshToken = session['refresh_token'] as String?;
        if (refreshToken == null) {
          return const WhatsAppLoginResult(
            success: false,
            message: 'Unable to restore the session.',
          );
        }

        try {
          await Supabase.instance.client.auth.setSession(refreshToken);
        } on Object catch (e) {
          if (kDebugMode) debugPrint('Session restore failed: $e');
          return const WhatsAppLoginResult(
            success: false,
            message: 'Unable to restore the session.',
          );
        }

        final resolvedRole = AppRole.fromString(body['role'] as String?);
        return WhatsAppLoginResult(
          success: true,
          message: 'Verified successfully',
          role: resolvedRole.isAdmin ? AppRole.passenger : resolvedRole,
        );
      }

      return WhatsAppLoginResult(
        success: false,
        message: body['message'] as String? ?? 'Verification failed',
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('WhatsAppLoginService.verifyLoginOtp: $e');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('WhatsAppLoginService.verifyLoginOtp: $e');
      return const WhatsAppLoginResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }

  String _loginRoleValue(AppRole role) {
    return role == AppRole.driver ? 'driver' : 'passenger';
  }

  static String normalizePhoneForCountry({
    required String phone,
    required String countryCode,
  }) => PhoneNumberNormalizer.normalizeForCountry(
    phone: phone,
    countryCode: countryCode,
  );

  static bool isValidCanonicalPhone(String phone) =>
      PhoneNumberNormalizer.isValidCanonical(phone);

  static Map<String, dynamic> _asBody(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  static int? _extractInt(Map<String, dynamic> body, String key) {
    final val =
        body[key] ?? (body['details'] is Map ? body['details'][key] : null);
    if (val is int) return val;
    if (val is num) return val.toInt();
    return null;
  }

  static WhatsAppLoginResult _fromDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final data = error.response?.data;
    final body = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : null);

    if (body != null) {
      return WhatsAppLoginResult(
        success: false,
        message: body['message'] as String? ?? fallbackMessage,
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
      );
    }

    return WhatsAppLoginResult(
      success: false,
      message: error.message ?? fallbackMessage,
    );
  }
}
