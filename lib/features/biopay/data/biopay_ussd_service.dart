import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BioPayUssdService {
  BioPayUssdService({this.supabase});

  final SupabaseClient? supabase;
  static const defaultInsuranceAgentWhatsapp = '+250795588248';

  Future<BioPayUssdPaymentRequest> createPaymentRequest({
    required BioPayRequestChannel channel,
    required int amountMinor,
    required String payeeLabel,
    String providerCode = 'mtn_rw',
    String? payeePhone,
  }) async {
    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_create_biopay_ussd_request',
      params: {
        'p_channel': channel.wireName,
        'p_amount_minor': amountMinor,
        'p_payee_label': payeeLabel,
        'p_provider_code': providerCode,
        'p_payee_phone': payeePhone,
      },
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<BioPayUssdPaymentRequest> createFaceMatchPaymentRequest({
    required String providerFaceId,
    required int amountMinor,
    String providerCode = 'mtn_rw',
  }) async {
    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_create_biopay_face_match_request',
      params: {
        'p_provider_face_id': providerFaceId,
        'p_amount_minor': amountMinor,
        'p_provider_code': providerCode,
      },
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  BioPayUssdPaymentRequest createPreviewRequest({
    required BioPayRequestChannel channel,
    int amountMinor = 150000,
    String payeeLabel = 'BioPay merchant',
    String providerCode = 'mtn_rw',
    String payeePhone = '250788000000',
  }) {
    const reference = 'BP-DEMO';
    return BioPayUssdPaymentRequest(
      id: 'preview-$reference',
      token: 'mobio-biopay-preview-$reference',
      channel: channel,
      providerCode: providerCode,
      payeeLabel: payeeLabel,
      amountMinor: amountMinor,
      currency: 'RWF',
      reference: reference,
      ussdCode: buildPreviewUssdCode(
        providerCode: providerCode,
        payeePhone: payeePhone,
        amountMinor: amountMinor,
        reference: reference,
      ),
      status: BioPayRequestStatus.readyToDial,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      createdAt: DateTime.now(),
    );
  }

  String buildPreviewUssdCode({
    required String providerCode,
    required String payeePhone,
    required int amountMinor,
    required String reference,
  }) {
    final amountMajor = (amountMinor / 100).ceil();
    final normalizedPhone = payeePhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final receiver = normalizedPhone.isEmpty ? reference : normalizedPhone;
    if (providerCode == 'mtn_rw') {
      final isMomoPayCode = RegExp(r'^[0-9]{5,6}$').hasMatch(receiver);
      final menu = isMomoPayCode ? '*182*8*1' : '*182*1*1';
      if (amountMajor <= 0) return '$menu*$receiver#';
      return '$menu*$receiver*$amountMajor#';
    }
    if (amountMajor <= 0) return '*$providerCode*$receiver#';
    return '*$providerCode*$receiver*$amountMajor#';
  }

  BioPayUssdPaymentRequest resolvePreviewToken(String token) {
    return createPreviewRequest(
      channel: token.contains('nfc')
          ? BioPayRequestChannel.nfc
          : token.contains('face')
          ? BioPayRequestChannel.face
          : BioPayRequestChannel.qr,
    );
  }

  Future<BioPayUssdPaymentRequest> resolveRequest(String token) async {
    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_resolve_biopay_ussd_request',
      params: {'p_token': token},
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<BioPayUssdPaymentRequest> recordDialerOpened(
    BioPayUssdPaymentRequest request,
  ) async {
    if (supabase == null || request.id.startsWith('preview-')) {
      return request.copyWith(status: BioPayRequestStatus.dialerOpened);
    }

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_record_biopay_ussd_dialer_opened',
      params: {'p_request_id': request.id},
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<BioPayUssdPaymentRequest> markUserPaid(
    BioPayUssdPaymentRequest request,
  ) async {
    if (supabase == null || request.id.startsWith('preview-')) {
      return request.copyWith(status: BioPayRequestStatus.userMarkedPaid);
    }

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_mark_biopay_ussd_user_paid',
      params: {'p_request_id': request.id},
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<BioPayUssdPaymentRequest>> listPaymentRequests({
    int limit = 20,
  }) async {
    if (supabase == null) return previewActivityRequests();

    final response = await _requireSupabase().rpc<dynamic>(
      'rpc_list_biopay_ussd_requests',
      params: {'p_limit': limit},
    );
    final rows = response is List ? response : const [];
    return rows.whereType<Map<Object?, Object?>>().map((row) {
      return BioPayUssdPaymentRequest.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<BioPayUssdPaymentRequest> confirmExternally({
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
      'rpc_confirm_biopay_ussd_external',
      params: {
        'p_request_id': request.id,
        'p_confirmation_source': confirmationSource,
      },
    );

    return BioPayUssdPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  List<BioPayUssdPaymentRequest> previewActivityRequests() {
    final now = DateTime.now();
    return [
      createPreviewRequest(
        channel: BioPayRequestChannel.qr,
      ).copyWith(status: BioPayRequestStatus.userMarkedPaid),
      createPreviewRequest(
        channel: BioPayRequestChannel.nfc,
      ).copyWith(status: BioPayRequestStatus.dialerOpened),
      createPreviewRequest(channel: BioPayRequestChannel.face).copyWith(
        status: BioPayRequestStatus.confirmed,
        confirmedAt: now.subtract(const Duration(minutes: 4)),
        confirmationSource: 'operator_external_reference',
      ),
    ];
  }

  Future<BioPayUssdPaymentRequest?> openUssdDialer(
    BioPayUssdPaymentRequest request,
  ) async {
    final launched = await launchUssdCode(request.ussdCode);
    if (!launched) return null;

    try {
      return await recordDialerOpened(request);
    } on Object {
      return request.copyWith(status: BioPayRequestStatus.dialerOpened);
    }
  }

  @Deprecated(
    'Use the discovery prepare contract and explicit reviewed handoff.',
  )
  Future<bool> launchUssdCode(String ussdCode) async => false;

  Uri ussdTelUri(String ussdCode) {
    final encoded = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
    return Uri.parse('tel:$encoded');
  }

  Uri paymentRequestDialerUri(BioPayUssdPaymentRequest request) {
    return bioPayShareUri(request.token);
  }

  String paymentRequestShareText(
    BioPayUssdPaymentRequest request, {
    String? receiverLabel,
  }) {
    final amount = request.amountLabel;
    final ussdLink = paymentRequestDialerUri(request);
    final receiver = receiverLabel?.trim();
    final receiverText = receiver == null || receiver.isEmpty
        ? ''
        : ' Receiver: $receiver.';
    return 'Mobio payment request: $amount.$receiverText Review this Mobio payment request: $ussdLink';
  }

  Uri paymentRequestWhatsAppUri(
    BioPayUssdPaymentRequest request, {
    String? receiverLabel,
  }) {
    return Uri.https('wa.me', '/', {
      'text': paymentRequestShareText(request, receiverLabel: receiverLabel),
    });
  }

  Future<String> insuranceAgentWhatsapp() async {
    final client = supabase;
    if (client == null) return defaultInsuranceAgentWhatsapp;

    try {
      final response = await client.rpc<dynamic>(
        'rpc_get_public_app_setting',
        params: {
          'p_key': 'insurance_agent_whatsapp_e164',
          'p_fallback': defaultInsuranceAgentWhatsapp,
        },
      );
      final value = response?.toString().trim() ?? '';
      return value.isEmpty ? defaultInsuranceAgentWhatsapp : value;
    } on Object {
      return defaultInsuranceAgentWhatsapp;
    }
  }

  Uri insuranceAgentWhatsAppUri(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return Uri.https('wa.me', '/$digits', {
      'text':
          'Hello Mobio Insurance, I want motor insurance and the 3000 TOKEN reward.',
    });
  }

  Future<bool> openInsuranceAgentChat() async {
    final phone = await insuranceAgentWhatsapp();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    return launchUrl(
      insuranceAgentWhatsAppUri(phone),
      mode: LaunchMode.externalApplication,
    );
  }

  SupabaseClient _requireSupabase() {
    final client = supabase;
    if (client == null) {
      throw StateError(
        'Supabase is required for persisted BioPay USSD requests.',
      );
    }
    return client;
  }
}
