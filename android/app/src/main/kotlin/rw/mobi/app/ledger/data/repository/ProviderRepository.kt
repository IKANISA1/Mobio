package rw.mobi.app.ledger.data.repository

import android.content.Context
import rw.mobi.app.ledger.data.local.PayLedgerDatabase
import rw.mobi.app.ledger.data.local.ProviderEntity
import rw.mobi.app.ledger.data.remote.SupabaseManager
import rw.mobi.app.ledger.domain.model.MoMoProvider
import rw.mobi.app.ledger.util.PrefsManager
import io.github.jan.supabase.postgrest.from

/**
 * Repository for MoMo provider data.
 * Fetches from Supabase, caches locally in Room for offline access.
 * Refreshes every 24 hours.
 */
class ProviderRepository(private val context: Context) {

    private val db = PayLedgerDatabase.getInstance(context)
    private val dao = db.providerDao()

    companion object {
        private const val CACHE_TTL_MS = 24 * 60 * 60 * 1000L // 24 hours
    }

    /**
     * Get all active sender IDs for BroadcastReceiver filtering.
     * Returns cached data — no network call.
     */
    suspend fun getCachedSenderIds(): List<String> {
        return dao.getActiveSenderIds()
    }

    /**
     * Get all active providers. Refreshes from network if cache is stale.
     */
    suspend fun getProviders(forceRefresh: Boolean = false): List<MoMoProvider> {
        val lastRefresh = PrefsManager.getLastProviderRefresh(context)
        val cacheAge = System.currentTimeMillis() - lastRefresh

        if (!forceRefresh && cacheAge < CACHE_TTL_MS && dao.count() > 0) {
            return dao.getActiveProviders().map { it.toDomain() }
        }

        return try {
            refreshFromNetwork()
        } catch (e: Exception) {
            android.util.Log.e("ProviderRepository", "Network fetch failed: ${e.message}", e)
            // Offline fallback — use cached data
            dao.getActiveProviders().map { it.toDomain() }
        }
    }

    /**
     * Fetch from Supabase and update local cache.
     */
    private suspend fun refreshFromNetwork(): List<MoMoProvider> {
        val remoteProviders = SupabaseManager.client.from("countries")
            .select()
            .decodeList<CountryDto>()

        val entities = remoteProviders.map { it.toEntity() }
        dao.clearAll()
        dao.insertAll(entities)
        PrefsManager.setLastProviderRefresh(context, System.currentTimeMillis())

        return remoteProviders.map { it.toDomain() }
    }

    /**
     * Get providers for a specific country.
     */
    suspend fun getProvidersByCountry(countryId: String): List<MoMoProvider> {
        return dao.getProvidersByCountry(countryId).map { it.toDomain() }
    }

    /**
     * Get distinct active countries for onboarding country selection.
     */
    suspend fun getActiveCountries(): List<Pair<String, String>> {
        val countries = dao.getActiveCountries()
        return countries.map { it.id to it.name }
    }

    // --- Mapping helpers ---

    private fun ProviderEntity.toDomain() = MoMoProvider(
        id = id,
        name = name,
        flag = flag,
        dialingCode = dialingCode,
        currency = currency,
        phonePlaceholder = phonePlaceholder,
        telecomProvider = telecomProvider,
        momoBrand = momoBrand,
        ussdCodeFormat = ussdCodeFormat,
        ussdNumberFormat = ussdNumberFormat,
        currencyName = currencyName,
        senderId = senderId,
        active = active
    )
}

/**
 * DTO for Supabase countries table deserialization.
 */
@kotlinx.serialization.Serializable
data class CountryDto(
    val id: String,
    val name: String,
    val flag: String,
    val dialing_code: String,
    val currency: String,
    val phone_placeholder: String,
    val is_active: Boolean = true,
    val sort_order: Int = 99,
    val telecom_provider: String? = null,
    val momo_brand: String? = null,
    val ussd_code_format: String? = null,
    val ussd_number_format: String? = null,
    val currency_name: String? = null,
    val sender_id: String? = null
) {
    fun toEntity() = ProviderEntity(
        id = id,
        name = name,
        flag = flag,
        dialingCode = dialing_code,
        currency = currency,
        phonePlaceholder = phone_placeholder,
        telecomProvider = telecom_provider,
        momoBrand = momo_brand,
        ussdCodeFormat = ussd_code_format,
        ussdNumberFormat = ussd_number_format,
        currencyName = currency_name,
        senderId = sender_id,
        active = is_active,
        sortOrder = sort_order
    )

    fun toDomain() = MoMoProvider(
        id = id,
        name = name,
        flag = flag,
        dialingCode = dialing_code,
        currency = currency,
        phonePlaceholder = phone_placeholder,
        telecomProvider = telecom_provider,
        momoBrand = momo_brand,
        ussdCodeFormat = ussd_code_format,
        ussdNumberFormat = ussd_number_format,
        currencyName = currency_name,
        senderId = sender_id,
        active = is_active
    )
}
