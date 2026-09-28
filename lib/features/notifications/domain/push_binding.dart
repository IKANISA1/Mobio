/// Opaque delivery-address binding. It is not an authentication credential.
class PushBinding {
  const PushBinding({required this.bindingId, required this.tokenId,
    required this.ownerId, required this.sessionId});
  final String bindingId;
  final String tokenId;
  final String ownerId;
  final String sessionId;
  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  factory PushBinding.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || !_uuid.hasMatch(value)) {
        throw const FormatException('Invalid push binding');
      }
      return value;
    }
    return PushBinding(bindingId: field('binding_id'), tokenId: field('token_id'),
      ownerId: field('owner_id'), sessionId: field('session_id'));
  }
  Map<String, String> toJson() => {'binding_id': bindingId, 'token_id': tokenId,
    'owner_id': ownerId, 'session_id': sessionId};
  bool belongsTo(String? owner, String? session) => owner == ownerId && session == sessionId;
  bool accepts(Map<String, dynamic> data) => data['protocol'] == 'mobio.push.v1' &&
    data['binding_id'] == bindingId && data['notification_id'] is String &&
    _uuid.hasMatch(data['notification_id'] as String) && data['route'] == '/notifications';
}
