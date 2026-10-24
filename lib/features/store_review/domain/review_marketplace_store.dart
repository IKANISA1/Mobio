import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/store_review/domain/marketplace_repositories.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';
import 'package:mobi_app/features/store_review/domain/review_world_models.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:mobi_shared_types/models/trip.dart';

/// Opaque capability: no public constructor, JSON restore or user-ID shortcut.
final class ReviewWorldAction implements MarketplaceAction {
  ReviewWorldAction._(
    this._owner,
    this._world,
    this._epoch,
    this._proof,
    this._actorId,
  );
  final ReviewMarketplaceStore _owner;
  final int _world;
  final int _epoch;
  final bool Function() _proof;
  final String _actorId;
  @override
  String get actorId => _actorId;
  @override
  void requireCurrent() => _owner._guard(this);
}

/// No persistence, backend, native/plugin, UI or implicit external effects.
/// A composition owner must bind grants/proofs to accepted server authority.
class ReviewMarketplaceStore
    implements
        MarketplaceProfileRepository,
        MarketplaceDiscoveryRepository,
        MarketplaceScheduledPostRepository,
        MarketplaceChatRepository,
        MarketplaceInboxRepository {
  ReviewMarketplaceStore({required Duration Function() elapsed})
    : this._(elapsed);
  ReviewMarketplaceStore._(this._elapsed);
  static const vehicles = {
    'cab',
    'moto',
    'bus',
    'trike',
    'truck',
    'private',
    'rentals',
  };
  static const maxPosts = 100;
  static const maxConversations = 32;
  static const maxMessagesPerConversation = 200;
  static const maxInbox = 200;
  static const maxReports = 50;
  final Duration Function() _elapsed;
  ReviewWorldSnapshot? _world;
  ReviewLeaseGrant? _grant;
  ReviewWorldPhase _phase = ReviewWorldPhase.locked;
  ReviewWorldClearReason? _lastClearReason;
  ReviewWorldClearReason? get lastClearReason => _lastClearReason;
  Duration? _deadline;
  Duration _grantReceived = Duration.zero;
  Duration _lastElapsed = Duration.zero;
  int _worldInstance = 0;
  int _actionEpoch = 0;
  bool _disposed = false;

  ReviewWorldPhase get phase {
    _checkClock();
    if (_phase == ReviewWorldPhase.active &&
        (_grant == null || !_current(_grant!.isCurrent))) {
      clear(ReviewWorldClearReason.authorityLost);
    }
    return _phase;
  }

  bool get hasWorld => phase != ReviewWorldPhase.locked && _world != null;
  ReviewWorldBinding? get binding => hasWorld ? _world!.binding : null;
  Duration get remaining {
    if (!hasWorld) return Duration.zero;
    _checkClock();
    return _deadline == null ? Duration.zero : _deadline! - _lastElapsed;
  }

  void _checkClock() {
    if (_deadline == null) return;
    final now = _elapsed();
    if (now < _lastElapsed) {
      clear(ReviewWorldClearReason.clockReset);
    } else if (now >= _deadline!) {
      clear(ReviewWorldClearReason.expiry);
    } else {
      _lastElapsed = now;
    }
  }

  /// A new proof invalidates old actions, but the stable world may survive.
  void acceptValidatedLease(ReviewLeaseGrant grant) {
    if (_disposed ||
        !_current(grant.isCurrent) ||
        !grant.serverNow.isUtc ||
        grant.remaining <= Duration.zero ||
        grant.remaining > const Duration(hours: 1) ||
        grant.authorityEpoch < 0 ||
        grant.authorityEpoch > 2147483647) {
      throw const ReviewWorldUnavailable('invalid_grant');
    }
    _checkClock();
    final now = _elapsed();
    if (now.isNegative) throw const ReviewWorldUnavailable('invalid_clock');
    final retained = _world;
    final same =
        retained != null &&
        retained.binding.sameWorld(grant.binding) &&
        _grant?.serverRole == grant.serverRole;
    final replacement = same
        ? retained
        : _Draft.seed(
            grant.binding,
            _worldInstance + 1,
            grant.serverRole,
            grant.serverNow,
          ).freeze(0);
    if (!_current(grant.isCurrent)) {
      clear(ReviewWorldClearReason.authorityLost);
      throw const ReviewWorldUnavailable('invalid_grant');
    }
    if (!same) {
      clear(ReviewWorldClearReason.replacement);
      _worldInstance++;
    }
    _world = replacement;
    _grant = grant;
    _grantReceived = now;
    _deadline = now + grant.remaining;
    _lastElapsed = now;
    _actionEpoch++;
    _phase = ReviewWorldPhase.active;
    _lastClearReason = null;
  }

  void quarantine() {
    _checkClock();
    _actionEpoch++;
    if (_world != null) _phase = ReviewWorldPhase.quarantined;
  }

  void clear(ReviewWorldClearReason reason) {
    _actionEpoch++;
    _phase = ReviewWorldPhase.locked;
    _world = null;
    _grant = null;
    _deadline = null;
    _lastClearReason = reason;
  }

  void dispose() {
    _disposed = true;
    clear(ReviewWorldClearReason.disposed);
  }

  ReviewWorldAction captureAction() {
    if (phase != ReviewWorldPhase.active || _world == null || _grant == null) {
      throw const ReviewWorldUnavailable('world_locked');
    }
    return ReviewWorldAction._(
      this,
      _worldInstance,
      _actionEpoch,
      _grant!.isCurrent,
      _world!.binding.userId,
    );
  }

  void _guard(MarketplaceAction action) {
    if (phase != ReviewWorldPhase.active ||
        action is! ReviewWorldAction ||
        !identical(action._owner, this) ||
        action._world != _worldInstance ||
        action._epoch != _actionEpoch ||
        action.actorId != _world?.binding.userId) {
      throw const ReviewWorldUnavailable('stale_or_foreign_action');
    }
    if (!_current(action._proof)) {
      clear(ReviewWorldClearReason.authorityLost);
      throw const ReviewWorldUnavailable('stale_or_foreign_action');
    }
    _checkClock();
    if (_phase != ReviewWorldPhase.active ||
        action._epoch != _actionEpoch ||
        action._world != _worldInstance) {
      throw const ReviewWorldUnavailable('stale_or_foreign_action');
    }
  }

  ReviewWorldSnapshot snapshot(MarketplaceAction action) {
    _guard(action);
    return _world!;
  }

  T _change<T>(MarketplaceAction action, T Function(_Draft) change) {
    _guard(action);
    final before = _world!;
    final draft = _Draft.from(before);
    final result = change(draft);
    final next = draft.freeze(before.revision + 1);
    _guard(action);
    _world = next;
    return result;
  }

  @override
  Profile getProfile(MarketplaceAction action) => snapshot(action).profile;
  @override
  Profile editProfile(
    MarketplaceAction action, {
    required String displayName,
    String? vehicleType,
  }) => _change(action, (draft) {
    _text(displayName, 64);
    if (vehicleType != null && !vehicles.contains(vehicleType)) {
      throw const ReviewWorldUnavailable('invalid_vehicle');
    }
    final previous = draft.profile;
    draft.profile = _profile(
      previous.id,
      previous.memberId!,
      displayName.trim(),
      _grant!.serverRole,
      vehicleType ?? previous.vehicleType!,
      previous.createdAt!,
    );
    for (final post in draft.trips.values.toList()) {
      if (post.authorId == action.actorId) {
        draft.trips[post.id!] = post.copyWith(
          authorName: draft.profile.displayName!,
        );
      }
    }
    return draft.profile;
  });
  @override
  void setMode(MarketplaceAction action, MarketplaceRole mode) =>
      _change(action, (draft) {
        if (mode == MarketplaceRole.driver &&
            _grant!.serverRole != MarketplaceRole.driver) {
          throw const ReviewWorldUnavailable('driver_role_required');
        }
        draft.mode = mode;
        if (mode == MarketplaceRole.passenger) draft.driverOnline = false;
      });
  @override
  void setDriverOnline(MarketplaceAction action, bool online) =>
      _change(action, (draft) {
        if (_grant!.serverRole != MarketplaceRole.driver ||
            draft.mode != MarketplaceRole.driver) {
          throw const ReviewWorldUnavailable('driver_role_required');
        }
        draft.driverOnline = online;
      });
  @override
  List<ReviewDiscoveryPeer> nearby(
    MarketplaceAction action, {
    String? vehicleType,
  }) {
    final current = snapshot(action);
    if (vehicleType != null && !vehicles.contains(vehicleType)) {
      throw const ReviewWorldUnavailable('invalid_vehicle');
    }
    return List.unmodifiable(
      current.peers.values
          .where(
            (peer) =>
                peer.online &&
                !current.blockedPeers.contains(peer.profile.id) &&
                (vehicleType == null ||
                    peer.profile.vehicleType == vehicleType),
          )
          .toList()
        ..sort((a, b) => a.profile.id.compareTo(b.profile.id)),
    );
  }

  @override
  List<Trip> listTrips(
    MarketplaceAction action, {
    bool ownOnly = false,
    bool includeCancelled = false,
    MarketplaceRole? role,
  }) {
    final current = snapshot(action);
    final list =
        current.trips.values
            .where(
              (trip) =>
                  (!ownOnly || trip.authorId == action.actorId) &&
                  (includeCancelled || trip.isActive) &&
                  (role == null || trip.role == role.name),
            )
            .toList()
          ..sort((a, b) {
            final order = a.startsAt!.compareTo(b.startsAt!);
            return order == 0 ? a.id!.compareTo(b.id!) : order;
          });
    return List.unmodifiable(list);
  }

  @override
  Trip getTrip(MarketplaceAction action, String id) {
    final trip = snapshot(action).trips[id];
    if (trip == null) throw const ReviewWorldUnavailable('unknown_post');
    return trip;
  }

  void _validateTrip(_Draft world, ReviewTripDraft draft) {
    final currentServerTime = _grant!.serverNow.add(
      _elapsed() - _grantReceived,
    );
    if (!world.places.containsKey(draft.originPlaceId) ||
        !world.places.containsKey(draft.destinationPlaceId) ||
        draft.originPlaceId == draft.destinationPlaceId ||
        !draft.departureAt.isUtc ||
        !draft.departureAt.isAfter(currentServerTime) ||
        draft.departureAt.difference(currentServerTime) >
            const Duration(days: 90) ||
        !vehicles.contains(draft.vehicleType) ||
        draft.seats < 1 ||
        draft.seats > 8 ||
        draft.recurringDays.length > 7 ||
        draft.recurringDays.toSet().length != draft.recurringDays.length ||
        draft.recurringDays.any((day) => day < 0 || day > 6) ||
        (draft.note?.length ?? 0) > 280 ||
        (draft.role == MarketplaceRole.driver &&
            _grant!.serverRole != MarketplaceRole.driver)) {
      throw const ReviewWorldUnavailable('invalid_post');
    }
  }

  @override
  Trip createTrip(MarketplaceAction action, ReviewTripDraft input) =>
      _change(action, (draft) {
        _validateTrip(draft, input);
        if (draft.trips.length >= maxPosts) {
          throw const ReviewWorldUnavailable('post_limit');
        }
        draft.requireInboxCapacity();
        final trip = draft.makeTrip(
          draft.id('post'),
          action.actorId,
          draft.profile.displayName!,
          input,
        );
        draft.trips[trip.id!] = trip;
        draft.tripRevisions[trip.id!] = 0;
        draft.addInbox(
          ReviewInboxKind.scheduledPost,
          'Scheduled post created',
          trip.id,
          read: true,
        );
        return trip;
      });
  Trip _ownedPost(
    _Draft draft,
    MarketplaceAction action,
    String id,
    int expectedRevision,
  ) {
    final trip = draft.trips[id];
    if (trip == null ||
        trip.authorId != action.actorId ||
        draft.tripRevisions[id] != expectedRevision ||
        !trip.isActive) {
      throw const ReviewWorldUnavailable('post_ownership_or_revision');
    }
    return trip;
  }

  @override
  Trip editTrip(
    MarketplaceAction action,
    String id,
    ReviewTripDraft input, {
    required int expectedRevision,
  }) => _change(action, (draft) {
    final previous = _ownedPost(draft, action, id, expectedRevision);
    _validateTrip(draft, input);
    final trip = draft
        .makeTrip(id, action.actorId, draft.profile.displayName!, input)
        .copyWith(createdAt: previous.createdAt);
    draft.trips[id] = trip;
    draft.tripRevisions[id] = expectedRevision + 1;
    return trip;
  });
  @override
  Trip cancelTrip(
    MarketplaceAction action,
    String id, {
    required int expectedRevision,
  }) => _change(action, (draft) {
    final previous = _ownedPost(draft, action, id, expectedRevision);
    final at = draft.time().toIso8601String();
    final trip = previous.copyWith(
      isActive: false,
      status: 'cancelled',
      cancelledAt: at,
      updatedAt: at,
    );
    draft.trips[id] = trip;
    draft.tripRevisions[id] = expectedRevision + 1;
    return trip;
  });

  void _peer(_Draft draft, String id) {
    if (!draft.peers.containsKey(id)) {
      throw const ReviewWorldUnavailable('unknown_peer');
    }
  }

  ChatConversation _conversation(
    _Draft draft,
    MarketplaceAction action,
    String id,
  ) {
    final conversation = draft.conversations[id];
    if (conversation == null ||
        (conversation.participantLowId != action.actorId &&
            conversation.participantHighId != action.actorId)) {
      throw const ReviewWorldUnavailable('conversation_ownership');
    }
    return conversation;
  }

  @override
  ChatConversation openConversation(
    MarketplaceAction action,
    String peerId, {
    String? tripId,
  }) => _change(action, (draft) {
    _peer(draft, peerId);
    if (draft.blocked.contains(peerId)) {
      throw const ReviewWorldUnavailable('peer_blocked');
    }
    if (tripId != null) {
      final trip = draft.trips[tripId];
      if (trip == null ||
          !trip.isActive ||
          (trip.authorId != action.actorId && trip.authorId != peerId)) {
        throw const ReviewWorldUnavailable('invalid_conversation_post');
      }
    }
    for (final conversation in draft.conversations.values) {
      if (conversation.peerIdFor(action.actorId) == peerId &&
          conversation.tripId == tripId) {
        return conversation;
      }
    }
    if (draft.conversations.length >= maxConversations) {
      throw const ReviewWorldUnavailable('conversation_limit');
    }
    return draft.createConversation(peerId, tripId);
  });
  @override
  List<ChatConversation> listConversations(MarketplaceAction action) =>
      List.unmodifiable(
        snapshot(action).conversations.values.toList()
          ..sort((a, b) => a.id.compareTo(b.id)),
      );
  @override
  List<ChatMessageModel> messagesFor(
    MarketplaceAction action,
    String conversationId,
  ) {
    _guard(action);
    final draft = _Draft.from(_world!);
    _conversation(draft, action, conversationId);
    return List.unmodifiable(_world!.messages[conversationId]!);
  }

  @override
  ChatMessageModel sendMessage(
    MarketplaceAction action,
    String conversationId,
    String body,
  ) => _change(action, (draft) {
    _text(body, 1000);
    final conversation = _conversation(draft, action, conversationId);
    if (draft.blocked.contains(conversation.peerIdFor(action.actorId))) {
      throw const ReviewWorldUnavailable('peer_blocked');
    }
    final list = draft.messages[conversationId]!;
    if (list.length >= maxMessagesPerConversation) {
      throw const ReviewWorldUnavailable('message_limit');
    }
    final message = ChatMessageModel(
      id: draft.id('message'),
      conversationId: conversationId,
      senderId: action.actorId,
      messageType: 'text',
      body: body,
      createdAt: draft.time(),
    );
    list.add(message);
    draft.conversations[conversationId] = _withMessage(conversation, message);
    return ReviewWorldSnapshot.copyMessage(message);
  });
  @override
  void markConversationRead(MarketplaceAction action, String conversationId) =>
      _change(action, (draft) {
        _conversation(draft, action, conversationId);
        final at = draft.time();
        draft.messages[conversationId] = draft.messages[conversationId]!
            .map(
              (message) =>
                  message.senderId == action.actorId || message.readAt != null
                  ? message
                  : ChatMessageModel(
                      id: message.id,
                      conversationId: message.conversationId,
                      senderId: message.senderId,
                      messageType: message.messageType,
                      body: message.body,
                      createdAt: message.createdAt,
                      readAt: at,
                      metadata: const {},
                    ),
            )
            .toList();
        for (final item in draft.inbox.values.toList()) {
          if (item.kind == ReviewInboxKind.message &&
              item.targetId == conversationId) {
            draft.inbox[item.id] = item.read();
          }
        }
      });
  @override
  void blockPeer(MarketplaceAction action, String peerId, bool blocked) =>
      _change(action, (draft) {
        _peer(draft, peerId);
        if (blocked) {
          draft.blocked.add(peerId);
        } else {
          draft.blocked.remove(peerId);
        }
      });
  @override
  ReviewReport reportPeer(
    MarketplaceAction action,
    String peerId,
    String reason,
  ) => _change(action, (draft) {
    _peer(draft, peerId);
    _text(reason, 280);
    if (draft.reports.length >= maxReports) {
      throw const ReviewWorldUnavailable('report_limit');
    }
    draft.requireInboxCapacity();
    final report = ReviewReport(
      id: draft.id('report'),
      peerId: peerId,
      reason: reason.trim(),
      createdAt: draft.time(),
    );
    draft.reports.add(report);
    draft.addInbox(
      ReviewInboxKind.report,
      'Synthetic report recorded',
      report.id,
      read: true,
    );
    return report;
  });
  @override
  List<ReviewInboxItem> listInbox(MarketplaceAction action) =>
      List.unmodifiable(
        snapshot(action).inbox.values.toList()..sort((a, b) {
          final at = b.createdAt.compareTo(a.createdAt);
          return at == 0 ? b.id.compareTo(a.id) : at;
        }),
      );
  @override
  void markInboxRead(MarketplaceAction action, {String? id}) =>
      _change(action, (draft) {
        if (id != null && !draft.inbox.containsKey(id)) {
          throw const ReviewWorldUnavailable('unknown_notification');
        }
        for (final item in draft.inbox.values.toList()) {
          if (id == null || item.id == id) draft.inbox[item.id] = item.read();
        }
      });
}

