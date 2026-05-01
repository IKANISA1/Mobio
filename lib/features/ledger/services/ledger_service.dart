import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/ledger/models/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LedgerService {
  LedgerService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Stream<List<Transaction>> watchTransactions() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('profile_id', userId)
        .order('txn_timestamp', ascending: false)
        .map((data) => data.map(Transaction.fromJson).toList());
  }

  Future<List<Transaction>> getTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('profile_id', userId)
          .order('txn_timestamp', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch transactions: $error',
        error,
        stackTrace,
      );
      return [];
    }
  }

  Future<Map<String, double>> getTransactionSummary() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'totalIn': 0.0, 'totalOut': 0.0};

    try {
      final response = await _supabase
          .from('transactions')
          .select('amount, direction')
          .eq('profile_id', userId);

      double totalIn = 0;
      double totalOut = 0;

      for (final item in (response as List)) {
        final amount = (item['amount'] as num).toDouble();
        if (item['direction'] == 'IN') {
          totalIn += amount;
        } else {
          totalOut += amount;
        }
      }

      return {'totalIn': totalIn, 'totalOut': totalOut};
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to fetch transaction summary: $error',
        error,
        stackTrace,
      );
      return {'totalIn': 0.0, 'totalOut': 0.0};
    }
  }
}
