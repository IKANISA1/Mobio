import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/features/ledger/services/ledger_bridge.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/app/src/main/kotlin/com/mobi/ledger/LedgerBridge.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.mobi.ledger'),
))

class LedgerSyncStatus {
  final int pendingCount;
  final int failedCount;
  final int syncedCount;
  final int lastSyncTimestamp;
  final String? lastError;

  LedgerSyncStatus({
    required this.pendingCount,
    required this.failedCount,
    required this.syncedCount,
    required this.lastSyncTimestamp,
    this.lastError,
  });
}

@HostApi()
abstract class LedgerApi {
  @async
  bool isSmsPermissionGranted();

  @async
  bool requestSmsPermission();

  void startLedgerService(String agentId, String supabaseUrl, String supabaseAnonKey);

  void stopLedgerService();

  @async
  LedgerSyncStatus getSyncStatus();

  @async
  void syncNow();

  @async
  void setCredentials(String agentId, String accessToken);
}
