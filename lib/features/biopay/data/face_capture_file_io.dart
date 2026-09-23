import 'dart:io';

Future<void> deleteFaceCaptureFile(String path) async {
  // Only the camera's returned, app-owned temporary path reaches this helper.
  final file = File(path);
  if (await file.exists()) await file.delete();
}
