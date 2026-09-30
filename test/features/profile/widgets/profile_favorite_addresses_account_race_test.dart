import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/application/profile_services.dart';
import 'package:mobi_app/features/profile/data/favorite_address_service.dart';
import 'package:mobi_app/features/profile/presentation/widgets/profile_favorite_addresses_section.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_section_header.dart';
import 'package:mobi_app/shared/widgets/place_autocomplete_field.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';

const address = FavoriteAddress(
  id: 'address-A',
  profileId: 'owner',
  label: 'Home A',
  addressType: 'home',
  formattedAddress: 'Private pickup A',
  latitude: -1.9,
  longitude: 30,
);

class _Addresses extends Fake implements FavoriteAddressService {
  int reads = 0, deletes = 0, saves = 0;
  Future<List<FavoriteAddress>> Function() read = () async => [address];
  @override
  Future<List<FavoriteAddress>> list({bool activeOnly = true}) {
    reads++;
    return read();
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
  }

  @override
  Future<FavoriteAddress> save({
    String? id,
    required String label,
    required String addressType,
    required PlaceDetails place,
    int sortOrder = 0,
  }) async {
    saves++;
    return address;
  }
}

void main() {
  late _Addresses addresses;
  var generation = 0;
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    generation = 0;
    addresses = _Addresses();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteAddressServiceProvider.overrideWithValue(addresses),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileFavoriteAddressesSection.test(
                captureAccount: () =>
                    AccountSnapshot('owner', 'session-$generation', generation),
                isCurrent: (account) => account.generation == generation,
              ),
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
  }

  void replace() {
    generation++;
    AccountContext.changes.value++;
  }

  VoidCallback add(WidgetTester tester) => tester
      .widget<MobiSectionHeader>(find.byType(MobiSectionHeader))
      .onAction!;

  testWidgets(
    'retained favorite add and delete cannot use a replacement session',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      final oldAdd = add(tester);
      final oldDelete = tester
          .widget<InputChip>(find.byType(InputChip))
          .onDeleted!;
      replace();
      await tester.pumpAndSettle();
      final reads = addresses.reads;
      oldAdd();
      oldDelete();
      await tester.pumpAndSettle();
      expect(addresses.reads, reads);
      expect(addresses.deletes, 0);
      expect(addresses.saves, 0);
      expect(find.text('Save address'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('retained favorite retry cannot dispatch a replacement read', (
    tester,
  ) async {
    addresses.read = () async => throw StateError('synthetic unavailable');
    await mount(tester);
    await tester.pumpAndSettle();
    final retry = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == 'Retry',
          ),
        )
        .onPressed!;
    addresses.read = () async => [address];
    replace();
    await tester.pumpAndSettle();
    expect(addresses.reads, 2);
    retry();
    await tester.pumpAndSettle();
    expect(addresses.reads, 2);
    expect(find.text('Home A'), findsOneWidget);
  });
  testWidgets('late favorite reply cannot reveal old private addresses', (
    tester,
  ) async {
    final oldRead = Completer<List<FavoriteAddress>>();
    addresses.read = () => oldRead.future;
    await mount(tester);
    addresses.read = () async => [];
    replace();
    await tester.pumpAndSettle();
    oldRead.complete([address]);
    await tester.pumpAndSettle();
    expect(find.text('Home A'), findsNothing);
    expect(addresses.reads, 2);
  });
  testWidgets(
    'open favorite sheet clears and rejects old inputs after replacement',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      add(tester)();
      await tester.pumpAndSettle();
      final label = find.byType(TextField).first;
      await tester.enterText(label, 'Private label A');
      final controller = tester.widget<TextField>(label).controller!;
      final save = tester
          .widget<MobiButton>(find.widgetWithText(MobiButton, 'Save address'))
          .onPressed!;
      final select = tester
          .widget<PlaceAutocompleteField>(find.byType(PlaceAutocompleteField))
          .onPlaceSelected;
      replace();
      await tester.pumpAndSettle();
      expect(find.text('Private label A'), findsNothing);
      expect(
        find.text('Account changed. Close this view and sign in again.'),
        findsOneWidget,
      );
      expect(controller.text, isEmpty);
      select(
        const PlaceDetails(
          placeId: 'old',
          formattedAddress: 'Private pickup A',
          latitude: -1.9,
          longitude: 30,
        ),
      );
      save();
      await tester.pumpAndSettle();
      expect(addresses.saves, 0);
      expect(
        find.text('Account changed. Close this view and sign in again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('current favorite retry and delete remain usable', (
    tester,
  ) async {
    addresses.read = () async => throw StateError('synthetic unavailable');
    await mount(tester);
    await tester.pumpAndSettle();
    addresses.read = () async => [address];
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(addresses.reads, 2);
    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
    await tester.pumpAndSettle();
    expect(addresses.deletes, 1);
    expect(addresses.reads, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('current favorite sheet submits one selected address', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    add(tester)();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Work');
    tester
        .widget<PlaceAutocompleteField>(find.byType(PlaceAutocompleteField))
        .onPlaceSelected(
          const PlaceDetails(
            placeId: 'current',
            formattedAddress: 'Kigali',
            latitude: -1.9,
            longitude: 30,
          ),
        );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save address'));
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();
    expect(addresses.saves, 1);
    expect(addresses.reads, 2);
    expect(find.text('Save address'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
