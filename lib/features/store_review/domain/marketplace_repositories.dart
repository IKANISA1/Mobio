import 'dart:async';

import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/store_review/domain/review_world_models.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/trip.dart';

/// Ordinary adapters may return their guarded Future; the in-memory review
/// implementation is synchronous. Neither contract grants SDK authority.
abstract interface class MarketplaceProfileRepository {
  FutureOr<Profile> getProfile(MarketplaceAction action);
  FutureOr<Profile> editProfile(
    MarketplaceAction action, {
    required String displayName,
    String? vehicleType,
  });
  FutureOr<void> setMode(MarketplaceAction action, MarketplaceRole mode);
}

abstract interface class MarketplaceDiscoveryRepository {
  FutureOr<List<ReviewDiscoveryPeer>> nearby(
    MarketplaceAction action, {
    String? vehicleType,
  });
  FutureOr<void> setDriverOnline(MarketplaceAction action, bool online);
}

abstract interface class MarketplaceScheduledPostRepository {
  FutureOr<List<Trip>> listTrips(
    MarketplaceAction action, {
    bool ownOnly = false,
    bool includeCancelled = false,
    MarketplaceRole? role,
  });
  FutureOr<Trip> getTrip(MarketplaceAction action, String id);
  FutureOr<Trip> createTrip(MarketplaceAction action, ReviewTripDraft draft);
  FutureOr<Trip> editTrip(
    MarketplaceAction action,
    String id,
    ReviewTripDraft draft, {
    required int expectedRevision,
  });
  FutureOr<Trip> cancelTrip(
    MarketplaceAction action,
    String id, {
    required int expectedRevision,
  });
}

abstract interface class MarketplaceChatRepository {
  FutureOr<ChatConversation> openConversation(
    MarketplaceAction action,
    String peerId, {
    String? tripId,
  });
  FutureOr<List<ChatConversation>> listConversations(MarketplaceAction action);
  FutureOr<List<ChatMessageModel>> messagesFor(
    MarketplaceAction action,
    String conversationId,
  );
  FutureOr<ChatMessageModel> sendMessage(
    MarketplaceAction action,
    String conversationId,
    String body,
  );
  FutureOr<void> markConversationRead(
    MarketplaceAction action,
    String conversationId,
  );
  FutureOr<void> blockPeer(
    MarketplaceAction action,
    String peerId,
    bool blocked,
  );
  FutureOr<ReviewReport> reportPeer(
    MarketplaceAction action,
    String peerId,
    String reason,
  );
}

abstract interface class MarketplaceInboxRepository {
  FutureOr<List<ReviewInboxItem>> listInbox(MarketplaceAction action);
  FutureOr<void> markInboxRead(MarketplaceAction action, {String? id});
}
