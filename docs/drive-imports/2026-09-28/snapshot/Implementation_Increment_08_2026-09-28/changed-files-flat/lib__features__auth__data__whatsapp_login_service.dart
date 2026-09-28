import 'dart:async';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/admin/data/otp_service.dart';

class WhatsAppLoginResult extends OtpResult {
  final AppRole? role;
  final bool usesReviewCode;

  const WhatsAppLoginResult({
    required super.success,
    super.message,
    super.retryAfterSeconds,
    super.attemptsRemaining,
    this.role,
    this.usesReviewCode = false,
  });
}

/// WhatsApp Cloud OTP login for passenger and driver app sessions.
class WhatsAppLoginService {
  WhatsAppLoginService({Dio? dio, this._playIntegrityEvidenceProvider})
    : _dio = dio ?? _defaultDio(),
      super();

  final Dio _dio;
  LoginAttempt? _attempt;
  Object? _attemptOwner;
  Future<void> cancelVerification({required Object owner}) async {
    if (identical(owner, _attemptOwner)) await AccountContext.cancelPendingLogin(_attempt);
  }
  final Future<Map<String, dynamic>?> Function(String action)?
  _playIntegrityEvidenceProvider;

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
        sendTimeout: const Duration(seconds: 10),
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
      final playIntegrity = await _playIntegrityEvidence('app_login_send_otp').timeout(const Duration(seconds: 6));
      final data = <String, dynamic>{
        'phone': normalizedPhone,
        'countryCode': countryCode,
        'role': _loginRoleValue(role),
      };
      if (playIntegrity != null) {
        data['playIntegrity'] = playIntegrity;
      }
      final response = await _dio.post('/send-login-otp', data: data).timeout(const Duration(seconds: 15));
      final body = _asBody(response.data);

      if (body['success'] == true) {
        return WhatsAppLoginResult(
          success: true,
          message: body['message'] as String? ?? 'OTP sent to your WhatsApp',
          retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
          usesReviewCode: body['deliveryMode'] == 'review_code',
        );
      }

      return WhatsAppLoginResult(
        success: false,
        message: body['message'] as String? ?? 'Failed to send OTP',
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('WhatsAppLoginService.sendLoginOtp: unavailable');
      return _fromDioException(
        e,
        fallbackMessage: 'Network error. Check your connection.',
      );
    } on Object {
      if (kDebugMode) debugPrint('WhatsAppLoginService.sendLoginOtp: unavailable');
      return const WhatsAppLoginResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }

  Future<WhatsAppLoginResult> verifyLoginOtp({
    Object? owner,
    required String phone,
    required String code,
    required AppRole role,
    required String countryCode,
  }) async {
    if (_attempt != null) return const WhatsAppLoginResult(success: false, message: 'Verification is already in progress.');
    LoginAttempt? ticket;
    var completed = false;
    try {
      ticket = AccountContext.beginLoginAttempt(provider: 'whatsapp_cloud_otp');
      _attempt = ticket;
      _attemptOwner = owner;
      await AccountContext.prepareLogin(ticket);
      final normalizedPhone = normalizePhoneForCountry(phone: phone, countryCode: countryCode);
      final playIntegrity = await _playIntegrityEvidence('app_login_verify_otp').timeout(const Duration(seconds: 6));
      AccountContext.requireLoginAttempt(ticket);
      final data = <String, dynamic>{
        'phone': normalizedPhone, 'code': code, 'role': _loginRoleValue(role),
        'countryCode': countryCode, if (playIntegrity != null) 'playIntegrity': playIntegrity,
      };
      final response = await _dio.post('/verify-login-otp', data: data).timeout(const Duration(seconds: 15));
      AccountContext.requireLoginAttempt(ticket);
      final body = _asBody(response.data);
      if (body['success'] != true || body['session'] is! Map) {
        return WhatsAppLoginResult(success: false,
          message: body['message'] as String? ?? 'Verification failed',
          attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
          retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'));
      }
      await AccountContext.restoreServerSession(ticket, Map<String, dynamic>.from(body['session'] as Map));
      await AccountContext.completeVerifiedLogin(ticket).timeout(const Duration(seconds: 8));
      final resolvedRole = AppRole.fromString(body['role'] as String?);
      completed = true;
      return WhatsAppLoginResult(success: true, message: 'Verified successfully',
        role: resolvedRole.isAdmin ? AppRole.passenger : resolvedRole);
    } on DioException catch (error) {
      return _fromDioException(error, fallbackMessage: 'Network error. Check your connection.');
    } on Object {
      return const WhatsAppLoginResult(success: false,
        message: 'Unable to confirm and save this login. Request a new code.');
    } finally {
      if (!completed) {
        // abort invalidates trust before waiting for native/disk completion.
        try { await AccountContext.abortLogin(ticket).timeout(const Duration(seconds: 5)); } on Object { /* locked */ }
      }
      _attempt = null;
      _attemptOwner = null;
    }
  }

  String _loginRoleValue(AppRole role) {
    return role == AppRole.driver ? 'driver' : 'passenger';
  }

  Future<Map<String, dynamic>?> _playIntegrityEvidence(String action) async {
    try {
      return await _playIntegrityEvidenceProvider?.call(action);
    } on Object {
      if (kDebugMode) debugPrint('Play integrity evidence unavailable');
      return null;
    }
  }

  static String normalizePhoneForCountry({
    required String phone,
    required String countryCode,
  }) => PhoneNumberNormalizer.normalizeForCountry(
    phone: phone,
    countryCode: countryCode,
  );

  static bool isValidCanonicalPhone(String phone, {String? countryCode}) {
    if (countryCode == null) {
      return PhoneNumberNormalizer.isValidCanonical(phone);
    }
    return PhoneNumberNormalizer.isValidForCountry(
      phone: phone,
      countryCode: countryCode,
    );
  }

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
        message: _friendlyMessage(body['message'] as String?, fallbackMessage),
        retryAfterSeconds: _extractInt(body, 'retryAfterSeconds'),
        attemptsRemaining: _extractInt(body, 'attemptsRemaining'),
      );
    }

    return WhatsAppLoginResult(
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
