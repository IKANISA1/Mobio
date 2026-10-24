import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:ndef/ndef.dart' as ndef;

enum BioPayNfcOperationStep { waiting, writing, verifying, locking }

class BioPayNfcService {
  const BioPayNfcService({
    Duration requestTimeout = const Duration(seconds: 8),
    Duration pollTimeout = const Duration(seconds: 30),
    Duration nativeMutationTimeout = const Duration(seconds: 30),
    Duration readBackTimeout = const Duration(seconds: 12),
  }) : _requestTimeout = requestTimeout,
       _pollTimeout = pollTimeout,
       _nativeMutationTimeout = nativeMutationTimeout,
       _readBackTimeout = readBackTimeout;

  final Duration _requestTimeout;
  final Duration _pollTimeout;
  final Duration _nativeMutationTimeout;
  final Duration _readBackTimeout;
  static _NfcKitSession? _activeKitSession;

  Future<BioPayNfcWriteResult> writeCard(
    BioPayNfcCardPayload payload, {
    ValueChangedStep? onStep,
  }) async {
    if (_useAndroidNativeWriter) {
      onStep?.call(BioPayNfcOperationStep.waiting);
      await _ensureNfcAvailable();
      return _writeCardWithAndroidNativeWriter(payload, onStep: onStep);
    }
    return _withKitSession((session) async {
      onStep?.call(BioPayNfcOperationStep.waiting);
      await _ensureNfcAvailable();
      session.requireActive();
      return _writeCardWithFlutterNfcKit(payload, session, onStep: onStep);
    });
  }

