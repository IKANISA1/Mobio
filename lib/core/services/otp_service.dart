import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
      if (kDebugMode) debugPrint('OtpService.sendOtp error: $e');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('OtpService.sendOtp error: $e');
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
    final normalizedPhone = PhoneNumberNormalizer.normalizeForCountry(
      phone: phone,
      countryCode: countryCode,
    );

    try {
      final response = await _dio.post(
        '/verify-otp',
        data: {
          'phone': normalizedPhone,
          'code': code,
          'countryCode': countryCode,
        },
      );
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true && body['session'] != null) {
        final session = body['session'] as Map<String, dynamic>;
        final refreshToken = session['refresh_token'] as String?;

        if (refreshToken != null) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
          } on Object catch (e) {
            if (kDebugMode) debugPrint('Session restore failed: $e');
          }
        }

        try {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser == null) {
            return const OtpResult(
              success: false,
              message: 'Unable to restore the admin session.',
            );
          }

          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', currentUser.id)
              .maybeSingle();

          if (profile == null || profile['role'] != 'admin') {
            await Supabase.instance.client.auth.signOut();
            return const OtpResult(
              success: false,
              message:
                  'This WhatsApp number does not have platform admin access.',
            );
          }
        } on Object catch (e) {
          if (kDebugMode) {
            debugPrint('OtpService.verifyOtp admin role check failed: $e');
          }
          return const OtpResult(
            success: false,
            message: 'Unable to verify admin access right now.',
          );
        }

        return const OtpResult(success: true, message: 'Verified successfully');
      }

      return OtpResult(
        success: false,
        message: body['message'] as String? ?? 'Verification failed',
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('OtpService.verifyOtp error: $e');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('OtpService.verifyOtp error: $e');
      return const OtpResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
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
        message: body['message'] as String? ?? fallbackMessage,
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
      );
    }

    return OtpResult(success: false, message: error.message ?? fallbackMessage);
  }
}
