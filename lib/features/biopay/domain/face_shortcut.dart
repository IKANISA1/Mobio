/// A receiving shortcut, never a payment authorization or receipt.
class PreparedFaceUssdShortcut {
  const PreparedFaceUssdShortcut({
    required this.requestId,
    required this.payeeId,
    required this.receivingMethodId,
    required this.receivingMethodVersion,
    required this.provider,
    required this.routeId,
    required this.routeVersion,
    required this.ussdCode,
    required this.expiresAt,
    this.displayName,
  });
  final String requestId,
      payeeId,
      receivingMethodId,
      provider,
      routeId,
      ussdCode;
  final String? displayName;
  final int receivingMethodVersion, routeVersion;
  final DateTime expiresAt;
  factory PreparedFaceUssdShortcut.fromJson(Map<String, dynamic> json) {
    final expires = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    final code = json['ussd_code']?.toString() ?? '';
    final ids = ['request_id', 'payee_id', 'receiving_method_id', 'route_id'];
    if (json['status'] != 'dial_ready' ||
        expires == null ||
        !RegExp(r'^\*[0-9*]+#$').hasMatch(code) ||
        code.length > 100 ||
        ids.any(
          (key) => !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(json[key]?.toString() ?? ''),
        ) ||
        json['receiving_method_version'] is! int ||
        (json['receiving_method_version'] as int) < 1 ||
        json['route_version'] is! int ||
        (json['route_version'] as int) < 1 ||
        json['provider'] is! String ||
        !RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(json['provider'] as String)) {
      throw const FormatException('Invalid face shortcut');
    }
    return PreparedFaceUssdShortcut(
      requestId: json['request_id'] as String,
      payeeId: json['payee_id'] as String,
      receivingMethodId: json['receiving_method_id'] as String,
      receivingMethodVersion: json['receiving_method_version'] as int,
      provider: json['provider'] as String,
      routeId: json['route_id'] as String,
      routeVersion: json['route_version'] as int,
      ussdCode: code,
      expiresAt: expires.toUtc(),
      displayName: json['display_name'] as String?,
    );
  }
  bool isCurrent(DateTime now) =>
      expiresAt.isAfter(now) &&
      expiresAt.difference(now) <= const Duration(minutes: 3);
}

class FaceScanTicket {
  const FaceScanTicket(this.generation, this.account);
  final int generation;
  final String account;
}

/// Claims the external launch synchronously, before awaiting camera/native work.
/// Cancellation, account changes and lifecycle events invalidate all older work.
class FaceHandoffGate {
  int _generation = 0;
  bool _busy = false;
  bool _foreground = true;
  final Set<String> _claimed = {};
  FaceScanTicket? begin(String? account) {
    if (_busy || !_foreground || account == null) return null;
    _busy = true;
    return FaceScanTicket(++_generation, account);
  }

  bool accepts(FaceScanTicket ticket, String? account) =>
      _busy &&
      _foreground &&
      ticket.generation == _generation &&
      ticket.account == account;
  bool claim(
    FaceScanTicket ticket,
    String? account,
    PreparedFaceUssdShortcut shortcut,
    DateTime now,
  ) =>
      accepts(ticket, account) &&
      shortcut.isCurrent(now) &&
      _claimed.add(shortcut.requestId);
  void finish(FaceScanTicket ticket) {
    if (ticket.generation == _generation) _busy = false;
  }

  void cancel() {
    _generation++;
    _busy = false;
  }

  void foreground(bool value) {
    _foreground = value;
    if (!value) cancel();
  }
}
