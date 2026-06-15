import 'dart:async';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';
import 'package:ndef/ndef.dart' as ndef;

enum BioPayNfcOperationStep { waiting, writing, verifying, locking }

class BioPayNfcService {
  const BioPayNfcService();

  Future<BioPayNfcWriteResult> writeCard(
    BioPayNfcCardPayload payload, {
    ValueChangedStep? onStep,
  }) async {
    onStep?.call(BioPayNfcOperationStep.waiting);
    await _ensureNfcAvailable();

    final tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 25),
      iosAlertMessage: 'Hold near the blank NFC card',
    );
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
    await FlutterNfcKit.writeNDEFRecords(records);

    onStep?.call(BioPayNfcOperationStep.verifying);
    final readBackRecords = await _readNdefRecordsWithRetry();
    final readBackPayload = bioPayNfcCardPayloadFromRecords(readBackRecords);
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
    await FlutterNfcKit.finish(iosAlertMessage: 'BioPay card written');
    return result;
  }

  Future<BioPayNfcLockResult> lockVerifiedCard(
    BioPayNfcCardPayload expected, {
    ValueChangedStep? onStep,
  }) async {
    onStep?.call(BioPayNfcOperationStep.waiting);
    await _ensureNfcAvailable();

    final tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 20),
      iosAlertMessage: 'Hold near the verified NFC card',
    );
    var diagnostics = BioPayNfcTagDiagnostics.fromTag(tag);
    if (tag.ndefCanMakeReadOnly == false) {
      throw BioPayNfcException(
        'This NFC card cannot be locked by this device.',
        diagnostics,
      );
    }

    onStep?.call(BioPayNfcOperationStep.verifying);
    final readBackRecords = await FlutterNfcKit.readNDEFRecords(cached: false);
    final readBackPayload = bioPayNfcCardPayloadFromRecords(readBackRecords);
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
    await FlutterNfcKit.makeNdefReadOnly();
    AppLogger.warning(
      'NFC card locked: ${diagnostics.logSummary}',
      context: 'BioPayNfc',
    );
    await FlutterNfcKit.finish(iosAlertMessage: 'BioPay card locked');
    return BioPayNfcLockResult(payload: expected, diagnostics: diagnostics);
  }

  Future<void> finishWithError(String message) async {
    try {
      await FlutterNfcKit.finish(iosErrorMessage: message);
    } on Object {
      // Session may not have started.
    }
  }

  Future<void> cancelActiveSession() async {
    try {
      await FlutterNfcKit.finish();
    } on Object {
      // Session may not have started.
    }
  }

  Future<void> _ensureNfcAvailable() async {
    final availability = await FlutterNfcKit.nfcAvailability;
    if (availability == NFCAvailability.available) return;
    if (availability == NFCAvailability.disabled) {
      throw const BioPayNfcException('NFC is disabled.');
    }
    throw const BioPayNfcException('NFC is not supported.');
  }

  Future<List<ndef.NDEFRecord>> _readNdefRecordsWithRetry() async {
    Object? lastError;
    const readModes = <bool?>[false, null, true];
    for (var attempt = 0; attempt < 6; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 300 + attempt * 150));
      }
      for (final cached in readModes) {
        try {
          final records = await FlutterNfcKit.readNDEFRecords(cached: cached);
          if (records.isNotEmpty) return records;
        } on Object catch (error) {
          lastError = error;
        }
      }
    }
    if (lastError != null) throw lastError;
    return const [];
  }
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
