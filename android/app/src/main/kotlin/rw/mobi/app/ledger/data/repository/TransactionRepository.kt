package rw.mobi.app.ledger.data.repository

import android.content.Context
import rw.mobi.app.ledger.data.local.PayLedgerDatabase
import rw.mobi.app.ledger.data.remote.SupabaseManager
import rw.mobi.app.ledger.domain.model.DashboardStats
import rw.mobi.app.ledger.domain.model.Transaction
import rw.mobi.app.ledger.domain.model.TransactionFilter
import rw.mobi.app.ledger.util.PrefsManager
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

/**
 * Repository for transaction data.
 * Fetches from Supabase, supports realtime subscription, filtering, and stats.
 */
class TransactionRepository(private val context: Context) {

    private val providerDao = PayLedgerDatabase.getInstance(context).providerDao()

    private val _transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val transactions = _transactions.asStateFlow()

    /**
     * Fetch transactions from Supabase with optional filtering.
     */
    suspend fun fetchTransactions(filter: TransactionFilter = TransactionFilter()): List<Transaction> {
        val agentId = PrefsManager.getAgentId(context) ?: return emptyList()

        val result = SupabaseManager.client.from("transactions")
            .select {
                filter {
                    eq("agent_id", agentId)
                    filter.dateFrom?.let { gte("txn_timestamp", it.toString()) }
                    filter.dateTo?.let { lte("txn_timestamp", it.toString()) }
                    filter.network?.let { eq("network", it) }
                    filter.direction?.let { eq("direction", it) }
                    filter.minAmount?.let { gte("amount", it) }
                    filter.maxAmount?.let { lte("amount", it) }
                    filter.searchQuery?.let {
                        or {
                            ilike("payer_name", "%$it%")
                            ilike("payer_number", "%$it%")
                        }
                    }
                }
                order(filter.sortBy, if (filter.sortDescending) Order.DESCENDING else Order.ASCENDING)
                limit(500)
            }
            .decodeList<TransactionDto>()

        val mapped = result.map { it.toDomain() }
        _transactions.value = mapped
        return mapped
    }

    /**
     * Subscribe to realtime transaction updates.
     */
    suspend fun subscribeToRealtime() {
        val agentId = PrefsManager.getAgentId(context) ?: return

        val channel = SupabaseManager.client.realtime.channel("transactions-$agentId")

        val changeFlow = channel.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = "transactions"
        }

        channel.subscribe()

        // Collect changes and refresh local list
        changeFlow.collect { action ->
            when (action) {
                is PostgresAction.Insert -> {
                    // Refresh the full list (simplest approach for v1)
                    fetchTransactions()
                }
                else -> { /* Update/Delete — handle if needed */ }
            }
        }
    }

    /**
     * Calculate dashboard statistics.
     */
    suspend fun getDashboardStats(): DashboardStats {
        val agentId = PrefsManager.getAgentId(context) ?: return DashboardStats()
        val currency = PrefsManager.getCountryCode(context)?.let { getCurrencyForCountry(it) } ?: "RWF"

        val now = Instant.now()
        val startOfToday = now.atZone(ZoneOffset.UTC).toLocalDate().atStartOfDay().toInstant(ZoneOffset.UTC)
        val startOfWeek = now.minus(7, ChronoUnit.DAYS)
        val startOfMonth = now.atZone(ZoneOffset.UTC).toLocalDate().withDayOfMonth(1).atStartOfDay().toInstant(ZoneOffset.UTC)

        val allTxns = SupabaseManager.client.from("transactions")
            .select {
                filter {
                    eq("agent_id", agentId)
                    eq("direction", "IN")
                    gte("txn_timestamp", startOfMonth.toString())
                }
            }
            .decodeList<TransactionDto>()

        val todayTxns = allTxns.filter {
            Instant.parse(it.txn_timestamp).isAfter(startOfToday)
        }
        val weekTxns = allTxns.filter {
            Instant.parse(it.txn_timestamp).isAfter(startOfWeek)
        }

        return DashboardStats(
            todayTotal = todayTxns.sumOf { it.amount },
            weekTotal = weekTxns.sumOf { it.amount },
            monthTotal = allTxns.sumOf { it.amount },
            todayCount = todayTxns.size,
            weekCount = weekTxns.size,
            monthCount = allTxns.size,
            currency = currency
        )
    }

    /**
     * Get all transactions for export (no limit).
     */
    suspend fun getTransactionsForExport(
        filter: TransactionFilter = TransactionFilter()
    ): List<Transaction> {
        val agentId = PrefsManager.getAgentId(context) ?: return emptyList()

        val result = SupabaseManager.client.from("transactions")
            .select {
                filter {
                    eq("agent_id", agentId)
                    filter.dateFrom?.let { gte("txn_timestamp", it.toString()) }
                    filter.dateTo?.let { lte("txn_timestamp", it.toString()) }
                    filter.network?.let { eq("network", it) }
                    filter.direction?.let { eq("direction", it) }
                    filter.minAmount?.let { gte("amount", it) }
                    filter.maxAmount?.let { lte("amount", it) }
                    filter.searchQuery?.let {
                        or {
                            ilike("payer_name", "%$it%")
                            ilike("payer_number", "%$it%")
                        }
                    }
                }
                order(filter.sortBy, if (filter.sortDescending) Order.DESCENDING else Order.ASCENDING)
            }
            .decodeList<TransactionDto>()

        return result.map { it.toDomain() }
    }

    /**
     * Get currency for a country from the provider cache.
     * Falls back to stored preference or USD if cache is unavailable.
     */
    private suspend fun getCurrencyForCountry(countryCode: String): String {
        try {
            val db = rw.mobi.app.ledger.data.local.PayLedgerDatabase.getInstance(context)
            val providers = db.providerDao().getProvidersByCountry(countryCode)
            if (providers.isNotEmpty()) return providers.first().currency
        } catch (_: Exception) {
            // Cache unavailable — use fallback
        }
        return "USD"
    }
}

/**
 * DTO for Supabase transactions table deserialization.
 */
@kotlinx.serialization.Serializable
data class TransactionDto(
    val id: String,
    val agent_id: String,
    val transaction_ref: String? = null,
    val payer_name: String? = null,
    val payer_number: String? = null,
    val amount: Double,
    val currency: String,
    val network: String,
    val balance_after: Double? = null,
    val direction: String,
    val txn_timestamp: String,
    val raw_sms: String,
    val sms_hash: String,
    val parse_confidence: Float? = null,
    val country: String,
    val parsed_at: String? = null,
    val created_at: String
) {
    fun toDomain() = Transaction(
        id = id,
        agentId = agent_id,
        transactionRef = transaction_ref,
        payerName = payer_name,
        payerNumber = payer_number,
        amount = amount,
        currency = currency,
        network = network,
        balanceAfter = balance_after,
        direction = direction,
        txnTimestamp = Instant.parse(txn_timestamp),
        rawSms = raw_sms,
        smsHash = sms_hash,
        parseConfidence = parse_confidence,
        country = country,
        parsedAt = parsed_at?.let { Instant.parse(it) },
        createdAt = Instant.parse(created_at)
    )
}
