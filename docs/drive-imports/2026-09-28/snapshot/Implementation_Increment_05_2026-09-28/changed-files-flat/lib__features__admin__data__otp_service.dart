import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_service.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an OTP send or verify operation.
class OtpResult {
  final bool success;
  final String? message;
  final int? retryAfterSeconds;
  final int? attemptsRemaining;

  const OtpResult({
    required this.success,
    this.message,
    this.retryAfterSeconds,
    this.attemptsRemaining,
  });
}

/// WhatsApp OTP service for platform-admin sign-in.
class OtpService {
  OtpService._();
  static bool _verificationPending = false;

  // Edge functions live on the configured Supabase project.
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: SupabaseConfig.functionsBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Send OTP to [phone] via WhatsApp Cloud.
  /// Phone must be in international format: "+250788123456".
  static Future<OtpResult> sendOtp({
    required String phone,
    required String countryCode,
  }) async {
    final normalizedPhone = PhoneNumberNormalizer.normalizeForCountry(
      phone: phone,
      countryCode: countryCode,
    );

    try {
      final response = await _dio.post(
        '/send-otp',
        data: {'phone': normalizedPhone, 'countryCode': countryCode},
      );
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return const OtpResult(
          success: true,
          message: 'OTP sent to your WhatsApp',
        );
      }

      return OtpResult(
        success: false,
        message: body['message'] as String? ?? 'Failed to send OTP',
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('OtpService.sendOtp: request unavailable');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object {
      if (kDebugMode) debugPrint('OtpService.sendOtp: request unavailable');
      return const OtpResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }

  /// Verify OTP [code] for [phone]. On success, restores session in Supabase.
  static Future<OtpResult> verifyOtp({
    required String phone,
    required String code,
    required String countryCode,
  }) async {
    if (_verificationPending) return const OtpResult(success: false, message: 'Verification is already in progress.');
    if (!SupabaseConfig.isConfigured) return const OtpResult(success:false, message:'Admin service is unavailable.');
    _verificationPending = true;
    final auth = Supabase.instance.client.auth;
    final previousSession = AccountContext.sessionId(auth.currentSession);
    var restorationStarted = false;
    try {
      final normalizedPhone = PhoneNumberNormalizer.normalizeForCountry(phone: phone, countryCode: countryCode);

      final response = await _dio.post(
        '/verify-otp',
        data: {
          'phone': normalizedPhone,
          'code': code,
          'countryCode': countryCode,
        },
      );
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true && body['session'] is Map && body['admin_lease'] is Map) {
        final session = Map<String, dynamic>.from(body['session'] as Map);
        final lease = Map<String, dynamic>.from(body['admin_lease'] as Map);
        final refreshToken = session['refresh_token'];
        if (refreshToken is! String || refreshToken.isEmpty || lease['active'] != true ||
            AccountContext.sessionId(auth.currentSession) != previousSession) {
          throw StateError('ADMIN_SESSION_RESTORE_REJECTED');
        }
        restorationStarted = true;
        final restored = await auth.setSession(refreshToken).timeout(const Duration(seconds: 12));
        if (restored.session == null || restored.user?.id != lease['user_id'] ||
            restored.user?.appMetadata['provider'] != 'admin_whatsapp_otp' ||
            AccountContext.sessionId(restored.session) != lease['session_id'] ||
            AccountContext.sessionId(auth.currentSession) != lease['session_id']) {
          throw StateError('ADMIN_SESSION_RESTORE_REJECTED');
        }
        await AccountContext.completeVerifiedLogin();
        if (!await AdminSessionService.synchronize()) throw StateError('ADMIN_LEASE_REQUIRED');
        return const OtpResult(success: true, message: 'Verified successfully');
      }

      return OtpResult(
        success: false,
        message: body['message'] as String? ?? 'Verification failed',
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (error) {
      AdminSessionGuard.revoke();
      return _fromDioException(error, fallbackMessage: 'Network error. Check your connection.');
    } on Object {
      AdminSessionGuard.revoke();
      if (restorationStarted) {
        // A late SDK restoration cannot clear this fail-closed marker.
        try { await AccountContext.beginExit(); } on Object { /* Runtime fence remains closed. */ }
      }
      return const OtpResult(success: false, message: 'Unable to confirm admin access. Request a new code.');
    } finally {
      _verificationPending = false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static int? _extractInt(Map<String, dynamic> body, String key) {
    final val =
        body[key] ?? (body['details'] is Map ? body['details'][key] : null);
    if (val is int) return val;
    if (val is num) return val.toInt();
    return null;
  }

  static OtpResult _fromDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final data = error.response?.data;
    final body = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : null);

    if (body != null) {
      return OtpResult(
        success: false,
        message: _friendlyMessage(body['message'] as String?, fallbackMessage),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
      );
    }

    return OtpResult(
      success: false,
      message: _friendlyDioMessage(error, fallbackMessage),
    );
  }

  static String _friendlyDioMessage(
    DioException error,
    String fallbackMessage,
  ) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Check your internet and try again.';
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return fallbackMessage;
    }

    return _friendlyMessage(error.message, fallbackMessage);
  }

  static String _friendlyMessage(String? message, String fallbackMessage) {
    final text = message?.trim();
    if (text == null || text.isEmpty) {
      return fallbackMessage;
    }

    final lower = text.toLowerCase();
    if (lower.contains('xmlhttprequest') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection errored') ||
        lower.contains('failed host lookup')) {
      return fallbackMessage;
    }

    return text;
  }
}
