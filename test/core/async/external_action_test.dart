import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/external_action.dart';
import 'package:mobi_app/core/errors/app_exception.dart';

void main() {
  testWidgets('system action wait expires without dispatching another action', (
    tester,
  ) async {
    final reply = Completer<bool>();
    var actions = 0;
    Future<bool> start() {
      actions++;
      return reply.future;
    }

    Object? error;
    final observed = ExternalAction.run(start(), operation: 'share').catchError(
      (Object value) {
        error = value;
        return false;
      },
    );
    await tester.pump(const Duration(seconds: 61));
    await observed;
    expect(error, isA<MutationOutcomeUnknownException>());
    expect(actions, 1);
    reply.complete(true);
    await tester.pump();
    expect(actions, 1);
  });

  testWidgets(
    'simple callback observes failed native completion without an unhandled error',
    (tester) async {
      ExternalAction.start<void>(
        Future<void>.error(StateError('native failure')),
        operation: 'copy',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
