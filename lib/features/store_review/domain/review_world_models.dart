import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/trip.dart';

final class ReviewPlace {
  const ReviewPlace({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final String label;
  final double latitude;
  final double longitude;
}

final class ReviewDiscoveryPeer {
  const ReviewDiscoveryPeer({
    required this.profile,
    required this.place,
    required this.online,
  });
  final Profile profile;
  final ReviewPlace place;
  final bool online;
}

final class ReviewTripDraft {
  ReviewTripDraft({
    required this.originPlaceId,
    required this.destinationPlaceId,
    required this.departureAt,
    required this.role,
    this.vehicleType = 'cab',
    this.seats = 1,
    this.note,
    List<int> recurringDays = const [],
  }) : recurringDays = List.unmodifiable(recurringDays);
  final String originPlaceId;
  final String destinationPlaceId;
  final DateTime departureAt;
  final MarketplaceRole role;
  final String vehicleType;
  final int seats;
  final String? note;
  final List<int> recurringDays;
}

enum ReviewInboxKind { welcome, message, scheduledPost, report }

final class ReviewInboxItem {
  const ReviewInboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.isRead,
    this.targetId,
  });
  final String id;
  final ReviewInboxKind kind;
  final String title;
  final DateTime createdAt;
  final bool isRead;
  final String? targetId;
  ReviewInboxItem read() => ReviewInboxItem(
    id: id,
    kind: kind,
    title: title,
    createdAt: createdAt,
    isRead: true,
    targetId: targetId,
  );
}

final class ReviewReport {
  const ReviewReport({
    required this.id,
    required this.peerId,
    required this.reason,
    required this.createdAt,
  });
  final String id;
  final String peerId;
  final String reason;
  final DateTime createdAt;
}

/// All collections and nested message metadata are copied before exposure.
/// Existing Profile/Trip/Chat models are pure and contain no transport client.
final class ReviewWorldSnapshot {
  ReviewWorldSnapshot({
    required this.binding,
    required this.worldInstance,
    required this.revision,
    required this.anchor,
    required this.profile,
    required this.mode,
    required this.driverOnline,
    required this.serial,
    required this.logicalTime,
    required Map<String, ReviewPlace> places,
    required Map<String, ReviewDiscoveryPeer> peers,
    required Map<String, Trip> trips,
    required Map<String, int> tripRevisions,
    required Map<String, ChatConversation> conversations,
    required Map<String, List<ChatMessageModel>> messages,
    required Map<String, ReviewInboxItem> inbox,
    required Set<String> blockedPeers,
    required List<ReviewReport> reports,
  }) : places = Map.unmodifiable(places),
       peers = Map.unmodifiable(peers),
       trips = Map.unmodifiable({
         for (final entry in trips.entries) entry.key: copyTrip(entry.value),
       }),
       tripRevisions = Map.unmodifiable(tripRevisions),
       conversations = Map.unmodifiable(conversations),
       messages = Map.unmodifiable({
         for (final entry in messages.entries)
           entry.key: List<ChatMessageModel>.unmodifiable(
             entry.value.map(copyMessage),
           ),
       }),
       inbox = Map.unmodifiable(inbox),
       blockedPeers = Set.unmodifiable(blockedPeers),
       reports = List.unmodifiable(reports);
  final ReviewWorldBinding binding;
  final int worldInstance;
  final int revision;
  final DateTime anchor;
  final Profile profile;
  final MarketplaceRole mode;
  final bool driverOnline;
  final int serial;
  final int logicalTime;
  final Map<String, ReviewPlace> places;
  final Map<String, ReviewDiscoveryPeer> peers;
  final Map<String, Trip> trips;
  final Map<String, int> tripRevisions;
  final Map<String, ChatConversation> conversations;
  final Map<String, List<ChatMessageModel>> messages;
  final Map<String, ReviewInboxItem> inbox;
  final Set<String> blockedPeers;
  final List<ReviewReport> reports;
  int get unreadInbox => inbox.values.where((item) => !item.isRead).length;
  int get unreadMessages => messages.values
      .expand((list) => list)
      .where(
        (message) =>
            message.senderId != binding.userId && message.readAt == null,
      )
      .length;
  static Trip copyTrip(Trip trip) => trip.copyWith(
    recurringDays: List.unmodifiable(trip.recurringDays),
    recurrenceSkipDates: List.unmodifiable(trip.recurrenceSkipDates),
  );
  static ChatMessageModel copyMessage(ChatMessageModel message) =>
      ChatMessageModel(
        id: message.id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        messageType: message.messageType,
        body: message.body,
        createdAt: message.createdAt,
        readAt: message.readAt,
        metadata: Map<String, dynamic>.unmodifiable(
          _copyMetadata(message.metadata, 0) as Map<String, Object?>,
        ),
      );

  // Metadata remains bounded JSON-like data; no caller-owned mutable aliases.
  static Object? _copyMetadata(Object? value, int depth) {
    if (depth > 8) throw const ReviewWorldUnavailable('invalid_metadata');
    if (value == null ||
        value is bool ||
        (value is String && value.length <= 1000) ||
        (value is num && value.isFinite)) {
      return value;
    }
    if (value is List && value.length <= 100) {
      return List<Object?>.unmodifiable(
        value.map((item) => _copyMetadata(item, depth + 1)),
      );
    }
    if (value is Map &&
        value.length <= 100 &&
        value.keys.every((key) => key is String && key.length <= 64)) {
      return Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _copyMetadata(entry.value, depth + 1),
      });
    }
    throw const ReviewWorldUnavailable('invalid_metadata');
  }
}
