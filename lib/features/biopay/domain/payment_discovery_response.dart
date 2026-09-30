import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';

/// Typed projections at the RPC boundary. Original rows remain available for
/// the existing UI, after validation; no status, role or money is fabricated.
class PaymentQuote {
  PaymentQuote.fromJson(Map<String, dynamic> json)
    : id = PaymentWire.text(json, 'quote_id'),
      expiresAt = PaymentWire.timestamp(json, 'expires_at'),
      revision = PaymentWire.integer(json, 'revision'),
      recipient = PaymentRecipient.fromJson(
        PaymentWire.object(json['recipient']),
      ),
      options = PaymentWire.rows(
        json['options'],
      ).map(PaymentOption.fromJson).toList(growable: false),
      sourceAvailability = PaymentWire.rows(json['source_availability']) {
    for (final option in options) {
      if (!option.source.active ||
          !option.source.canSend ||
          !option.destination.active ||
          !option.destination.canReceive) {
        throw const FormatException('Ineligible payment option');
      }
    }
    for (final row in sourceAvailability) {
      PaymentWire.text(row, 'id');
      if (row['reason'] != null) {
        PaymentWire.choice(row, 'reason', const [
          'notSending',
          'missingSim',
          'missingLogin',
          'noReviewedRoute',
        ]);
      }
    }
  }
  final String id;
  final DateTime expiresAt;
  final int revision;
  final PaymentRecipient recipient;
  final List<PaymentOption> options;
  final List<Map<String, dynamic>> sourceAvailability;
}

class PaymentPreparedInstruction {
  PaymentPreparedInstruction.fromJson(Map<String, dynamic> json)
    : attemptId = PaymentWire.text(json, 'attempt_id'),
      mode = PaymentWire.choice(json, 'mode', const ['dial', 'instructions']),
      instruction = PaymentWire.text(json, 'instruction') {
    PaymentWire.choice(json, 'evidence', const ['prepared']);
    PaymentWire.text(json, 'source_label');
    PaymentWire.optionalText(json, 'sim_label');
    if (mode == 'dial' && !RegExp(r'^\*[0-9*]+#$').hasMatch(instruction)) {
      throw const FormatException('Invalid dial instruction');
    }
  }
  final String attemptId;
  final String mode;
  final String instruction;
}

abstract final class PaymentDiscoveryResponse {
  static const reads = {'workspace', 'sharing', 'resolve'};
  static const emptyReceipts = {
    'remove_method',
    'grant',
    'delete_draft',
    'revoke_link',
    'save_recent',
    'remove_recent',
    'remove_template',
  };
  static const actions = {
    ...reads,
    ...emptyReceipts,
    'save_method',
    'save_draft',
    'quote',
    'prepare',
    'pay_again',
    'record_attempt',
    'acknowledge',
    'create_link',
    'save_template',
  };

  static void owner(String actual, String expected) {
    if (actual != expected) {
      throw const FormatException('Payment owner mismatch');
    }
  }

  static void correlate(
    Map<String, dynamic> result,
    Map<String, dynamic> input,
    String field,
  ) {
    if (input[field] != result[field]) {
      throw FormatException('Payment receipt mismatch: $field');
    }
  }

