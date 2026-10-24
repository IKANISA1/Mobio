import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/features/biopay/data/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/domain/payment_payload.dart';
import 'package:mobi_app/l10n/app_localizations.dart';
import 'package:ndef/ndef.dart' as ndef;

class BioPayNfcForegroundSuspendedNotifier extends Notifier<bool> {
  int _suspensionGeneration = 0;
  @override
  bool build() => false;

  void setSuspended(bool suspended) {
    // A route may finish cancelling an NFC session as its scope is torn down.
    if (ref.mounted) {
      _suspensionGeneration++;
      state = suspended;
    }
  }

  int acquireSuspension() {
    final ticket = ++_suspensionGeneration;
    if (ref.mounted) state = true;
    return ticket;
  }

  void releaseSuspension(int ticket) {
    if (ref.mounted && ticket == _suspensionGeneration) state = false;
  }

  bool ownsSuspension(int ticket) =>
      ref.mounted && ticket == _suspensionGeneration && state;

  // A queued native stop remains authorized after this lease releases its UI
  // suspension, until a newer lease takes ownership of the native bridge.
  bool isCurrentSuspensionLease(int ticket) =>
      ref.mounted && ticket == _suspensionGeneration;
}

final bioPayNfcForegroundSuspendedProvider =
    NotifierProvider<BioPayNfcForegroundSuspendedNotifier, bool>(
      BioPayNfcForegroundSuspendedNotifier.new,
    );

class BioPayNfcForegroundListener extends ConsumerStatefulWidget {
  const BioPayNfcForegroundListener({
    super.key,
    required this.child,
    this.onPaymentEntry,
  });

  final Widget child;
  final Future<void> Function(String)? onPaymentEntry;

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