void _text(String text, int maximum) {
  if (text.trim().isEmpty || text.length > maximum) {
    throw const ReviewWorldUnavailable('invalid_text');
  }
}

Profile _profile(
  String id,
  String member,
  String name,
  MarketplaceRole role,
  String vehicle,
  String created,
) => Profile(
  id: id,
  memberId: member,
  name: name,
  displayName: name,
  role: role.name,
  countryCode: 'RW',
  vehicleType: vehicle,
  isDriver: role == MarketplaceRole.driver,
  createdAt: created,
);
ChatConversation _withMessage(ChatConversation old, ChatMessageModel message) =>
    ChatConversation(
      id: old.id,
      tripId: old.tripId,
      participantLowId: old.participantLowId,
      participantHighId: old.participantHighId,
      createdBy: old.createdBy,
      contextType: old.contextType,
      status: old.status,
      createdAt: old.createdAt,
      updatedAt: message.createdAt,
      lastMessageAt: message.createdAt,
      lastMessagePreview: message.body,
    );

class _Draft {
  _Draft.from(ReviewWorldSnapshot snapshot)
    : binding = snapshot.binding,
      worldInstance = snapshot.worldInstance,
      anchor = snapshot.anchor,
      profile = snapshot.profile,
      mode = snapshot.mode,
      driverOnline = snapshot.driverOnline,
      serial = snapshot.serial,
      logicalTime = snapshot.logicalTime,
      places = Map.of(snapshot.places),
      peers = Map.of(snapshot.peers),
      trips = Map.of(snapshot.trips),
      tripRevisions = Map.of(snapshot.tripRevisions),
      conversations = Map.of(snapshot.conversations),
      messages = {
        for (final entry in snapshot.messages.entries)
          entry.key: List.of(entry.value),
      },
      inbox = Map.of(snapshot.inbox),
      blocked = Set.of(snapshot.blockedPeers),
      reports = List.of(snapshot.reports);
  _Draft._(this.binding, this.worldInstance, this.anchor, this.profile)
    : mode = MarketplaceRole.passenger,
      driverOnline = false,
      serial = 0,
      logicalTime = 0,
      places = {},
      peers = {},
      trips = {},
      tripRevisions = {},
      conversations = {},
      messages = {},
      inbox = {},
      blocked = {},
      reports = [];
  final ReviewWorldBinding binding;
  final int worldInstance;
  final DateTime anchor;
  Profile profile;
  MarketplaceRole mode;
  bool driverOnline;
  int serial;
  int logicalTime;
  final Map<String, ReviewPlace> places;
  final Map<String, ReviewDiscoveryPeer> peers;
  final Map<String, Trip> trips;
  final Map<String, int> tripRevisions;
  final Map<String, ChatConversation> conversations;
  final Map<String, List<ChatMessageModel>> messages;
  final Map<String, ReviewInboxItem> inbox;
  final Set<String> blocked;
  final List<ReviewReport> reports;

