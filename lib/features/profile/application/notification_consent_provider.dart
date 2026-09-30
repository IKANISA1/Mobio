import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/notifications/application/notification_services.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';

final notificationConsentProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationConsentController,
      NotificationConsentSettings
    >(NotificationConsentController.new);

class NotificationConsentController
    extends AsyncNotifier<NotificationConsentSettings> {
  NotificationConsentController()
    : _captureOverride = null,
      _isCurrentOverride = null;

  @visibleForTesting
  NotificationConsentController.test({
    required AccountSnapshot Function() captureAccount,
    required bool Function(AccountSnapshot) isCurrent,
  }) : _captureOverride = captureAccount,
       _isCurrentOverride = isCurrent;

  final AccountSnapshot Function()? _captureOverride;
  final bool Function(AccountSnapshot)? _isCurrentOverride;
  AccountSnapshot? _owner;
  int _revision = 0;
  int _buildRevision = 0;
  Future<void> _writeTail = Future<void>.value();
  NotificationConsentSettings? _confirmed;

  bool _current(AccountSnapshot account) =>
      ref.mounted &&
      (_isCurrentOverride?.call(account) ?? AccountContext.isCurrent(account));

  void _requireCurrent(AccountSnapshot account) {
    if (!_current(account)) throw const StaleAccountWork();
  }

  @override
  Future<NotificationConsentSettings> build() async {
    _revision++;
    final buildRevision = ++_buildRevision;
    _owner = null;
    _confirmed = null;
    ref.onDispose(() {
      _revision++;
      _buildRevision++;
    });
    if (SupabaseConfig.isLocalUiPreview && _captureOverride == null) {
      return const NotificationConsentSettings(
        promotionalInApp: true,
        promotionalPush: false,
      );
    }
    final account = _captureOverride?.call() ?? AccountContext.capture();
    _owner = account;
    void accountChanged() {
      if (ref.mounted && !_current(account)) ref.invalidateSelf();
    }

    AccountContext.changes.addListener(accountChanged);
    ref.onDispose(() => AccountContext.changes.removeListener(accountChanged));
    final saved = await ref
        .read(notificationConsentServiceProvider)
        .getSettings();
    _requireCurrent(account);
    if (buildRevision != _buildRevision) throw const StaleAccountWork();
    _confirmed = saved;
    return saved;
  }

  Future<void> setPromotionalInApp(bool value) async {
    final current = state.value ?? const NotificationConsentSettings();
    await _save(current.copyWith(promotionalInApp: value));
  }

  Future<void> setPromotionalPush(bool value) async {
    final current = state.value ?? const NotificationConsentSettings();
    await _save(current.copyWith(promotionalPush: value));
  }

  Future<void> _save(NotificationConsentSettings settings) async {
    if (SupabaseConfig.isLocalUiPreview && _captureOverride == null) {
      state = AsyncValue.data(settings);
      return;
    }
    final account = _owner;
    if (account == null) throw const StaleAccountWork();
    _requireCurrent(account);
    final revision = ++_revision;
    final buildRevision = _buildRevision;
    void requireWork() {
      _requireCurrent(account);
      if (buildRevision != _buildRevision) throw const StaleAccountWork();
    }

    state = AsyncValue.data(settings);
    // Keep backend writes in order. An older failure cannot roll back the
    // newer optimistic choice, and a queued old-account write never starts.
    final work = _writeTail.then((_) async {
      requireWork();
      final saved = await ref
          .read(notificationConsentServiceProvider)
          .saveSettings(settings);
      requireWork();
      _confirmed = saved;
      if (revision == _revision) state = AsyncValue.data(saved);
    });
    _writeTail = work.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    try {
      await work;
    } on Object catch (error, stackTrace) {
      if (_current(account) &&
          buildRevision == _buildRevision &&
          revision == _revision) {
        state = _confirmed == null
            ? AsyncValue.error(error, stackTrace)
            : AsyncValue.data(_confirmed!);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
