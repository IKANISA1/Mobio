import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _channel = MethodChannel('rw.mobi.app/biopay_qr_export');

Future<bool> saveBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final saved = await RequestDeadline.mutation(
    _channel.invokeMethod<bool>('savePngToGallery', {
      'bytes': bytes,
      'fileName': fileName,
    }),
    operation: 'save_biopay_qr_gallery',
  );
  return saved ?? false;
}

Future<bool> shareBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final directory = await RequestDeadline.read(getTemporaryDirectory());
  final file = File('${directory.path}/$fileName');
  await RequestDeadline.mutation(
    file.writeAsBytes(bytes, flush: true),
    operation: 'write_biopay_qr_export',
  );

  final result = await RequestDeadline.mutation(
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'Mobio BioPay QR code',
        text: 'Mobio BioPay QR code',
      ),
    ),
    operation: 'share_biopay_qr',
    timeout: const Duration(seconds: 60),
  );

  return result.status != ShareResultStatus.unavailable;
}
