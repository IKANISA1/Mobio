import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('hung platform status does not grant access', () async {
    final pending = Completer<PermissionStatus>();
    final service = AppPermissionService(
      supportsRuntimePermissions: true,
      readStatus: (_) => pending.future,
      readTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      service.hasLocationAccess(),
      throwsA(isA<TimeoutException>()),
    );
    pending.complete(PermissionStatus.granted);
  });

  test(
    'timed-out permission prompt is re-observed before another prompt',
    () async {
      final pending = Completer<PermissionStatus>();
      var status = PermissionStatus.denied;
      var prompts = 0;
      final service = AppPermissionService(
        supportsRuntimePermissions: true,
        readStatus: (_) async => status,
        requestPermission: (_) {
          prompts++;
          return pending.future;
        },
        promptTimeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        service.ensureLocationAccess(),
        throwsA(isA<TimeoutException>()),
      );
      status = PermissionStatus.granted;
      pending.complete(status);
      expect(await service.ensureLocationAccess(), isTrue);
      expect(prompts, 1);
    },
  );

  test('lost settings completion does not claim launch failure', () async {
    final pending = Completer<bool>();
    final service = AppPermissionService(
      openSettings: () => pending.future,
      readTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      service.openAppPermissionSettings(),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
    pending.complete(true);
  });
}
