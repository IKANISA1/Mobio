import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:ndef/ndef.dart' as ndef;

const bioPayNfcCardMimeType = 'application/vnd.rw.mobi.biopay.nfc';
const bioPayNfcAppPackage = 'rw.mobi.app';
const bioPayNfcAppLinkHost = 'mobio.ikanisa.com';
const bioPayNfcAppLinkPath = '/biopay/nfc';

enum BioPayNfcReceiverType { momoNumber, momoPayCode, paymentLink }

class BioPayNfcCardPayload {
  const BioPayNfcCardPayload({
    required this.receiverType,
    required this.receiver,
    this.label,
  });

  const BioPayNfcCardPayload.paymentLink(String token)
    : receiverType = BioPayNfcReceiverType.paymentLink,
      receiver = token,
      label = null;

  final BioPayNfcReceiverType receiverType;
  final String receiver;
  final String? label;

  String get receiverTypeWireName {
    return switch (receiverType) {
      BioPayNfcReceiverType.momoNumber => 'momo_number',
      BioPayNfcReceiverType.momoPayCode => 'momo_pay_code',
      BioPayNfcReceiverType.paymentLink => 'payment_link',
    };
  }

  String get receiverTypeLabel {
    return switch (receiverType) {
      BioPayNfcReceiverType.momoNumber => 'MoMo Number',
      BioPayNfcReceiverType.momoPayCode => 'MoMo Pay Code',
      BioPayNfcReceiverType.paymentLink => 'Mobio payment link',
    };
  }

  String get ussdCode {
    return switch (receiverType) {
      BioPayNfcReceiverType.momoNumber => '*182*1*1*$receiver#',
      BioPayNfcReceiverType.momoPayCode => '*182*8*1*$receiver#',
      BioPayNfcReceiverType.paymentLink => '',
    };
  }

  String get canonicalReceiver {
    if (receiverType == BioPayNfcReceiverType.paymentLink) return receiver;
    final digits = receiver.replaceAll(RegExp(r'\D'), '');
    if (receiverType == BioPayNfcReceiverType.momoPayCode) return digits;
    return _displayMomoNumber(digits);
  }

  bool semanticallyMatches(BioPayNfcCardPayload other) {
    return receiverType == other.receiverType &&
        canonicalReceiver == other.canonicalReceiver;
  }

  Uri get ussdTelUri {
    final encoded = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
    return Uri.parse('tel:$encoded');
  }

  String get ussdTelLink => ussdTelUri.toString();

  String get deepLink {
    if (receiverType == BioPayNfcReceiverType.paymentLink) return appLink;
    return Uri(
      scheme: 'mobio',
      host: 'biopay',
      path: '/nfc',
      queryParameters: {
        'type': receiverTypeWireName,
        'receiver': receiver,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
      },
    ).toString();
  }

  String get appLink {
    if (receiverType == BioPayNfcReceiverType.paymentLink) {
      return bioPayShareUri(receiver).toString();
    }
    return Uri.https(bioPayNfcAppLinkHost, bioPayNfcAppLinkPath, {
      'type': receiverTypeWireName,
      'receiver': receiver,
    }).toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'mobio_biopay_nfc_card',
      'version': receiverType == BioPayNfcReceiverType.paymentLink ? 2 : 1,
      'receiver_type': receiverTypeWireName,
      'receiver': receiver,
      'provider_code': 'mtn_rw',
      if (receiverType != BioPayNfcReceiverType.paymentLink)
        'ussd_code': ussdCode,
      if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static BioPayNfcCardPayload? fromJsonMap(Map<Object?, Object?> raw) {
    final type = raw['type']?.toString().trim();
    if (type != 'mobio_biopay_nfc_card') return null;

    final receiverType = _receiverTypeFromWireName(
      raw['receiver_type']?.toString().trim(),
    );
    final receiver = raw['receiver']?.toString().trim() ?? '';
    if (receiverType == null || receiver.isEmpty) return null;
    if (receiverType == BioPayNfcReceiverType.paymentLink &&
        parsePaymentEntry(receiver)?.token != receiver) {
      return null;
    }

    return BioPayNfcCardPayload(
      receiverType: receiverType,
      receiver: receiver,
      label: raw['label']?.toString().trim(),
    );
  }

  static BioPayNfcCardPayload? fromRawText(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<Object?, Object?>) {
        return fromJsonMap(decoded);
      }
    } on FormatException {
      // Continue with legacy/direct formats.
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final fromUri = fromUriValue(uri);
      if (fromUri != null) return fromUri;
    }

