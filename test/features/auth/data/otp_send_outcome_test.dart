import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/admin/data/otp_service.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final Future<ResponseBody> Function() reply;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return reply();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final admin in [false, true]) {
    Future<OtpResult> send(
      Dio dio, {
      Duration timeout = const Duration(milliseconds: 100),
    }) => admin
        ? OtpService.sendOtp(
            phone: '0788123456',
            countryCode: '+250',
            dio: dio,
            requestTimeout: timeout,
          )
        : WhatsAppLoginService(dio: dio, requestTimeout: timeout).sendLoginOtp(
            phone: '0788123456',
            countryCode: '+250',
            role: AppRole.passenger,
          );
    for (final success in [true, false]) {
      test(
        '${admin ? 'admin' : 'app'} preserves usable send metadata: $success',
        () async {
          final adapter = _Adapter(
            () async => ResponseBody.fromString(
              jsonEncode({
                'success': success,
                'message': 'Fixture result',
                'retryAfterSeconds': 42,
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            ),
          );
          final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
            ..httpClientAdapter = adapter;
          addTearDown(dio.close);
          final result = await send(dio);
          expect(result.success, success);
          expect(result.deliveryUnconfirmed, isFalse);
          expect(
            result.message,
            admin && success ? 'OTP sent to your WhatsApp' : 'Fixture result',
          );
          expect(result.retryAfterSeconds, admin && success ? null : 42);
          expect(adapter.calls, 1);
        },
      );
      for (final message in [null, 42, true, <Object>[], <String, Object>{}]) {
        test(
          '${admin ? 'admin' : 'app'} preserves send outcome with optional message $message: $success',
          () async {
            final adapter = _Adapter(
              () async => ResponseBody.fromString(
                jsonEncode({
                  'success': success,
                  'message': message,
                  'retryAfterSeconds': 42,
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              ),
            );
            final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
              ..httpClientAdapter = adapter;
            addTearDown(dio.close);
            final result = await send(dio);
            expect(result.success, success);
            expect(result.deliveryUnconfirmed, isFalse);
            expect(
              result.message,
              success ? 'OTP sent to your WhatsApp' : 'Failed to send OTP',
            );
            expect(result.retryAfterSeconds, admin && success ? null : 42);
            expect(adapter.calls, 1);
          },
        );
      }
    }
    for (final body in [
      <String, Object>{},
      {'success': 'true', 'message': 'Sent'},
    ]) {
      test(
        '${admin ? 'admin' : 'app'} still requires a boolean send acknowledgement: $body',
        () async {
          final adapter = _Adapter(
            () async => ResponseBody.fromString(
              jsonEncode(body),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            ),
          );
          final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
            ..httpClientAdapter = adapter;
          addTearDown(dio.close);
          final result = await send(dio);
          expect(result.success, isFalse);
          expect(result.deliveryUnconfirmed, isTrue);
          expect(result.retryAfterSeconds, 60);
          expect(adapter.calls, 1);
        },
      );
    }
    test(
      '${admin ? 'admin' : 'app'} send loses transport reply without claiming delivery failed or resending',
      () async {
        final adapter = _Adapter(
          () =>
              Future<ResponseBody>.error(http.ClientException('response lost')),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
          ..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final result = await send(dio);
        expect(result.success, isFalse);
        expect(result.deliveryUnconfirmed, isTrue);
        expect(result.retryAfterSeconds, 60);
        expect(result.message, contains('Check WhatsApp'));
        expect(adapter.calls, 1);
      },
    );
    test(
      '${admin ? 'admin' : 'app'} send total deadline releases a hung callback',
      () async {
        final reply = Completer<ResponseBody>();
        final adapter = _Adapter(() => reply.future);
        final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
          ..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final result = await send(
          dio,
          timeout: const Duration(milliseconds: 2),
        );
        expect(result.deliveryUnconfirmed, isTrue);
        expect(adapter.calls, 1);
        reply.complete(
          ResponseBody.fromString(
            '{"success":true}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adapter.calls, 1);
      },
    );
    test(
      '${admin ? 'admin' : 'app'} explicit rejection retains server cooldown',
      () async {
        final adapter = _Adapter(
          () async => ResponseBody.fromString(
            '{"success":false,"retryAfterSeconds":42,"message":"Rejected"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
          ..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final result = await send(dio);
        expect(result.deliveryUnconfirmed, isFalse);
        expect(result.retryAfterSeconds, 42);
        expect(result.message, 'Rejected');
        expect(adapter.calls, 1);
      },
    );
  }
}
