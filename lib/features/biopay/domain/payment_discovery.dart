/// Payment discovery values. RWF uses whole francs, never floating point.
/// These values describe an external handoff; they are not a payment ledger.
enum PaymentPurpose { transfer, merchant }

enum PaymentMethodKind { mobileWallet, merchantCode, bankAccount, bankAlias }

enum FeeCertainty { exact, capped, unknown }

enum PaymentEvidence {
  draft,
  prepared,
  handoffOpened,
  outcomeUnknown,
  userReported,
  receiverAcknowledged,
  operatorReviewed,
  providerConfirmed,
}

int? parseRwf(String value) {
  final text = value.trim();
  if (!RegExp(r'^[0-9]{1,8}$').hasMatch(text)) return null;
  final amount = int.tryParse(text);
  return amount != null && amount > 0 && amount <= 10000000 ? amount : null;
}

int legacyMinorFromRwf(int amount) {
  if (amount <= 0 || amount > 10000000) {
    throw const FormatException('Enter a positive whole-franc amount.');
  }
  return amount * 100;
}

int rwfFromLegacyMinor(int minor) {
  if (minor <= 0 || minor % 100 != 0) {
    throw const FormatException('This request has an unsupported amount.');
  }
  final amount = minor ~/ 100;
  legacyMinorFromRwf(amount);
  return amount;
}

String? normalizeRwandaPhone(String input) {
  if (!RegExp(r'^[+0-9 ()-]+$').hasMatch(input.trim())) return null;
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10 && digits.startsWith('0')) {
    digits = '250${digits.substring(1)}';
  } else if (digits.length == 9) {
    digits = '250$digits';
  }
  return RegExp(r'^2507[0-9]{8}$').hasMatch(digits) ? '+$digits' : null;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.ownerId,
    required this.provider,
    required this.kind,
    required this.identifier,
    required this.label,
    this.canSend = false,
    this.canReceive = true,
    this.phoneDiscoverable = false,
    this.loginPhone,
    this.simLabel,
    this.preferred = false,
    this.version = 1,
    this.active = true,
  });

  final String id;
  final String ownerId;
  final String provider;
  final PaymentMethodKind kind;
  final String identifier;
  final String label;
  final bool canSend;
  final bool canReceive;
  final bool phoneDiscoverable;
  final String? loginPhone;
  final String? simLabel;
  final bool preferred;
  final int version;
  final bool active;

  String get maskedIdentifier => identifier.length <= 4
      ? identifier
      : '•••• ${identifier.substring(identifier.length - 4)}';

  String? get validationError {
    if (label.trim().isEmpty || label.length > 60) return 'label';
    if (provider.isEmpty) return 'provider';
    if (!canSend && !canReceive) return 'role';
    if (kind == PaymentMethodKind.mobileWallet &&
        normalizeRwandaPhone(identifier) == null) {
      return 'phone';
    }
    if (kind == PaymentMethodKind.merchantCode &&
        !RegExp(r'^[0-9]{3,20}$').hasMatch(identifier)) {
      return 'merchant';
    }
    if ((kind == PaymentMethodKind.bankAccount ||
            kind == PaymentMethodKind.bankAlias) &&
        !RegExp(r'^[A-Za-z0-9 -]{3,40}$').hasMatch(identifier)) {
      return 'account';
    }
    if (loginPhone != null &&
        loginPhone!.isNotEmpty &&
        normalizeRwandaPhone(loginPhone!) == null) {
      return 'loginPhone';
    }
    return null;
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String? ?? '',
    provider: json['provider'] as String,
    kind: PaymentMethodKind.values.byName(json['kind'] as String),
    identifier: json['identifier'] as String,
    label: json['label'] as String,
    canSend: json['can_send'] == true,
    canReceive: json['can_receive'] == true,
    phoneDiscoverable: json['phone_discoverable'] == true,
    loginPhone: json['login_phone'] as String?,
    simLabel: json['sim_label'] as String?,
    preferred: json['preferred'] == true,
    version: (json['version'] as num?)?.toInt() ?? 1,
    active: json['active'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'provider': provider,
    'kind': kind.name,
    'identifier': identifier,
    'label': label,
    'can_send': canSend,
    'can_receive': canReceive,
    'phone_discoverable': phoneDiscoverable,
    'login_phone': loginPhone,
    'sim_label': simLabel,
    'preferred': preferred,
    'version': version,
    'active': active,
  };
}

