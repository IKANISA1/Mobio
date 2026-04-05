import 'dart:typed_data';

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
}

class File {
  File(this.path);

  final String path;

  Future<void> delete() {
    throw UnsupportedError('File deletion is not supported on this platform.');
  }

  Future<Uint8List> readAsBytes() {
    throw UnsupportedError('File reads are not supported on this platform.');
  }
}
