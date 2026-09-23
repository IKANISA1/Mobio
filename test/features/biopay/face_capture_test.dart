import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/face_capture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/camera');
  var nextId = 1;
  late CameraFaceCapture capture;
  late Completer<void> initialize;
  late Completer<void> initializing;
  Completer<String>? picture;
  bool denied = false;
  var disposed = 0;
  setUp(() {
    capture = CameraFaceCapture();
    initialize = Completer<void>();
    initializing = Completer<void>();
    picture = null;
    denied = false;
    disposed = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      switch (call.method) {
        case 'availableCameras':
          return [
            {'name': 'front', 'lensFacing': 'front', 'sensorOrientation': 0},
          ];
        case 'create':
          expect(call.arguments['enableAudio'], false);
          if (denied) throw PlatformException(code: 'CameraAccessDenied');
          return {'cameraId': nextId++};
        case 'initialize':
          initializing.complete();
          await initialize.future;
          await binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter.io/cameraPlugin/camera${call.arguments['cameraId']}',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('initialized', {
                'previewWidth': 640.0,
                'previewHeight': 480.0,
                'exposureMode': 'auto',
                'exposurePointSupported': true,
                'focusMode': 'auto',
                'focusPointSupported': true,
              }),
            ),
            (_) {},
          );
          return null;
        case 'takePicture':
          return picture!.future;
        case 'dispose':
          disposed++;
          return null;
        default:
          throw StateError('Unexpected camera call: ${call.method}');
      }
    });
  });
  tearDown(() async {
    await capture.stop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'late initialization after cancellation disposes native camera',
    () async {
      final opening = capture.start(front: true);
      await initializing.future;
      await capture.stop();
      initialize.complete();
      await opening;
      expect(capture.isReady, false);
      expect(capture.controller, isNull);
      expect(disposed, 1);
    },
  );

  test(
    'permission denial is surfaced without retaining a controller',
    () async {
      denied = true;
      await expectLater(
        capture.start(front: true),
        throwsA(isA<CameraException>()),
      );
      expect(capture.controller, isNull);
    },
  );

  for (final late in [false, true]) {
    test(
      'temporary still is deleted${late ? ' after caller timeout' : ''}',
      () async {
        initialize.complete();
        await capture.start(front: true);
        final directory = await Directory.systemTemp.createTemp(
          'face-capture-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/capture.jpg');
        await file.writeAsBytes([1, 2, 3]);
        picture = Completer<String>();
        final reading = capture.capture();
        if (late) {
          await expectLater(reading, throwsA(isA<TimeoutException>()));
          picture!.complete(file.path);
          // The underlying camera operation owns cleanup beyond its caller's deadline.
          for (var i = 0; i < 100 && await file.exists(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        } else {
          picture!.complete(file.path);
          expect(await reading, [1, 2, 3]);
        }
        expect(await file.exists(), false);
        await capture.stop();
        expect(disposed, 1);
      },
    );
  }
}
