import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/data/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';
import 'package:ndef/ndef.dart' as ndef;

class BioPayNfcForegroundSuspendedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSuspended(bool suspended) => state = suspended;
}

final bioPayNfcForegroundSuspendedProvider =
    NotifierProvider<BioPayNfcForegroundSuspendedNotifier, bool>(
      BioPayNfcForegroundSuspendedNotifier.new,
    );

class BioPayNfcForegroundListener extends ConsumerStatefulWidget {
  const BioPayNfcForegroundListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BioPayNfcForegroundListener> createState() =>
      _BioPayNfcForegroundListenerState();
}

class _BioPayNfcForegroundListenerState
    extends ConsumerState<BioPayNfcForegroundListener>
    with WidgetsBindingObserver {
  static const _nativeReaderChannel = MethodChannel(
    'rw.mobi.app/biopay_native_nfc_reader',
  );

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _running = false;
  bool _disposed = false;
  bool _requestResolving = false;
  DateTime? _lastLaunchAt;
  Uri? _lastHandledUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nativeReaderChannel.setMethodCallHandler(_handleNativeReaderCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingNativePayload();
      _startNativeReader();
      _ensureLoop();
    });
    if (!kIsWeb) {
      unawaited(_ensureLinkListener());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _nativeReaderChannel.setMethodCallHandler(null);
    unawaited(_stopNativeReader());
    unawaited(_linkSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_finishSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startNativeReader();
      _ensureLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_stopNativeReader());
      unawaited(_finishSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(bioPayNfcForegroundSuspendedProvider, (_, suspended) {
      if (suspended) {
        unawaited(_stopNativeReader());
        unawaited(_finishSession());
      } else {
        _startNativeReader();
        _ensureLoop();
      }
    });

    return widget.child;
  }

  Future<dynamic> _handleNativeReaderCall(MethodCall call) async {
    if (call.method != 'onNfcPayload') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final payload = args['payload']?.toString().trim();
    if (payload == null || payload.isEmpty) return null;
    await _handleNativePayload(payload);
    return null;
  }

  Future<void> _handleNativePayload(String payload) async {
    final cardPayload = BioPayNfcCardPayload.fromRawText(payload);
    if (cardPayload != null) {
      await _launchPayload(cardPayload);
      return;
    }

    final token = bioPayTokenFromPayload(payload);
    if (token.isNotEmpty) {
      await _launchRequestToken(token);
    }
  }

  Future<void> _startNativeReader() async {
    if (_disposed || kIsWeb) return;
    if (ref.read(bioPayNfcForegroundSuspendedProvider)) return;
    try {
      final status = await const BioPayDeviceNfcService().status();
      if (status.canAdvertise) return;
      await _nativeReaderChannel.invokeMethod<Object?>('start');
    } on Object {
      // FlutterNfcKit polling remains as fallback on unsupported platforms.
    }
  }

  Future<void> _consumePendingNativePayload() async {
    if (_disposed || kIsWeb) return;
    try {
      final pending = await _nativeReaderChannel
          .invokeMapMethod<String, String>('consumePendingPayload');
      final payload = pending?['payload']?.trim();
      if (payload == null || payload.isEmpty) return;
      await _handleNativePayload(payload);
    } on Object {
      // No native launch payload is pending.
    }
  }

  Future<void> _stopNativeReader() async {
    if (kIsWeb) return;
    try {
      await _nativeReaderChannel.invokeMethod<Object?>('stop');
    } on Object {
      // Reader may not be available on this platform.
    }
  }

  void _ensureLoop() {
    if (_disposed || _running || kIsWeb) return;
    final suspended = ref.read(bioPayNfcForegroundSuspendedProvider);
    if (suspended) return;
    _running = true;
    unawaited(_runLoop());
  }

  Future<void> _ensureLinkListener() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleIncomingUri(initial);
      }
    } on Object {
      // NFC app-link handling is best-effort; foreground polling still works.
    }

    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (_) {
        // Keep the NFC foreground loop alive even if app-link delivery fails.
      },
    );
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (_disposed || uri == _lastHandledUri) return;
    final payload = BioPayNfcCardPayload.fromUriValue(uri);
    _lastHandledUri = uri;
    if (payload != null) {
      await _launchPayload(payload);
      return;
    }

    final token = bioPayTokenFromPayload(uri.toString());
    if (token.isNotEmpty) {
      await _launchRequestToken(token);
    }
  }

  Future<void> _runLoop() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) return;

      while (!_disposed &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        if (ref.read(bioPayNfcForegroundSuspendedProvider)) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }

        try {
          final tag = await FlutterNfcKit.poll(
            timeout: const Duration(seconds: 2),
            iosAlertMessage: 'Hold near a BioPay NFC card',
            androidPlatformSound: false,
          );
          if (tag.type == NFCTagType.iso7816) {
            final response = await FlutterNfcKit.transceive<String>(
              bioPayDeviceNfcSelectApdu,
            );
            await FlutterNfcKit.finish();
            final payload = deviceNfcPayloadFromApduResponse(response);
            if (payload != null && payload.isNotEmpty) {
              await _handleNativePayload(payload);
            }
            continue;
          }

          final records = await FlutterNfcKit.readNDEFRecords(cached: false);
          await FlutterNfcKit.finish();
          final payload = bioPayNfcCardPayloadFromRecords(records);
          if (payload != null) {
            await _launchPayload(payload);
          } else {
            final token = _requestTokenFromRecords(records);
            if (token.isNotEmpty) {
              await _launchRequestToken(token);
            }
          }
        } on Object {
          // Poll timeouts are expected while the app is foregrounded. Calling
          // finish() after every timeout causes Android NFC service noise and
          // can race with explicit write flows; lifecycle/suspend paths still
          // finish active sessions.
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _launchPayload(BioPayNfcCardPayload payload) async {
    final now = DateTime.now();
    final last = _lastLaunchAt;
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastLaunchAt = now;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('NFC card detected. Opening USSD.'),
        duration: Duration(seconds: 2),
      ),
    );

    await ref.read(biopayUssdServiceProvider).launchUssdCode(payload.ussdCode);
  }

  Future<void> _launchRequestToken(String token) async {
    if (_requestResolving) return;
    final now = DateTime.now();
    final last = _lastLaunchAt;
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastLaunchAt = now;
    _requestResolving = true;

    try {
      final service = ref.read(biopayUssdServiceProvider);
      final request = SupabaseConfig.isConfigured
          ? await service.resolveRequest(token)
          : service.resolvePreviewToken(token);
      final updated = await service.openUssdDialer(request);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            updated == null
                ? 'USSD dialer unavailable.'
                : 'NFC payment request detected. Opening USSD.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on Object {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('NFC payment request unavailable.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      _requestResolving = false;
    }
  }

  Future<void> _finishSession() async {
    try {
      await FlutterNfcKit.finish();
    } on Object {
      // No active session.
    }
  }
}

String _requestTokenFromRecords(Iterable<ndef.NDEFRecord> records) {
  for (final record in records) {
    final token = _requestTokenFromRecord(record);
    if (token.isNotEmpty) return token;
  }
  return '';
}

String _requestTokenFromRecord(ndef.NDEFRecord record) {
  if (record is ndef.UriRecord) {
    final uri = record.uri;
    if (uri == null) return '';
    return bioPayTokenFromPayload(uri.toString());
  }

  if (record is ndef.TextRecord) {
    return bioPayTokenFromPayload(record.text);
  }

  final payload = record.payload;
  if (payload == null || payload.isEmpty) return '';
  try {
    return bioPayTokenFromPayload(utf8.decode(payload));
  } on FormatException {
    return '';
  }
}
