import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
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
    final response = await RequestDeadline.mutation(
      _requireSupabase().rpc<dynamic>(
        'rpc_create_biopay_ussd_request',
        params: {
          'p_channel': channel.wireName,
          'p_amount_minor': amountMinor,
          'p_payee_label': payeeLabel,
          'p_provider_code': providerCode,
          'p_payee_phone': payeePhone,
        },
      ),
      operation: 'rpc_create_biopay_ussd_request',
    );

    return _confirmResponse(
      response,
      operation: 'rpc_create_biopay_ussd_request',
      validate: (request) {
        final normalizedLabel = payeeLabel.trim().isEmpty
            ? 'BioPay merchant'
            : payeeLabel.trim();
        final normalizedProvider = providerCode.trim().isEmpty
            ? 'mtn_rw'
            : providerCode.trim();
        if (request.status != BioPayRequestStatus.readyToDial ||
            request.channel != channel ||
            request.amountMinor != amountMinor ||
            request.payeeLabel != normalizedLabel ||
            request.providerCode != normalizedProvider) {
          throw const FormatException('Created BioPay request mismatch');
        }
      },
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
    final response = await RequestDeadline.read(
      _requireSupabase().rpc<dynamic>(
        'rpc_resolve_biopay_ussd_request',
        params: {'p_token': token},
      ),
    );

    return BioPayUssdPaymentRequest.fromResolvedJson(
      BioPayWireRecord.object(response),
      token: token,
    );
  }

  Future<BioPayUssdPaymentRequest> recordDialerOpened(
    BioPayUssdPaymentRequest request,
  ) async {
    if (supabase == null || request.id.startsWith('preview-')) {
      return request.copyWith(status: BioPayRequestStatus.dialerOpened);
    }

    final response = await RequestDeadline.mutation(
      _requireSupabase().rpc<dynamic>(
        'rpc_record_biopay_ussd_dialer_opened',
        params: {'p_request_id': request.id},
      ),
      operation: 'rpc_record_biopay_ussd_dialer_opened',
      operationId: request.id,
    );

    return _confirmResponse(
      response,
      operation: 'rpc_record_biopay_ussd_dialer_opened',
      operationId: request.id,
      validate: (confirmed) {
        if (confirmed.status != BioPayRequestStatus.dialerOpened ||
            !confirmed.hasSameInstruction(request)) {
          throw const FormatException('BioPay request receipt mismatch');
        }
      },
    );
  }

  Future<BioPayUssdPaymentRequest> markUserPaid(
    BioPayUssdPaymentRequest request,
  ) async {
    if (supabase == null || request.id.startsWith('preview-')) {
      return request.copyWith(status: BioPayRequestStatus.userMarkedPaid);
    }

    final response = await RequestDeadline.mutation(
      _requireSupabase().rpc<dynamic>(
        'rpc_mark_biopay_ussd_user_paid',
        params: {'p_request_id': request.id},
      ),
      operation: 'rpc_mark_biopay_ussd_user_paid',
      operationId: request.id,
    );

    return _confirmResponse(
      response,
      operation: 'rpc_mark_biopay_ussd_user_paid',
      operationId: request.id,
      validate: (confirmed) {
        if (confirmed.status != BioPayRequestStatus.userMarkedPaid ||
            !confirmed.hasSameInstruction(request)) {
          throw const FormatException('BioPay request receipt mismatch');
        }
      },
    );
  }

  Future<List<BioPayUssdPaymentRequest>> listPaymentRequests({
    int limit = 20,
  }) async {
    if (supabase == null) return previewActivityRequests();

    final response = await RequestDeadline.read(
      _requireSupabase().rpc<dynamic>(
        'rpc_list_biopay_ussd_requests',
        params: {'p_limit': limit},
      ),
    );
    if (response is! List) {
      throw const FormatException('Invalid BioPay request list');
    }
    return response.map((row) {
      if (row is! Map) {
        throw const FormatException('Invalid BioPay request row');
      }
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

    final response = await RequestDeadline.mutation(
      _requireSupabase().rpc<dynamic>(
        'rpc_confirm_biopay_ussd_external',
        params: {
          'p_request_id': request.id,
          'p_confirmation_source': confirmationSource,
        },
      ),
      operation: 'rpc_confirm_biopay_ussd_external',
      operationId: request.id,
    );

    return _confirmResponse(
      response,
      operation: 'rpc_confirm_biopay_ussd_external',
      operationId: request.id,
      validate: (confirmed) {
        if (confirmed.status != BioPayRequestStatus.confirmed ||
            confirmed.confirmationSource != confirmationSource.trim() ||
            !confirmed.hasSameInstruction(request)) {
          throw const FormatException('BioPay request receipt mismatch');
        }
      },
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

    return recordDialerOpened(request);
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
      final response = await RequestDeadline.read(
        client.rpc<dynamic>(
          'rpc_get_public_app_setting',
          params: {
            'p_key': 'insurance_agent_whatsapp_e164',
            'p_fallback': defaultInsuranceAgentWhatsapp,
          },
        ),
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
    return RequestDeadline.mutation(
      launchUrl(
        insuranceAgentWhatsAppUri(phone),
        mode: LaunchMode.externalApplication,
      ),
      operation: 'open_insurance_agent_whatsapp',
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

  BioPayUssdPaymentRequest _confirmResponse(
    Object? response, {
    required String operation,
    String? operationId,
    required void Function(BioPayUssdPaymentRequest) validate,
  }) {
    try {
      final request = BioPayUssdPaymentRequest.fromJson(
        BioPayWireRecord.object(response),
      );
      validate(request);
      return request;
    } on FormatException catch (error) {
      throw MutationOutcomeUnknownException(
        operation: operation,
        operationId: operationId,
        originalError: error,
        debugMessage: error.message,
      );
    }
  }
}
