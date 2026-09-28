import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_history_page.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';

/// Owns exactly one realtime subscription for this conversation. History is
/// invalidated on reconnect/head refresh rather than retaining stale redactions.
class ChatHistoryView extends StatefulWidget {
  const ChatHistoryView({super.key,required this.service,required this.conversationId,
    required this.scrollController,required this.messageBuilder,required this.requireCurrent,this.contextCard});
  final ChatService service;
  final void Function() requireCurrent;
  final String conversationId;
  final ScrollController scrollController;
  final Widget Function(ChatMessageModel) messageBuilder;
  final Widget? contextCard;
  @override State<ChatHistoryView> createState()=>_ChatHistoryViewState();
}
class _ChatHistoryViewState extends State<ChatHistoryView> with WidgetsBindingObserver {
  StreamSubscription<ChatHistoryPage>? _subscription;
  List<ChatMessageModel> _messages=[];
  ChatHistoryCursor? _before;
  bool _hasMore=false,_loading=true,_olderLoading=false,_suspended=false;
  bool? _redacted;
  String? _error;
  int _epoch=0,_headRevision=0;
  bool get _current { try { widget.requireCurrent(); return true; } on Object { return false; } }
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_start());}
  @override void didUpdateWidget(covariant ChatHistoryView old){
    super.didUpdateWidget(old);
    if(old.conversationId!=widget.conversationId || old.service!=widget.service)unawaited(_start());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    _suspended=state!=AppLifecycleState.resumed;
    if(_suspended){_epoch++;unawaited(_subscription?.cancel());_subscription=null;
      if(mounted)setState((){_messages=[];_before=null;_hasMore=false;_loading=false;_error='Chat is paused while the app is inactive.';});
    }else{unawaited(_start());}
  }
  Future<void> _start()async {
    final epoch=++_epoch;
    final previous = _subscription;
    _subscription = null;
    await previous?.cancel();
    if(!mounted||_suspended||epoch!=_epoch||!_current)return;
    setState((){_messages=[];_before=null;_hasMore=false;_loading=true;_olderLoading=false;_error=null;});
    try {
      _subscription=widget.service.watchMessagePages(widget.conversationId).listen((page){
        if(!mounted||_suspended||epoch!=_epoch||!_current)return;
        final wasEmpty=_messages.isEmpty;
        final nearBottom=!widget.scrollController.hasClients ||
          widget.scrollController.position.maxScrollExtent-widget.scrollController.offset<100;
        _headRevision++;
        setState((){_messages=page.messages;_before=page.before;_hasMore=page.hasMore;
          _redacted=page.redacted;_loading=false;_olderLoading=false;_error=null;});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(!mounted||_suspended||epoch!=_epoch||!_current)return;
          if((wasEmpty||nearBottom)&&widget.scrollController.hasClients) {
            widget.scrollController.jumpTo(widget.scrollController.position.maxScrollExtent);
          }
          if(page.newest!=null&&page.redacted!=true) {
            unawaited(widget.service.markConversationRead(widget.conversationId,
              through:page.newest).catchError((Object _){}));
          }
        });
      },onError:(Object _,StackTrace __){
        if(!mounted||epoch!=_epoch)return;
        _headRevision++;
        setState((){_messages=[];_hasMore=false;_before=null;_loading=false;_olderLoading=false;
          _error='Chat history is unavailable. No cached messages are shown.';});
      });
    }on Object {
      if(mounted&&epoch==_epoch)setState((){_loading=false;_error='Sign in again to open this chat.';});
    }
  }
  Future<void> _older()async {
    final before=_before,epoch=_epoch,revision=_headRevision;
    if(before==null||_olderLoading||!_hasMore||_suspended||!_current)return;
    setState(()=>_olderLoading=true);
    final oldExtent=widget.scrollController.hasClients?widget.scrollController.position.maxScrollExtent:0.0;
    final oldOffset=widget.scrollController.hasClients?widget.scrollController.offset:0.0;
    try {
      final page=await widget.service.getMessagesPage(widget.conversationId,before:before);
      if(!mounted||epoch!=_epoch||revision!=_headRevision||_suspended||!_current)return;
      if(page.redacted!=null&&page.redacted!=_redacted){unawaited(_start());return;}
      final existing=_messages.map((m)=>m.id).toSet();
      setState((){_messages=[...page.messages.where((m)=>!existing.contains(m.id)),..._messages];
        _before=page.before;_hasMore=page.hasMore;_olderLoading=false;});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted&&epoch==_epoch&&revision==_headRevision&&_current&&widget.scrollController.hasClients){
          final extent=widget.scrollController.position.maxScrollExtent;
          widget.scrollController.jumpTo((oldOffset+extent-oldExtent).clamp(0.0,extent).toDouble());
        }
      });
    }on Object {
      if(mounted&&epoch==_epoch&&revision==_headRevision)setState((){
        _olderLoading=false;_error='Older messages could not be loaded. Retry without changing this conversation.';
      });
    }
  }
  @override void dispose(){_epoch++;WidgetsBinding.instance.removeObserver(this);unawaited(_subscription?.cancel());super.dispose();}
  @override Widget build(BuildContext context){
    if(_loading)return const Center(child:CircularProgressIndicator());
    return Column(children:[
      if(_error!=null)Semantics(liveRegion:true,child:Padding(padding:const EdgeInsets.all(12),
        child:Column(children:[Text(_error!,textAlign:TextAlign.center),
          TextButton(onPressed:_suspended?null:()=>unawaited(_start()),child:const Text('Reload chat'))]))),
      if(_hasMore)TextButton(onPressed:_olderLoading?null:_older,
        child:Text(_olderLoading?'Loading older messages…':'Load older messages')),
      Expanded(child:_messages.isEmpty&&_error==null?const Center(child:Text('No messages yet.')):
        ListView.separated(controller:widget.scrollController,padding:const EdgeInsets.fromLTRB(24,12,24,24),
          itemCount:_messages.length+(widget.contextCard==null?0:1),
          separatorBuilder:(_,__)=>const SizedBox(height:12),itemBuilder:(context,index){
            if(widget.contextCard!=null&&index==0)return widget.contextCard!;
            final m=_messages[index-(widget.contextCard==null?0:1)];
            return KeyedSubtree(key:ValueKey(m.id),child:widget.messageBuilder(m));
          })),
    ]);
  }
}
