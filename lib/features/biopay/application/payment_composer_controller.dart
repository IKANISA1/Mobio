import 'package:flutter/foundation.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';

enum ComposerStep { recipient, options, review, outcome }

/// Every async write/result belongs to one account and one draft revision.
class PaymentComposerController extends ChangeNotifier {
  PaymentComposerController({required this.gateway, required this.draft});

  final PaymentDiscoveryGateway gateway;
  PaymentDraft draft;
  PaymentRecipient? recipient;
  List<PaymentOption> options = const [];
  Map<String, String?> sourceAvailability = const {};
  PaymentOption? selected;
  String? quoteId;
  DateTime? quoteExpiresAt;
  Map<String, dynamic>? prepared;
  ComposerStep step = ComposerStep.recipient;
  bool busy = false;
  bool saved = false;
  String? error;
  int _operation = 0;
  bool _disposed = false;

  bool get accountCurrent => gateway.ownerId == draft.ownerId;
  bool get quoteCurrent =>
      accountCurrent &&
      quoteId != null &&
      quoteExpiresAt != null &&
      quoteExpiresAt!.isAfter(DateTime.now());

  void edit(PaymentDraft next) {
    if (next.id != draft.id || next.ownerId != draft.ownerId) {
      throw ArgumentError('Use a new controller for another draft or account.');
    }
    draft = next;
    _operation++;
    busy = false;
    saved = false;
    quoteId = null;
    quoteExpiresAt = null;
    selected = null;
    options = const [];
    sourceAvailability = const {};
    prepared = null;
    error = null;
    step = recipient == null ? ComposerStep.recipient : ComposerStep.options;
    notifyListeners();
  }

  bool _current(int operation, int revision) =>
      !_disposed &&
      accountCurrent &&
      operation == _operation &&
      revision == draft.revision;

  Future<T?> _perform<T>(Future<T> Function(int, int) action) async {
    if (busy || !accountCurrent) return null;
    final operation = ++_operation;
    final revision = draft.revision;
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await action(operation, revision);
    } on Object catch (failure) {
      if (!_disposed && accountCurrent && operation == _operation) {
        error = failure is PaymentDiscoveryException
            ? failure.reason
            : 'refreshRequired';
        quoteId = null;
        selected = null;
        // A prepared request is recoverable in Activity even if saving its
        // shortcut fails. Never offer to submit the consumed quote again.
        step = draft.attemptId != null
            ? ComposerStep.outcome
            : recipient == null
            ? ComposerStep.recipient
            : ComposerStep.options;
        prepared = null;
        saved = false;
      }
      return null;
    } finally {
      if (!_disposed && operation == _operation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> resolve() async {
    await _perform((operation, revision) async {
      final result = await gateway.call('resolve', draft.toJson());
      if (!_current(operation, revision)) return;
      recipient = PaymentRecipient.fromJson(result);
      if (recipient!.fixedAmount != null ||
          recipient!.purpose != null ||
          recipient!.reference.isNotEmpty) {
        draft = draft.copyWith(
          amount: recipient!.fixedAmount?.toString(),
          purpose: recipient!.purpose,
          reference: recipient!.reference.isEmpty ? null : recipient!.reference,
        );
        // This controlled edit invalidates the operation's revision.
        busy = false;
      }
      step = ComposerStep.options;
      notifyListeners();
    });
  }

  Future<void> save() async {
    await _perform((operation, revision) async {
      await _saveSnapshot(draft);
      if (_current(operation, revision)) saved = true;
    });
  }

  Future<void> _saveSnapshot(PaymentDraft snapshot) async {
    await gateway.call('save_draft', snapshot.toJson());
    if (!accountCurrent) throw StateError('Account changed.');
    await gateway.rememberDraft(snapshot.ownerId, snapshot.id);
  }

  Future<void> quote() async {
    if (parseRwf(draft.amount) == null) {
      error = 'wholeAmount';
      notifyListeners();
      return;
    }
    await _perform((operation, revision) async {
      final snapshot = draft;
      await _saveSnapshot(snapshot);
      if (!_current(operation, revision)) return;
      saved = true;
      final result = await gateway.call('quote', {
        'id': snapshot.id,
        'revision': snapshot.revision,
        'device': gateway.deviceFamily,
      });
      if (!_current(operation, revision)) return;
      recipient = PaymentRecipient.fromJson(
        result['recipient'] as Map<String, dynamic>,
      );
      options = rankPaymentOptions(
        (result['options'] as List).map(
          (x) => PaymentOption.fromJson(Map<String, dynamic>.from(x as Map)),
        ),
      );
      sourceAvailability = {
        for (final entry
            in (result['source_availability'] as List? ?? const []))
          entry['id'] as String: entry['reason'] as String?,
      };
      quoteId = result['quote_id'] as String;
      quoteExpiresAt = DateTime.parse(result['expires_at'] as String);
      selected = null;
      step = ComposerStep.options;
    });
  }

  void review(PaymentOption option) {
    if (!quoteCurrent || !options.contains(option)) {
      error = 'refreshRequired';
      notifyListeners();
      return;
    }
    selected = option;
    step = ComposerStep.review;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> prepare() async {
    if (step != ComposerStep.review || selected == null || !quoteCurrent) {
      error = 'refreshRequired';
      notifyListeners();
      return null;
    }
    return _perform<Map<String, dynamic>?>((operation, revision) async {
      final result = await gateway.call('prepare', {
        'quote_id': quoteId,
        'option_id': selected!.id,
        'device': gateway.deviceFamily,
      });
      if (!_current(operation, revision)) return null;
      prepared = result;
      draft = draft.copyWith(
        evidence: PaymentEvidence.prepared,
        attemptId: result['attempt_id'] as String,
      );
      // Persist before handing control away. A failed save prevents launching.
      await _saveSnapshot(draft);
      if (_disposed || !accountCurrent || operation != _operation) return null;
      saved = true;
      quoteId = null;
      step = ComposerStep.outcome;
      busy = false;
      notifyListeners();
      return result;
    });
  }

  Future<void> record(PaymentEvidence evidence) async {
    if (draft.attemptId == null || !accountCurrent) return;
    if (!const {
      PaymentEvidence.handoffOpened,
      PaymentEvidence.outcomeUnknown,
      PaymentEvidence.userReported,
    }.contains(evidence)) {
      return;
    }
    await _perform((operation, revision) async {
      final response = await gateway.call('record_attempt', {
        'id': draft.attemptId,
        'evidence': evidence.name,
      });
      if (!_current(operation, revision)) return;
      draft = draft.copyWith(
        evidence: PaymentEvidence.values.byName(response['evidence'] as String),
      );
      await _saveSnapshot(draft);
      busy = false;
      notifyListeners();
    });
  }

  void invalidateOnResume() {
    _operation++;
    busy = false;
    quoteId = null;
    selected = null;
    options = const [];
    if (draft.attemptId != null) {
      step = ComposerStep.outcome;
    } else if (recipient != null) {
      step = ComposerStep.options;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}
