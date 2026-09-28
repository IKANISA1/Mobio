// Synthetic API double for the real Dart coordinator; NOT SQL acceptance.
import 'dart:async';
import 'package:mobi_app/features/chat/application/chat_delivery_coordinator.dart';
import 'package:mobi_app/features/chat/data/chat_delivery_store.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

const ownerA='00000000-0000-4000-8000-000000000001';
const ownerB='00000000-0000-4000-8000-000000000002';
const conversationA='00000000-0000-4000-8000-000000000010';
const conversationB='00000000-0000-4000-8000-000000000011';
const messageA='00000000-0000-4000-8000-000000000020';

class MemoryChatStore implements ChatDeliveryStore {
  ChatSendPointer? pointer;
  bool failWrite=false,failRemove=false,corruptRead=false;
  @override Future<ChatSendPointer?> read(String owner,String c)async {
    if(corruptRead)throw const ChatDeliveryException('invalid_recovery_record');
    final p=pointer;
    return p!=null&&p.ownerId==owner&&p.conversationId==c?p:null;
  }
  @override Future<void> write(ChatSendPointer p)async {
    if(failWrite)throw const ChatDeliveryException('recovery_storage_unavailable');
    pointer=p;
  }
  @override Future<void> remove(ChatSendPointer p)async {
    if(failRemove)throw const ChatDeliveryException('recovery_storage_unavailable');
    if(pointer?.clientMessageId==p.clientMessageId)pointer=null;
  }
}
class ProtocolFixture {
  final store=MemoryChatStore();
  final records=<String,Map<String,dynamic>>{};
  final sendIds=<String>[];
  bool validOwner=true,loseSendReply=false,rejectSend=false,failClose=false,loseCloseReply=false;
  int effects=0;
  Future<void> Function(String)? before;
  Map<String,dynamic> Function(String,Map<String,dynamic>)? overrideReply;
  ChatDeliveryCoordinator get client=>ChatDeliveryCoordinator(ownerId:ownerA,store:store,
    rpc:call,requireCurrent:(){if(!validOwner)throw const ChatDeliveryException('account_changed');});
  Map<String,dynamic> notObserved(String c,Object? id)=>{'owner_id':ownerA,
    'conversation_id':c,'client_message_id':id,'state':'not_observed'};
  Future<Map<String,dynamic>> call(String fn,Map<String,dynamic> p)async {
    await before?.call(fn);
    final c=p['p_conversation_id'] as String;
    final id=p['p_client_message_id'] as String?;
    Map<String,dynamic> row;
    if(fn=='rpc_chat_delivery_status') {
      final active=records.values.where((v)=>v['conversation_id']==c&&v['acknowledged']==false);
      row=id==null?(active.isEmpty?notObserved(c,null):active.first):(records[id]??notObserved(c,id));
    }else if(fn=='rpc_send_chat_message_v2') {
      sendIds.add(id!);
      if(rejectSend)throw StateError('synthetic server rejection');
      final digest=ChatSendPointer.bodyHash(p['p_body'] as String);
      final old=records[id];
      if(old!=null && (old['body_sha256']!=digest||old['conversation_id']!=c))throw StateError('conflict');
      row=old??{'owner_id':ownerA,'conversation_id':c,'client_message_id':id,
        'body_sha256':digest,'state':'sent','message_id':messageA,'acknowledged':false};
      if(old==null){records[id]=row;effects++;}
      if(loseSendReply)throw TimeoutException('synthetic lost acknowledgement');
    }else if(fn=='rpc_close_chat_delivery') {
      if(failClose)throw TimeoutException('synthetic close timeout');
      row=records[id]??{'owner_id':ownerA,'conversation_id':c,'client_message_id':id,
        'body_sha256':p['p_body_sha256'],'state':'cancelled','message_id':null,'acknowledged':true};
      if(!records.containsKey(id)&&p['p_cancel_if_unobserved']!=true)throw StateError('not observed');
      row={...row,'acknowledged':true};records[id!]=row;
      if(loseCloseReply)throw TimeoutException('synthetic lost close response');
    }else{throw StateError('Unexpected RPC $fn');}
    return overrideReply?.call(fn,{...row})??{...row};
  }
}
