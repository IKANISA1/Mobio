import 'package:mobi_app/core/auth/account_context.dart';

/// Binds a dialog, navigation result or delayed UI callback to its originating
/// account generation. Authorization remains enforced by services and server.
class AccountActionToken {
  AccountActionToken._(
    this._account,
    this._revision,
    this._capture,
    this._readRevision,
  );

  factory AccountActionToken.capture({
    AccountSnapshot? Function()? captureAccount,
    int Function()? readRevision,
  }) {
    final capture = captureAccount ?? _captureCurrent;
    final revision = readRevision ?? (() => AccountContext.changes.value);
    return AccountActionToken._(capture(), revision(), capture, revision);
  }

  final AccountSnapshot? _account;
  final int _revision;
  final AccountSnapshot? Function() _capture;
  final int Function() _readRevision;

  static AccountSnapshot? _captureCurrent() {
    try {
      return AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool get isCurrent {
    if (_readRevision() != _revision) return false;
    final current = _capture();
    if (_account == null) return current == null;
    return current?.identity == _account.identity &&
        current?.generation == _account.generation;
  }
}
