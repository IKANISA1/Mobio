import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralAttributionService {
  ReferralAttributionService({required this.referralService});

  final ReferralService referralService;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  static const _platform = MethodChannel('rw.mobi.app/install_referrer');
  static const _pendingCodeKey = 'mobio.pending_referral_code';
  static const _pendingInstallIdKey = 'mobio.pending_referral_install_id';
  static const _pendingAttributionSourceKey =
      'mobio.pending_referral_attribution_source';
  static const _installMarkerKey = 'mobio.install_marker';

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;

    await _captureInstallReferrer();
    await _captureInitialUri();
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri, source: 'app_link_stream')),
      onError: (error, stackTrace) {
        AppLogger.error('Referral app link stream failed: $error\n$stackTrace');
      },
    );
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  Future<void> completePendingSignup() async {
    if (!SupabaseConfig.isConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingCodeKey);
    if (code == null || code.isEmpty) return;
    final installId = prefs.getString(_pendingInstallIdKey);
    final attributionSource = prefs.getString(_pendingAttributionSourceKey);

    try {
      final metadata = <String, dynamic>{'source': 'post_login_attribution'};
      if (attributionSource != null) {
        metadata['attribution_source'] = attributionSource;
      }
      if (installId != null && installId.startsWith('iosul_')) {
        metadata['install_proof'] = 'ios_universal_link_first_open';
      }

      await referralService.completeSignup(
        code: code,
        installId: installId,
        metadata: metadata,
      );
      await prefs.remove(_pendingCodeKey);
      await prefs.remove(_pendingInstallIdKey);
      await prefs.remove(_pendingAttributionSourceKey);
    } on Object catch (error, stackTrace) {
      AppLogger.error('Referral signup completion failed: $error\n$stackTrace');
    }
  }

  Future<void> _captureInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _handleUri(uri, source: 'initial_app_link');
      }
    } on Object catch (error, stackTrace) {
      AppLogger.error('Initial referral app link failed: $error\n$stackTrace');
    }
  }

  Future<void> _captureInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final response = await _platform.invokeMethod<dynamic>(
        'getInstallReferrer',
      );
      final raw = _installReferrerValue(response);
      if (raw == null || raw.isEmpty) return;

      final uri = Uri.tryParse('https://mobio.ikanisa.com/?$raw');
      final code = _extractCode(uri);
      if (code == null) return;

      final installMarker = await _getOrCreateInstallMarker();
      final installId = _stableInstallId(
        [
          raw,
          installMarker,
          if (response is Map) response['installBeginTimestampSeconds'],
          if (response is Map) response['referrerClickTimestampSeconds'],
        ].whereType<Object>().join('|'),
      );

      await _persistPendingCode(
        code,
        source: 'play_install_referrer',
        installId: installId,
      );
    } on MissingPluginException {
      return;
    } on Object catch (error, stackTrace) {
      AppLogger.error('Install referrer capture failed: $error\n$stackTrace');
    }
  }

  String? _installReferrerValue(dynamic response) {
    if (response is String) return response;
    if (response is Map) {
      final value = response['installReferrer'];
      return value is String ? value : null;
    }
    return null;
  }

  Future<String> _getOrCreateInstallMarker() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installMarkerKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final marker = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await prefs.setString(_installMarkerKey, marker);
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

  Future<void> _handleUri(Uri uri, {required String source}) async {
    final code = _extractCode(uri);
    if (code == null) return;

    final installId = await _installIdForUniversalLink(code, source: source);
    await _persistPendingCode(code, source: source, installId: installId);
    try {
      await referralService.recordOpen(
        code: code,
        platform: defaultTargetPlatform.name,
        metadata: {
          'source': source,
          'uri': uri.toString(),
          if (installId != null && installId.startsWith('iosul_'))
            'install_proof': 'ios_universal_link_first_open',
        },
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error('Referral open recording failed: $error\n$stackTrace');
    }
  }

  Future<String?> _installIdForUniversalLink(
    String code, {
    required String source,
  }) async {
    if (!shouldCreateIosUniversalLinkInstallId(
      platform: defaultTargetPlatform,
      source: source,
      kIsWeb: kIsWeb,
    )) {
      return null;
    }

    final installMarker = await _getOrCreateInstallMarker();
    return 'iosul_${_stableInstallId('ios-universal-link|$code|$installMarker')}';
  }

  @visibleForTesting
  static bool shouldCreateIosUniversalLinkInstallId({
    required TargetPlatform platform,
    required String source,
    required bool kIsWeb,
  }) {
    return !kIsWeb &&
        platform == TargetPlatform.iOS &&
        (source == 'initial_app_link' || source == 'app_link_stream');
  }

  Future<void> _persistPendingCode(
    String code, {
    required String source,
    String? installId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCodeKey, code);
    await prefs.setString(_pendingAttributionSourceKey, source);
    if (installId != null && installId.isNotEmpty) {
      await prefs.setString(_pendingInstallIdKey, installId);
    } else {
      await prefs.remove(_pendingInstallIdKey);
    }
    AppLogger.info('Stored pending referral code from $source.');
  }

  String? _extractCode(Uri? uri) {
    if (uri == null) return null;
    final direct = uri.queryParameters['ref'] ?? uri.queryParameters['code'];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim().toUpperCase();
    }

    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first.toLowerCase() == 'invite') {
      return segments[1].trim().toUpperCase();
    }
    return null;
  }
}
