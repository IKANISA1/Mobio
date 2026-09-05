import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/router/app_router.dart';

void main() {
  group('AppRoutes constants', () {
    test('discover route is root', () {
      expect(AppRoutes.discover, '/');
    });

    test('biopay route', () {
      expect(AppRoutes.biopay, '/biopay');
    });

    test('login route', () {
      expect(AppRoutes.login, '/login');
    });

    test('profile route', () {
      expect(AppRoutes.profile, '/profile');
    });

    test('profile setup route is first-run wizard', () {
      expect(AppRoutes.profileSetup, '/profile/setup');
    });

    test('trip details route has :id param', () {
      expect(AppRoutes.tripDetails, '/trip/:id');
    });

    test('trip edit route has :id param', () {
      expect(AppRoutes.tripEdit, '/trip/:id/edit');
    });

    test('EV charger locator route', () {
      expect(AppRoutes.evChargers, '/ev-chargers');
      expect(AppRoutes.adminEvChargers, '/admin/ev-chargers');
    });

    test('biopay sub-routes are prefixed', () {
      expect(AppRoutes.getQr, startsWith('/biopay'));
      expect(AppRoutes.scanQr, startsWith('/biopay'));
      expect(AppRoutes.faceScan, startsWith('/biopay'));
      expect(AppRoutes.faceEnroll, startsWith('/biopay'));
      expect(AppRoutes.nfc, startsWith('/biopay'));
    });

    test('admin BioPay operations route uses explicit BioPay path', () {
      expect(AppRoutes.adminBioPayOps, '/admin/biopay');
      // ignore: deprecated_member_use_from_same_package
      expect(AppRoutes.adminFinance, '/admin/finance');
    });
  });
}
