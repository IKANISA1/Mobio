import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'read deadline reports a timeout without changing read semantics',
    () async {
      final pending = Completer<String>();
      await expectLater(
        RequestDeadline.read(
          pending.future,
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
      pending.complete('late read');
    },
  );

  test(
    'mutation deadline preserves operation identity and uncertainty',
    () async {
      final pending = Completer<String>();
      var starts = 0;
      Future<String> startWrite() {
        starts++;
        return pending.future;
      }

      await expectLater(
        RequestDeadline.mutation(
          startWrite(),
          operation: 'create_trip',
          operationId: 'request-123',
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(
          isA<MutationOutcomeUnknownException>()
              .having((error) => error.operation, 'operation', 'create_trip')
              .having(
                (error) => error.operationId,
                'operation ID',
                'request-123',
              ),
        ),
      );
      pending.complete('late committed reply');
      expect(starts, 1, reason: 'a timeout must not start another write');
    },
  );

  test('lost transport reply is an unknown write outcome', () async {
    await expectLater(
      RequestDeadline.mutation(
        Future<void>.error(const SocketException('connection reset')),
        operation: 'update_profile',
        operationId: 'member-1',
      ),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });

  test('explicit server rejection remains a confirmed error', () async {
    const rejection = PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    await expectLater(
      RequestDeadline.mutation(
        Future<void>.error(rejection),
        operation: 'update_profile',
      ),
      throwsA(same(rejection)),
    );
  });

  test('Edge Function 5xx after a write is uncertain', () async {
    await expectLater(
      RequestDeadline.mutation(
        Future<void>.error(const FunctionException(status: 500)),
        operation: 'create_privacy_request',
      ),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });

  test('Edge Function validation rejection remains confirmed', () async {
    const rejection = FunctionException(status: 400);
    await expectLater(
      RequestDeadline.mutation(
        Future<void>.error(rejection),
        operation: 'create_privacy_request',
      ),
      throwsA(same(rejection)),
    );
  });
  test(
    'real PostgREST adapter exposes a proxy 502 as an unknown write',
    () async {
      final client = SupabaseClient(
        'https://deadline-fixture.invalid',
        'synthetic-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '<html>proxy failure</html>',
            502,
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        RequestDeadline.mutation(
          client.rpc('fixture_write'),
          operation: 'fixture_write',
        ),
        throwsA(
          isA<MutationOutcomeUnknownException>().having(
            (error) => error.originalError,
            'SDK error',
            isA<PostgrestException>().having(
              (error) => error.code,
              'proxy code',
              '502',
            ),
          ),
        ),
      );
    },
  );
  for (final code in ['23505', '42501', 'PT503', 'XX000']) {
    test('structured database error $code remains a known rejection', () async {
      final client = SupabaseClient(
        'https://deadline-fixture.invalid',
        'synthetic-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"code":"$code","message":"rejected"}',
            503,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        RequestDeadline.mutation(
          client.rpc('fixture_write'),
          operation: 'fixture_write',
        ),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'database code',
            code,
          ),
        ),
      );
    });
  }
}