  static void validate(
    String action,
    Map<String, dynamic> row,
    Map<String, dynamic> input,
    String ownerId,
  ) {
    if (!actions.contains(action)) {
      throw const FormatException('Unknown discovery response');
    }
    if (emptyReceipts.contains(action)) {
      // These SQL branches deliberately return an empty JSON object.
      if (row.isNotEmpty) {
        throw const FormatException('Invalid empty payment receipt');
      }
      return;
    }
    switch (action) {
      case 'workspace':
        for (final method in PaymentWire.rows(
          row['methods'],
        ).map(PaymentMethod.fromJson)) {
          owner(method.ownerId, ownerId);
        }
        for (final draft in PaymentWire.rows(
          row['drafts'],
        ).map(PaymentDraft.fromJson)) {
          owner(draft.ownerId, ownerId);
        }
        for (final link in PaymentWire.rows(row['links'])) {
          validateLink(link, ownerId);
        }
        for (final recent in PaymentWire.rows(row['recents'])) {
          PaymentWire.text(recent, 'id');
          owner(PaymentWire.text(recent, 'owner_id'), ownerId);
          PaymentWire.text(recent, 'lookup');
          PaymentWire.text(recent, 'nickname');
          PaymentWire.boolean(recent, 'favorite');
          PaymentWire.timestamp(recent, 'updated_at');
        }
        for (final template in PaymentWire.rows(row['templates'])) {
          validateTemplate(template, ownerId);
        }
        for (final activity in PaymentWire.rows(row['activity'])) {
          PaymentWire.text(activity, 'id');
          final payer = PaymentWire.optionalText(activity, 'payer_id');
          final payee = PaymentWire.optionalText(activity, 'payee_id');
          if (payer != ownerId && payee != ownerId) {
            throw const FormatException('Payment activity owner mismatch');
          }
          PaymentWire.text(activity, 'payee_label');
          PaymentWire.integer(activity, 'amount_minor');
          if (!RegExp(
            r'^[A-Z]{3}$',
          ).hasMatch(PaymentWire.text(activity, 'currency')))
            throw const FormatException('Invalid historical currency');
          PaymentWire.timestamp(activity, 'updated_at');
          PaymentWire.choice(activity, 'evidence_kind', [
            'unclassified',
            ...PaymentEvidence.values.map((value) => value.name),
          ]);
          if (activity['reviewed_snapshot'] != null) {
            final snapshot = PaymentWire.object(activity['reviewed_snapshot']);
            if (snapshot['source'] != null) {
              PaymentWire.text(PaymentWire.object(snapshot['source']), 'label');
            }
          }
        }
      case 'save_method':
        final method = PaymentMethod.fromJson(row);
        owner(method.ownerId, ownerId);
        if ((input['id'] as String?)?.isNotEmpty == true)
          correlate(row, input, 'id');
        if (row['label'] != PaymentWire.text(input, 'label').trim() ||
            row['identifier'] != PaymentWire.text(input, 'identifier').trim())
          throw const FormatException('Method label or identifier mismatch');
        for (final key in ['login_phone', 'sim_label']) {
          final expected = input[key] == '' ? null : input[key];
          if (row[key] != expected)
            throw FormatException('Method receipt mismatch: $key');
        }
        if ((input['id'] as String?)?.isNotEmpty != true &&
            (method.version != 1 || !method.active))
          throw const FormatException('New method receipt mismatch');
        for (final key in [
          'provider',
          'kind',
          'can_send',
          'can_receive',
          'phone_discoverable',
          'preferred',
        ]) {
          correlate(row, input, key);
        }
        if ((input['id'] as String?)?.isNotEmpty == true &&
            method.version != PaymentWire.integer(input, 'version') + 1) {
          throw const FormatException('Payment method version mismatch');
        }
      case 'sharing':
        final method = PaymentMethod.fromReceivingJson(
          PaymentWire.object(row['method']),
        );
        owner(method.ownerId, ownerId);
        if (method.id != input['id']) {
          throw const FormatException('Payment sharing method mismatch');
        }
        PaymentWire.boolean(row, 'phone_discoverable');
        for (final grant in PaymentWire.rows(row['grants'])) {
          if (!RegExp(
            r'^[0-9]{6}$',
          ).hasMatch(PaymentWire.text(grant, 'member_id'))) {
            throw const FormatException('Invalid sharing member ID');
          }
          PaymentWire.timestamp(grant, 'created_at');
        }
        for (final link in PaymentWire.rows(row['links'])) {
          PaymentWire.text(link, 'id');
          PaymentWire.text(link, 'label');
          PaymentWire.timestamp(link, 'expires_at');
          if (link['revoked_at'] != null) {
            PaymentWire.timestamp(link, 'revoked_at');
          }
        }
      case 'resolve':
        PaymentRecipient.fromJson(row);
      case 'save_draft':
      case 'pay_again':
        final draft = PaymentDraft.fromJson(row);
        owner(draft.ownerId, ownerId);
        if (action == 'pay_again' &&
            (draft.revision != 0 ||
                draft.evidence != PaymentEvidence.draft ||
                draft.attemptId != null))
          throw const FormatException('New draft receipt mismatch');
        if (action == 'save_draft') {
          for (final key in input.keys) {
            if (!PaymentWire.sameValue(row[key], input[key])) {
              throw FormatException('Draft receipt mismatch: $key');
            }
          }
        }
      case 'quote':
        final quote = PaymentQuote.fromJson(row);
        if (quote.revision != input['revision']) {
          throw const FormatException('Quote revision mismatch');
        }
        for (final option in quote.options) {
          owner(option.source.ownerId, ownerId);
        }
      case 'prepare':
        PaymentPreparedInstruction.fromJson(row);
      case 'record_attempt':
        final evidence = PaymentWire.choice(row, 'evidence', const [
          'handoffOpened',
          'outcomeUnknown',
          'userReported',
          'receiverAcknowledged',
          'operatorReviewed',
          'providerConfirmed',
        ]);
        if (evidence != input['evidence'] &&
            !const [
              'userReported',
              'receiverAcknowledged',
              'operatorReviewed',
              'providerConfirmed',
            ].contains(evidence))
          throw const FormatException('Attempt evidence mismatch');
      case 'acknowledge':
        PaymentWire.choice(row, 'evidence', const [
          'receiverAcknowledged',
          'operatorReviewed',
          'providerConfirmed',
        ]);
      case 'create_link':
        validateLink(row, ownerId);
        if (row['version'] != 1 ||
            row['revoked_at'] != null ||
            row['label'] != PaymentWire.text(input, 'label').trim() ||
            row['reference'] != (input['reference'] ?? '') ||
            PaymentWire.timestamp(row, 'expires_at') !=
                PaymentWire.timestamp(input, 'expires_at'))
          throw const FormatException('New link receipt mismatch');
        for (final key in ['scope', 'amount_rwf', 'purpose']) {
          correlate(row, input, key);
        }
        final expected = (input['method_ids'] as List).toSet();
        final actual = (row['method_ids'] as List).toSet();
        if (expected.length != actual.length || !expected.containsAll(actual)) {
          throw const FormatException('Link methods mismatch');
        }
      case 'save_template':
        validateTemplate(row, ownerId);
        if (row['label'] != input['label'] ||
            !PaymentWire.sameValue(row['data'], input['data']))
          throw const FormatException('Template receipt mismatch');
      default:
        throw const FormatException('Unsupported payment response');
    }
  }

