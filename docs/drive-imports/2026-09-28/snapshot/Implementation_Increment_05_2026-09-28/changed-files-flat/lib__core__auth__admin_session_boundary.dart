import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/auth/admin_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Masks an already-open admin view on expiry, blur or backgrounding. It avoids
/// continuous activity heartbeats: only real foreground input can request touch.
class AdminSessionBoundary extends StatefulWidget {
  const AdminSessionBoundary({super.key,required this.child,required this.router});
  final Widget child;
  final GoRouter router;
  @override State<AdminSessionBoundary> createState()=>_AdminSessionBoundaryState();
}
class _AdminSessionBoundaryState extends State<AdminSessionBoundary> with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground=true;
  DateTime _lastInteraction=DateTime.fromMillisecondsSinceEpoch(0);
  bool get _protected {
    final path=widget.router.routeInformationProvider.value.uri.path;
    if(path=='/admin'||path.startsWith('/admin/'))return true;
    try{return path=='/home' && Supabase.instance.client.auth.currentUser?.appMetadata['role']=='admin';}
    on Object{return false;}
  }
  @override void initState() {
    super.initState();WidgetsBinding.instance.addObserver(this);
    _timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted&&_protected)setState((){});});
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground=state==AppLifecycleState.resumed;
    if (_foreground&&_protected) unawaited(AdminSessionService.synchronize().then((_){if(mounted)setState((){});}));
    if(mounted)setState((){});
  }
  void _activity() {
    if(!_foreground||!_protected||DateTime.now().difference(_lastInteraction)<const Duration(seconds:30))return;
    _lastInteraction=DateTime.now();
    // Never allow an input event to revive an expired local or server lease.
    final auth=Supabase.instance.client.auth;
    if(!AdminSessionGuard.isAdminFor(auth.currentUser?.id,sessionId:AccountContext.sessionId(auth.currentSession)))return;
    unawaited(AdminSessionService.synchronize(userActivity:true).then((_){if(mounted)setState((){});}));
  }
  @override void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override Widget build(BuildContext context) {
    if(!_protected)return widget.child;
    final auth=Supabase.instance.client.auth;
    final active=_foreground && !AccountContext.exitRequested && AdminSessionGuard.isAdminFor(
      auth.currentUser?.id,sessionId:AccountContext.sessionId(auth.currentSession));
    if(!active)return Material(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('Admin session locked'),const SizedBox(height:16),
      FilledButton(onPressed:()=>widget.router.go('/admin-auth'),child:const Text('Verify again')),
    ])));
    return Listener(onPointerDown:(_)=>_activity(),child:Focus(
      onKeyEvent:(_,__){_activity();return KeyEventResult.ignored;},child:widget.child));
  }
}
