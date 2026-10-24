import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/features/store_review/domain/review_marketplace_store.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';

/// Volatile composition only: accepted review status owns a synthetic world.
/// Ordinary AccountContext authority cannot grant an action through this owner.
/// This owner performs no backend, persistence, provider or native work.
final class ReviewMarketplaceOwner extends ChangeNotifier {
  factory ReviewMarketplaceOwner({
    required ReviewSessionContext context,
    required String issuer,
    Duration Function()? elapsed,
  }) => ReviewMarketplaceOwner._(
    context,
    _canonicalIssuer(issuer),
    elapsed ?? (Stopwatch()..start()).elapsedAsFunction,
  );

  ReviewMarketplaceOwner._(
    this._context,
    this.issuer,
    Duration Function() elapsed,
  ) : store = ReviewMarketplaceStore(elapsed: elapsed) {
    _context.addAuthorityListener(_synchronize);
    _synchronize();
  }

  final ReviewSessionContext _context;
  final String issuer;
  final ReviewMarketplaceStore store;
  bool _disposed = false;
  bool _synchronizing = false;
  bool _synchronizeAgain = false;

  /// Transport presence suppresses ordinary external effects; it grants no task.
  bool get hasTransport => _context.hasTransport;
  ReviewWorldPhase get phase => store.phase;
  Duration get remaining {
    final authorityRemaining = _context.remaining;
    final worldRemaining = store.remaining;
    return authorityRemaining < worldRemaining
        ? authorityRemaining
        : worldRemaining;
  }

  ReviewWorldAction captureAction() => store.captureAction();

  DateTime? get serverTimeUpperBound => _context.serverTimeUpperBound;

  /// Trusted feature commands are synchronous, memory-only callbacks. This is
  /// not a sandbox for arbitrary Dart callbacks or a production task grant.
  T perform<T>(
    ReviewWorldAction action,
    T Function(ReviewMarketplaceStore store) command,
  ) {
    final before = store.snapshot(action);
    try {
      final result = command(store);
      if (result is Future || result is Stream) {
        // This diagnoses visible misuse only. It cannot retract effects or
        // detect an async callback typed void; composition must remain trusted.
        throw const ReviewWorldUnavailable('asynchronous_review_command');
      }
      return result;
    } finally {
      final after = store.snapshot(action);
      // Even a throwing trusted callback cannot hide a completed local change.
      if (after.revision != before.revision) notifyListeners();
    }
  }

  static String _canonicalIssuer(String issuer) {
    // Reuse the strict domain origin parser without granting this syntax-only
    // identity to a store. Actual world identities come only from accepted status.
    return ReviewWorldBinding(
      issuer: issuer,
      userId: '00000000-0000-4000-8000-000000000001',
      sessionId: '00000000-0000-4000-8000-000000000002',
      generation: 1,
      fixtureVersion: ReviewWorldBinding.supportedFixtureVersion,
    ).issuer;
  }

  void _synchronize() {
    if (_disposed) return;
    if (_synchronizing) {
      _synchronizeAgain = true;
      return;
    }
    _synchronizing = true;
    try {
      do {
        _synchronizeAgain = false;
        _synchronizeOnce();
      } while (_synchronizeAgain && !_disposed);
    } finally {
      _synchronizing = false;
    }
    if (!_disposed) notifyListeners();
  }

  void _synchronizeOnce() {
    // Check pending before any store phase/proof read: the old action proof is
    // deliberately invalid during validation, but same-binding memory may live
    // quarantined until a fresh accepted status or terminal invalidation.
    if (_context.pending) {
      store.quarantine();
      final binding = store.binding;
      final transport = _context.transportIdentity;
      if (binding != null &&
          (transport == null ||
              binding.userId != transport.userId.toLowerCase() ||
              binding.sessionId != transport.sessionId.toLowerCase())) {
        store.clear(ReviewWorldClearReason.replacement);
      }
      return;
    }
    try {
      final lease = _context.lease;
      if (lease == null) {
        _clearUnavailable();
        return;
      }
      final revision = _context.revision;
      final role = switch (lease.role) {
        'passenger' => MarketplaceRole.passenger,
        'driver' => MarketplaceRole.driver,
        _ => throw const ReviewWorldUnavailable('unsupported_role'),
      };
      final remaining = _context.remaining;
      final serverNow = _context.serverTimeUpperBound;
      final proof = _context.capture();
      if (serverNow == null || remaining <= Duration.zero) {
        _clearUnavailable();
        return;
      }
      store.acceptValidatedLease(
        ReviewLeaseGrant(
          binding: ReviewWorldBinding(
            issuer: issuer,
            userId: lease.identity.userId,
            sessionId: lease.identity.sessionId,
            generation: lease.generation,
            fixtureVersion: lease.fixtureVersion,
          ),
          serverRole: role,
          serverNow: serverNow,
          remaining: remaining,
          authorityEpoch: revision,
          isCurrent: () =>
              !_disposed &&
              _context.revision == revision &&
              identical(_context.lease, lease) &&
              proof.isCurrent,
        ),
      );
    } on ReviewAccessUnavailable {
      _clearUnavailable();
    } on ReviewWorldUnavailable {
      _clearUnavailable();
    }
  }

  void _clearUnavailable() {
    // The domain clock establishes expiry/reset before checking a lost proof.
    // Core invalidation currently carries no reason, so other terminal losses
    // use statusFailure rather than guessing logout/background provenance.
    final phase = store.phase;
    final reason = store.lastClearReason;
    if (phase == ReviewWorldPhase.locked &&
        (reason == ReviewWorldClearReason.expiry ||
            reason == ReviewWorldClearReason.clockReset ||
            reason == ReviewWorldClearReason.disposed)) {
      return;
    }
    store.clear(ReviewWorldClearReason.statusFailure);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _context.removeAuthorityListener(_synchronize);
    store.dispose();
    super.dispose();
  }
}

extension on Stopwatch {
  Duration elapsedAsFunction() => elapsed;
}
