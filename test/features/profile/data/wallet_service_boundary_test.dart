import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet_wire_record_test.dart'
    show summaryRow, ledgerRow, owner, other;

WalletService fixture(Object? response, {void Function()? requireCurrent}) {
  final client = SupabaseClient(
    'https://wallet-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return WalletService(
    supabase: client,
    captureAuthority: () =>
        WalletAuthority(userId: owner, requireCurrent: requireCurrent ?? () {}),
  );
}

void main() {
  test(
    'malformed close acknowledgement stays unknown and keeps its identity',
    () async {
      const operation = WalletOperationRecord(
        operationId: other,
        ownerId: owner,
        kind: 'transfer',
        status: 'prepared',
        amountTokens: 100,
        receiverMemberId: '004321',
        acknowledged: false,
      );
      await expectLater(
        fixture({}).closeOperation(operation, cancel: true),
        throwsA(
          isA<UnknownWalletOutcome>().having(
            (error) => error.operationId,
            'operation',
            other,
          ),
        ),
      );
    },
  );
  test(
    'missing, wrong or ambiguous recipient payload cannot confirm 004321',
    () async {
      for (final response in [
        null,
        <String, dynamic>{},
        {'member_id': '004322', 'display_name': 'Recipient'},
        [
          {'member_id': '004321', 'display_name': 'First'},
          {'member_id': '004321', 'display_name': 'Second'},
        ],
      ]) {
        await expectLater(
          fixture(response).lookupTransferRecipient(receiverMemberId: '004321'),
          throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
        );
      }
    },
  );
  test(
    'malformed execution acknowledgement retains the operation for reconciliation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      final prepared = <String, dynamic>{
        'operation_id': other,
        'owner_id': owner,
        'kind': 'transfer',
        'status': 'prepared',
        'amount_tokens': 100,
        'receiver_member_id': '004321',
        'acknowledged': false,
        'receipt': null,
      };
      final client = SupabaseClient(
        'https://wallet-contract.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final fn = request.url.path.split('/').last;
          calls.add(fn);
          final row = fn == 'rpc_prepare_wallet_operation'
              ? prepared
              : {
                  ...prepared,
                  'status': 'committed',
                  'receipt': <String, dynamic>{},
                };
          return http.Response(
            jsonEncode(row),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = WalletService(
        supabase: client,
        captureAuthority: () =>
            WalletAuthority(userId: owner, requireCurrent: () {}),
      );
      await expectLater(
        service.transferOperation(
          receiverMemberId: '004321',
          amountTokens: 100,
          idempotencyKey: other,
        ),
        throwsA(
          isA<UnknownWalletOutcome>().having(
            (error) => error.operationId,
            'operation',
            other,
          ),
        ),
      );
      expect(calls, [
        'rpc_prepare_wallet_operation',
        'rpc_execute_wallet_operation',
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('mobio.wallet.operation.v2.$owner'),
        contains(other),
      );
    },
  );

  test('a malformed ledger payload cannot become an empty ledger', () async {
    for (final raw in [
      null,
      <String, dynamic>{},
      [ledgerRow(), 7],
    ]) {
      await expectLater(fixture(raw).listLedger(), throwsFormatException);
    }
  });

  test('an explicitly empty ledger remains valid', () async {
    expect(await fixture([]).listLedger(), isEmpty);
  });

  test('summary and ledger rows must belong to the captured owner', () async {
    await expectLater(
      fixture({...summaryRow(), 'profile_id': other}).getSummary(),
      throwsFormatException,
    );
    await expectLater(
      fixture([
        {...ledgerRow(), 'profile_id': other},
      ]).listLedger(),
      throwsFormatException,
    );
  });

  test(
    'a committed operation with an empty receipt cannot claim completion',
    () async {
      final row = {
        'operation_id': other,
        'owner_id': owner,
        'kind': 'transfer',
        'status': 'committed',
        'amount_tokens': 100,
        'receiver_member_id': '482013',
        'acknowledged': false,
        'receipt': <String, dynamic>{},
      };
      await expectLater(fixture(row).activeOperation(), throwsFormatException);
    },
  );

  test(
    'committed redemption receipt amount must match the operation',
    () async {
      final row = {
        'operation_id': other,
        'owner_id': owner,
        'kind': 'redeem',
        'status': 'committed',
        'amount_tokens': 5000,
        'receiver_member_id': null,
        'acknowledged': false,
        'receipt': {
          'redemption_id': owner,
          'transfer_id': other,
          'status': 'pending',
          'admin_member_id': '482013',
          'amount_tokens': 6000,
          'amount_rwf': 6000,
          'momo_number': null,
        },
      };
      await expectLater(fixture(row).activeOperation(), throwsFormatException);
    },
  );

  test(
    'only explicit not-observed status represents no active operation',
    () async {
      expect(
        await fixture({'status': 'not_observed'}).activeOperation(),
        isNull,
      );
      await expectLater(fixture(null).activeOperation(), throwsFormatException);
      await expectLater(fixture({}).activeOperation(), throwsFormatException);
    },
  );

  test(
    'late wallet summary is discarded after account generation changes',
    () async {
      final response = Completer<http.Response>();
      final called = Completer<http.Request>();
      final client = SupabaseClient(
        'https://wallet-contract.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          called.complete(request);
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      var current = true;
      final service = WalletService(
        supabase: client,
        captureAuthority: () => WalletAuthority(
          userId: owner,
          requireCurrent: () {
            if (!current) throw const StaleAccountWork();
          },
        ),
      );
      final pending = service.getSummary();
      final assertion = expectLater(pending, throwsA(isA<StaleAccountWork>()));
      final request = await called.future;
      current = false;
      response.complete(
        http.Response(
          jsonEncode(summaryRow()),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      await assertion;
    },
  );
}
