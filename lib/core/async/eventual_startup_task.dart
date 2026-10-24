import 'package:mobi_app/core/async/startup_task.dart';

/// One initialization and its dependent installation survive a bounded wait.
/// Observing again joins the same work, including after a timeout or failure.
class EventualStartupTask<T> {
  EventualStartupTask({required this.initialize, required this.install});

  final Future<T> Function() initialize;
  final Future<void> Function(T value) install;
  Future<T>? _work;

  Future<T> get work =>
      _work ??= Future<T>.sync(initialize).then((value) async {
        await install(value);
        return value;
      });

  Future<StartupTaskResult<T>> observe(Duration budget) =>
      runStartupTask<T>(() => work, budget);
}