  String id(String kind) {
    if (serial >= 100000 || logicalTime >= 100000) {
      throw const ReviewWorldUnavailable('world_capacity');
    }
    final raw = sha256
        .convert(utf8.encode('${binding.key}|$worldInstance|$kind|${++serial}'))
        .toString();
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-4${raw.substring(13, 16)}-8${raw.substring(17, 20)}-${raw.substring(20, 32)}';
  }

  DateTime time() {
    if (logicalTime >= 100000) {
      throw const ReviewWorldUnavailable('world_capacity');
    }
    return anchor.add(Duration(microseconds: ++logicalTime));
  }

  void requireInboxCapacity() {
    if (inbox.length >= ReviewMarketplaceStore.maxInbox) {
      throw const ReviewWorldUnavailable('inbox_limit');
    }
  }

  void addInbox(
    ReviewInboxKind kind,
    String title,
    String? target, {
    bool read = false,
  }) {
    requireInboxCapacity();
    final key = id('inbox');
    inbox[key] = ReviewInboxItem(
      id: key,
      kind: kind,
      title: title,
      targetId: target,
      createdAt: time(),
      isRead: read,
    );
  }

  Trip makeTrip(String key, String author, String name, ReviewTripDraft draft) {
    final origin = places[draft.originPlaceId]!,
        destination = places[draft.destinationPlaceId]!;
    final at = time().toIso8601String();
    final date = draft.departureAt.toIso8601String().substring(0, 10);
    final clock = draft.departureAt.toIso8601String().substring(11, 16);
    return Trip(
      id: key,
      authorId: author,
      authorName: name,
      origin: origin.label,
      destination: destination.label,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: destination.latitude,
      destLng: destination.longitude,
      originPlaceId: origin.id,
      destinationPlaceId: destination.id,
      departureDate: date,
      departureTime: clock,
      date: date,
      time: clock,
      role: draft.role.name,
      seats: draft.seats,
      note: draft.note,
      vehicleTypeStr: draft.vehicleType,
      isActive: true,
      status: 'active',
      isRecurring: draft.recurringDays.isNotEmpty,
      recurringDays: List.unmodifiable(draft.recurringDays),
      startsAt: draft.departureAt.toIso8601String(),
      createdAt: at,
      updatedAt: at,
    );
  }

