import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';

// Synthetic, local-only data. These adapters are never inserted in a live DB.
class PaymentDiscoveryFixture extends PaymentDiscoveryService {
  PaymentDiscoveryFixture() : super(null);
  int generation = 0;
  @override
  AccountSnapshot captureAccount() =>
      AccountSnapshot(ownerId!, 'fixture', generation);
  @override
  bool isCurrent(AccountSnapshot account) =>
      account.userId == ownerId && account.generation == generation;

  @override
  String? ownerId = '00000000-0000-4000-8000-000000000001';
  @override
  String deviceFamily = 'android';
  int opens = 0;
  String? failAction, remembered;
  Map<String, String>? contact;
  final calls = <String>[];
  final drafts = <Map<String, dynamic>>[];
  final source = const PaymentMethod(
    id: 'source',
    ownerId: '00000000-0000-4000-8000-000000000001',
    provider: 'mtn_rw',
    kind: PaymentMethodKind.mobileWallet,
    identifier: '+250788000001',
    label: 'My MoMo',
    canSend: true,
    simLabel: 'SIM 1',
    preferred: true,
  );
  final destination = const PaymentMethod(
    id: 'destination',
    ownerId: 'receiver',
    provider: 'bpr_rw',
    kind: PaymentMethodKind.bankAccount,
    identifier: '0012345678',
    label: 'Receiving bank',
  );
  Map<String, dynamic> get recipient => {
    'label': 'Shared receiving details',
    'assurance': 'shared',
    'methods': [destination.toJson()],
  };
  Map<String, dynamic> get link => {
    'id': 'link',
    'owner_id': ownerId,
    'token': '0123456789abcdef0123456789abcdef0123456789abcdef',
    'label': 'Lunch request',
    'amount_rwf': 1000,
    'scope': 'request',
    'method_ids': ['source'],
    'method_versions': {'source': 1},
    'version': 1,
    'purpose': 'transfer',
    'reference': '',
    'expires_at': '2030-01-01T12:00:00Z',
    'created_at': '2026-09-08T12:00:00Z',
    'revoked_at': null,
  };
  Map<String, dynamic> get workspace => {
    'methods': [source.toJson()],
    'drafts': drafts,
    'links': [link],
    'recents': [
      {
        'id': 'recent',
        'owner_id': ownerId,
        'lookup': '+250788000002',
        'nickname': 'My contact label',
        'favorite': true,
        'updated_at': '2026-09-08T12:00:00Z',
      },
    ],
    'templates': [
      {
        'id': 'template',
        'owner_id': ownerId,
        'label': 'Lunch',
        'data': link,
        'created_at': '2026-09-08T12:00:00Z',
      },
    ],
    'activity': [
      {
        'id': 'attempt',
        'payer_id': ownerId,
        'payee_label': 'Shared receiving details',
        'amount_minor': 100000,
        'currency': 'RWF',
        'evidence_kind': 'handoffOpened',
        'updated_at': '2026-09-08T12:00:00Z',
        'discovery_quote_id': 'quote',
        'reviewed_snapshot': {
          'source': {'label': 'My MoMo'},
        },
      },
    ],
  };
  Map<String, dynamic> get quote => {
    'quote_id': 'quote',
    'revision': drafts.isEmpty ? 0 : drafts.last['revision'],
    'source_availability': [
      {'id': source.id, 'reason': null},
    ],
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 2))
        .toIso8601String(),
    'recipient': recipient,
    'options': [
      {
        'id': 'option',
        'source': source.toJson(),
        'destination': destination.toJson(),
        'rail': 'eKash',
        'fee': {'certainty': 'capped', 'francs': 20, 'all_in': true},
        'adapter_version': 1,
        'tariff_version': 1,
        'handoff_mode': 'dial',
        'supports_reference': false,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add(action);
    if (action == failAction) throw StateError('Synthetic connection failure');
    switch (action) {
      case 'workspace':
        return workspace;
      case 'resolve':
        return recipient;
      case 'quote':
        return quote;
      case 'save_draft':
        drafts.removeWhere((d) => d['id'] == data['id']);
        drafts.add(Map.from(data));
        return data;
      case 'prepare':
        return {
          'attempt_id': 'attempt',
          'evidence': 'prepared',
          'source_label': source.label,
          'sim_label': source.simLabel,
          'mode': 'dial',
          'instruction': '*182*1*1*0788000002*1000#',
        };
      case 'record_attempt':
        return data;
      case 'create_link':
        return {...link, ...data};
      case 'sharing':
        return {'grants': [], 'links': []};
      default:
        return data;
    }
  }

  @override
  Future<void> rememberDraft(String ownerId, String draftId) async {
    remembered = draftId;
  }

  @override
  Future<String?> rememberedDraft(String ownerId) async => remembered;
  @override
  Future<Map<String, String>?> pickPhone() async => contact;
  @override
  Future<bool> openReviewedInstruction(Map<String, dynamic> prepared) async {
    opens++;
    return true;
  }

  @override
  Future<Map<String, dynamic>> previewLink(String token) async => {
    'available': true,
    ...link,
  };
  @override
  Future<Map<String, dynamic>> adminCall(
    String action,
    Map<String, dynamic> data,
  ) async => {
    'routes': [],
    'evidence': [
      {
        'name': 'MTN MoMo',
        'published_root': '*182#',
        'source_url': 'https://example.invalid/evidence',
      },
    ],
  };
}
