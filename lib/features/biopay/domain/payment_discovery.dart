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

/// Strict JSON primitives shared by authoritative discovery projections.
/// Missing booleans and fractional versions must never become capabilities.
class PaymentWire {
  PaymentWire._();
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid payment record');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> rows(Object? value) {
    if (value is! List) throw const FormatException('Invalid payment list');
    return value.map(object).toList(growable: false);
  }

  static String text(
    Map<String, dynamic> json,
    String key, {
    bool empty = false,
  }) {
    final value = json[key];
    if (value is! String || (!empty && value.trim().isEmpty)) {
      throw FormatException('Invalid payment field: $key');
    }
    return value;
  }

  static String? optionalText(Map<String, dynamic> json, String key) =>
      json[key] == null ? null : text(json, key, empty: true);

  static bool boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('Invalid payment flag: $key');
    return value;
  }

  static int integer(Map<String, dynamic> json, String key, {int min = 0}) {
    final value = json[key];
    if (value is! int || value < min || value > 2147483647) {
      throw FormatException('Invalid payment integer: $key');
    }
    return value;
  }

  static DateTime timestamp(Map<String, dynamic> json, String key) {
    final value = DateTime.tryParse(text(json, key));
    if (value == null) throw FormatException('Invalid payment date: $key');
    return value;
  }

  static String choice(
    Map<String, dynamic> json,
    String key,
    Iterable<String> allowed,
  ) {
    final value = text(json, key);
    if (!allowed.contains(value)) {
      throw FormatException('Invalid payment state: $key');
    }
    return value;
  }

  static bool sameValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) => right.containsKey(key) && sameValue(left[key], right[key]),
          );
    }
    if (left is List && right is List) {
      return left.length == right.length &&
          List.generate(
            left.length,
            (index) => index,
          ).every((index) => sameValue(left[index], right[index]));
    }
    return left == right;
  }
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

/// History can contain legacy minor amounts with fractional RWF. Preserve the
/// integer evidence exactly; new discovery preparation still requires whole RWF.
String formatHistoricalRwfMinor(int minor) =>
    formatHistoricalAmountMinor(minor, 'RWF');