  ChatConversation createConversation(String peer, String? trip) {
    final ids = [binding.userId, peer]..sort();
    final at = time();
    final key = id('conversation');
    final conversation = ChatConversation(
      id: key,
      tripId: trip,
      participantLowId: ids.first,
      participantHighId: ids.last,
      createdBy: binding.userId,
      contextType: trip == null ? 'direct' : 'trip',
      status: 'active',
      createdAt: at,
      updatedAt: at,
    );
    conversations[key] = conversation;
    messages[key] = [];
    return conversation;
  }

  static _Draft seed(
    ReviewWorldBinding binding,
    int instance,
    MarketplaceRole role,
    DateTime anchor,
  ) {
    final draft = _Draft._(
      binding,
      instance,
      anchor,
      _profile(
        binding.userId,
        '900001',
        'Review member',
        role,
        'cab',
        anchor.toIso8601String(),
      ),
    );
    for (final data in [
      ('Kigali city centre', -1.9536, 30.0606),
      ('Nyabugogo', -1.9391, 30.0435),
      ('Remera', -1.9574, 30.1110),
    ]) {
      final id = draft.id('place');
      draft.places[id] = ReviewPlace(
        id: id,
        label: data.$1,
        latitude: data.$2,
        longitude: data.$3,
      );
    }
    final places = draft.places.values.toList();
    for (var index = 0; index < 2; index++) {
      final id = draft.id('peer');
      if (id == binding.userId) {
        throw const ReviewWorldUnavailable('fixture_identity_collision');
      }
      final peer = _profile(
        id,
        '${920001 + index}',
        'Review peer ${index + 1}',
        index == 0 ? MarketplaceRole.driver : MarketplaceRole.passenger,
        index == 0 ? 'cab' : 'bus',
        anchor.toIso8601String(),
      );
      draft.peers[id] = ReviewDiscoveryPeer(
        profile: peer,
        place: places[index],
        online: true,
      );
      final trip = draft.makeTrip(
        draft.id('post'),
        id,
        peer.displayName!,
        ReviewTripDraft(
          originPlaceId: places[index].id,
          destinationPlaceId: places.last.id,
          departureAt: DateTime.utc(
            anchor.year,
            anchor.month,
            anchor.day + 1,
            9 + index,
          ),
          role: index == 0 ? MarketplaceRole.driver : MarketplaceRole.passenger,
          vehicleType: peer.vehicleType!,
        ),
      );
      draft.trips[trip.id!] = trip;
      draft.tripRevisions[trip.id!] = 0;
    }
    final peer = draft.peers.values.first.profile.id;
    final conversation = draft.createConversation(peer, null);
    final message = ChatMessageModel(
      id: draft.id('message'),
      conversationId: conversation.id,
      senderId: peer,
      messageType: 'text',
      body: 'Welcome to the synthetic Mobio review journey.',
      createdAt: draft.time(),
    );
    draft.messages[conversation.id]!.add(message);
    draft
      ..conversations[conversation.id] = _withMessage(conversation, message)
      ..addInbox(ReviewInboxKind.welcome, 'Synthetic review world', null)
      ..addInbox(
        ReviewInboxKind.message,
        'Review peer sent a message',
        conversation.id,
      );
    return draft;
  }

  ReviewWorldSnapshot freeze(int revision) => ReviewWorldSnapshot(
    binding: binding,
    worldInstance: worldInstance,
    revision: revision,
    anchor: anchor,
    profile: profile,
    mode: mode,
    driverOnline: driverOnline,
    serial: serial,
    logicalTime: logicalTime,
    places: places,
    peers: peers,
    trips: trips,
    tripRevisions: tripRevisions,
    conversations: conversations,
    messages: messages,
    inbox: inbox,
    blockedPeers: blocked,
    reports: reports,
  );
}

bool _current(bool Function() proof) {
  try {
    return proof();
  } on Object {
    return false;
  }
}
