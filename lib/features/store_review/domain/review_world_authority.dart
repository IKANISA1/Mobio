/// Pure composition contracts. Construct a grant only after authenticated,
/// exact-session server status has been accepted by ReviewSessionContext.
/// These types parse no JWT/status JSON and authorize no production service.
abstract interface class MarketplaceAction {
  String get actorId;
  void requireCurrent();
}

enum MarketplaceRole { passenger, driver }

enum ReviewWorldPhase { locked, active, quarantined }

enum ReviewWorldClearReason {
  statusFailure,
  expiry,
  logout,
  background,
  replacement,
  authorityLost,
  clockReset,
  disposed,
}

final class ReviewWorldUnavailable implements Exception {
  const ReviewWorldUnavailable(this.code);
  final String code;
  @override
  String toString() => 'ReviewWorldUnavailable($code)';
}

final class ReviewWorldBinding {
  factory ReviewWorldBinding({
    required String issuer,
    required String userId,
    required String sessionId,
    required int generation,
    required String fixtureVersion,
  }) {
    final uri = Uri.tryParse(issuer);
    if (issuer != issuer.trim() ||
        !_httpsOrigin.hasMatch(issuer) ||
        uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
        !_uuid.hasMatch(userId) ||
        !_uuid.hasMatch(sessionId) ||
        generation < 1 ||
        generation > 2147483647 ||
        fixtureVersion != supportedFixtureVersion) {
      throw const ReviewWorldUnavailable('invalid_binding');
    }
    return ReviewWorldBinding._(
      uri.origin,
      userId.toLowerCase(),
      sessionId.toLowerCase(),
      generation,
      fixtureVersion,
    );
  }
  const ReviewWorldBinding._(
    this.issuer,
    this.userId,
    this.sessionId,
    this.generation,
    this.fixtureVersion,
  );
  static const supportedFixtureVersion = 'mobio-marketplace-v1';
  // Reject encoded/dot-segment paths before Uri can normalize them into origin.
  static final _httpsOrigin = RegExp(
    r'^https://(?:[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:]+\])(?::[0-9]{1,5})?/?$',
  );
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  final String issuer;
  final String userId;
  final String sessionId;
  final int generation;
  final String fixtureVersion;
  String get key => '$issuer|$userId|$sessionId|$generation|$fixtureVersion';
  bool sameWorld(ReviewWorldBinding other) => key == other.key;
}

final class ReviewLeaseGrant {
  const ReviewLeaseGrant({
    required this.binding,
    required this.serverRole,
    required this.serverNow,
    required this.remaining,
    required this.authorityEpoch,
    required this.isCurrent,
  });
  final ReviewWorldBinding binding;
  final MarketplaceRole serverRole;
  final DateTime serverNow;

  /// Already deduct the authenticated status request round trip at composition.
  final Duration remaining;
  final int authorityEpoch;
  final bool Function() isCurrent;
}
