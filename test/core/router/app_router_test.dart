import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/router/app_router.dart';

void main() {
  group('AppRoutes constants', () {
    test('discover route is root', () {
      expect(AppRoutes.discover, '/');
    });

    test('biopay route', () {
      expect(AppRoutes.biopay, '/biopay');
    });

    test('profile route', () {
      expect(AppRoutes.profile, '/profile');
    });

    test('trip details route has :id param', () {
      expect(AppRoutes.tripDetails, '/trip/:id');
    });

    test('biopay sub-routes are prefixed', () {
      expect(AppRoutes.getQr, startsWith('/biopay'));
      expect(AppRoutes.scanQr, startsWith('/biopay'));
      expect(AppRoutes.faceScan, startsWith('/biopay'));
      expect(AppRoutes.faceEnroll, startsWith('/biopay'));
    });
  });
}
