package rw.mobi.app.ledger.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

/**
 * DAO for cached MoMo providers.
 * Supports bulk replace (on cache refresh) and sender ID lookups.
 */
@Dao
interface ProviderDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(providers: List<ProviderEntity>)

    @Query("SELECT * FROM providers_cache WHERE active = 1")
    suspend fun getActiveProviders(): List<ProviderEntity>

    @Query("SELECT sender_id FROM providers_cache WHERE active = 1 AND sender_id IS NOT NULL")
    suspend fun getActiveSenderIds(): List<String>

    @Query("SELECT * FROM providers_cache WHERE id = :countryId AND active = 1")
    suspend fun getProvidersByCountry(countryId: String): List<ProviderEntity>

    @Query("SELECT DISTINCT id, name FROM providers_cache WHERE active = 1 ORDER BY name")
    suspend fun getActiveCountries(): List<CountryInfo>

    @Query("DELETE FROM providers_cache")
    suspend fun clearAll(): Int

    @Query("SELECT COUNT(*) FROM providers_cache")
    suspend fun count(): Int

    @Query("SELECT MAX(cached_at) FROM providers_cache")
    suspend fun getLastCacheTime(): Long?
}

/**
 * Projection for country list display.
 */
data class CountryInfo(
    val id: String,
    val name: String
)
