import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/services/enrollment_capture_session.dart';

void main() {
  group('EnrollmentCaptureSession', () {
    test('tracks progress and completion across five samples', () {
      final session = EnrollmentCaptureSession();

      for (var sample = 0; sample < 4; sample++) {
        session.addSample(
          List<double>.filled(192, 0.1 + sample),
          qualityScore: 0.8,
        );
        expect(session.isComplete, false);
      }

      session.addSample(List<double>.filled(192, 0.5), qualityScore: 0.9);

      expect(session.sampleCount, 5);
      expect(session.isComplete, true);
      expect(session.progress, 1.0);
    });

    test('buildAggregate averages quality score and returns unit vector', () {
      final session = EnrollmentCaptureSession();
      const dimension = 192;

      for (var sample = 0; sample < 5; sample++) {
        final embedding = List<double>.generate(
          dimension,
          (index) => index == 0 ? 1 + sample.toDouble() : 0.0,
        );
        session.addSample(embedding, qualityScore: 0.6 + (sample * 0.1));
      }

      final aggregate = session.buildAggregate();
      final magnitude = math.sqrt(
        aggregate.embedding.fold<double>(
          0,
          (sum, value) => sum + (value * value),
        ),
      );

      expect(aggregate.sampleCount, 5);
      expect(aggregate.qualityScore, closeTo(0.8, 0.0001));
      expect(magnitude, closeTo(1.0, 0.0001));
      expect(aggregate.embedding.first, closeTo(1.0, 0.0001));
    });

    test('buildAggregate rejects incomplete sessions', () {
      final session = EnrollmentCaptureSession();
      session.addSample(List<double>.filled(192, 0.25), qualityScore: 0.9);

      expect(session.buildAggregate, throwsStateError);
    });

    test('reset clears stored samples', () {
      final session = EnrollmentCaptureSession();
      session.addSample(List<double>.filled(192, 0.2), qualityScore: 0.9);
      session.reset();

      expect(session.sampleCount, 0);
      expect(session.progress, 0.0);
      expect(session.isComplete, false);
    });
  });
}