  Future<BioPayNfcWriteResult> _writeCardWithFlutterNfcKit(
    BioPayNfcCardPayload payload,
    _NfcKitSession session, {
    ValueChangedStep? onStep,
  }) async {
    session.requireActive();
    session.started = true;
    final tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 25),
      androidPlatformSound: false,
      iosAlertMessage: 'Hold near the blank NFC card',
    ).timeout(_pollTimeout);
    session.requireActive();
    final diagnostics = BioPayNfcTagDiagnostics.fromTag(tag);
    AppLogger.warning(
      'NFC write tag detected: ${diagnostics.logSummary}',
      context: 'BioPayNfc',
    );

    if (tag.ndefWritable == false) {
      throw BioPayNfcException('NFC card is not writable.', diagnostics);
    }

    final records = buildBioPayNfcCardRecordsForCapacity(
      payload,
      capacity: tag.ndefCapacity,
    );
    final encodedSize = ndef.encodeNdefMessage(records).length;
    final capacity = tag.ndefCapacity;
    final diagnosticsWithSize = diagnostics.copyWith(
      encodedSize: encodedSize,
      recordCount: records.length,
    );
    if (capacity != null && capacity > 0 && encodedSize > capacity) {
      throw BioPayNfcException('NFC card is too small.', diagnosticsWithSize);
    }

    onStep?.call(BioPayNfcOperationStep.writing);
    session.requireActive();
    await _mutateNfc(
      FlutterNfcKit.writeNDEFRecords(records),
      operation: 'nfc_write_card',
    );

    onStep?.call(BioPayNfcOperationStep.verifying);
    session.requireActive();
    late List<ndef.NDEFRecord> readBackRecords;
    try {
      readBackRecords = await _readNdefRecordsWithRetry(
        requireActive: session.requireActive,
      );
    } on Object catch (error, stackTrace) {
      // The write acknowledged, but its required read-back did not. Preserve
      // that uncertainty instead of calling the physical change unsuccessful.
      throw MutationOutcomeUnknownException(
        operation: 'nfc_write_card',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    final readBackPayload = bioPayNfcCardPayloadFromRecords(readBackRecords);
    session.requireActive();
    final verified =
        readBackPayload != null && readBackPayload.semanticallyMatches(payload);
    final result = BioPayNfcWriteResult(
      expected: payload,
      readBack: readBackPayload,
      verified: verified,
      diagnostics: diagnosticsWithSize.copyWith(
        readBackRecordCount: readBackRecords.length,
        readBackRecordTypes: readBackRecords.map(_recordLabel).toList(),
      ),
    );

    if (!verified) {
      throw BioPayNfcVerificationException(result);
    }

    AppLogger.warning(
      'NFC write verified: ${result.diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    await _finishKitSession(session, iosAlertMessage: 'BioPay card written');
    return result;
  }

  Future<BioPayNfcLockResult> lockVerifiedCard(
    BioPayNfcCardPayload expected, {
    ValueChangedStep? onStep,
  }) async {
    if (_useAndroidNativeWriter) {
      onStep?.call(BioPayNfcOperationStep.waiting);
      await _ensureNfcAvailable();
      return _lockCardWithAndroidNativeWriter(expected, onStep: onStep);
    }
    return _withKitSession((session) async {
      onStep?.call(BioPayNfcOperationStep.waiting);
      await _ensureNfcAvailable();
      session.requireActive();
      return _lockCardWithFlutterNfcKit(expected, session, onStep: onStep);
    });
  }

  Future<BioPayNfcLockResult> _lockCardWithFlutterNfcKit(
    BioPayNfcCardPayload expected,
    _NfcKitSession session, {
    ValueChangedStep? onStep,
  }) async {
    session.requireActive();
    session.started = true;
    final tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 20),
      androidPlatformSound: false,
      iosAlertMessage: 'Hold near the verified NFC card',
    ).timeout(_pollTimeout);
    session.requireActive();
    var diagnostics = BioPayNfcTagDiagnostics.fromTag(tag);
    if (tag.ndefCanMakeReadOnly == false) {
      throw BioPayNfcException(
        'This NFC card cannot be locked by this device.',
        diagnostics,
      );
    }

    onStep?.call(BioPayNfcOperationStep.verifying);
    session.requireActive();
    final readBackRecords = await RequestDeadline.read(
      FlutterNfcKit.readNDEFRecords(cached: false),
      timeout: _requestTimeout,
    );
    final readBackPayload = bioPayNfcCardPayloadFromRecords(readBackRecords);
    session.requireActive();
    final verified =
        readBackPayload != null &&
        readBackPayload.semanticallyMatches(expected);
    diagnostics = diagnostics.copyWith(
      readBackRecordCount: readBackRecords.length,
      readBackRecordTypes: readBackRecords.map(_recordLabel).toList(),
    );
    if (!verified) {
      throw BioPayNfcException(
        'This is not the verified BioPay NFC card.',
        diagnostics,
      );
    }

    AppLogger.warning(
      'NFC lock verification passed: ${diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    onStep?.call(BioPayNfcOperationStep.locking);
    session.requireActive();
    await _mutateNfc(
      FlutterNfcKit.makeNdefReadOnly(),
      operation: 'nfc_lock_card',
    );
    session.requireActive();
    AppLogger.warning(
      'NFC card locked: ${diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    await _finishKitSession(session, iosAlertMessage: 'BioPay card locked');
    return BioPayNfcLockResult(payload: expected, diagnostics: diagnostics);
  }

  Future<void> finishWithError(String message) async {
    if (_useAndroidNativeWriter) {
      await _cancelAndroidNativeWriter();
      await _finishSafely(iosErrorMessage: message);
    } else {
      final session = _activeKitSession;
      if (session != null) {
        await _finishKitSession(session, iosErrorMessage: message);
      }
    }
  }

  Future<void> cancelActiveSession() async {
    if (_useAndroidNativeWriter) {
      await _cancelAndroidNativeWriter();
      await _finishSafely();
    } else {
      final session = _activeKitSession;
      if (session != null) await _finishKitSession(session);
    }
  }

  Future<T> _withKitSession<T>(Future<T> Function(_NfcKitSession) task) async {
    if (_activeKitSession != null) {
      throw const BioPayNfcException('An NFC session is still active.');
    }
    final session = _NfcKitSession();
    _activeKitSession = session;
    try {
      return await task(session);
    } finally {
      await _finishKitSession(session);
    }
  }

  Future<void> _finishKitSession(
    _NfcKitSession session, {
    String? iosAlertMessage,
    String? iosErrorMessage,
  }) async {
    session.cancelled = true;
    if (!session.started) {
      if (identical(_activeKitSession, session)) _activeKitSession = null;
      return;
    }
    if (session.finishWork != null) return;
    // Retain the real cleanup future as session authority after a UI deadline.
    // A late finish callback must never close a replacement CoreNFC session.
    final work = session.finishWork =
        FlutterNfcKit.finish(
          iosAlertMessage: iosAlertMessage,
          iosErrorMessage: iosErrorMessage,
        ).whenComplete(() {
          if (identical(_activeKitSession, session)) _activeKitSession = null;
        });
    try {
      await work.timeout(_requestTimeout);
    } on Object {
      // Cancellation is requested once; native completion may remain unknown.
    }
  }

  Future<void> _finishSafely({
    String? iosAlertMessage,
    String? iosErrorMessage,
  }) async {
    try {
      await FlutterNfcKit.finish(
        iosAlertMessage: iosAlertMessage,
        iosErrorMessage: iosErrorMessage,
      ).timeout(_requestTimeout);
    } on Object {
      // Cleanup cannot revoke a verified write or lock receipt. A deadline
      // bounds the wait; it does not prove that the native session was cancelled.
    }
  }

  Future<T> _mutateNfc<T>(
    Future<T> request, {
    required String operation,
  }) async {
    try {
      return await RequestDeadline.mutation(
        request,
        operation: operation,
        timeout: _requestTimeout,
      );
    } on PlatformException catch (error, stackTrace) {
      // A card can change before the platform reports tag loss or another I/O
      // error. Require a fresh read before repeating the physical write/lock.
      throw MutationOutcomeUnknownException(
        operation: operation,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _ensureNfcAvailable() async {
    final availability = await RequestDeadline.read(
      FlutterNfcKit.nfcAvailability,
      timeout: _requestTimeout,
    );
    if (availability == NFCAvailability.available) return;
    if (availability == NFCAvailability.disabled) {
      throw const BioPayNfcException('NFC is disabled.');
    }
    throw const BioPayNfcException('NFC is not supported.');
  }

  Future<BioPayNfcWriteResult> _writeCardWithAndroidNativeWriter(
    BioPayNfcCardPayload payload, {
    ValueChangedStep? onStep,
  }) async {
    onStep?.call(BioPayNfcOperationStep.writing);
    final response = await _invokeAndroidNativeWriter(
      'writeCard',
      payload,
      timeout: _nativeMutationTimeout,
    );
    onStep?.call(BioPayNfcOperationStep.verifying);
    final result = _androidWriteResultFromResponse(payload, response);
    if (!result.verified) {
      throw BioPayNfcVerificationException(result);
    }
    AppLogger.warning(
      'Native NFC write verified: ${result.diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    return result;
  }

  Future<BioPayNfcLockResult> _lockCardWithAndroidNativeWriter(
    BioPayNfcCardPayload expected, {
    ValueChangedStep? onStep,
  }) async {
    onStep?.call(BioPayNfcOperationStep.verifying);
    final response = await _invokeAndroidNativeWriter(
      'lockVerifiedCard',
      expected,
      timeout: _nativeMutationTimeout,
    );
    onStep?.call(BioPayNfcOperationStep.locking);
    final result = _androidWriteResultFromResponse(expected, response);
    if (!result.verified) {
      throw BioPayNfcException(
        'This is not the verified BioPay NFC card.',
        result.diagnostics,
      );
    }
    AppLogger.warning(
      'Native NFC card locked: ${result.diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    return BioPayNfcLockResult(
      payload: expected,
      diagnostics: result.diagnostics,
    );
  }

  Future<Map<Object?, Object?>> _invokeAndroidNativeWriter(
    String method,
    BioPayNfcCardPayload payload, {
    required Duration timeout,
  }) async {
    try {
      final response = await RequestDeadline.mutation(
        _androidNfcWriterChannel.invokeMapMethod<Object?, Object?>(method, {
          'appLink': payload.appLink,
          'jsonPayload': payload.toJsonString(),
          'mimeType': bioPayNfcCardMimeType,
          'packageName': bioPayNfcAppPackage,
          'receiverType': payload.receiverTypeWireName,
          'receiver': payload.receiver,
        }),
        operation: method == 'lockVerifiedCard'
            ? 'nfc_lock_card'
            : 'nfc_write_card',
        timeout: timeout,
      );
      if (response == null) {
        throw const BioPayNfcException('NFC card write failed.');
      }
      return response;
    } on MissingPluginException {
      throw const BioPayNfcException('NFC is not supported.');
    } on PlatformException catch (error, stackTrace) {
      if (!const {
        'NFC_DISABLED',
        'NFC_NOT_SUPPORTED',
        'NFC_NOT_WRITABLE',
        'NFC_TOO_SMALL',
        'NFC_LOCK_UNSUPPORTED',
        'INVALID_ARGUMENTS',
        'NFC_BUSY',
      }.contains(error.code)) {
        throw MutationOutcomeUnknownException(
          operation: method == 'lockVerifiedCard'
              ? 'nfc_lock_card'
              : 'nfc_write_card',
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      throw BioPayNfcException(_androidNfcErrorLabel(error));
    }
  }

  BioPayNfcWriteResult _androidWriteResultFromResponse(
    BioPayNfcCardPayload expected,
    Map<Object?, Object?> response,
  ) {
    final diagnostics = BioPayNfcTagDiagnostics.fromNativeResponse(response);
    final readBackPayload = BioPayNfcCardPayload.fromRawText(
      response['readBackPayload']?.toString(),
    );
    final verified =
        response['verified'] == true &&
        readBackPayload != null &&
        readBackPayload.semanticallyMatches(expected);
    return BioPayNfcWriteResult(
      expected: expected,
      readBack: readBackPayload,
      verified: verified,
      diagnostics: diagnostics,
    );
  }

  Future<void> _cancelAndroidNativeWriter() async {
    if (!_useAndroidNativeWriter) return;
    try {
      await _androidNfcWriterChannel
          .invokeMethod<Object?>('cancel')
          .timeout(_requestTimeout);
    } on Object {
      // Writer may not be active or available on this platform.
    }
  }

  Future<List<ndef.NDEFRecord>> _readNdefRecordsWithRetry({
    required VoidCallback requireActive,
  }) async {
    Object? lastError;
    final elapsed = Stopwatch()..start();
    Duration remaining() {
      final budget = _readBackTimeout - elapsed.elapsed;
      if (budget <= Duration.zero)
        throw TimeoutException(
          'NFC read-back was not confirmed.',
          _readBackTimeout,
        );
      return budget;
    }

    const readModes = <bool?>[false, null, true];
    for (var attempt = 0; attempt < 6; attempt += 1) {
      requireActive();
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 300 + attempt * 150),
        ).timeout(remaining());
      }
      for (final cached in readModes) {
        requireActive();
        try {
          final records = await FlutterNfcKit.readNDEFRecords(
            cached: cached,
          ).timeout(remaining());
          requireActive();
          if (records.isNotEmpty) return records;
        } on StaleAccountWork {
          rethrow;
        } on TimeoutException {
          // Do not start another platform read while a timed-out one may remain active.
          rethrow;
        } on Object catch (error) {
          lastError = error;
        }
      }
    }
    if (lastError != null) throw lastError;
    return const [];
  }
}

class _NfcKitSession {
  bool started = false;
  bool cancelled = false;
  Future<void>? finishWork;

  void requireActive() {
    if (cancelled || !identical(BioPayNfcService._activeKitSession, this)) {
      throw const StaleAccountWork();
    }
  }
}

const _androidNfcWriterChannel = MethodChannel('rw.mobi.app/biopay_nfc_writer');

bool get _useAndroidNativeWriter =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String _androidNfcErrorLabel(PlatformException error) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) return message;
  return switch (error.code) {
    'NFC_DISABLED' => 'NFC is disabled.',
    'NFC_NOT_SUPPORTED' => 'NFC is not supported.',
    'NFC_TIMEOUT' => 'NFC card write timed out.',
    'NFC_NOT_WRITABLE' => 'NFC card is not writable.',
    'NFC_TOO_SMALL' => 'NFC card is too small.',
    'NFC_VERIFY_FAILED' => 'NFC card verification failed.',
    'NFC_LOCK_UNSUPPORTED' => 'This NFC card cannot be locked by this device.',
    _ => 'NFC card write failed.',
  };
}

typedef ValueChangedStep = void Function(BioPayNfcOperationStep step);

class BioPayNfcWriteResult {
  const BioPayNfcWriteResult({
    required this.expected,
    required this.readBack,
    required this.verified,
    required this.diagnostics,
  });

  final BioPayNfcCardPayload expected;
  final BioPayNfcCardPayload? readBack;
  final bool verified;
  final BioPayNfcTagDiagnostics diagnostics;
}

class BioPayNfcLockResult {
  const BioPayNfcLockResult({required this.payload, required this.diagnostics});

  final BioPayNfcCardPayload payload;
  final BioPayNfcTagDiagnostics diagnostics;
}

class BioPayNfcTagDiagnostics {
  const BioPayNfcTagDiagnostics({
    required this.tagId,
    required this.standard,
    required this.type,
    required this.ndefAvailable,
    required this.ndefWritable,
    required this.ndefCanMakeReadOnly,
    required this.ndefCapacity,
    this.encodedSize,
    this.recordCount,
    this.readBackRecordCount,
    this.readBackRecordTypes = const [],
  });

  factory BioPayNfcTagDiagnostics.fromTag(NFCTag tag) {
    return BioPayNfcTagDiagnostics(
      tagId: tag.id,
      standard: tag.standard,
      type: tag.type.name,
      ndefAvailable: tag.ndefAvailable,
      ndefWritable: tag.ndefWritable,
      ndefCanMakeReadOnly: tag.ndefCanMakeReadOnly,
      ndefCapacity: tag.ndefCapacity,
    );
  }

  factory BioPayNfcTagDiagnostics.fromNativeResponse(
    Map<Object?, Object?> response,
  ) {
    final readBackTypes = response['readBackRecordTypes'];
    return BioPayNfcTagDiagnostics(
      tagId: response['tagId']?.toString() ?? '',
      standard: response['standard']?.toString() ?? 'unknown',
      type: response['type']?.toString() ?? 'unknown',
      ndefAvailable: response['ndefAvailable'] as bool?,
      ndefWritable: response['ndefWritable'] as bool?,
      ndefCanMakeReadOnly: response['ndefCanMakeReadOnly'] as bool?,
      ndefCapacity: response['ndefCapacity'] as int?,
      encodedSize: response['encodedSize'] as int?,
      recordCount: response['recordCount'] as int?,
      readBackRecordCount: response['readBackRecordCount'] as int?,
      readBackRecordTypes: readBackTypes is List
          ? readBackTypes.map((value) => value.toString()).toList()
          : const [],
    );
  }

  final String tagId;
  final String standard;
  final String type;
  final bool? ndefAvailable;
  final bool? ndefWritable;
  final bool? ndefCanMakeReadOnly;
  final int? ndefCapacity;
  final int? encodedSize;
  final int? recordCount;
  final int? readBackRecordCount;
  final List<String> readBackRecordTypes;

  String get tagLabel => tagId.isEmpty ? standard : 'Tag $tagId';

  String get logSummary {
    return 'id=$tagId standard=$standard type=$type '
        'ndefAvailable=$ndefAvailable ndefWritable=$ndefWritable '
        'canLock=$ndefCanMakeReadOnly capacity=$ndefCapacity '
        'encodedSize=$encodedSize records=$recordCount '
        'readBackRecords=$readBackRecordCount readBackTypes=$readBackRecordTypes';
  }

  BioPayNfcTagDiagnostics copyWith({
    int? encodedSize,
    int? recordCount,
    int? readBackRecordCount,
    List<String>? readBackRecordTypes,
  }) {
    return BioPayNfcTagDiagnostics(
      tagId: tagId,
      standard: standard,
      type: type,
      ndefAvailable: ndefAvailable,
      ndefWritable: ndefWritable,
      ndefCanMakeReadOnly: ndefCanMakeReadOnly,
      ndefCapacity: ndefCapacity,
      encodedSize: encodedSize ?? this.encodedSize,
      recordCount: recordCount ?? this.recordCount,
      readBackRecordCount: readBackRecordCount ?? this.readBackRecordCount,
      readBackRecordTypes: readBackRecordTypes ?? this.readBackRecordTypes,
    );
  }
}

class BioPayNfcException implements Exception {
  const BioPayNfcException(this.message, [this.diagnostics]);

  final String message;
  final BioPayNfcTagDiagnostics? diagnostics;

  @override
  String toString() => message;
}

class BioPayNfcVerificationException extends BioPayNfcException {
  BioPayNfcVerificationException(this.result)
    : super('NFC card verification failed.', result.diagnostics);

  final BioPayNfcWriteResult result;
}

String _recordLabel(ndef.NDEFRecord record) {
  final decodedType = record.decodedType;
  if (decodedType != null && decodedType.isNotEmpty) {
    return '${record.runtimeType}($decodedType)';
  }
  return record.runtimeType.toString();
}
