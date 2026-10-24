import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/auth/data/store_review_session_service.dart';

/// Revalidate restored authority before task hydration and on foreground return.
/// Pausing a synthetic review immediately fences its pending task callbacks.
class SessionAuthorityLifecycle extends WidgetsBindingObserver {
  SessionAuthorityLifecycle({StoreReviewSessionService? reviewService})
    : _reviewService = reviewService ?? StoreReviewSessionService();
  final StoreReviewSessionService _reviewService;
  bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
    if (AccountContext.hasReviewTransport) unawaited(_reviewService.validate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_installed) return;
    if (state == AppLifecycleState.resumed) {
      if (AccountContext.hasReviewTransport) {
        unawaited(_reviewService.validate());
      } else {
        unawaited(AccountContext.validateInteractiveSession());
      }
    } else {
      AccountContext.reviewSession.invalidate();
    }
  }

  void dispose() {
    if (!_installed) return;
    _installed = false;
    WidgetsBinding.instance.removeObserver(this);
    AccountContext.reviewSession.invalidate();
  }
}
