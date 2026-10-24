import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

void main() {
  for (final mode in ['review_code', 'whatsapp', null]) {
    test(
      'reads delivery mode $mode without changing the OTP request',
      () async {
        final dio = Dio();
        addTearDown(dio.close);
        RequestOptions? request;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'deliveryMode': ?mode,
                    if (mode == 'review_code')
                      'challengeId': '44444444-4444-4444-8444-444444444444',
                    'retryAfterSeconds': 60,
                  },
                ),
              );
            },
          ),
        );
        final result = await WhatsAppLoginService(dio: dio).sendLoginOtp(
          phone: '0789 000 123',
          countryCode: '+250',
          role: AppRole.driver,
        );
        expect(result.success, isTrue);
        expect(result.usesReviewCode, mode == 'review_code');
        expect(
          result.challengeId,
          mode == 'review_code' ? '44444444-4444-4444-8444-444444444444' : null,
        );
        expect(result.retryAfterSeconds, 60);
        expect(request?.path, '/send-login-otp');
        expect(request?.data, {
          'phone': '+250789000123',
          'countryCode': '+250',
          'role': 'driver',
        });
      },
    );
  }

  for (final challenge in [null, '', 'not-a-challenge']) {
    test(
      'review delivery without a valid opaque challenge is rejected ($challenge)',
      () async {
        final dio = Dio();
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'deliveryMode': 'review_code',
                    'challengeId': challenge,
                  },
                ),
              );
            },
          ),
        );
        final result = await WhatsAppLoginService(dio: dio).sendLoginOtp(
          phone: '0789 000 123',
          countryCode: '+250',
          role: AppRole.driver,
        );
        expect(result.success, false);
        expect(result.usesReviewCode, false);
        expect(result.challengeId, null);
      },
    );
  }

  group('WhatsAppLoginService phone normalization', () {
    test('removes local trunk zero for Rwanda numbers', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '0788 123 456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('keeps canonical E.164 phone numbers', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '+250788123456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('handles pasted country code without plus', () {
      expect(
        WhatsAppLoginService.normalizePhoneForCountry(
          phone: '250788123456',
          countryCode: '+250',
        ),
        '+250788123456',
      );
    });

    test('rejects short canonical numbers for send readiness', () {
      expect(WhatsAppLoginService.isValidCanonicalPhone('+25012'), false);
      expect(WhatsAppLoginService.isValidCanonicalPhone('+250788123456'), true);
    });

    test('uses selected-country semantics for send readiness', () {
      expect(
        WhatsAppLoginService.isValidCanonicalPhone(
          '788123456',
          countryCode: '+250',
        ),
        true,
      );
      expect(
        WhatsAppLoginService.isValidCanonicalPhone(
          '356123456',
          countryCode: '+250',
        ),
        false,
      );
    });
  });
}
