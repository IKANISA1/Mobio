import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> saveBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final blob = _pngBlob(bytes);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor
    ..click()
    ..remove();
  web.URL.revokeObjectURL(url);
  return true;
}

Future<bool> shareBioPayQrPng(
  Uint8List bytes, {
  required String fileName,
}) async {
  final file = web.File(
    <web.BlobPart>[bytes.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: 'image/png'),
  );
  final data = web.ShareData(
    files: <web.File>[file].toJS,
    title: 'Mobio BioPay QR code',
    text: 'Mobio BioPay QR code',
  );

  if (!web.window.navigator.canShare(data)) return false;
  await web.window.navigator.share(data).toDart;
  return true;
}

web.Blob _pngBlob(Uint8List bytes) {
  return web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
}
