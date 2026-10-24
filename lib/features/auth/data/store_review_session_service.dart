import 'package:dio/dio.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticated status is the only client admission to the bundled journey.
/// Ordinary account services continue to require AccountContext.capture().
class StoreReviewSessionService {
  StoreReviewSessionService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: SupabaseConfig.functionsBaseUrl,
              headers: {'apikey': SupabaseConfig.anonKey},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );
  final Dio _dio;

  Future<Object?> status() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null ||
        session.user.appMetadata['provider'] != 'store_review') {
      throw const ReviewAccessUnavailable();
    }
    final response = await _dio
        .post(
          '/store-review-session',
          data: {'action': 'status'},
          options: Options(
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          ),
        )
        .timeout(const Duration(seconds: 10));
    final data = response.data;
    if (data is! Map ||
        data['success'] != true ||
        data['reviewSession'] is! Map) {
      throw const ReviewAccessUnavailable();
    }
    return data['reviewSession'];
  }

  Future<bool> validate() async {
    final context = AccountContext.reviewSession;
    ReviewValidationTicket? ticket;
    try {
      ticket = context.beginValidation();
      final response = await status();
      context.acceptStatus(ticket, response);
      return true;
    } on Object {
      if (ticket != null) context.rejectStatus(ticket);
      return false;
    }
  }
}
