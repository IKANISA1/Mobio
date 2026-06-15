import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _channel = MethodChannel('rw.mobi.app/biopay_qr_export');

Future<bool> saveBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final saved = await _channel.invokeMethod<bool>('savePngToGallery', {
    'bytes': bytes,
    'fileName': fileName,
  });
  return saved ?? false;
}

Future<bool> shareBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
      subject: 'Mobio BioPay QR code',
      text: 'Mobio BioPay QR code',
    ),
  );

  return result.status != ShareResultStatus.unavailable;
}
