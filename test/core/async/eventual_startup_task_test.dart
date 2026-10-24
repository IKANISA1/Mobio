import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/eventual_startup_task.dart';
import 'package:mobi_app/core/async/startup_task.dart';

void main() {
  for (final completion in ['early', 'late']) {
    testWidgets(
      '$completion Firebase success installs optional handlers once',
      (tester) async {
        final sdk = Completer<bool>();
        final push = Completer<void>();
        final events = <String>[];
        var owner = 'first-account';
        final task = EventualStartupTask<bool>(
          initialize: () {
            events.add('initialize');
            return sdk.future;
          },
          install: (ready) async {
            if (!ready) return;
            events.add('push-handlers');
            await push.future;
            events.add('register:$owner');
          },
        );
        StartupTaskResult<bool>? observed;
        unawaited(
          task.observe(const Duration(seconds: 6)).then((r) => observed = r),
        );
        await tester.pumpWidget(const _UsableShell());
        expect(find.text('Usable shell'), findsOneWidget);
        expect(events, ['initialize']);
        expect(observed, isNull);
        if (completion == 'early') {
          sdk.complete(true);
          push.complete();
          await tester.pump();
          expect(observed!.completed, isTrue);
        } else {
          await tester.pump(const Duration(seconds: 6));
          expect(observed!.timedOut, isTrue);
          expect(events, ['initialize']);
          // Remote fetch recovery/default fallback does not reuse old auth.
          owner = 'replacement-account';
          sdk.complete(true);
          await tester.pump();
          expect(events, ['initialize', 'push-handlers']);
          push.complete();
          await tester.pump();
        }
        expect(await task.work, isTrue);
        expect(
          (await task.observe(const Duration(seconds: 6))).completed,
          isTrue,
        );
        expect(events, ['initialize', 'push-handlers', 'register:$owner']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failure in [
    'not-configured',
    'late-sdk-failure',
    'late-push-failure',
  ]) {
    testWidgets('$failure is handled without another initializer', (
      tester,
    ) async {
      final sdk = Completer<bool>();
      final push = Completer<void>();
      var initializations = 0;
      var installations = 0;
      final task = EventualStartupTask<bool>(
        initialize: () {
          initializations++;
          return sdk.future;
        },
        install: (ready) async {
          if (!ready) return;
          installations++;
          await push.future;
        },
      );
      StartupTaskResult<bool>? observed;
      unawaited(
        task.observe(const Duration(seconds: 6)).then((r) => observed = r),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(observed!.timedOut, isTrue);
      if (failure == 'not-configured') {
        sdk.complete(false);
      } else if (failure == 'late-sdk-failure') {
        sdk.completeError(StateError('Synthetic SDK failure'));
      } else {
        sdk.complete(true);
        await tester.pump();
        push.completeError(StateError('Synthetic handler failure'));
      }
      await tester.pump();
      final again = await task.observe(const Duration(seconds: 6));
      expect(again.completed, failure == 'not-configured');
      expect(initializations, 1);
      expect(installations, failure == 'late-push-failure' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
}

// A renderable shell stands in for the app which is mounted before optional work.
class _UsableShell extends StatelessWidget {
  const _UsableShell();

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: Text('Usable shell'),
  );
}