  static void validateLink(Map<String, dynamic> row, String ownerId) {
    PaymentWire.text(row, 'id');
    owner(PaymentWire.text(row, 'owner_id'), ownerId);
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(PaymentWire.text(row, 'token'))) {
      throw const FormatException('Invalid payment link token');
    }
    PaymentWire.text(row, 'label');
    PaymentWire.choice(row, 'scope', const ['profile', 'method', 'request']);
    PaymentWire.choice(
      row,
      'purpose',
      PaymentPurpose.values.map((value) => value.name),
    );
    PaymentWire.text(row, 'reference', empty: true);
    amount(row, 'amount_rwf');
    PaymentWire.integer(row, 'version', min: 1);
    PaymentWire.timestamp(row, 'created_at');
    PaymentWire.timestamp(row, 'expires_at');
    if (row['revoked_at'] != null) PaymentWire.timestamp(row, 'revoked_at');
    final methods = row['method_ids'];
    if (methods is! List ||
        methods.isEmpty ||
        methods.any((id) => id is! String || id.isEmpty) ||
        methods.toSet().length != methods.length) {
      throw const FormatException('Invalid link methods');
    }
    final versions = PaymentWire.object(row['method_versions']);
    for (final id in methods.cast<String>()) {
      PaymentWire.integer(versions, id, min: 1);
    }
  }

  static void validateTemplate(Map<String, dynamic> row, String ownerId) {
    PaymentWire.text(row, 'id');
    owner(PaymentWire.text(row, 'owner_id'), ownerId);
    PaymentWire.text(row, 'label');
    PaymentWire.object(row['data']);
    PaymentWire.timestamp(row, 'created_at');
  }

  static void amount(Map<String, dynamic> row, String key) {
    if (row[key] != null && PaymentWire.integer(row, key, min: 1) > 10000000) {
      throw const FormatException('Invalid whole RWF amount');
    }
  }

  static void preview(Map<String, dynamic> row) {
    if (!PaymentWire.boolean(row, 'available')) return;
    PaymentWire.text(row, 'label');
    final scope = PaymentWire.choice(row, 'scope', const [
      'legacy',
      'profile',
      'method',
      'request',
    ]);
    amount(row, 'amount_rwf');
    PaymentWire.timestamp(row, 'expires_at');
    if (scope != 'legacy') {
      PaymentWire.choice(
        row,
        'purpose',
        PaymentPurpose.values.map((value) => value.name),
      );
    }
  }

  static void admin(
    String action,
    Map<String, dynamic> row,
    Map<String, dynamic> input,
  ) {
    if (action == 'list') {
      for (final route in PaymentWire.rows(row['routes'])) {
        routeRecord(route);
      }
      for (final evidence in PaymentWire.rows(row['evidence'])) {
        PaymentWire.text(evidence, 'provider');
        PaymentWire.text(evidence, 'name');
        PaymentWire.text(evidence, 'evidence_state');
        PaymentWire.timestamp(evidence, 'reviewed_on');
        PaymentWire.optionalText(evidence, 'published_root');
        PaymentWire.optionalText(evidence, 'source_url');
      }
      return;
    }
    routeRecord(row);
    if (input['id'] != null) correlate(row, input, 'id');
    final expected = switch (action) {
      'save' => 'draft',
      'tested' => 'tested',
      'approve' => 'approved',
      'disable' => 'disabled',
      _ => throw const FormatException('Invalid route action'),
    };
    if (row['state'] != expected) {
      throw const FormatException('Route receipt state mismatch');
    }
    final previousVersion = input['id'] == null
        ? 0
        : PaymentWire.integer(input, 'adapter_version', min: 1);
    final expectedVersion = switch (action) {
      'save' || 'disable' => previousVersion + 1,
      _ => previousVersion,
    };
    if (row['adapter_version'] != expectedVersion) {
      throw const FormatException('Route receipt version mismatch');
    }
    if (action == 'save') {
      for (final field in [
        'source_provider',
        'source_kind',
        'destination_provider',
        'destination_kind',
        'rail',
        'purpose',
        'min_rwf',
        'max_rwf',
        'fee_certainty',
        'fee_rwf',
        'steps',
        'handoff_mode',
        'device_families',
        'evidence_url',
        'tariff_evidence_url',
        'test_evidence_url',
      ]) {
        if (!PaymentWire.sameValue(row[field], input[field])) {
          throw FormatException('Route receipt mismatch: $field');
        }
      }
      for (final field in [
        'requires_login_phone',
        'fee_all_in',
        'requires_sim',
      ]) {
        final expectedFlag = input[field] ?? (field == 'requires_sim');
        if (expectedFlag is! bool || row[field] != expectedFlag) {
          throw const FormatException('Route receipt flag mismatch');
        }
      }
      if (row['recipient_format'] != (input['recipient_format'] ?? 'raw') ||
          row['instruction_template'] !=
              (input['instruction_template'] == ''
                  ? null
                  : input['instruction_template'])) {
        throw const FormatException('Route instruction receipt mismatch');
      }
      for (final field in ['valid_from', 'valid_until']) {
        if (input[field] == null && row[field] == null) continue;
        if (!PaymentWire.timestamp(
          row,
          field,
        ).isAtSameMomentAs(PaymentWire.timestamp(input, field))) {
          throw const FormatException('Route validity receipt mismatch');
        }
      }
      if ((input['id'] == null && row['tariff_version'] != 1) ||
          (input['tariff_version'] != null &&
              row['tariff_version'] !=
                  PaymentWire.integer(input, 'tariff_version', min: 1) + 1) ||
          [
            'tested_at',
            'tested_by',
            'reviewed_at',
            'reviewed_by',
          ].any((field) => row[field] != null)) {
        throw const FormatException('Route review reset receipt mismatch');
      }
    }
  }

  static void routeRecord(Map<String, dynamic> row) {
    for (final field in [
      'id',
      'source_provider',
      'destination_provider',
      'rail',
    ]) {
      PaymentWire.text(row, field);
    }
    PaymentWire.choice(row, 'source_kind', const [
      'mobileWallet',
      'bankAccount',
      'bankAlias',
    ]);
    PaymentWire.choice(
      row,
      'destination_kind',
      PaymentMethodKind.values.map((value) => value.name),
    );
    PaymentWire.choice(
      row,
      'purpose',
      PaymentPurpose.values.map((value) => value.name),
    );
    PaymentWire.choice(row, 'currency', const ['RWF']);
    PaymentWire.choice(row, 'state', const [
      'draft',
      'tested',
      'approved',
      'disabled',
    ]);
    PaymentWire.choice(row, 'handoff_mode', const ['dial', 'instructions']);
    PaymentWire.choice(row, 'recipient_format', const [
      'raw',
      'e164Digits',
      'rwandaNational',
    ]);
    PaymentFee.fromJson({
      'certainty': row['fee_certainty'],
      'francs': row['fee_rwf'],
      'all_in': row['fee_all_in'],
    });
    final min = PaymentWire.integer(row, 'min_rwf', min: 1);
    final max = PaymentWire.integer(row, 'max_rwf', min: 1);
    if (max > 10000000 || max < min) {
      throw const FormatException('Invalid route amount range');
    }
    for (final field in ['adapter_version', 'tariff_version']) {
      PaymentWire.integer(row, field, min: 1);
    }
    if (row['steps'] != null) PaymentWire.integer(row, 'steps', min: 1);
    for (final field in ['requires_sim', 'requires_login_phone']) {
      PaymentWire.boolean(row, field);
    }
    final devices = row['device_families'];
    if (devices is! List ||
        devices.any(
          (value) =>
              !const ['android', 'ios', 'web', 'desktop'].contains(value),
        )) {
      throw const FormatException('Invalid route devices');
    }
    PaymentWire.timestamp(row, 'valid_from');
    for (final field in ['valid_until', 'tested_at', 'reviewed_at']) {
      if (row[field] != null) PaymentWire.timestamp(row, field);
    }
  }
}
