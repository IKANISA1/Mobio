import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';

// rpc_biopay_face_authority status projection. Nullable method/vector fields
// remain present even for a user without a biopay_profiles row.
Map<String, dynamic> status({String state = 'active', bool hasFace = true}) => {
  'status': state,
  'has_face': hasFace,
  'receiving_method_id': '44444444-4444-4444-8444-444444444444',
  'pending_vector_id': null,
  'revision': 1,
  'model_version': 'yunet2023mar-sface2021dec-opencv4.11-v1',
  'enrolled_at': '2026-09-20T10:00:00Z',
  'consent_version': 'face-discovery-v1',
};
void main() {
  test(
    'exact active SQL projection preserves face and pending replacement',
    () {
      final row = status()..['pending_vector_id'] = 'vector-replacement';
      final parsed = BioPayEnrollmentStatus.fromJson(row);
      expect(parsed.isEnrolled, isTrue);
      expect(parsed.pending, isTrue);
    },
  );
  test(
    'intentional nullable no-profile SQL values are confirmed not started',
    () {
      final row = status(state: 'not_started', hasFace: false)
        ..['receiving_method_id'] = null
        ..['pending_vector_id'] = null
        ..['revision'] = null
        ..['model_version'] = null
        ..['enrolled_at'] = null
        ..['consent_version'] = null;
      final parsed = BioPayEnrollmentStatus.fromJson(row);
      expect(parsed.label, 'Set up');
      expect(parsed.hasFace, isFalse);
    },
  );
  test(
    'rejected SQL status stays unavailable and preserves existing face flag',
    () {
      final parsed = BioPayEnrollmentStatus.fromJson(status(state: 'rejected'));
      expect(parsed.isUnavailable, isTrue);
      expect(parsed.hasFace, isTrue);
    },
  );
  for (final key in [
    'status',
    'has_face',
    'receiving_method_id',
    'pending_vector_id',
  ]) {
    test('missing $key cannot fabricate absent enrollment', () {
      final row = status()..remove(key);
      expect(() => BioPayEnrollmentStatus.fromJson(row), throwsFormatException);
    });
  }
  for (final entry in <MapEntry<String, Object?>>[
    const MapEntry('status', 'invented'),
    const MapEntry('status', null),
    const MapEntry('has_face', 'true'),
    const MapEntry('has_face', null),
    const MapEntry('receiving_method_id', 'invalid'),
    const MapEntry('pending_vector_id', 1),
    const MapEntry('pending_vector_id', ''),
  ]) {
    test('malformed ${entry.key} ${entry.value} is unavailable error', () {
      final row = status()..[entry.key] = entry.value;
      expect(() => BioPayEnrollmentStatus.fromJson(row), throwsFormatException);
    });
  }
}
