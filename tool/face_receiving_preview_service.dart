import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';

/// In-memory receiving-method data for the explicitly labelled visual proof host.
/// It cannot resolve faces, call a backend or open a dialer.
class FaceReceivingPreviewService extends PaymentDiscoveryService {
  FaceReceivingPreviewService() : super(null);

  final _methods = <Map<String, dynamic>>[
    {
      'id': '44444444-4444-4444-8444-444444444444',
      'owner_id': '11111111-1111-4111-8111-111111111111',
      'provider': 'mtn_rw',
      'kind': 'mobileWallet',
      'identifier': '+250788000002',
      'label': 'My MoMo',
      'can_send': true,
      'can_receive': true,
      'phone_discoverable': false,
      'preferred': false,
      'active': true,
      'version': 1,
    },
  ];

  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async {
    if (action == 'workspace') return {'methods': _methods};
    if (action == 'save_method') {
      final id = data['id'] as String?;
      _methods
        ..removeWhere((method) => method['id'] == id)
        ..add({
          ...data,
          'id': id == null || id.isEmpty ? newBioPayUuid() : id,
          'owner_id': '11111111-1111-4111-8111-111111111111',
          'active': true,
        });
      return {};
    }
    if (action == 'remove_method') {
      _methods.removeWhere((method) => method['id'] == data['id']);
      return {};
    }
    if (action == 'sharing') return {'grants': [], 'links': []};
    throw StateError('This action requires a signed-in application session.');
  }

  @override
  Future<bool> openReviewedInstruction(Map<String, dynamic> data) async =>
      false;
}
