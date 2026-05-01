import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/features/ledger/models/transaction.dart';
import 'package:mobi_app/features/ledger/services/ledger_native_service.dart';
import 'package:mobi_app/features/ledger/services/ledger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService();
});

final ledgerNativeServiceProvider = Provider<LedgerNativeService>((ref) {
  return LedgerNativeService();
});

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final service = ref.watch(ledgerServiceProvider);
  return service.watchTransactions();
});

final transactionSummaryProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final service = ref.watch(ledgerServiceProvider);
  // We trigger this whenever the stream updates
  ref.watch(transactionsStreamProvider);
  return service.getTransactionSummary();
});

final pendingSmsCountProvider = FutureProvider<int>((ref) async {
  final nativeService = ref.watch(ledgerNativeServiceProvider);
  // Refresh when transactions update (sync might have happened)
  ref.watch(transactionsStreamProvider);
  return nativeService.getPendingSmsCount();
});

final ledgerCredentialsSyncProvider = FutureProvider<void>((ref) async {
  final nativeService = ref.watch(ledgerNativeServiceProvider);
  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;
  if (session == null) return;

  final profileResponse = await supabase
      .from('profiles')
      .select('member_id')
      .eq('id', session.user.id)
      .maybeSingle();

  if (profileResponse != null) {
    final memberId = profileResponse['member_id'] as String?;
    if (memberId != null) {
      if (SupabaseConfig.isConfigured) {
        await nativeService.startService(
          memberId,
          SupabaseConfig.url,
          SupabaseConfig.anonKey,
        );
      }
      await nativeService.setLedgerCredentials(
        agentId: memberId,
        authToken: session.accessToken,
      );
    }
  }
});
