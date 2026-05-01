package com.mobi.ledger.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface ProviderDao {

    @Query("SELECT sender_id FROM providers_cache WHERE is_active = 1")
    suspend fun getActiveSenderIds(): List<String>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProviders(providers: List<ProviderEntity>)

    @Query("DELETE FROM providers_cache")
    suspend fun clearAll(): Int

    @Query("SELECT * FROM providers_cache")
    suspend fun getAll(): List<ProviderEntity>
}
