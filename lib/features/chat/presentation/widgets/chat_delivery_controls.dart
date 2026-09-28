import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

class ChatDeliveryControls extends StatefulWidget {
  const ChatDeliveryControls({super.key,required this.service,required this.conversationId,
    required this.revision,required this.composer,required this.onResolved,required this.requireCurrent});
  final ChatService service;
  final void Function() requireCurrent;
  final String conversationId;
  final int revision;
  final Widget Function(bool sendsEnabled) composer;
  final void Function(ChatDeliveryReceipt receipt) onResolved;
  @override State<ChatDeliveryControls> createState()=>_ChatDeliveryControlsState();
}
class _ChatDeliveryControlsState extends State<ChatDeliveryControls> with WidgetsBindingObserver {
  Timer? _timer;
  bool _enabled=false,_busy=false,_inactive=false;
  String? _message;
  ChatDeliveryReceipt? _pending;
  int _generation=0;
  bool get _current { try { widget.requireCurrent(); return true; } on Object { return false; } }
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_schedule();}
  void _schedule(){_timer?.cancel();unawaited(_check());_timer=Timer.periodic(const Duration(seconds:30),(_)=>unawaited(_check()));}
  @override void didUpdateWidget(covariant ChatDeliveryControls old){super.didUpdateWidget(old);
    if(old.revision!=widget.revision||old.conversationId!=widget.conversationId){unawaited(_check());}}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    _inactive=state!=AppLifecycleState.resumed;
    if(_inactive){_generation++;_timer?.cancel();if(mounted)setState((){_enabled=false;_busy=false;_pending=null;});}
    else _schedule();
  }
  Future<void> _check()async {
    if(_inactive||_busy||!_current)return;
    final generation=++_generation;
    setState(()=>_busy=true);
    try {
      final enabled=await widget.service.sendsEnabled();
      if(!mounted||generation!=_generation||_inactive||!_current)return;
      final pending=await widget.service.pendingDelivery(widget.conversationId);
      if(!mounted||generation!=_generation||_inactive||!_current)return;
      setState((){_enabled=enabled;_pending=pending;_message=enabled?null:'Messaging is temporarily paused. History remains available.';});
    }on Object {
      if(mounted&&generation==_generation)setState((){_enabled=false;_message='Chat status is unavailable. Check again before sending.';});
    }finally{if(mounted&&generation==_generation)setState(()=>_busy=false);}
  }
  Future<void> _resolve({bool cancel=false})async {
    if(_inactive||_busy||!_current)return;
    final generation=++_generation;
    setState(()=>_busy=true);
    try {
      final receipt=await widget.service.resolveDelivery(widget.conversationId,cancelIfUnobserved:cancel);
      if(!mounted||generation!=_generation||_inactive||!_current)return;
      if(receipt!=null&&receipt.state!=ChatDeliveryState.notObserved){
        widget.onResolved(receipt);
        setState((){_pending=null;_message=receipt.state==ChatDeliveryState.sent?
          'The previous message was sent.':'The pending request was cancelled; it will not send later.';});
      }else{setState((){_pending=receipt;_message='Delivery is not confirmed. Retry the unchanged text or cancel the pending request.';});}
    }on Object {
      if(mounted&&generation==_generation)setState(()=>_message='Delivery is still unresolved. No replacement message has been sent.');
    }finally{if(mounted&&generation==_generation)setState(()=>_busy=false);}
  }
  @override void dispose(){_generation++;_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    if(_message!=null||_pending!=null)Semantics(liveRegion:true,child:Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:8),
      child:Column(children:[Text(_message??(_pending?.state==ChatDeliveryState.sent?
        'The previous message was sent. Resolve its recovery record before sending another.':
        'A previous send needs delivery confirmation.'),textAlign:TextAlign.center),
        Wrap(alignment:WrapAlignment.center,children:[
          TextButton(onPressed:_busy?null:()=>unawaited(_check()),child:const Text('Check status')),
          if(_pending!=null)TextButton(onPressed:_busy?null:()=>unawaited(_resolve()),child:const Text('Resolve previous send')),
          if(_pending?.state==ChatDeliveryState.notObserved)
            TextButton(onPressed:_busy?null:()=>unawaited(_resolve(cancel:true)),child:const Text('Cancel pending request')),
        ])]))),
    widget.composer(_enabled&&!_inactive&&!_busy&&_current&&_pending?.state!=ChatDeliveryState.sent),
  ]);
}
