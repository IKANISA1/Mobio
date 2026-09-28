import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/notifications/domain/push_binding.dart';

void main() {
  const owner = '00000000-0000-4000-8000-000000000001';
  const session = '00000000-0000-4000-8000-000000000002';
  const bindingId = '00000000-0000-4000-8000-000000000003';
  const tokenId = '00000000-0000-4000-8000-000000000004';
  const notificationId = '00000000-0000-4000-8000-000000000005';
  const other = '00000000-0000-4000-8000-000000000006';
  Map<String, dynamic> stored() => {'owner_id': owner, 'session_id': session,
    'binding_id': bindingId, 'token_id': tokenId};
  Map<String, dynamic> envelope() => {'protocol': 'mobio.push.v1',
    'binding_id': bindingId, 'notification_id': notificationId, 'route': '/notifications'};
  final binding = PushBinding.fromJson(stored());
  test('opaque stored binding round-trips without raw token', () {
    expect(PushBinding.fromJson(binding.toJson()).toJson(), stored());
    expect(binding.toJson().containsKey('token'), isFalse);
  });
  test('requires exact owner and session including same-owner session replacement', () {
    expect(binding.belongsTo(owner, session), isTrue);
    expect(binding.belongsTo(other, session), isFalse);
    expect(binding.belongsTo(owner, other), isFalse);
    expect(binding.belongsTo(null, session), isFalse);
    expect(binding.belongsTo(owner, null), isFalse);
  });
  test('accepts only current protocol and fixed inbox route', () {
    expect(binding.accepts(envelope()), isTrue);
    expect(binding.accepts({...envelope(), 'protocol': 'legacy'}), isFalse);
    expect(binding.accepts({...envelope(), 'route': '/admin'}), isFalse);
    expect(binding.accepts({...envelope(), 'route': 'https://outside.invalid/'}), isFalse);
  });
  test('old token binding and malformed notification identity are dropped', () {
    expect(binding.accepts({...envelope(), 'binding_id': other}), isFalse);
    expect(binding.accepts({...envelope(), 'notification_id': 'not-a-uuid'}), isFalse);
    expect(binding.accepts({...envelope(), 'notification_id': 123}), isFalse);
    expect(binding.accepts({}), isFalse);
  });
  for (final key in ['owner_id', 'session_id', 'binding_id', 'token_id']) {
    test('rejects missing stored $key', () {
      final data = stored()..remove(key);
      expect(() => PushBinding.fromJson(data), throwsFormatException);
    });
    test('rejects malformed stored $key', () {
      expect(() => PushBinding.fromJson({...stored(), key: 12}), throwsFormatException);
      expect(() => PushBinding.fromJson({...stored(), key: 'wrong'}), throwsFormatException);
    });
  }
}
