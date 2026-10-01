import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
// Exercise deadlines with the existing locked test clock; no new dependency.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/admin/data/otp_service.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final Future<ResponseBody> Function() reply;
  int calls = 0;
  final entered = Completer<RequestOptions>();
  final settled = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (!entered.isCompleted) entered.complete(options);
    return reply().whenComplete(() {
      if (!settled.isCompleted) settled.complete();
    });
  }

  @override
  void close({bool force = false}) {}
}

OtpResult _sendBeforeDeadline(Future<OtpResult> Function() send) =>
    fakeAsync((clock) {
      final results = <OtpResult>[];
      unawaited(send().then(results.add));
      // Immediate response fixtures test parsing and outcome classification.
      // Run Dio's scheduled work before advancing time, so host scheduling
      // cannot turn a known fixture response into an unrelated deadline case.
      clock
        ..flushMicrotasks()
        ..elapse(Duration.zero);
      expect(results, hasLength(1));
      return results.single;
    });

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
        () {
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
          final result = _sendBeforeDeadline(() => send(dio));
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
          () {
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
            final result = _sendBeforeDeadline(() => send(dio));
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
        () {
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
          final result = _sendBeforeDeadline(() => send(dio));
          expect(result.success, isFalse);
          expect(result.deliveryUnconfirmed, isTrue);
          expect(result.retryAfterSeconds, 60);
          expect(adapter.calls, 1);
        },
      );
    }
    test(
      '${admin ? 'admin' : 'app'} send loses transport reply without claiming delivery failed or resending',
      () {
        final adapter = _Adapter(
          () =>
              Future<ResponseBody>.error(http.ClientException('response lost')),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
          ..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final result = _sendBeforeDeadline(() => send(dio));
        expect(result.success, isFalse);
        expect(result.deliveryUnconfirmed, isTrue);
        expect(result.retryAfterSeconds, 60);
        expect(result.message, contains('Check WhatsApp'));
        expect(adapter.calls, 1);
      },
    );
    test(
      '${admin ? 'admin' : 'app'} send total deadline releases a hung callback',
      () {
        fakeAsync((clock) {
          final reply = Completer<ResponseBody>();
          final adapter = _Adapter(() => reply.future);
          final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
            ..httpClientAdapter = adapter;
          addTearDown(dio.close);
          final results = <OtpResult>[];
          unawaited(
            send(
              dio,
              timeout: const Duration(milliseconds: 2),
            ).then(results.add),
          );
          // Dio schedules interceptors and adapter entry on zero-duration
          // timers. Run those without advancing the deadline clock, and require
          // actual adapter entry before testing a hung transport response.
          clock
            ..flushMicrotasks()
            ..elapse(Duration.zero);
          expect(adapter.entered.isCompleted, isTrue);
          expect(adapter.calls, 1);
          expect(reply.isCompleted, isFalse);
          expect(adapter.settled.isCompleted, isFalse);
          expect(results, isEmpty);

          clock.elapse(const Duration(milliseconds: 1));
          expect(results, isEmpty);
          clock.elapse(const Duration(milliseconds: 1));
          expect(results, hasLength(1));
          final result = results.single;
          expect(result.success, isFalse);
          expect(result.deliveryUnconfirmed, isTrue);
          expect(result.retryAfterSeconds, 60);
          expect(result.message, contains('Check WhatsApp'));
          expect(adapter.settled.isCompleted, isFalse);
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
          clock
            ..flushMicrotasks()
            ..elapse(Duration.zero);
          expect(adapter.settled.isCompleted, isTrue);
          // A late success neither changes the published unknown result nor
          // retries automatically, including after the offered cooldown.
          clock.elapse(const Duration(seconds: 61));
          expect(results, hasLength(1));
          expect(results.single, same(result));
          expect(results.single.deliveryUnconfirmed, isTrue);
          expect(adapter.calls, 1);
        });
      },
    );
    test(
      '${admin ? 'admin' : 'app'} total deadline also bounds waiting before adapter dispatch',
      () {
        fakeAsync((clock) {
          final dispatchAllowed = Completer<void>();
          final interceptorEntered = Completer<void>();
          final adapter = _Adapter(
            () async => ResponseBody.fromString(
              '{"success":true}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            ),
          );
          final dio = Dio(BaseOptions(baseUrl: 'https://otp-fixture.invalid'))
            ..httpClientAdapter = adapter;
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                interceptorEntered.complete();
                unawaited(
                  dispatchAllowed.future.then((_) => handler.next(options)),
                );
              },
            ),
          );
          addTearDown(dio.close);
          final results = <OtpResult>[];
          unawaited(
            send(
              dio,
              timeout: const Duration(milliseconds: 2),
            ).then(results.add),
          );
          clock
            ..flushMicrotasks()
            ..elapse(Duration.zero);
          expect(interceptorEntered.isCompleted, isTrue);
          expect(adapter.entered.isCompleted, isFalse);
          expect(adapter.calls, 0);
          expect(results, isEmpty);
          clock.elapse(const Duration(milliseconds: 2));
          expect(results, hasLength(1));
          final result = results.single;
          expect(result.success, isFalse);
          expect(result.deliveryUnconfirmed, isTrue);
          expect(adapter.calls, 0);

          // The observer deadline is not transport cancellation. The original
          // late dispatch may finish, but it never becomes a second send.
          dispatchAllowed.complete();
          clock
            ..flushMicrotasks()
            ..elapse(Duration.zero);
          expect(adapter.entered.isCompleted, isTrue);
          expect(adapter.settled.isCompleted, isTrue);
          clock.elapse(const Duration(seconds: 61));
          expect(results, hasLength(1));
          expect(results.single, same(result));
          expect(results.single.deliveryUnconfirmed, isTrue);
          expect(adapter.calls, 1);
        });
      },
    );
    test(
      '${admin ? 'admin' : 'app'} explicit rejection retains server cooldown',
      () {
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
        final result = _sendBeforeDeadline(() => send(dio));
        expect(result.deliveryUnconfirmed, isFalse);
        expect(result.retryAfterSeconds, 42);
        expect(result.message, 'Rejected');
        expect(adapter.calls, 1);
      },
    );
  }
}
