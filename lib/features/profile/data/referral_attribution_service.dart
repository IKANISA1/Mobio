import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/links/incoming_app_link.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralAttributionService {
  ReferralAttributionService({
    required this.referralService,
    Future<SharedPreferences> Function()? preferences,
    bool Function()? enabled,
    bool Function()? verified,
    AccountSnapshot Function()? captureAccount,
    void Function(AccountSnapshot)? requireCurrent,
    Listenable? accountChanges,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _enabled = enabled ?? (() => SupabaseConfig.isConfigured),
       _verified = verified ?? (() => AccountContext.hasVerifiedSession),
       _capture = captureAccount ?? AccountContext.capture,
       _require = requireCurrent ?? AccountContext.requireCurrent,
       _accountChanges = accountChanges ?? AccountContext.changes {
    _accountChanges.addListener(_accountChanged);
  }

  final ReferralService referralService;
  final Future<SharedPreferences> Function() _preferences;
  final bool Function() _enabled, _verified;
  final AccountSnapshot Function() _capture;
  final void Function(AccountSnapshot) _require;
  final Listenable _accountChanges;
  static const _platform = MethodChannel('rw.mobi.app/install_referrer');
  static const _pendingKey = 'mobio.pending_referral.v2';
  static const _legacyCode = 'mobio.pending_referral_code';
  static const _legacyInstall = 'mobio.pending_referral_install_id';
  static const _legacySource = 'mobio.pending_referral_attribution_source';
  static const _installMarker = 'mobio.install_marker';
  Future<void> _diskTail = Future<void>.value();
  Future<void>? _initialization;
  final _completing = <String, Future<void>>{};
  int _arrivalRevision = 0;
  bool _disposed = false;

  Future<T> _disk<T>(Future<T> Function(SharedPreferences) work) {
    final result = _diskTail.then((_) async => work(await _preferences()));
    _diskTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await _captureInstallReferrer();
    if (!_disposed && _verified()) unawaited(completePendingSignup());
  }

  Future<void> dispose() async {
    _disposed = true;
    _accountChanges.removeListener(_accountChanged);
  }

  void _accountChanged() => unawaited(completePendingSignup());

  /// A validated arrival is persisted before navigation. Network work does not
  /// block routing, first frame, or capture of the next link.
  Future<void> captureInvite(
    IncomingInvite invite, {
    String source = 'app_link_stream',
  }) async {
    if (_disposed || !_enabled()) return;
    final arrivalAccount = _verified() ? _capture() : null;
    final revision = ++_arrivalRevision;
    final stored = await _disk((prefs) async {
      if (_disposed || revision != _arrivalRevision) return false;
      String? installId;
      if (shouldCreateIosUniversalLinkInstallId(
        platform: defaultTargetPlatform,
        source: source,
        kIsWeb: kIsWeb,
        universalLink: invite.universalLink,
      )) {
        installId =
            'iosul_${_stableInstallId('ios-universal-link|${invite.code}|${await _marker(prefs)}')}';
      }
      await _save(prefs, {
        'id': '${DateTime.now().microsecondsSinceEpoch}:$revision',
        'code': invite.code,
        'source': source,
        'install_id': installId,
        if (arrivalAccount != null) 'claimed_by': arrivalAccount.userId,
      });
      return true;
    });
    if (!stored || _disposed) return;
    unawaited(
      referralService
          .recordOpen(
            code: invite.code,
            platform: defaultTargetPlatform.name,
            metadata: {
              'source': source,
              if (invite.universalLink) 'link_kind': 'universal',
            },
          )
          .catchError((Object _) {
            AppLogger.warning('REFERRAL_OPEN_UNAVAILABLE');
          }),
    );
    if (_verified()) {
      if (arrivalAccount != null) {
        try {
          _require(arrivalAccount);
        } on Object {
          return;
        }
      }
      unawaited(completePendingSignup());
    }
  }

  Future<void> completePendingSignup() async {
    try {
      if (_disposed || !_enabled() || !_verified()) return;
      final account = _capture();
      final revision = _arrivalRevision;
      final pending = await _disk(_read);
      _require(account);
      if (_disposed ||
          pending == null ||
          pending['unknown_outcome'] == true ||
          (pending['claimed_by'] != null &&
              pending['claimed_by'] != account.userId) ||
          revision != _arrivalRevision)
        return;
      final key = '${account.identity}:${account.generation}:${pending['id']}';
      final existing = _completing[key];
      if (existing != null) return existing;
      final work = _complete(account, pending, revision);
      _completing[key] = work;
      try {
        await work;
      } finally {
        if (identical(_completing[key], work)) _completing.remove(key);
      }
    } on Object {
      AppLogger.warning('REFERRAL_COMPLETION_UNAVAILABLE');
    }
  }

  Future<void> _complete(
    AccountSnapshot account,
    Map<String, dynamic> pending,
    int revision,
  ) async {
    var requestStarted = false;
    try {
      final admitted = await _disk((prefs) async {
        _require(account);
        if (_disposed ||
            revision != _arrivalRevision ||
            (await _read(prefs))?['id'] != pending['id'])
          return false;
        // Write uncertainty before dispatch, so process exit while the RPC is
        // in flight cannot turn a later restore into an automatic write replay.
        await _save(prefs, {
          ...pending,
          'claimed_by': account.userId,
          'unknown_outcome': true,
        });
        return true;
      });
      if (!admitted) return;
      _require(account);
      final installId = pending['install_id'] as String?;
      requestStarted = true;
      await referralService.completeSignup(
        code: pending['code'] as String,
        installId: installId,
        metadata: {
          'source': 'post_login_attribution',
          'attribution_source': pending['source'],
          if (installId?.startsWith('iosul_') == true)
            'install_proof': 'ios_universal_link_first_open',
        },
      );
      await _disk((prefs) async {
        _require(account);
        if (_disposed ||
            revision != _arrivalRevision ||
            (await _read(prefs))?['id'] != pending['id'])
          return;
        if (!await prefs.remove(_pendingKey))
          throw StateError('REFERRAL_STORAGE_FAILED');
      });
    } on MutationOutcomeUnknownException {
      // A lost response requires reconciliation, not another automatic reward
      // mutation on a token refresh, login retry, or process restart.
      await _markUnknownPending(account, pending, revision);
      AppLogger.warning('REFERRAL_COMPLETION_UNKNOWN');
    } on StaleAccountWork {
      if (requestStarted) await _markUnknownPending(account, pending, revision);
      AppLogger.warning('REFERRAL_COMPLETION_UNAVAILABLE');
    } on PostgrestException {
      // RequestDeadline already separates transport/proxy uncertainty. An
      // explicit SQL rejection is known and can retain ordinary retry state.
      try {
        await _disk((prefs) async {
          _require(account);
          final current = await _read(prefs);
          if (!_disposed &&
              revision == _arrivalRevision &&
              current?['id'] == pending['id'] &&
              current?['claimed_by'] == account.userId) {
            await _save(prefs, {...current!, 'unknown_outcome': false});
          }
        });
      } on Object {
        /* Retain uncertainty if its owner is no longer current. */
      }
      AppLogger.warning('REFERRAL_COMPLETION_REJECTED');
    } on Object {
      AppLogger.warning('REFERRAL_COMPLETION_UNAVAILABLE');
    }
  }

  Future<void> _markUnknownPending(
    AccountSnapshot account,
    Map<String, dynamic> pending,
    int revision,
  ) async {
    try {
      await _disk((prefs) async {
        // This is pending-record bookkeeping, not work for the replacement
        // account. Keep uncertainty durable even if its original owner exits.
        final current = await _read(prefs);
        if (!_disposed &&
            revision == _arrivalRevision &&
            current?['id'] == pending['id'] &&
            current?['claimed_by'] == account.userId) {
          await _save(prefs, {...current!, 'unknown_outcome': true});
        }
      });
    } on Object {
      /* Keep the durable claimed owner if storage is unavailable. */
    }
  }

  Future<Map<String, dynamic>?> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_pendingKey);
    if (raw != null) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final code = prefs.getString(_legacyCode);
    if (code == null || code.isEmpty) return null;
    final pending = <String, dynamic>{
      'id': 'legacy:$code',
      'code': code,
      'install_id': prefs.getString(_legacyInstall),
      'source': prefs.getString(_legacySource),
    };
    await _save(prefs, pending);
    // Migration is complete only after the atomic replacement was acknowledged.
    for (final key in [_legacyCode, _legacyInstall, _legacySource]) {
      if (!await prefs.remove(key)) throw StateError('REFERRAL_STORAGE_FAILED');
    }
    return pending;
  }

  Future<void> _save(
    SharedPreferences prefs,
    Map<String, dynamic> pending,
  ) async {
    if (!await prefs.setString(_pendingKey, jsonEncode(pending))) {
      throw StateError('REFERRAL_STORAGE_FAILED');
    }
  }

  Future<void> _captureInstallReferrer() async {
    if (_disposed ||
        !_enabled() ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android)
      return;
    final revision = _arrivalRevision;
    try {
      final response = await RequestDeadline.read(
        _platform.invokeMethod<dynamic>('getInstallReferrer'),
      );
      final raw = response is String
          ? response
          : response is Map
          ? response['installReferrer']
          : null;
      if (raw is! String || raw.isEmpty) return;
      final intent = parseIncomingInvite(
        Uri.parse('https://mobio.ikanisa.com/?$raw'),
      );
      if (intent is! IncomingInvite) return;
      await _disk((prefs) async {
        if (_disposed ||
            revision != _arrivalRevision ||
            await _read(prefs) != null)
          return;
        final marker = await _marker(prefs);
        final installId = _stableInstallId(
          [
            raw,
            marker,
            if (response is Map) response['installBeginTimestampSeconds'],
            if (response is Map) response['referrerClickTimestampSeconds'],
          ].whereType<Object>().join('|'),
        );
        await _save(prefs, {
          'id': 'play:$installId',
          'code': intent.code,
          'source': 'play_install_referrer',
          'install_id': installId,
        });
      });
    } on Object {
      AppLogger.warning('REFERRAL_INSTALL_SOURCE_UNAVAILABLE');
    }
  }

  Future<String> _marker(SharedPreferences prefs) async {
    final existing = prefs.getString(_installMarker);
    if (existing != null && existing.isNotEmpty) return existing;
    final marker = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    if (!await prefs.setString(_installMarker, marker))
      throw StateError('REFERRAL_STORAGE_FAILED');
    return marker;
  }

  String _stableInstallId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  @visibleForTesting
  static bool shouldCreateIosUniversalLinkInstallId({
    required TargetPlatform platform,
    required String source,
    required bool kIsWeb,
    required bool universalLink,
  }) =>
      universalLink &&
      !kIsWeb &&
      platform == TargetPlatform.iOS &&
      (source == 'initial_app_link' ||
          source == 'app_link_stream' ||
          source == 'web_route');
}
