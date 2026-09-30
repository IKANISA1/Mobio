// Authored Flutter tests. Run on the pinned real Flutter/Dart toolchain.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/startup_task.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';

void main() {
  const owner = '11111111-1111-4111-8111-111111111111';
  const session = '22222222-2222-4222-8222-222222222222';
  setUp(AdminSessionGuard.revoke);
  tearDown(AdminSessionGuard.revoke);
  test('account generation invalidates A to B to A stale work', () {
    final epoch=AccountEpoch();
    final first=epoch.update('A:one');
    expect(epoch.update('A:one'),first);
    epoch..update('B:two')..update('A:one');
    expect(epoch.matches('A:one',first),isFalse);
  });
  test('explicit exit invalidates work without replacing identity', () {
    final epoch=AccountEpoch(); final version=epoch.update('A');epoch.invalidate();
    expect(epoch.matches('A',version),isFalse);
  });
  test('client-only grant cannot grant admin access', () {
    // ignore: deprecated_member_use_from_same_package
    AdminSessionGuard.grant(owner);
    expect(AdminSessionGuard.isAdmin,isFalse);
  });
  test('accepted server lease is owner and session scoped', () {
    AdminSessionGuard.acceptServerLease(userId:owner,sessionId:session,
      idleRemaining:const Duration(minutes:10),absoluteRemaining:const Duration(hours:1));
    expect(AdminSessionGuard.isAdminFor(owner,sessionId:session),isTrue);
    expect(AdminSessionGuard.isAdminFor('other',sessionId:session),isFalse);
    expect(AdminSessionGuard.isAdminFor(owner,sessionId:'other'),isFalse);
    expect(AdminSessionGuard.isAdminFor(owner),isFalse);
    AdminSessionGuard.revoke();expect(AdminSessionGuard.isAdmin,isFalse);
  });
  test('zero or excessive server lease fails closed', () {
    for(final remaining in [Duration.zero,const Duration(minutes:31)]) {
      expect(()=>AdminSessionGuard.acceptServerLease(userId:owner,sessionId:session,
        idleRemaining:remaining,absoluteRemaining:const Duration(hours:1)),throwsStateError);
      expect(AdminSessionGuard.isAdmin,isFalse);
    }
  });
  test('startup budget completes a successful initializer', () async {
    final result=await runStartupTask(()=>Future.value(7),const Duration(seconds:1));
    expect(result.completed,isTrue);expect(result.value,7);
  });
  test('startup failure has no false completed status', () async {
    final result=await runStartupTask<int>(()=>throw StateError('synthetic'),const Duration(seconds:1));
    expect(result.completed,isFalse);expect(result.timedOut,isFalse);
  });
  test('startup timeout bounds wait but does not imply cancellation', () async {
    final pending=Completer<int>();
    final result=await runStartupTask(()=>pending.future,const Duration(milliseconds:1));
    expect(result.completed,isFalse);expect(result.timedOut,isTrue);
    pending.complete(9);expect(await pending.future,9);
  });
  Map<String,dynamic> record()=>{'operation_id':session,'owner_id':owner,'kind':'transfer','status':'prepared',
    'amount_tokens':1000,'acknowledged':false,'receiver_member_id':'123456','receipt':null};
  test('valid wallet preparation preserves exact owner and operation', () {
    final result=WalletOperationRecord.fromJson(record(),ownerId:owner);
    expect(result.ownerId,owner);expect(result.operationId,session);expect(result.committed,isFalse);
  });
  for(final override in <Map<String,dynamic>>[
    {'owner_id':'other'},{'operation_id':'------------------------------------'},{'amount_tokens':0},
    {'amount_tokens':1.5},{'amount_tokens':9007199254740992},{'kind':'payment'},
    {'status':'success'},{'status':'committed','receipt':null},{'acknowledged':1},
    {'receiver_member_id':'1'},{'kind':'redeem','receiver_member_id':'123456'},
  ]) {
    test('invalid wallet record rejected: $override', () {
      expect(()=>WalletOperationRecord.fromJson({...record(),...override},ownerId:owner),throwsFormatException);
    });
  }
}
