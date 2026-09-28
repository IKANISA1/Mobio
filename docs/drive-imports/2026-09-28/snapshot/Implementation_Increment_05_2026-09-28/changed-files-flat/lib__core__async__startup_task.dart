import 'dart:async';
class StartupTaskResult<T> {
  const StartupTaskResult({required this.completed,this.value,this.timedOut=false});
  final bool completed,timedOut;
  final T? value;
}
/// A timeout bounds the wait, not the underlying initializer. Call once: never
/// retry a timed-out singleton initializer in parallel with the still-running one.
Future<StartupTaskResult<T>> runStartupTask<T>(Future<T> Function() task,Duration budget) async {
  if(budget<=Duration.zero)throw ArgumentError.value(budget,'budget');
  try{return StartupTaskResult(completed:true,value:await Future<T>.sync(task).timeout(budget));}
  on TimeoutException{return StartupTaskResult<T>(completed:false,timedOut:true);}
  on Object{return StartupTaskResult<T>(completed:false);}
}
