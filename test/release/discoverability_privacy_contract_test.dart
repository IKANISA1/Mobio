import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discoverability and privacy contract', () {
    late final String tripService;
    late final String homeScreen;
    late final String bookingsScreen;
    late final String chatScreen;
    late final String scheduleProvider;
    late final String tripRouteForm;
    late final String profileFavorites;
    late final String editProfileScreen;
    late final String scheduledChatPrivacySql;
    late final String scheduledChatBlockPatchSql;

    setUpAll(() {
      tripService = File(
        'lib/features/bookings/data/trip_service.dart',
      ).readAsStringSync();
      homeScreen = File(
        'lib/features/home/presentation/home_screen.dart',
      ).readAsStringSync();
      bookingsScreen = File(
        'lib/features/bookings/presentation/bookings_screen.dart',
      ).readAsStringSync();
      chatScreen = File(
        'lib/features/chat/presentation/chat_screen.dart',
      ).readAsStringSync();
      scheduleProvider = File(
        'lib/features/bookings/application/schedule_trip_provider.dart',
      ).readAsStringSync();
      tripRouteForm = File(
        'lib/features/bookings/presentation/widgets/trip_route_form.dart',
      ).readAsStringSync();
      profileFavorites = File(
        'lib/features/profile/presentation/widgets/profile_favorite_addresses_section.dart',
      ).readAsStringSync();
      editProfileScreen = File(
        'lib/features/profile/presentation/edit_profile_screen.dart',
      ).readAsStringSync();
      scheduledChatPrivacySql = File(
        'supabase/migrations/20260614170000_driver_passenger_scheduled_chat_privacy.sql',
      ).readAsStringSync();
      scheduledChatBlockPatchSql = File(
        'supabase/migrations/20260614173000_restore_chat_block_enforcement.sql',
      ).readAsStringSync();
    });

    test('scheduled-trip discovery is role-aware', () {
      expect(
        tripService,
        contains('Future<List<Trip>> getNearbyTrips({String? role})'),
      );
      expect(tripService, contains("query.eq('role', normalizedRole!"));
      expect(tripService, contains('getCounterpartScheduledTrips'));
      expect(tripService, contains("? 'passenger'"));
      expect(tripService, contains(": 'driver'"));
      expect(
        bookingsScreen,
        contains('getCounterpartScheduledTrips(widget.mode)'),
      );
      expect(bookingsScreen, contains('didUpdateWidget'));
    });

    test('nearby discovery keeps passengers private by default', () {
      expect(homeScreen, contains('findNearbyDrivers'));
      expect(homeScreen, contains('_loadOnlineDriverTrips'));
      expect(homeScreen, contains("widget.mode == 'driver'"));
      expect(homeScreen, contains('Future<List<Trip>>.value(const [])'));
      expect(homeScreen, contains('getCounterpartScheduledTrips'));
      expect(homeScreen, contains('Passenger requests'));
      expect(homeScreen, contains('No passenger scheduled trips'));
      expect(homeScreen, isNot(contains('findNearbyPassengers')));
    });

    test('drivers are gated before messaging passenger scheduled trips', () {
      expect(chatScreen, contains('_plusGatedDriverIdForTrip'));
      expect(
        chatScreen,
        contains("trip.role == 'passenger' && trip.authorId != currentUserId"),
      );
      expect(chatScreen, contains('_currentUserIsDriverParticipant'));
      expect(chatScreen, contains('_externalDriverContactLocked'));
      expect(scheduledChatPrivacySql, contains("v_trip.role = 'passenger'"));
      expect(
        scheduledChatPrivacySql,
        contains('_driver_can_reply_to_conversation'),
      );
      expect(
        scheduledChatPrivacySql,
        contains('_record_driver_request_entitlement'),
      );
      expect(
        scheduledChatPrivacySql,
        contains('Upgrade to Mobio Plus to message passenger scheduled trips.'),
      );
    });

    test('latest scheduled chat RPC preserves block enforcement', () {
      expect(
        scheduledChatBlockPatchSql,
        contains('rpc_get_or_create_chat_conversation'),
      );
      expect(
        scheduledChatBlockPatchSql,
        contains('public.user_blocks block_row'),
      );
      expect(scheduledChatBlockPatchSql, contains("message = 'USER_BLOCKED'"));
    });

    test('favorite addresses are profile-owned and schedule-consumed', () {
      expect(editProfileScreen, contains('ProfileFavoriteAddressesSection'));
      expect(profileFavorites, contains('favoriteAddressServiceProvider'));
      expect(profileFavorites, contains('MobiBottomSheet.show'));
      expect(profileFavorites, contains('PlaceAutocompleteField'));
      expect(profileFavorites, contains('_addressTypeForLabel'));
      expect(scheduleProvider, contains('_loadFavoriteAddresses'));
      expect(scheduleProvider, contains('useFavoriteAsOrigin'));
      expect(scheduleProvider, contains('useFavoriteAsDestination'));
      expect(tripRouteForm, contains('_FavoriteAddressChips'));
      expect(tripRouteForm, contains('Pick up location'));
      expect(tripRouteForm, contains('Drop off location'));
    });

    test('schedule pickup defaults to current location when available', () {
      expect(scheduleProvider, contains('_prefillCurrentPickupIfEmpty'));
      expect(scheduleProvider, contains('reverseGeocode'));
      expect(scheduleProvider, contains('originDetails'));
      expect(tripRouteForm, contains('_CurrentLocationButton'));
      expect(tripRouteForm, contains('Use current location'));
    });
  });
}
