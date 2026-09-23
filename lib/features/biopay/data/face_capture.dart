import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:mobi_app/features/biopay/data/face_capture_file.dart';

abstract class FaceCapture {
  CameraController? get controller;
  bool get isReady;
  Future<void> start({required bool front});
  Future<Uint8List> capture();
  Future<void> stop();
}

class CameraFaceCapture implements FaceCapture {
  CameraController? _controller;
  int _generation = 0;
  @override
  CameraController? get controller => _controller;
  @override
  bool get isReady => _controller?.value.isInitialized == true;
  @override
  Future<void> start({required bool front}) async {
    final generation = ++_generation;
    final cameras = await availableCameras().timeout(
      const Duration(seconds: 8),
    );
    if (generation != _generation) return;
    if (cameras.isEmpty) throw CameraException('unavailable', '');
    final facing = front ? CameraLensDirection.front : CameraLensDirection.back;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == facing,
      orElse: () => cameras.first,
    );
    final camera = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    final opening = () async {
      try {
        await camera.initialize();
        if (generation != _generation) {
          await camera.dispose();
          return;
        }
        _controller = camera;
      } catch (_) {
        await camera.dispose();
        rethrow;
      }
    }();
    try {
      await opening.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _generation++;
      unawaited(opening.catchError((Object _) {}));
      rethrow;
    }
  }

  @override
  Future<Uint8List> capture() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized) {
      throw CameraException('unavailable', '');
    }
    // Cleanup belongs to the underlying operation, even if its caller times out.
    return (() async {
      final file = await camera.takePicture();
      try {
        if (await file.length() > 1500000) {
          throw CameraException('IMAGE_TOO_LARGE', '');
        }
        return await file.readAsBytes();
      } finally {
        await deleteFaceCaptureFile(file.path);
      }
    })().timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> stop() async {
    _generation++;
    final camera = _controller;
    _controller = null;
    if (camera != null) {
      await camera.dispose().timeout(const Duration(seconds: 8));
    }
  }
}
