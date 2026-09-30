import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/features/profile/data/wallet_operation_journal.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Use the locked plugin's real method-channel backend for native I/O tests.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet_wire_record_test.dart'
    show summaryRow, ledgerRow, owner, other;

WalletService fixture(
  Object? response, {
  void Function()? requireCurrent,
  void Function(http.Request)? onRequest,
}) {
  final client = SupabaseClient(
    'https://wallet-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      onRequest?.call(request);
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return WalletService(
    supabase: client,
    captureAuthority: () =>
        WalletAuthority(userId: owner, requireCurrent: requireCurrent ?? () {}),
  );
}

const _operation = WalletOperationRecord(
  operationId: other,
  ownerId: owner,
  kind: 'transfer',
  status: 'prepared',
  amountTokens: 100,
  receiverMemberId: '004321',
  acknowledged: false,
);
const _nextOperation = WalletOperationRecord(
  operationId: '33333333-3333-4333-8333-333333333333',
  ownerId: owner,
  kind: 'transfer',
  status: 'prepared',
  amountTokens: 200,
  receiverMemberId: '004321',
  acknowledged: false,
);
const _nativeJournalKey = 'flutter.mobio.wallet.operation.v2.$owner';

String _pointer(WalletOperationRecord operation) => jsonEncode({
  'version': 2,
  'owner_id': operation.ownerId,
  'operation_id': operation.operationId,
  'kind': operation.kind,
});

Map<String, Object?> _closedResponse({bool cancel = true}) => {
  'operation_id': _operation.operationId,
  'owner_id': owner,
  'kind': 'transfer',
  'status': cancel ? 'cancelled' : 'committed',
  'amount_tokens': 100,
  'receiver_member_id': '004321',
  'acknowledged': true,
  'receipt': cancel ? null : {'transfer_id': other, 'status': 'completed'},
};

/// Only native storage is simulated. SharedPreferences cache, method-channel
/// encoding, Supabase RPC transport and WalletService all execute normally.
class _NativeWalletPreferences {
  final values = <String, Object>{_nativeJournalKey: _pointer(_operation)};
  final calls = <String>[];
  Future<void>? getAllWait;
  Future<void>? removeWait;
  Future<void>? setStringWait;
  bool removeSucceeds = true;
  PlatformException? removeError;
  final _callSignals = <String, Completer<void>>{};

  Future<void> waitForCall(String method, {int number = 1}) {
    if (calls.where((call) => call == method).length >= number) {
      return Future<void>.value();
    }
    return _callSignals
        .putIfAbsent('$method:$number', Completer<void>.new)
        .future
        .timeout(const Duration(seconds: 5));
  }

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final count = calls.where((method) => method == call.method).length;
    _callSignals['${call.method}:$count']?.complete();
    switch (call.method) {
      case 'getAll':
        if (getAllWait != null) await getAllWait;
        return Map<String, Object>.from(values);
      case 'remove':
        if (removeWait != null) await removeWait;
        if (removeError != null) throw removeError!;
        if (!removeSucceeds) return false;
        final arguments = call.arguments as Map<Object?, Object?>;
        values.remove(arguments['key']);
        return true;
      case 'setString':
        if (setStringWait != null) await setStringWait;
        final arguments = call.arguments as Map<Object?, Object?>;
        values[arguments['key']! as String] = arguments['value']! as String;
        return true;
      default:
        throw PlatformException(code: 'UNEXPECTED_STORAGE_METHOD');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativePreferencesStore = SharedPreferencesStorePlatform.instance;
  const preferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('confirmed wallet close local cleanup', () {
    late _NativeWalletPreferences native;
    late List<http.Request> requests;

    setUp(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = nativePreferencesStore;
      native = _NativeWalletPreferences();
      requests = [];
      messenger.setMockMethodCallHandler(preferencesChannel, native.handle);
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(preferencesChannel, null);
      SharedPreferences.resetStatic();
    });

    WalletService closingService({bool cancel = true}) =>
        fixture(_closedResponse(cancel: cancel), onRequest: requests.add);

    void expectSingleClose({bool cancel = true}) {
      expect(requests, hasLength(1));
      expect(requests.single.url.path, endsWith('/rpc_close_wallet_operation'));
      expect(jsonDecode(requests.single.body), {
        'p_operation_id': _operation.operationId,
        'p_action': cancel ? 'cancel' : 'acknowledge',
      });
    }

    test('confirmed cancellation removes only its matching pointer', () async {
      await closingService().closeOperation(_operation, cancel: true);
      expect(native.values, isEmpty);
      expect(native.calls.where((method) => method == 'remove'), hasLength(1));
      expectSingleClose();
    });

    test(
      'confirmed acknowledgement keeps the server receipt authoritative',
      () async {
        await closingService(
          cancel: false,
        ).closeOperation(_operation, cancel: false);
        expect(native.values, isEmpty);
        expectSingleClose(cancel: false);
      },
    );

    for (final throwsNativeError in [false, true]) {
      test(
        'native cleanup ${throwsNativeError ? 'error' : 'rejection'} cannot turn confirmed close into failure',
        () async {
          native.removeSucceeds = false;
          if (throwsNativeError) {
            native.removeError = PlatformException(code: 'STORAGE_UNAVAILABLE');
          }
          await closingService().closeOperation(_operation, cancel: true);
          expect(native.values[_nativeJournalKey], _pointer(_operation));
          expect(
            native.calls.where((method) => method == 'remove'),
            hasLength(1),
          );
          expectSingleClose();
          // A settled error releases the queue; no automatic close is replayed.
          await WalletOperationJournal.save(_nextOperation);
          expect(native.values[_nativeJournalKey], _pointer(_nextOperation));
          expectSingleClose();
        },
      );
    }

    for (final blockedMethod in ['getAll', 'remove']) {
      test(
        'hung native $blockedMethod cleanup completes the observer in four seconds',
        () async {
          await SharedPreferences.getInstance();
          final nativeReply = Completer<void>();
          if (blockedMethod == 'getAll') {
            native.getAllWait = nativeReply.future;
          } else {
            native.removeWait = nativeReply.future;
          }
          var completed = false;
          final closing = closingService().closeOperation(
            _operation,
            cancel: true,
          );
          final observed = closing.then((_) => completed = true);
          await native.waitForCall(
            blockedMethod,
            number: blockedMethod == 'getAll' ? 2 : 1,
          );
          expect(completed, isFalse);
          final cleanupWait = Stopwatch()..start();
          await observed.timeout(const Duration(seconds: 5));
          expect(completed, isTrue);
          expect(
            cleanupWait.elapsed,
            greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
          );
          expect(native.values[_nativeJournalKey], _pointer(_operation));
          expectSingleClose();
          // Settle the real native call before ending this test. The timeout
          // did not cancel storage or issue a second server mutation.
          nativeReply.complete();
          final drained =
              WalletOperationJournal.assertNoUnattributedLegacyRequest();
          await drained.timeout(const Duration(seconds: 5));
          expect(native.values, isEmpty);
          expectSingleClose();
        },
      );
    }

    for (final lateError in [false, true]) {
      test(
        'late native cleanup ${lateError ? 'error' : 'completion'} cannot erase a queued newer pointer',
        () async {
          final nativeReply = Completer<void>();
          native.removeWait = nativeReply.future;
          if (lateError) {
            native.removeError = PlatformException(
              code: 'LATE_STORAGE_FAILURE',
            );
          }
          var closed = false;
          final closing = closingService()
              .closeOperation(_operation, cancel: true)
              .then((_) => closed = true);
          await native.waitForCall('remove');
          expect(closed, isFalse);
          await closing.timeout(const Duration(seconds: 5));
          expect(closed, isTrue);
          expectSingleClose();

          // Newer recovery writes have bounded observers too, but neither
          // observer can release the old native remove's serialization slot.
          final saving = WalletOperationJournal.save(_nextOperation);
          final saveDeadline = saving.timeout(
            WalletOperationJournal.observationTimeout,
          );
          final deadlineAssertion = expectLater(
            saveDeadline,
            throwsA(isA<TimeoutException>()),
          );
          await deadlineAssertion;
          expect(native.calls, isNot(contains('setString')));
          expect(native.values[_nativeJournalKey], _pointer(_operation));

          nativeReply.complete();
          await saving.timeout(const Duration(seconds: 5));
          expect(native.values[_nativeJournalKey], _pointer(_nextOperation));
          final removeCalls = native.calls
              .where((method) => method == 'remove')
              .length;
          await WalletOperationJournal.clear(owner, _operation.operationId);
          expect(
            native.calls.where((method) => method == 'remove'),
            hasLength(removeCalls),
          );
          expect(native.values[_nativeJournalKey], _pointer(_nextOperation));
          expectSingleClose();
        },
      );
    }

    test(
      'a late recovery write settles before queued matching cleanup',
      () async {
        final nativeReply = Completer<void>();
        native.setStringWait = nativeReply.future;
        final saving = WalletOperationJournal.save(_operation);
        final saveDeadline = saving.timeout(
          WalletOperationJournal.observationTimeout,
        );
        final deadlineAssertion = expectLater(
          saveDeadline,
          throwsA(isA<TimeoutException>()),
        );
        await native.waitForCall('setString');
        await deadlineAssertion;
        final clearing = WalletOperationJournal.clear(
          owner,
          _operation.operationId,
        );
        await Future<void>.delayed(Duration.zero);
        expect(native.calls, isNot(contains('remove')));
        nativeReply.complete();
        await clearing.timeout(const Duration(seconds: 5));
        await saving;
        expect(native.values, isEmpty);
        expect(requests, isEmpty);
      },
    );
  });

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