String formatHistoricalAmountMinor(int minor, String currency) {
  if (minor < 0 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency))
    throw const FormatException('Invalid historical amount or currency');
  final remainder = minor % 100;
  return '${minor ~/ 100}${remainder == 0 ? '' : '.${remainder.toString().padLeft(2, '0')}'} $currency';
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

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      PaymentMethod._parse(json, receivingProjection: false);

  /// The server receiving projection intentionally omits private source roles,
  /// login phone, SIM and preferences. It cannot grant sending capabilities.
  factory PaymentMethod.fromReceivingJson(Map<String, dynamic> json) =>
      PaymentMethod._parse(json, receivingProjection: true);

  static PaymentMethod _parse(
    Map<String, dynamic> json, {
    required bool receivingProjection,
  }) {
    final id = PaymentWire.text(json, 'id');
    final manual = id == 'manual';
    final owner = PaymentWire.text(json, 'owner_id', empty: manual);
    final provider = PaymentWire.text(json, 'provider');
    final kind = PaymentMethodKind.values.byName(
      PaymentWire.choice(
        json,
        'kind',
        PaymentMethodKind.values.map((value) => value.name),
      ),
    );
    final method = PaymentMethod(
      id: id,
      ownerId: owner,
      provider: provider,
      kind: kind,
      identifier: PaymentWire.text(json, 'identifier'),
      label: PaymentWire.text(json, 'label'),
      canSend: receivingProjection
          ? false
          : PaymentWire.boolean(json, 'can_send'),
      canReceive: PaymentWire.boolean(json, 'can_receive'),
      phoneDiscoverable: receivingProjection
          ? false
          : PaymentWire.boolean(json, 'phone_discoverable'),
      loginPhone: receivingProjection
          ? null
          : PaymentWire.optionalText(json, 'login_phone'),
      simLabel: receivingProjection
          ? null
          : PaymentWire.optionalText(json, 'sim_label'),
      preferred: receivingProjection
          ? false
          : PaymentWire.boolean(json, 'preferred'),
      version: PaymentWire.integer(json, 'version', min: manual ? 0 : 1),
      active: PaymentWire.boolean(json, 'active'),
    );
    if (!RegExp(r'^[a-z0-9_]{2,32}$').hasMatch(provider) ||
        method.label.length > 60 ||
        method.identifier.length < 3 ||
        method.identifier.length > 40 ||
        (manual &&
            (owner.isNotEmpty ||
                method.version != 0 ||
                !method.canReceive ||
                method.canSend)) ||
        (kind == PaymentMethodKind.mobileWallet &&
            !RegExp(r'^\+2507[0-9]{8}$').hasMatch(method.identifier)) ||
        (kind == PaymentMethodKind.merchantCode &&
            (!RegExp(r'^[0-9]{3,20}$').hasMatch(method.identifier) ||
                method.canSend)) ||
        ((kind == PaymentMethodKind.bankAccount ||
                kind == PaymentMethodKind.bankAlias) &&
            !RegExp(r'^[A-Za-z0-9 -]{3,40}$').hasMatch(method.identifier)) ||
        (method.loginPhone != null &&
            !RegExp(r'^\+2507[0-9]{8}$').hasMatch(method.loginPhone!)) ||
        (method.simLabel?.length ?? 0) > 40 ||
        (!receivingProjection &&
            (!method.canSend && !method.canReceive ||
                method.preferred && !method.canSend ||
                method.phoneDiscoverable && !method.canReceive))) {
      throw const FormatException('Invalid payment method');
    }
    return method;
  }

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

  factory PaymentFee.fromJson(Map<String, dynamic> json) {
    final certainty = FeeCertainty.values.byName(
      PaymentWire.choice(
        json,
        'certainty',
        FeeCertainty.values.map((value) => value.name),
      ),
    );
    final francs = json['francs'] == null
        ? null
        : PaymentWire.integer(json, 'francs');
    if (certainty != FeeCertainty.unknown && francs == null) {
      throw const FormatException('Known payment fee needs whole francs');
    }
    return PaymentFee(
      certainty: certainty,
      francs: francs,
      allIn: PaymentWire.boolean(json, 'all_in'),
    );
  }

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
    id: PaymentWire.text(json, 'id'),
    source: PaymentMethod.fromJson(PaymentWire.object(json['source'])),
    destination: PaymentMethod.fromReceivingJson(
      PaymentWire.object(json['destination']),
    ),
    rail: PaymentWire.text(json, 'rail'),
    fee: PaymentFee.fromJson(PaymentWire.object(json['fee'])),
    adapterVersion: PaymentWire.integer(json, 'adapter_version', min: 1),
    tariffVersion: PaymentWire.integer(json, 'tariff_version', min: 1),
    steps: json['steps'] == null
        ? null
        : PaymentWire.integer(json, 'steps', min: 1),
    supportsReference: PaymentWire.boolean(json, 'supports_reference'),
    handoffMode: PaymentWire.choice(json, 'handoff_mode', const [
      'instructions',
      'dial',
    ]),
    unavailableReason: PaymentWire.optionalText(json, 'unavailable_reason'),
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
        label: PaymentWire.text(json, 'label'),
        methods: PaymentWire.rows(
          json['methods'],
        ).map(PaymentMethod.fromReceivingJson).toList(growable: false),
        assurance: PaymentWire.choice(json, 'assurance', const [
          'manual',
          'shared',
          'sharedLink',
        ]),
        lookup: PaymentWire.optionalText(json, 'lookup'),
        linkToken: PaymentWire.optionalText(json, 'link_token'),
        fixedAmount: json['fixed_amount'] == null ? null : _fixedAmount(json),
        reference: json['reference'] == null
            ? ''
            : PaymentWire.text(json, 'reference', empty: true),
        purpose: json['purpose'] == null
            ? null
            : PaymentPurpose.values.byName(
                PaymentWire.choice(
                  json,
                  'purpose',
                  PaymentPurpose.values.map((value) => value.name),
                ),
              ),
      );

  static int _fixedAmount(Map<String, dynamic> json) {
    final amount = PaymentWire.integer(json, 'fixed_amount', min: 1);
    if (amount > 10000000) {
      throw const FormatException('Invalid recipient amount');
    }
    return amount;
  }
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

  factory PaymentDraft.fromJson(Map<String, dynamic> json) {
    String text(String field, {bool emptyAllowed = false}) {
      final value = json[field];
      if (value is! String || (!emptyAllowed && value.isEmpty)) {
        throw FormatException('Invalid payment draft field: $field');
      }
      return value;
    }

    String? optionalText(String field) {
      final value = json[field];
      if (value == null) return null;
      return text(field);
    }

    final revision = json['revision'];
    if (revision is! int || revision < 0 || revision > 2147483647) {
      throw const FormatException('Invalid payment draft revision');
    }
    final purpose = text('purpose');
    final evidence = text('evidence');
    if (!PaymentPurpose.values.any((value) => value.name == purpose) ||
        !PaymentEvidence.values.any((value) => value.name == evidence)) {
      throw const FormatException('Invalid payment draft state');
    }
    final method = json['manual_method'];
    if (method != null &&
        (method is! Map || method.keys.any((key) => key is! String))) {
      throw const FormatException('Invalid manual payment method');
    }
    return PaymentDraft(
      id: text('id'),
      ownerId: text('owner_id'),
      lookup: text('lookup', emptyAllowed: true),
      linkToken: optionalText('link_token'),
      manualMethod: method == null
          ? null
          : PaymentMethod.fromJson(Map<String, dynamic>.from(method as Map)),
      amount: text('amount', emptyAllowed: true),
      purpose: PaymentPurpose.values.byName(purpose),
      sourceId: optionalText('source_id'),
      reference: text('reference', emptyAllowed: true),
      revision: revision,
      evidence: PaymentEvidence.values.byName(evidence),
      attemptId: optionalText('attempt_id'),
    );
  }

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