class PaymentFee {
  const PaymentFee({required this.certainty, this.francs, this.allIn = false});

  final FeeCertainty certainty;
  final int? francs;
  final bool allIn;

  int? get upperBound =>
      allIn && certainty != FeeCertainty.unknown && (francs ?? -1) >= 0
      ? francs
      : null;

  int? totalUpperBound(int amount) =>
      upperBound == null ? null : amount + upperBound!;

  factory PaymentFee.fromJson(Map<String, dynamic> json) => PaymentFee(
    certainty: FeeCertainty.values.byName(json['certainty'] as String),
    francs: (json['francs'] as num?)?.toInt(),
    allIn: json['all_in'] == true,
  );

  Map<String, dynamic> toJson() => {
    'certainty': certainty.name,
    'francs': francs,
    'all_in': allIn,
  };
}

class PaymentOption {
  const PaymentOption({
    required this.id,
    required this.source,
    required this.destination,
    required this.rail,
    required this.fee,
    required this.adapterVersion,
    required this.tariffVersion,
    this.steps,
    this.supportsReference = false,
    this.handoffMode = 'instructions',
    this.unavailableReason,
  });

  final String id;
  final PaymentMethod source;
  final PaymentMethod destination;
  final String rail;
  final PaymentFee fee;
  final int adapterVersion;
  final int tariffVersion;
  final int? steps;
  final bool supportsReference;
  final String handoffMode;
  final String? unavailableReason;

  String get routeKey =>
      '${source.provider}:${source.kind.name}:${source.identifier}|'
      '${destination.provider}:${destination.kind.name}:'
      '${destination.identifier}|$rail';

  factory PaymentOption.fromJson(Map<String, dynamic> json) => PaymentOption(
    id: json['id'] as String,
    source: PaymentMethod.fromJson(json['source'] as Map<String, dynamic>),
    destination: PaymentMethod.fromJson(
      json['destination'] as Map<String, dynamic>,
    ),
    rail: json['rail'] as String,
    fee: PaymentFee.fromJson(json['fee'] as Map<String, dynamic>),
    adapterVersion: (json['adapter_version'] as num).toInt(),
    tariffVersion: (json['tariff_version'] as num).toInt(),
    steps: (json['steps'] as num?)?.toInt(),
    supportsReference: json['supports_reference'] == true,
    handoffMode: json['handoff_mode'] as String? ?? 'instructions',
    unavailableReason: json['unavailable_reason'] as String?,
  );
}

/// Sort only already eligible options. The server remains the authority at
/// prepare. Equal caps are equal upper bounds, not equal actual fees.
List<PaymentOption> rankPaymentOptions(Iterable<PaymentOption> options) {
  final sorted = options.where((o) => o.unavailableReason == null).toList()
    ..sort((a, b) {
      final left = a.fee.upperBound;
      final right = b.fee.upperBound;
      if (left != right) {
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      }
      // Steps only resolve equal known exact fees. Capped/unknown totals
      // cannot justify claiming that a fewer-step option is cheaper.
      if (left != null &&
          a.fee.certainty == FeeCertainty.exact &&
          b.fee.certainty == FeeCertainty.exact &&
          a.steps != null &&
          b.steps != null) {
        final steps = a.steps!.compareTo(b.steps!);
        if (steps != 0) return steps;
      }
      return a.id.compareTo(b.id);
    });
  final seen = <String>{};
  return sorted.where((o) => seen.add(o.routeKey)).toList();
}

