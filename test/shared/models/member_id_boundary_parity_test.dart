import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:mobi_app/features/admin/domain/admin_wire_record.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/presentation/widgets/conversation_list.dart';
import 'package:mobi_app/features/nearby/data/driver_location_service.dart';
import 'package:mobi_app/features/profile/domain/profile_wire_record.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/shared/models/discovery_person.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

const _viewer = '00000000-0000-4000-8000-000000000001';
const _member = '00000000-0000-4000-8000-000000000002';
const _trip = '00000000-0000-4000-8000-000000000010';
const _memberId = '004321';

// One server subject is preserved across the actual supported projections.
// Ordinary public Trip rows contain author_id, not a member_id projection.
Map<String, dynamic> _profile() => {
  'id': _member,
  'member_id': _memberId,
  'role': 'driver',
  'is_driver': true,
};

Map<String, dynamic> _scheduledAdminTrip() => {
  'id': _trip,
  'author_id': _member,
  'author_name': '',
  'member_id': _memberId,
  'origin': 'Kigali',
  'destination': 'Musanze',
  'departure_date': '2026-10-01',
  'role': 'driver',
  'vehicle_type': 'moto',
  'status': 'active',
  'is_active': true,
  'created_at': '2026-09-30T08:00:00Z',
};

DiscoveryPerson _person() {
  final driver = NearbyDriver.fromJson({
    'driver_id': _member,
    'member_id': _memberId,
    'vehicle_type_id': 'moto',
    'latitude': -1.94,
    'longitude': 30.06,
    'distance_km': 1.2,
  });
  return DiscoveryPerson(
    peerId: driver.driverId,
    memberId: driver.memberId,
    vehicleTypeId: driver.vehicleTypeId,
    distanceKm: driver.distanceKm,
  );
}

void main() {
  test(
    '004321 is identical across profile, discovery, scheduled admin trip, chat peer, and wallet',
    () {
      final profile = ProfileWireRecord.parse(_profile(), expectedId: _member);
      final person = _person();
      final trip = AdminWireRecord.trip(_scheduledAdminTrip());
      final chatPeer = ProfileWireRecord.parse(_profile(), expectedId: _member);
      final recipient = WalletTransferRecipient.fromLookupJson({
        'member_id': _memberId,
        'display_name': 'Recipient',
      }, requestedMemberId: _memberId);
      expect([
        profile.memberId,
        person.memberId,
        trip.memberId,
        displayMobioMemberId(chatPeer.memberId),
        recipient.memberId,
      ], everyElement(_memberId));
      expect([
        profile.id,
        person.peerId,
        trip.authorId,
        chatPeer.id,
      ], everyElement(_member));
      expect(person.chatUri.queryParameters, {'peerId': _member});
      expect(trip.id, _trip);
    },
  );

  test(
    'unavailable member IDs stay unavailable and cannot confirm a wallet recipient',
    () {
      final profile = ProfileWireRecord.parse({
        ..._profile(),
        'member_id': null,
      }, expectedId: _member);
      final trip = AdminWireRecord.trip({
        ..._scheduledAdminTrip(),
        'member_id': null,
      });
      expect(displayMobioMemberId(profile.memberId), isNull);
      expect(trip.memberId, isNull);
      expect(
        () => WalletTransferRecipient.fromLookupJson({
          'member_id': null,
          'display_name': 'Recipient',
        }, requestedMemberId: _memberId),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'discovery and chat display the same member ID without exposing internal identities',
    (tester) async {
      final profile = ProfileWireRecord.parse(_profile(), expectedId: _member);
      const conversation = ChatConversation(
        id: _trip,
        participantLowId: _viewer,
        participantHighId: _member,
        createdBy: _viewer,
        contextType: 'direct',
        status: 'active',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                DriverCard.person(person: _person(), onChat: () {}),
                Expanded(
                  child: ConversationList(
                    conversations: const [conversation],
                    trip: null,
                    currentUserId: _viewer,
                    profileCache: {_member: profile.toJson()},
                    onOpenConversation: (_) {},
                    formatTime: (_) => '',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_memberId), findsOneWidget);
      expect(find.text('Member $_memberId'), findsOneWidget);
      expect(find.textContaining(_member), findsNothing);
      expect(find.textContaining(_trip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
