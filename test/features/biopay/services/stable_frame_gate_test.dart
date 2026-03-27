import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/services/stable_frame_gate.dart';

void main() {
  group('StableFrameGate', () {
    test('scan gate requires 3 stable frames', () {
      final gate = StableFrameGate.scan();

      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), true);
    });

    test('enrollment gate requires 5 stable frames', () {
      final gate = StableFrameGate.enrollment();

      for (var index = 0; index < 4; index++) {
        expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
      }
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), true);
    });

    test('resets on quality failure', () {
      final gate = StableFrameGate.scan();

      // ignore: cascade_invocations
      gate
        ..onFrame(isQualityAcceptable: true, trackingId: 1)
        ..onFrame(isQualityAcceptable: true, trackingId: 1)
        ..onFrame(isQualityAcceptable: false, trackingId: 1);

      expect(gate.stableCount, 0);
      expect(gate.onFrame(isQualityAcceptable: true, trackingId: 1), false);
    });

    test('resets on face change', () {
      final gate = StableFrameGate.scan();

      // ignore: cascade_invocations
      gate
        ..onFrame(isQualityAcceptable: true, trackingId: 1)
        ..onFrame(isQualityAcceptable: true, trackingId: 1)
        ..onFrame(isQualityAcceptable: true, trackingId: 2);

      expect(gate.stableCount, 0);
    });

    test('progress reports ratio', () {
      final gate = StableFrameGate.scan();

      expect(gate.progress, 0.0);

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      expect(gate.progress, closeTo(0.33, 0.01));

      gate.onFrame(isQualityAcceptable: true, trackingId: 1);
      expect(gate.progress, closeTo(0.67, 0.01));
    });
  });
}
