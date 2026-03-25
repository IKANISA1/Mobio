import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
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

/// WhatsApp OTP service — proxied via COOL AFRICA Supabase edge functions.
class OtpService {
  OtpService._();

  // Edge functions live on the COOL AFRICA project (deployed + secrets configured).
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

  /// Send OTP to [phone] via WhatsApp (gikundiro template).
  /// Phone must be in international format: "+250788123456".
  static Future<OtpResult> sendOtp(String phone) async {
    try {
      final response = await _dio.post('/send-otp', data: {'phone': phone});
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
    } catch (e) {
      debugPrint('OtpService.sendOtp error: $e');
      return const OtpResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }

  /// Verify OTP [code] for [phone]. On success, restores session in Supabase.
  static Future<OtpResult> verifyOtp(String phone, String code) async {
    try {
      final response = await _dio.post(
        '/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true && body['session'] != null) {
        final session = body['session'] as Map<String, dynamic>;
        final refreshToken = session['refresh_token'] as String?;

        if (refreshToken != null) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
          } catch (e) {
            debugPrint('Session restore skipped (cross-project): $e');
          }
        }

        return const OtpResult(success: true, message: 'Verified successfully');
      }

      return OtpResult(
        success: false,
        message: body['message'] as String? ?? 'Verification failed',
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } catch (e) {
      debugPrint('OtpService.verifyOtp error: $e');
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
}
