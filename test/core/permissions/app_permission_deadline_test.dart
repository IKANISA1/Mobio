import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/location/location_access_state.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late GeolocatorPlatform originalGeolocator;
  late _PermissionGeolocator geolocator;
  setUp(() {
    originalGeolocator = GeolocatorPlatform.instance;
    geolocator = _PermissionGeolocator();
    GeolocatorPlatform.instance = geolocator;
  });
  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  test(
    'non-mobile default reads actual geolocation consent and revocation',
    () async {
      final service = AppPermissionService();
      for (final permission in LocationPermission.values) {
        geolocator.permission = permission;
        expect(
          await service.hasLocationAccess(),
          permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse,
        );
      }
      geolocator.permission = LocationPermission.whileInUse;
      expect(await service.locationAccessState(), LocationAccessState.granted);
      geolocator.permission = LocationPermission.denied;
      expect(await service.locationAccessState(), LocationAccessState.denied);
      expect(await service.hasBackgroundLocationAccess(), isFalse);
      expect(await service.ensureBackgroundLocationAccess(), isFalse);
      expect(
        await service.locationAccessState(background: true),
        LocationAccessState.unavailable,
      );
      expect(geolocator.prompts, 0);
    },
  );

  test(
    'explicit non-mobile action requests a grant when observation is absent',
    () async {
      final service = AppPermissionService();
      geolocator.permission = LocationPermission.unableToDetermine;
      geolocator.requested = LocationPermission.denied;
      expect(await service.ensureLocationAccess(), isFalse);
      geolocator.requested = LocationPermission.whileInUse;
      expect(await service.ensureLocationAccess(), isTrue);
      expect(await service.ensureLocationAccess(), isTrue);
      expect(geolocator.prompts, 2);
    },
  );

  test(
    'non-mobile permanent denial does not open native settings or prompt',
    () async {
      var settings = 0;
      final service = AppPermissionService(
        openSettings: () async {
          settings++;
          return true;
        },
      );
      geolocator.permission = LocationPermission.deniedForever;
      expect(await service.ensureLocationAccess(), isFalse);
      expect(
        await service.locationAccessState(),
        LocationAccessState.permanentlyDenied,
      );
      expect(geolocator.prompts, 0);
      expect(settings, 0);
      expect(await AppPermissionService().openAppPermissionSettings(), isFalse);
    },
  );

  for (final fault in <Object>[
    MissingPluginException('permission channel missing'),
    UnimplementedError('permission channel unsupported'),
    UnsupportedError('permission API unavailable'),
  ]) {
    test(
      '${fault.runtimeType} from non-mobile geolocation is unavailable',
      () async {
        final service = AppPermissionService();
        geolocator.readFault = fault;
        expect(await service.hasLocationAccess(), isFalse);
        expect(await service.ensureLocationAccess(), isFalse);
        expect(
          await service.locationAccessState(),
          LocationAccessState.unavailable,
        );
        expect(geolocator.prompts, 0);
        geolocator.readFault = null;
        geolocator.requestFault = fault;
        expect(await service.ensureLocationAccess(), isFalse);
        expect(geolocator.prompts, 1);
      },
    );
    test(
      '${fault.runtimeType} does not authorize location or sharing',
      () async {
        var prompts = 0;
        var settings = 0;
        final service = AppPermissionService(
          supportsRuntimePermissions: true,
          readStatus: (_) => Future.error(fault),
          requestPermission: (_) async {
            prompts++;
            return PermissionStatus.granted;
          },
          openSettings: () async {
            settings++;
            return true;
          },
        );

        expect(await service.hasLocationAccess(), isFalse);
        expect(await service.hasBackgroundLocationAccess(), isFalse);
        expect(await service.ensureLocationAccess(), isFalse);
        expect(await service.ensureBackgroundLocationAccess(), isFalse);
        expect(
          await service.locationAccessState(),
          LocationAccessState.unavailable,
        );
        expect(
          await service.locationAccessState(background: true),
          LocationAccessState.unavailable,
        );
        expect(prompts, 0);
        expect(settings, 0);
      },
    );

    test('${fault.runtimeType} during prompt is not a grant', () async {
      var available = false;
      var prompts = 0;
      final service = AppPermissionService(
        supportsRuntimePermissions: true,
        readStatus: (_) async =>
            available ? PermissionStatus.granted : PermissionStatus.denied,
        requestPermission: (_) {
          prompts++;
          return Future.error(fault);
        },
      );

      expect(await service.ensureLocationAccess(), isFalse);
      available = true;
      expect(await service.ensureLocationAccess(), isTrue);
      expect(prompts, 1);
    });
  }

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

class _PermissionGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  Object? readFault;
  Object? requestFault;
  int prompts = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    if (readFault != null) throw readFault!;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    if (requestFault != null) throw requestFault!;
    permission = requested;
    return permission;
  }
}
