import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

abstract interface class ChatDeliveryStore {
  Future<ChatSendPointer?> read(String ownerId, String conversationId);
  Future<void> write(ChatSendPointer pointer);
  Future<void> remove(ChatSendPointer pointer);
}
class PreferencesChatDeliveryStore implements ChatDeliveryStore {
  String _key(String owner,String conversation)=>'mobio.chat.pending.v1.$owner.$conversation';
  @override Future<ChatSendPointer?> read(String ownerId,String conversationId) async {
    final prefs=await SharedPreferences.getInstance(); await prefs.reload();
    final raw=prefs.getString(_key(ownerId,conversationId));
    if(raw==null)return null;
    try {
      if(raw.length>1024)throw const FormatException();
      return ChatSendPointer.fromJson(Map<String,dynamic>.from(jsonDecode(raw) as Map),ownerId,conversationId);
    } on Object { throw const ChatDeliveryException('invalid_recovery_record'); }
  }
  @override Future<void> write(ChatSendPointer p) async {
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.setString(_key(p.ownerId,p.conversationId),jsonEncode(p.toJson()))) {
      throw const ChatDeliveryException('recovery_storage_unavailable');
    }
    final saved=await read(p.ownerId,p.conversationId);
    if(saved?.clientMessageId!=p.clientMessageId || saved?.bodySha256!=p.bodySha256) {
      throw const ChatDeliveryException('recovery_storage_conflict');
    }
  }
  @override Future<void> remove(ChatSendPointer p) async {
    final saved=await read(p.ownerId,p.conversationId);
    if(saved==null)return;
    if(saved.clientMessageId!=p.clientMessageId || saved.bodySha256!=p.bodySha256) {
      throw const ChatDeliveryException('recovery_storage_conflict');
    }
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.remove(_key(p.ownerId,p.conversationId))) {
      throw const ChatDeliveryException('recovery_storage_unavailable');
    }
  }
}
