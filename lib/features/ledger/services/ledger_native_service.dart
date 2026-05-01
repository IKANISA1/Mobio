import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/ledger/services/ledger_bridge.g.dart';

class LedgerNativeService {
  final _api = LedgerApi();

  Future<void> triggerSync() async {
    try {
      await _api.syncNow();
    } on Exception catch (e) {
      AppLogger.error('Failed to trigger native sync: $e');
    }
  }

  Future<void> setLedgerCredentials({
    required String agentId,
    required String authToken,
  }) async {
    try {
      await _api.setCredentials(agentId, authToken);
    } on Exception catch (e) {
      AppLogger.error('Failed to set native ledger credentials: $e');
    }
  }

  Future<int> getPendingSmsCount() async {
    try {
      final status = await _api.getSyncStatus();
      return status.pendingCount;
    } on Exception catch (e) {
      AppLogger.error('Failed to get pending SMS count: $e');
      return 0;
    }
  }

  Future<bool> isSmsPermissionGranted() async {
    try {
      return await _api.isSmsPermissionGranted();
    } on Exception catch (e) {
      AppLogger.error('Failed to check SMS permission: $e');
      return false;
    }
  }

  Future<bool> requestSmsPermission() async {
    try {
      return await _api.requestSmsPermission();
    } on Exception catch (e) {
      AppLogger.error('Failed to request SMS permission: $e');
      return false;
    }
  }

  Future<void> startService(String agentId, String supabaseUrl, String supabaseAnonKey) async {
    try {
      await _api.startLedgerService(agentId, supabaseUrl, supabaseAnonKey);
    } on Exception catch (e) {
      AppLogger.error('Failed to start ledger service: $e');
    }
  }
}
