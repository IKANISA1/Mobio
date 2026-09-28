// Run with the pinned Flutter SDK. These tests execute the Dart coordinator,
// with explicit memory storage/RPC doubles. They do not test PostgreSQL or Auth.
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';
import 'chat_protocol_fixture.dart';

void main(){
 test('normal send acknowledges one immutable operation and clears pointer',()async{
  final f=ProtocolFixture();final result=await f.client.send(conversationA,' hello ');
  expect(result.state,ChatDeliveryState.sent);expect(result.acknowledged,isTrue);
  expect(f.effects,1);expect(f.store.pointer,isNull);
  expect(result.pointer.bodySha256,ChatSendPointer.bodyHash('hello'));
 });
 test('lost reply reuses the original id without a second effect',()async{
  final f=ProtocolFixture()..loseSendReply=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<TimeoutException>()));
  final id=f.store.pointer!.clientMessageId;
  f.loseSendReply=false;await f.client.send(conversationA,'hello');
  expect(f.sendIds,[id,id]);expect(f.effects,1);expect(f.store.pointer,isNull);
 });
 test('server-side pending record recovers after local pointer loss',()async{
  final f=ProtocolFixture()..loseSendReply=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<TimeoutException>()));
  f.store.pointer=null;
  final result=await f.client.resolve(conversationA);
  expect(result!.state,ChatDeliveryState.sent);expect(f.effects,1);expect(f.store.pointer,isNull);
 });
 test('different draft cannot replace an unresolved send',()async{
  final f=ProtocolFixture()..loseSendReply=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<TimeoutException>()));
  await expectLater(f.client.send(conversationA,'changed'),throwsA(isA<ChatDeliveryException>()));
  expect(f.effects,1);expect(f.sendIds.length,1);
 });
 test('write failure prevents dispatch',()async{
  final f=ProtocolFixture();f.store.failWrite=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<ChatDeliveryException>()));
  expect(f.sendIds,isEmpty);expect(f.effects,0);
 });
 test('corrupt local record blocks replay rather than deleting evidence',()async{
  final f=ProtocolFixture();f.store.corruptRead=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<ChatDeliveryException>()));
  expect(f.sendIds,isEmpty);
 });
 test('uncommitted outcome is retained until explicit cancellation',()async{
  final f=ProtocolFixture()..rejectSend=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsStateError);
  final result=await f.client.resolve(conversationA);
  expect(result!.state,ChatDeliveryState.notObserved);expect(f.store.pointer,isNotNull);
  final cancelled=await f.client.resolve(conversationA,cancelIfUnobserved:true);
  expect(cancelled!.state,ChatDeliveryState.cancelled);expect(f.effects,0);expect(f.store.pointer,isNull);
 });
 test('cancel after a commit resolves sent; it does not claim unsent',()async{
  final f=ProtocolFixture()..loseSendReply=true;
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<TimeoutException>()));
  final result=await f.client.resolve(conversationA,cancelIfUnobserved:true);
  expect(result!.state,ChatDeliveryState.sent);expect(f.effects,1);
 });
 test('lost close reply retains pointer and can reconcile',()async{
  final f=ProtocolFixture()..loseCloseReply=true;
  final committed=await f.client.send(conversationA,'hello');
  expect(committed.state,ChatDeliveryState.sent);
  expect(f.store.pointer,isNotNull);f.loseCloseReply=false;
  final result=await f.client.resolve(conversationA);
  expect(result!.state,ChatDeliveryState.sent);expect(f.effects,1);expect(f.store.pointer,isNull);
 });
 test('close and storage removal failure do not make a replacement id',()async{
  final f=ProtocolFixture()..failClose=true;
  final sent=await f.client.send(conversationA,'hello');
  expect(sent.state,ChatDeliveryState.sent);expect(sent.acknowledged,isFalse);
  final id=f.store.pointer!.clientMessageId;f.failClose=false;f.store.failRemove=true;
  await expectLater(f.client.resolve(conversationA),throwsA(isA<ChatDeliveryException>()));
  expect(f.store.pointer!.clientMessageId,id);f.store.failRemove=false;
  await f.client.resolve(conversationA);expect(f.effects,1);
 });
 test('concurrent callbacks cannot dispatch two requests',()async{
  final entered=Completer<void>(),release=Completer<void>();final f=ProtocolFixture();
  f.before=(fn)async{if(fn=='rpc_send_chat_message_v2'){entered.complete();await release.future;}};
  final first=f.client.send(conversationA,'one');await entered.future;
  await expectLater(f.client.send(conversationA,'two'),throwsA(isA<ChatDeliveryException>()));
  release.complete();await first;expect(f.effects,1);
 });
 test('session invalidation before dispatch leaves zero side effects',()async{
  final f=ProtocolFixture();f.before=(fn)async{if(fn=='rpc_chat_delivery_status')f.validOwner=false;};
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<ChatDeliveryException>()));
  expect(f.effects,0);
 });
 test('session invalidation after send does not acknowledge on new account',()async{
  final f=ProtocolFixture();f.before=(fn)async{if(fn=='rpc_send_chat_message_v2')f.validOwner=false;};
  await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<ChatDeliveryException>()));
  expect(f.effects,1);expect(f.store.pointer,isNotNull);expect(f.records.values.single['acknowledged'],isFalse);
 });
 for(final change in <Map<String,dynamic>>[
  {'owner_id':ownerB},{'conversation_id':conversationB},{'client_message_id':conversationB},
  {'body_sha256':'0'*64},{'state':'success'},{'acknowledged':1},{'message_id':'not-a-uuid'},
 ]){
  test('mismatched send receipt fails closed: $change',()async{
   final f=ProtocolFixture();f.overrideReply=(fn,row)=>fn=='rpc_send_chat_message_v2'?{...row,...change}:row;
   await expectLater(f.client.send(conversationA,'hello'),throwsA(isA<ChatDeliveryException>()));
   expect(f.store.pointer,isNotNull);
  });
 }
 test('conflicting local and server recovery records block new sends',()async{
  final f=ProtocolFixture()..loseSendReply=true;
  await expectLater(f.client.send(conversationA,'one'),throwsA(isA<TimeoutException>()));
  f.store.pointer=ChatSendPointer.create(ownerA,conversationA,'two');
  await expectLater(f.client.pending(conversationA),throwsA(isA<ChatDeliveryException>()));expect(f.effects,1);
 });
 for(final body in ['', ' \n ', 'a'*2001, '😀'*2001]){
  test('invalid body has no network mutation: ${body.length}',()async{
   final f=ProtocolFixture();await expectLater(f.client.send(conversationA,body),throwsA(isA<ChatDeliveryException>()));
   expect(f.sendIds,isEmpty);
  });
 }
 test('two thousand supplementary Unicode scalars retain UTF8 digest',()async{
  final f=ProtocolFixture();final body='😀'*2000;
  final sent=await f.client.send(conversationA,body);expect(sent.pointer.bodySha256,ChatSendPointer.bodyHash(body));
  expect(utf8.encode(body).length,8000);
 });
 test('recovery metadata contains no message text',(){
  final p=ChatSendPointer.create(ownerA,conversationA,'private synthetic message');
  expect(jsonEncode(p.toJson()),isNot(contains('private synthetic message')));
  expect(p.clientMessageId[14],'4');expect(RegExp(r'[89ab]').hasMatch(p.clientMessageId[19]),isTrue);
 });
}
