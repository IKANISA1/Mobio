import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BiopayApiClient {
  final SupabaseClient _supabase;

  BiopayApiClient(this._supabase);

  Future<Map<String, dynamic>> enrollFace({
    required String displayName,
    required String ussdString,
    required List<double> embedding,
    required double qualityScore,
    required String clientInstallId,
    required int consentVersion,
    String modelVersion = 'mobilefacenet_float32_v1',
  }) async {
    return _invoke('enroll_face', {
      'display_name': displayName,
      'ussd_string': ussdString,
      'embedding': embedding,
      'quality_score': qualityScore,
      'model_version': modelVersion,
      'consent_version': consentVersion,
      'client_install_id': clientInstallId,
    });
  }

  Future<Map<String, dynamic>> matchFace({
    required List<double> embedding,
    required String clientInstallId,
    String? deviceLabel,
  }) async {
    return _invoke('match_face', {
      'embedding': embedding,
      'client_install_id': clientInstallId,
      'device_label': deviceLabel,
    });
  }

  Future<Map<String, dynamic>> getManagedProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    bool issueOwnerToken = false,
  }) async {
    return _invoke('get_managed_profile', {
      'owner_token': ownerToken,
      'biopay_id': biopayId,
      'management_code': managementCode,
      'issue_owner_token': issueOwnerToken,
    });
  }

  Future<Map<String, dynamic>> updateProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    String? displayName,
    String? ussdString,
    String? clientInstallId,
  }) async {
    return _invoke('update_profile', {
      'owner_token': ownerToken,
      'biopay_id': biopayId,
      'management_code': managementCode,
      'display_name': displayName,
      'ussd_string': ussdString,
      'client_install_id': clientInstallId,
    });
  }

  Future<Map<String, dynamic>> reEnrollFace({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    required List<double> embedding,
    required double qualityScore,
    String? clientInstallId,
    String modelVersion = 'mobilefacenet_float32_v1',
  }) async {
    return _invoke('re_enroll_face', {
      'owner_token': ownerToken,
      'biopay_id': biopayId,
      'management_code': managementCode,
      'embedding': embedding,
      'quality_score': qualityScore,
      'model_version': modelVersion,
      'client_install_id': clientInstallId,
    });
  }

  Future<Map<String, dynamic>> deleteProfile({
    String? ownerToken,
    String? biopayId,
    String? managementCode,
    String? clientInstallId,
  }) async {
    return _invoke('delete_profile', {
      'owner_token': ownerToken,
      'biopay_id': biopayId,
      'management_code': managementCode,
      'client_install_id': clientInstallId,
    });
  }

  Future<Map<String, dynamic>> reportProfile({
    required String biopayId,
    required String reason,
    String? notes,
    String? clientInstallId,
  }) async {
    return _invoke('report_profile', {
      'biopay_id': biopayId,
      'reason': reason,
      'notes': notes,
      'client_install_id': clientInstallId,
    });
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'biopay-api',
        body: {'action': action, ...params},
      );

      if (response.status < 200 || response.status >= 300) {
        final errorData = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : {'error': 'Request failed with status ${response.status}'};
        throw BiopayApiException(
          action: action,
          statusCode: response.status,
          message:
              errorData['error']?.toString() ??
              errorData['message']?.toString() ??
              'Unknown error',
        );
      }

      return unwrapFunctionData(
        action: action,
        statusCode: response.status,
        rawData: response.data,
      );
    } on Object catch (e) {
      if (e is BiopayApiException) rethrow;
      throw BiopayApiException(
        action: action,
        statusCode: 0,
        message: e.toString(),
      );
    }
  }

  @visibleForTesting
  static Map<String, dynamic> unwrapFunctionData({
    required String action,
    required int statusCode,
    required Object? rawData,
  }) {
    if (rawData is Map) {
      final map = Map<String, dynamic>.from(rawData);
      if (map['error'] != null) {
        throw BiopayApiException(
          action: action,
          statusCode: statusCode,
          message: map['error']?.toString() ?? 'Unknown error',
        );
      }
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }

    throw BiopayApiException(
      action: action,
      statusCode: statusCode,
      message: 'Unexpected BioPay response payload.',
    );
  }
}

class BiopayApiException implements Exception {
  final String action;
  final int statusCode;
  final String message;

  const BiopayApiException({
    required this.action,
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'BiopayApiException($action, $statusCode): $message';

  bool get isDuplicate => statusCode == 409;
  bool get isRateLimited => statusCode == 429;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
}
