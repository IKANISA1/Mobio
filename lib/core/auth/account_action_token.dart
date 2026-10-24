import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';

/// Binds a dialog, navigation result or delayed UI callback to its originating
/// account generation. Authorization remains enforced by services and server.
class AccountActionToken {
  AccountActionToken._(
    this._account,
    this._revision,
    this._capture,
    this._readRevision,
    this._review,
    this._readReview,
  );

  factory AccountActionToken.capture({
    AccountSnapshot? Function()? captureAccount,
    int Function()? readRevision,
    ReviewActionToken? Function()? captureReview,
  }) {
    final capture = captureAccount ?? _captureCurrent;
    final revision = readRevision ?? (() => AccountContext.changes.value);
    final review = captureReview ?? _captureReview;
    return AccountActionToken._(
      capture(),
      revision(),
      capture,
      revision,
      review(),
      review,
    );
  }

  final AccountSnapshot? _account;
  final int _revision;
  final AccountSnapshot? Function() _capture;
  final int Function() _readRevision;
  final ReviewActionToken? _review;
  final ReviewActionToken? Function() _readReview;
  static ReviewActionToken? _captureReview() =>
      AccountContext.reviewSession.hasAccess
      ? AccountContext.reviewSession.capture()
      : null;

  static AccountSnapshot? _captureCurrent() {
    try {
      return AccountContext.capture();
    } on Object {
      return null;
    }
  }

  bool get isCurrent {
    if (_readRevision() != _revision) return false;
    if (_review != null) return _review.isCurrent;
    if (_readReview() != null) return false;
    final current = _capture();
    if (_account == null) return current == null;
    return current?.identity == _account.identity &&
        current?.generation == _account.generation;
  }
}
