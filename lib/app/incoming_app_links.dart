import 'dart:async';
import 'dart:collection';

import 'package:app_links/app_links.dart';
import 'package:mobi_app/core/links/incoming_app_link.dart';
export 'package:mobi_app/core/links/incoming_app_link.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';

IncomingAppLink? parseIncomingAppLink(Uri uri) {
  if (!isValidatedMobioAppLinkOrigin(uri)) return null;
  final universal = uri.scheme == 'https' && uri.host == bioPayPublicHost;
  final customNfc =
      uri.scheme == 'mobio' && uri.host == 'biopay' && uri.path == '/nfc';
  if (!universal && !customNfc) return null;
  if (universal) {
    final invite = parseIncomingInvite(uri);
    if (invite != null) return invite;
    final token = parsePaymentEntry(uri.toString())?.token;
    if (token != null) return IncomingPayment(bioPayShareUri(token).toString());
  }
  if (customNfc || (universal && uri.path == '/biopay/nfc')) {
    if (uri.queryParameters.keys.any(
      (key) => !const {'type', 'receiver', 'label'}.contains(key),
    ))
      return null;
    final card = BioPayNfcCardPayload.fromUriValue(uri);
    if (card == null) return null;
    try {
      final entry = card.appLink;
      if (parsePaymentEntry(entry) == null) return null;
      return IncomingPayment(entry);
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// One mobile subscription, including the plugin's retained cold-start event.
/// Capture does not depend on authentication, attribution or optional SDKs.
class IncomingAppLinks {
  IncomingAppLinks({Stream<Uri> Function()? links, DateTime Function()? now})
    : _links = links ?? (() => AppLinks().uriLinkStream),
      _now = now ?? DateTime.now;

  static final instance = IncomingAppLinks();
  final Stream<Uri> Function() _links;
  final DateTime Function() _now;
  final _pending = Queue<IncomingAppLink>();
  final _recent = <String, DateTime>{};
  StreamSubscription<Uri>? _subscription;
  Future<void> Function(IncomingAppLink)? _handler;
  bool _draining = false;
  bool _disposed = false;
  int rejectedArrivals = 0;

  void start() {
    if (_disposed || _subscription != null || kIsWeb) return;
    _subscription = _links().listen(receive, onError: (Object _) {});
  }

  VoidCallback attach(Future<void> Function(IncomingAppLink) handler) {
    if (_disposed) throw StateError('Link coordinator disposed');
    if (_handler != null) throw StateError('Link arrival already owned');
    _handler = handler;
    start();
    unawaited(_drain());
    return () {
      if (identical(_handler, handler)) _handler = null;
    };
  }

  void receive(Uri uri) {
    if (_disposed) return;
    final intent = parseIncomingAppLink(uri);
    if (intent == null) return;
    final now = _now();
    _recent.removeWhere(
      (_, stamp) => now.difference(stamp) >= const Duration(seconds: 2),
    );
    if (_recent.containsKey(intent.identity)) return;
    // Reject excess new arrivals explicitly; never replace a queued intent.
    if (_pending.length >= 32) {
      rejectedArrivals++;
      return;
    }
    _recent[intent.identity] = now;
    _pending.add(intent);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      while (!_disposed && _handler != null && _pending.isNotEmpty) {
        final handler = _handler!;
        try {
          await handler(_pending.removeFirst());
        } on Object {
          // A failed arrival cannot prevent another independent link opening.
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _handler = null;
    _pending.clear();
    await _subscription?.cancel();
  }
}

final incomingAppLinksProvider = Provider<IncomingAppLinks>(
  (ref) => IncomingAppLinks.instance,
);