class PaymentRecipient {
  const PaymentRecipient({
    required this.label,
    required this.methods,
    required this.assurance,
    this.lookup,
    this.linkToken,
    this.fixedAmount,
    this.purpose,
    this.reference = '',
  });

  final String label;
  final List<PaymentMethod> methods;
  final String assurance;
  final String? lookup;
  final String? linkToken;
  final int? fixedAmount;
  final PaymentPurpose? purpose;
  final String reference;

  factory PaymentRecipient.fromJson(Map<String, dynamic> json) =>
      PaymentRecipient(
        label: json['label'] as String? ?? '',
        methods: (json['methods'] as List? ?? const [])
            .map(
              (x) =>
                  PaymentMethod.fromJson(Map<String, dynamic>.from(x as Map)),
            )
            .toList(),
        assurance: json['assurance'] as String? ?? 'unverified',
        lookup: json['lookup'] as String?,
        linkToken: json['link_token'] as String?,
        fixedAmount: (json['fixed_amount'] as num?)?.toInt(),
        reference: json['reference'] as String? ?? '',
        purpose: json['purpose'] == null
            ? null
            : PaymentPurpose.values.byName(json['purpose'] as String),
      );
}

class PaymentDraft {
  const PaymentDraft({
    required this.id,
    required this.ownerId,
    this.lookup = '',
    this.linkToken,
    this.manualMethod,
    this.amount = '',
    this.purpose = PaymentPurpose.transfer,
    this.sourceId,
    this.reference = '',
    this.revision = 0,
    this.evidence = PaymentEvidence.draft,
    this.attemptId,
  });

  final String id;
  final String ownerId;
  final String lookup;
  final String? linkToken;
  final PaymentMethod? manualMethod;
  final String amount;
  final PaymentPurpose purpose;
  final String? sourceId;
  final String reference;
  final int revision;
  final PaymentEvidence evidence;
  final String? attemptId;

  PaymentDraft copyWith({
    String? lookup,
    String? linkToken,
    PaymentMethod? manualMethod,
    String? amount,
    PaymentPurpose? purpose,
    String? sourceId,
    String? reference,
    PaymentEvidence? evidence,
    String? attemptId,
    bool clearRecipient = false,
  }) => PaymentDraft(
    id: id,
    ownerId: ownerId,
    lookup: lookup ?? this.lookup,
    linkToken: linkToken ?? (clearRecipient ? null : this.linkToken),
    manualMethod: manualMethod ?? (clearRecipient ? null : this.manualMethod),
    amount: amount ?? this.amount,
    purpose: purpose ?? this.purpose,
    sourceId: sourceId ?? this.sourceId,
    reference: reference ?? this.reference,
    revision: revision + 1,
    evidence: evidence ?? PaymentEvidence.draft,
    attemptId: attemptId ?? (evidence == null ? null : this.attemptId),
  );

  factory PaymentDraft.fromJson(Map<String, dynamic> json) => PaymentDraft(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    lookup: json['lookup'] as String? ?? '',
    linkToken: json['link_token'] as String?,
    manualMethod: json['manual_method'] == null
        ? null
        : PaymentMethod.fromJson(json['manual_method'] as Map<String, dynamic>),
    amount: json['amount'] as String? ?? '',
    purpose: PaymentPurpose.values.byName(
      json['purpose'] as String? ?? 'transfer',
    ),
    sourceId: json['source_id'] as String?,
    reference: json['reference'] as String? ?? '',
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    evidence: PaymentEvidence.values.byName(
      json['evidence'] as String? ?? 'draft',
    ),
    attemptId: json['attempt_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'lookup': lookup,
    'link_token': linkToken,
    'manual_method': manualMethod?.toJson(),
    'amount': amount,
    'purpose': purpose.name,
    'source_id': sourceId,
    'reference': reference,
    'revision': revision,
    'evidence': evidence.name,
    'attempt_id': attemptId,
  };
}