  bool _running = false;
  bool _disposed = false;
  bool _requestResolving = false;
  bool _nativeActive = true;
  int _readRevision = 0;
  Future<void>? _finishWork;
  bool _pollActive = false;
  Future<void>? _nativeStartWork;
  DateTime? _lastLaunchAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountContext.changes.addListener(_accountChanged);
    _nativeReaderChannel.setMethodCallHandler(_handleNativeReaderCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingNativePayload();
      _startNativeReader();
      _ensureLoop();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _readRevision++;
    _nativeActive = false;
    _nativeReaderChannel.setMethodCallHandler(null);
    unawaited(_stopNativeReader());
    WidgetsBinding.instance.removeObserver(this);
    AccountContext.changes.removeListener(_accountChanged);
    unawaited(_finishSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _nativeActive = true;
      _startNativeReader();
      _ensureLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _nativeActive = false;
      _readRevision++;
      unawaited(_stopNativeReader());
      unawaited(_finishSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(bioPayNfcForegroundSuspendedProvider, (_, suspended) {
      if (suspended) {
        _readRevision++;
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
    if (!_passiveAndroidReader || !_canReadNative) return;
    try {
      var work = _nativeStartWork;
      if (work == null) {
        // Keep the actual callback as the single-flight authority even when the
        // observer expires. Late start must still obey disposal/lifecycle.
        work = _startNativeReaderWork();
        final current = work.whenComplete(() => _nativeStartWork = null);
        _nativeStartWork = current;
        work = current;
      }
      await RequestDeadline.mutation(
        work,
        operation: 'start_nfc_reader',
        timeout: const Duration(seconds: 4),
      );
    } on Object {
      // FlutterNfcKit polling remains as fallback on unsupported platforms.
    }
  }

  bool get _canReadNative =>
      !_disposed &&
      _nativeActive &&
      !ref.read(bioPayNfcForegroundSuspendedProvider);

  // CoreNFC poll opens a system sheet. The global listener is passive only on
  // Android; iOS sessions belong to explicit write/lock task services.
  bool get _passiveAndroidReader =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _accountChanged() {
    _readRevision++;
    unawaited(_finishSession());
  }

  Future<void> _startNativeReaderWork() async {
    final status = await const BioPayDeviceNfcService().status();
    if (status.canAdvertise || !_canReadNative) return;
    await _nativeReaderChannel.invokeMethod<Object?>('start');
    if (!_canReadNative) await _stopNativeReader();
  }

  Future<void> _consumePendingNativePayload() async {
    if (_disposed || !_passiveAndroidReader) return;
    try {
      final pending = await RequestDeadline.mutation(
        _nativeReaderChannel.invokeMapMethod<String, String>(
          'consumePendingPayload',
        ),
        operation: 'consume_pending_nfc_payload',
        timeout: const Duration(seconds: 4),
      );
      if (_disposed) return;
      final payload = pending?['payload']?.trim();
      if (payload == null || payload.isEmpty) return;
      await _handleNativePayload(payload);
    } on Object {
      // No native launch payload is pending.
    }
  }

  Future<void> _stopNativeReader() async {
    if (!_passiveAndroidReader) return;
    try {
      await RequestDeadline.mutation(
        _nativeReaderChannel.invokeMethod<Object?>('stop'),
        operation: 'stop_nfc_reader',
        timeout: const Duration(seconds: 4),
      );
    } on Object {
      // Reader may not be available on this platform.
    }
  }

  void _ensureLoop() {
    if (_disposed || _running || !_passiveAndroidReader || !_nativeActive)
      return;
    final suspended = ref.read(bioPayNfcForegroundSuspendedProvider);
    if (suspended) return;
    _running = true;
    unawaited(_runLoop());
  }

  Future<void> _runLoop() async {
    try {
      final availability = await RequestDeadline.read(
        FlutterNfcKit.nfcAvailability,
        timeout: const Duration(seconds: 4),
      );
      if (availability != NFCAvailability.available) return;

      while (!_disposed &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        if (ref.read(bioPayNfcForegroundSuspendedProvider)) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }

        try {
          final revision = _readRevision;
          _pollActive = true;
          final tag = await FlutterNfcKit.poll(
            timeout: const Duration(seconds: 2),
            iosAlertMessage: 'Hold near a BioPay NFC card',
            androidPlatformSound: false,
          ).timeout(const Duration(seconds: 3));
          if (!_canReadNative || revision != _readRevision) {
            await _finishSession();
            return;
          }
          if (tag.type == NFCTagType.iso7816) {
            final response = await RequestDeadline.read(
              FlutterNfcKit.transceive<String>(bioPayDeviceNfcSelectApdu),
              timeout: const Duration(seconds: 4),
            );
            await _finishSession();
            if (!_canReadNative || revision != _readRevision) return;
            final payload = deviceNfcPayloadFromApduResponse(response);
            if (payload != null && payload.isNotEmpty) {
              await _handleNativePayload(payload);
            }
            continue;
          }

          final records = await RequestDeadline.read(
            FlutterNfcKit.readNDEFRecords(cached: false),
            timeout: const Duration(seconds: 4),
          );
          await _finishSession();
          if (!_canReadNative || revision != _readRevision) return;
          final payload = bioPayNfcCardPayloadFromRecords(records);
          if (payload != null) {
            await _launchPayload(payload);
          } else {
            final token = _requestTokenFromRecords(records);
            if (token.isNotEmpty) {
              await _launchRequestToken(token);
            }
          }
        } on TimeoutException {
          // A Dart deadline does not cancel the native operation. Finish once
          // and stop this loop before another poll can overlap it.
          await _finishSession();
          break;
        } on Object {
          // Poll timeouts are expected while the app is foregrounded. Calling
          // finish() after every timeout causes Android NFC service noise and
          // can race with explicit write flows; lifecycle/suspend paths still
          // finish active sessions.
          _pollActive = false;
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } on Object {
      // Availability/plugin failure makes this foreground attempt unavailable.
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
      SnackBar(
        content: Text(AppLocalizations.of(context)!.bpReview),
        duration: const Duration(seconds: 2),
      ),
    );

    await widget.onPaymentEntry?.call(payload.appLink);
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
      await widget.onPaymentEntry?.call(token);
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
    if (!_passiveAndroidReader || !_pollActive) return;
    final pending = _finishWork;
    if (pending != null) return pending;
    _pollActive = false;
    final work = _finishActiveSession();
    _finishWork = work;
    try {
      await work;
    } finally {
      if (identical(_finishWork, work)) _finishWork = null;
    }
  }

  Future<void> _finishActiveSession() async {
    try {
      await FlutterNfcKit.finish().timeout(const Duration(seconds: 4));
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
