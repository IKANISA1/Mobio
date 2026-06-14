import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';

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
  bool _running = false;
  bool _disposed = false;
  DateTime? _lastLaunchAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoop());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_finishSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_finishSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(bioPayNfcForegroundSuspendedProvider, (_, suspended) {
      if (!suspended) _ensureLoop();
    });

    return widget.child;
  }

  void _ensureLoop() {
    if (_disposed || _running || kIsWeb) return;
    final suspended = ref.read(bioPayNfcForegroundSuspendedProvider);
    if (suspended) return;
    _running = true;
    unawaited(_runLoop());
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
          await FlutterNfcKit.poll(
            timeout: const Duration(seconds: 2),
            iosAlertMessage: 'Hold near a BioPay NFC card',
            androidPlatformSound: false,
          );
          final payload = await readBioPayNfcCardPayloadFromActiveTag();
          await FlutterNfcKit.finish();
          if (payload != null) {
            await _launchPayload(payload);
          }
        } on Object {
          await _finishSession();
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

  Future<void> _finishSession() async {
    try {
      await FlutterNfcKit.finish();
    } on Object {
      // No active session.
    }
  }
}
