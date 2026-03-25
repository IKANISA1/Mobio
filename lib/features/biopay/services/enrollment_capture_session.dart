import 'dart:math' as math;

/// Collects multiple enrollment embeddings and reduces them into a single vector.
class EnrollmentCaptureSession {
  EnrollmentCaptureSession({this.requiredSamples = 5});

  final int requiredSamples;
  final List<List<double>> _embeddings = <List<double>>[];
  final List<double> _qualityScores = <double>[];

  int get sampleCount => _embeddings.length;
  bool get isComplete => sampleCount >= requiredSamples;
  double get progress => (sampleCount / requiredSamples).clamp(0.0, 1.0);

  void addSample(List<double> embedding, {required double qualityScore}) {
    if (embedding.isEmpty) {
      throw ArgumentError('Embedding must not be empty');
    }
    if (_embeddings.isNotEmpty && embedding.length != _embeddings.first.length) {
      throw ArgumentError(
        'Expected ${_embeddings.first.length}-dim embedding, got ${embedding.length}',
      );
    }
    if (isComplete) return;

    _embeddings.add(List<double>.from(embedding));
    _qualityScores.add(qualityScore.clamp(0.0, 1.0));
  }

  EnrollmentCaptureAggregate buildAggregate() {
    if (!isComplete) {
      throw StateError(
        'Cannot build enrollment aggregate before $requiredSamples samples are collected',
      );
    }

    final dim = _embeddings.first.length;
    final average = List<double>.filled(dim, 0);
    for (final embedding in _embeddings) {
      for (var index = 0; index < embedding.length; index++) {
        average[index] += embedding[index];
      }
    }
    for (var index = 0; index < average.length; index++) {
      average[index] /= _embeddings.length;
    }

    final normalized = _l2Normalize(average);
    final totalQuality = _qualityScores.fold<double>(
      0,
      (sum, score) => sum + score,
    );

    return EnrollmentCaptureAggregate(
      embedding: normalized,
      qualityScore: totalQuality / _qualityScores.length,
      sampleCount: _embeddings.length,
    );
  }

  void reset() {
    _embeddings.clear();
    _qualityScores.clear();
  }

  List<double> _l2Normalize(List<double> vector) {
    final magnitude = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + (value * value)),
    );
    if (magnitude <= 1e-10) return List<double>.filled(vector.length, 0);

    return vector.map((value) => value / magnitude).toList(growable: false);
  }
}

class EnrollmentCaptureAggregate {
  const EnrollmentCaptureAggregate({
    required this.embedding,
    required this.qualityScore,
    required this.sampleCount,
  });

  final List<double> embedding;
  final double qualityScore;
  final int sampleCount;
}
