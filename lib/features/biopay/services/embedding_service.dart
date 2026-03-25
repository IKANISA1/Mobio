import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Runs MobileFaceNet inference on a preprocessed face image.
///
/// The model expects a 112×112 RGB image and outputs a 192-dimensional
/// embedding vector. Before returning, the embedding is L2-normalized.
///
/// On Android, tries GpuDelegateV2 for hardware acceleration.
/// On iOS, tries Metal GPU delegate.
/// Falls back to CPU (2 threads) if delegates are unavailable.
class EmbeddingService {
  static const String _modelPath = 'assets/ml/mobilefacenet.tflite';
  static const int inputSize = 112;
  static const int expectedEmbeddingDim = 192;

  static final _log = Logger(
    printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true),
  );

  Interpreter? _interpreter;
  Future<void>? _initializing;
  int _embeddingDim = 0;
  bool _gpuEnabled = false;

  bool get isReady => _interpreter != null;
  int get embeddingDim => _embeddingDim;
  bool get gpuEnabled => _gpuEnabled;

  /// Load the MobileFaceNet TFLite model from assets.
  ///
  /// Attempts GPU delegate first (NNAPI/Metal), falls back to CPU.
  Future<void> initialize() async {
    if (_interpreter != null) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }

    _initializing = () async {
      final stopwatch = Stopwatch()..start();

      final options = InterpreterOptions()..threads = 2;
      bool usingGpu = false;

      // Try GPU delegate with fallback
      try {
        if (Platform.isAndroid) {
          options.addDelegate(GpuDelegateV2());
          usingGpu = true;
        } else if (Platform.isIOS) {
          options.addDelegate(GpuDelegate());
          usingGpu = true;
        }
      } catch (e) {
        _log.w('[BioPay] GPU delegate unavailable, using CPU: $e');
        usingGpu = false;
      }

      Interpreter interpreter;
      try {
        interpreter = await Interpreter.fromAsset(
          _modelPath,
          options: options,
        );
      } catch (e) {
        // If GPU delegate caused the failure, retry without it
        if (usingGpu) {
          _log.w('[BioPay] GPU init failed, retrying CPU-only: $e');
          usingGpu = false;
          final cpuOptions = InterpreterOptions()..threads = 2;
          interpreter = await Interpreter.fromAsset(
            _modelPath,
            options: cpuOptions,
          );
        } else {
          rethrow;
        }
      }

      final outputDim = interpreter.getOutputTensor(0).shape.last;
      if (outputDim != expectedEmbeddingDim) {
        interpreter.close();
        throw EmbeddingServiceException(
          'Expected a $expectedEmbeddingDim-dimensional BioPay model, got $outputDim.',
        );
      }

      _interpreter = interpreter;
      _embeddingDim = outputDim;
      _gpuEnabled = usingGpu;

      stopwatch.stop();
      _log.i(
        '[BioPay] EmbeddingService initialized in ${stopwatch.elapsedMilliseconds}ms '
        '(GPU: $usingGpu)',
      );
    }();

    try {
      await _initializing;
    } catch (e) {
      if (e is EmbeddingServiceException) rethrow;
      throw EmbeddingServiceException('Failed to load MobileFaceNet model: $e');
    } finally {
      _initializing = null;
    }
  }

  /// Run inference on a preprocessed 112×112 RGB byte array.
  ///
  /// [normalizedPixels] must be a Float32List of shape [1, 112, 112, 3]
  /// with pixel values in range [-1, 1].
  ///
  /// Returns a 192-dimensional L2-normalized embedding.
  List<double> getEmbedding(Float32List normalizedPixels) {
    if (_interpreter == null) {
      throw EmbeddingServiceException('EmbeddingService not initialized.');
    }

    if (normalizedPixels.length != 1 * inputSize * inputSize * 3) {
      throw EmbeddingServiceException(
        'Input must have ${1 * inputSize * inputSize * 3} values, '
        'got ${normalizedPixels.length}.',
      );
    }

    final stopwatch = Stopwatch()..start();

    // Reshape input: [1, 112, 112, 3]
    final input = normalizedPixels.buffer.asFloat32List().reshape([
      1,
      inputSize,
      inputSize,
      3,
    ]);

    // Output: [1, 192]
    final output = List.generate(
      1,
      (_) => List<double>.filled(_embeddingDim, 0),
    );

    _interpreter!.run(input, output);

    stopwatch.stop();
    _log.d(
      '[BioPay] Inference completed in ${stopwatch.elapsedMilliseconds}ms',
    );

    final rawEmbedding = output[0];
    return _l2Normalize(rawEmbedding);
  }

  /// Preprocess raw RGBA/RGB pixels into the model input format.
  ///
  /// Converts a [Uint8List] of RGB pixel data (112*112*3 bytes) into
  /// normalized Float32 values in range [-1, 1].
  static Float32List preprocessRgb(Uint8List rgbPixels) {
    if (rgbPixels.length != inputSize * inputSize * 3) {
      throw EmbeddingServiceException(
        'RGB input must be ${inputSize * inputSize * 3} bytes, '
        'got ${rgbPixels.length}.',
      );
    }

    final result = Float32List(inputSize * inputSize * 3);
    for (int i = 0; i < rgbPixels.length; i++) {
      result[i] = (rgbPixels[i] / 127.5) - 1.0;
    }
    return result;
  }

  List<double> _l2Normalize(List<double> vector) {
    double norm = 0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm < 1e-10) return vector;
    return vector.map((v) => v / norm).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initializing = null;
    _embeddingDim = 0;
    _gpuEnabled = false;
  }
}

class EmbeddingServiceException implements Exception {
  final String message;
  const EmbeddingServiceException(this.message);

  @override
  String toString() => 'EmbeddingServiceException: $message';
}
