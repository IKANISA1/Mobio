import 'package:flutter/material.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacyHealthCard extends StatefulWidget {
  const PrivacyHealthCard({super.key});
  @override State<PrivacyHealthCard> createState()=>_PrivacyHealthCardState();
}
class _PrivacyHealthCardState extends State<PrivacyHealthCard> with WidgetsBindingObserver {
  Map<String,dynamic>? _data;bool _loading=false,_foreground=true;int _revision=0;String? _error;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);AccountContext.changes.addListener(_clear);_load();}
  void _clear(){_revision++;if(mounted)setState((){_data=null;_loading=false;_error=null;});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){_foreground=state==AppLifecycleState.resumed;if(!_foreground)_clear();}
  Future<void> _load() async {
    if(!_foreground)return;final revision=++_revision;setState((){_loading=true;_data=null;_error=null;});
    try{
      final account=AccountContext.capture();
      final raw=await Supabase.instance.client.rpc('rpc_privacy_health').timeout(const Duration(seconds:6));
      AccountContext.requireCurrent(account);
      if(!mounted||!_foreground||revision!=_revision)return;
      if(raw is! Map||raw['protocol']!='mobio.privacy.health.v1'||raw['counts'] is! Map||
        raw['intake_enabled'] is! bool||raw['processing_enabled'] is! bool||raw['automatic_erasure_implemented']!=false||
        !(raw['counts'] as Map).values.every((v)=>v is int&&v>=0)||
        raw['oldest_pending_seconds'] is! int||raw['retention_reviews_due'] is! int||
        raw['oldest_pending_seconds']<0||raw['retention_reviews_due']<0)throw const FormatException('Invalid privacy health');
      setState((){_data=Map<String,dynamic>.from(raw);_loading=false;});
    }on Object{if(mounted&&revision==_revision)setState((){_loading=false;_error='Privacy request health unavailable.';});}
  }
  @override void dispose(){_revision++;AccountContext.changes.removeListener(_clear);WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override Widget build(BuildContext context){final data=_data;final counts=data?['counts'] as Map? ?? const {};
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('Privacy requests',style:Theme.of(context).textTheme.titleMedium)),
        IconButton(tooltip:'Refresh privacy request health',onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))]),
      if(_loading)const LinearProgressIndicator(),if(_error!=null)Semantics(liveRegion:true,child:Text(_error!)),
      if(data!=null)...[
        Text(data['intake_enabled']==true?'Intake enabled':'Intake disabled'),
        Text(data['processing_enabled']==true?'Fulfilment recording enabled':'Fulfilment recording paused'),
        Wrap(spacing:16,runSpacing:8,children:[for(final status in ['requested','processing','blocked'])Text('$status: ${counts[status]??0}')]),
        Text('Oldest pending: ${data['oldest_pending_seconds']} seconds'),
        Text('Retention reviews due: ${data['retention_reviews_due']}'),
        const Text('This tracks requests and fulfilment evidence. It does not automatically erase provider data.'),
      ],
    ])));
  }
}
