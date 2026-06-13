import 'package:mobi_app/core/services/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/models/biopay_admin.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BioPayAdminService {
  BioPayAdminService({this.supabase, BioPayFaceService? faceService})
    : faceService = faceService ?? BioPayFaceService(supabase: supabase);

  final SupabaseClient? supabase;
  final BioPayFaceService faceService;

  Future<BioPayAdminSnapshot> loadSnapshot({String? search}) async {
    if (supabase == null) return previewSnapshot(search: search);

    final results = await Future.wait<Object>([
      getSummary(),
      listPayees(search: search),
      listRequests(),
      getSystemStatus(),
    ]);

    return BioPayAdminSnapshot(
      summary: results[0] as BioPayAdminSummary,
      payees: results[1] as List<BioPayAdminPayee>,
      requests: results[2] as List<BioPayUssdPaymentRequest>,
      systemStatus: results[3] as BioPayAdminSystemStatus,
    );
  }

  Future<BioPayAdminSummary> getSummary() async {
    if (supabase == null) return BioPayAdminSummary.preview();

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_admin_biopay_summary',
    );
    return BioPayAdminSummary.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<BioPayAdminPayee>> listPayees({
    String? search,
    int limit = 50,
  }) async {
    if (supabase == null) return previewSnapshot(search: search).payees;

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_admin_biopay_list_payees',
      params: {'p_search': _nullableText(search), 'p_limit': limit},
    );
    final rows = response is List ? response : const [];
    return rows.whereType<Map<Object?, Object?>>().map((row) {
      return BioPayAdminPayee.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<List<BioPayUssdPaymentRequest>> listRequests({int limit = 50}) async {
    if (supabase == null) return previewSnapshot().requests;

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_admin_biopay_list_requests',
      params: {'p_limit': limit},
    );
    final rows = response is List ? response : const [];
    return rows.whereType<Map<Object?, Object?>>().map((row) {
      return BioPayUssdPaymentRequest.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<BioPayAdminSystemStatus> getSystemStatus() async {
    if (supabase == null) return BioPayAdminSystemStatus.preview();

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_admin_biopay_system_status',
    );
    final databaseStatus = BioPayAdminSystemStatus.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    try {
      final faceStatus = await faceService.health();
      final providerReady = faceStatus.productionReady;
      return databaseStatus.copyWith(
        overallStatus: providerReady
            ? databaseStatus.overallStatus
            : 'configuration_required',
        faceProvider: faceStatus.provider,
        faceProviderReady: providerReady,
        collectionId: faceStatus.providerCollectionId.isEmpty
            ? databaseStatus.collectionId
            : faceStatus.providerCollectionId,
        ussdHandoffStatus: faceStatus.paymentBoundary.isEmpty
            ? databaseStatus.ussdHandoffStatus
            : 'external_ussd_only',
      );
    } on Object {
      return databaseStatus.copyWith(
        overallStatus: 'configuration_required',
        faceProvider: 'unreachable',
        faceProviderReady: false,
      );
    }
  }

  Future<BioPayUssdPaymentRequest> confirmRequestExternally({
    required BioPayUssdPaymentRequest request,
    required String confirmationSource,
  }) async {
    if (supabase == null || request.id.startsWith('preview-')) {
      return request.copyWith(
        status: BioPayRequestStatus.confirmed,
        confirmedAt: DateTime.now(),
        confirmationSource: confirmationSource,
      );
    }

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_admin_biopay_confirm_external',
      params: {
        'p_request_id': request.id,
        'p_confirmation_source': confirmationSource,
      },
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  BioPayAdminSnapshot previewSnapshot({String? search}) {
    final now = DateTime.now();
    final payees = [
      BioPayAdminPayee.preview(
        userId: 'preview-payee-1',
        handle: 'BP-882931',
        displayName: 'BioPay merchant',
        requestCount: 32,
        confirmedCount: 28,
        lastRequestAt: now.subtract(const Duration(minutes: 12)),
      ),
      BioPayAdminPayee.preview(
        userId: 'preview-payee-2',
        handle: 'BP-104277',
        displayName: 'Kigali driver',
        requestCount: 18,
        confirmedCount: 14,
        lastRequestAt: now.subtract(const Duration(hours: 2)),
      ),
      BioPayAdminPayee.preview(
        userId: 'preview-payee-3',
        handle: 'BP-510044',
        displayName: 'MOBI partner',
        requestCount: 9,
        confirmedCount: 7,
        lastRequestAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    final normalizedSearch = search?.trim().toLowerCase();
    final filteredPayees = normalizedSearch == null || normalizedSearch.isEmpty
        ? payees
        : payees.where((payee) {
            return payee.handle.toLowerCase().contains(normalizedSearch) ||
                payee.displayName.toLowerCase().contains(normalizedSearch);
          }).toList();

    return BioPayAdminSnapshot(
      summary: BioPayAdminSummary.preview(),
      payees: filteredPayees,
      requests: [
        BioPayUssdPaymentRequest(
          id: 'preview-admin-1',
          token: 'mobio-biopay-preview-admin-1',
          channel: BioPayRequestChannel.face,
          providerCode: 'mtn_rw',
          payeeLabel: 'BioPay merchant',
          amountMinor: 250000,
          currency: 'RWF',
          reference: 'BP-ADMIN-1',
          ussdCode: '*182*8*1*250788000000*2500#',
          status: BioPayRequestStatus.userMarkedPaid,
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        BioPayUssdPaymentRequest(
          id: 'preview-admin-2',
          token: 'mobio-biopay-preview-admin-2',
          channel: BioPayRequestChannel.qr,
          providerCode: 'mtn_rw',
          payeeLabel: 'Kigali driver',
          amountMinor: 120000,
          currency: 'RWF',
          reference: 'BP-ADMIN-2',
          ussdCode: '*182*8*1*250788000001*1200#',
          status: BioPayRequestStatus.confirmed,
          confirmationSource: 'operator_external_reference',
          confirmedAt: now.subtract(const Duration(minutes: 22)),
          createdAt: now.subtract(const Duration(minutes: 30)),
        ),
      ],
      systemStatus: BioPayAdminSystemStatus.preview(),
    );
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  SupabaseClient _requireSupabase() {
    final client = supabase;
    if (client == null) {
      throw StateError('Supabase is required for BioPay admin operations.');
    }
    return client;
  }
}