    return fromUssdCode(value);
  }

  static BioPayNfcCardPayload? fromUriValue(Uri uri) {
    final entry = parsePaymentEntry(uri.toString());
    if (entry?.token != null) {
      return BioPayNfcCardPayload.paymentLink(entry!.token!);
    }
    if (uri.scheme == 'mobio' && uri.host == 'biopay' && uri.path == '/nfc') {
      final receiverType = _receiverTypeFromWireName(
        uri.queryParameters['type'],
      );
      final receiver = uri.queryParameters['receiver']?.trim() ?? '';
      if (receiverType == null || receiver.isEmpty) return null;
      return BioPayNfcCardPayload(
        receiverType: receiverType,
        receiver: receiver,
        label: uri.queryParameters['label']?.trim(),
      );
    }

    if (uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasFragment &&
        uri.host == bioPayNfcAppLinkHost &&
        uri.path == bioPayNfcAppLinkPath) {
      final receiverType = _receiverTypeFromWireName(
        uri.queryParameters['type'],
      );
      final receiver = uri.queryParameters['receiver']?.trim() ?? '';
      if (receiverType == null || receiver.isEmpty) return null;
      return BioPayNfcCardPayload(
        receiverType: receiverType,
        receiver: receiver,
        label: uri.queryParameters['label']?.trim(),
      );
    }

    if (uri.scheme == 'tel') {
      try {
        return fromUssdCode(Uri.decodeComponent(uri.toString().substring(4)));
      } on ArgumentError {
        return null;
      }
    }

    return null;
  }

  static BioPayNfcCardPayload? fromUssdCode(String raw) {
    final value = raw.trim();
    final numberPrefix = RegExp(r'^\*182\*1\*1\*([0-9]+)#?$');
    final codePrefix = RegExp(r'^\*182\*8\*1\*([0-9]+)#?$');
    final number = numberPrefix.firstMatch(value)?.group(1);
    if (number != null && number.isNotEmpty) {
      return BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: _displayMomoNumber(number),
      );
    }
    final code = codePrefix.firstMatch(value)?.group(1);
    if (code != null && code.isNotEmpty) {
      return BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoPayCode,
        receiver: code,
      );
    }
    return null;
  }
}

String normalizeBioPayNfcReceiver(
  String value, {
  required BioPayNfcReceiverType receiverType,
}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (receiverType == BioPayNfcReceiverType.momoPayCode) {
    return digits.length >= 5 && digits.length <= 6 ? digits : '';
  }

  final validation = PhoneNumberNormalizer.validateForCountry(
    phone: digits,
    countryCode: '+250',
  );
  if (!validation.isValid) return '';
  return _displayMomoNumber(validation.normalized);
}

List<ndef.NDEFRecord> buildBioPayNfcCardRecords(
  BioPayNfcCardPayload payload, {
  bool includeStructuredPayload = true,
  bool includeAndroidAppRecord = true,
}) {
  return [
    ndef.UriRecord.fromString(payload.appLink),
    if (includeStructuredPayload)
      ndef.MimeRecord(
        decodedType: bioPayNfcCardMimeType,
        payload: Uint8List.fromList(utf8.encode(payload.toJsonString())),
      ),
    if (includeAndroidAppRecord)
      ndef.AARRecord(packageName: bioPayNfcAppPackage),
  ];
}

List<ndef.NDEFRecord> buildBioPayNfcCardRecordsForCapacity(
  BioPayNfcCardPayload payload, {
  int? capacity,
}) {
  final candidates = [
    buildBioPayNfcCardRecords(payload),
    buildBioPayNfcCardRecords(payload, includeStructuredPayload: false),
    buildBioPayNfcCardRecords(
      payload,
      includeStructuredPayload: false,
      includeAndroidAppRecord: false,
    ),
  ];

  if (capacity == null || capacity <= 0) {
    return candidates[1];
  }

  for (final records in candidates) {
    if (ndef.encodeNdefMessage(records).length <= capacity) {
      return records;
    }
  }
  return candidates.last;
}

Future<BioPayNfcCardPayload?> readBioPayNfcCardPayloadFromActiveTag({
  bool? cached,
}) async {
  final records = await FlutterNfcKit.readNDEFRecords(cached: cached);
  return bioPayNfcCardPayloadFromRecords(records);
}

BioPayNfcCardPayload? bioPayNfcCardPayloadFromRecords(
  Iterable<ndef.NDEFRecord> records,
) {
  for (final record in records) {
    try {
      final payload = _payloadFromRecord(record);
      if (payload != null) return payload;
    } on FormatException {
      continue;
    } on ArgumentError {
      continue;
    }
  }
  return null;
}

BioPayNfcCardPayload? _payloadFromRecord(ndef.NDEFRecord record) {
  if (record is ndef.MimeRecord &&
      record.decodedType?.toLowerCase() == bioPayNfcCardMimeType) {
    final payload = record.payload;
    if (payload == null) return null;
    return BioPayNfcCardPayload.fromRawText(utf8.decode(payload));
  }

  if (record is ndef.TextRecord) {
    return BioPayNfcCardPayload.fromRawText(record.text);
  }

  if (record is ndef.UriRecord) {
    final uri = record.uri;
    if (uri == null) return null;
    return BioPayNfcCardPayload.fromUriValue(uri);
  }

  final payload = record.payload;
  if (payload == null || payload.isEmpty) return null;
  try {
    return BioPayNfcCardPayload.fromRawText(utf8.decode(payload));
  } on FormatException {
    return null;
  }
}

BioPayNfcReceiverType? _receiverTypeFromWireName(String? raw) {
  return switch (raw) {
    'momo_number' => BioPayNfcReceiverType.momoNumber,
    'momo_pay_code' => BioPayNfcReceiverType.momoPayCode,
    'payment_link' => BioPayNfcReceiverType.paymentLink,
    _ => null,
  };
}

String _displayMomoNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('250') && digits.length == 12) {
    return '0${digits.substring(3)}';
  }
  if (digits.startsWith('0')) return digits;
  if (digits.length == 9) return '0$digits';
  return digits;
}
