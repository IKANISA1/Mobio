package com.mobi.ledger.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

/**
 * DAO for the SMS offline queue.
 */
@Dao
interface SmsQueueDao {

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertIfNotExists(item: SmsQueueEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBatch(items: List<SmsQueueEntity>): List<Long>

    @Query("SELECT * FROM sms_queue WHERE status = 'PENDING' ORDER BY received_at ASC LIMIT :limit")
    suspend fun getPendingBatch(limit: Int = 50): List<SmsQueueEntity>

    @Query("UPDATE sms_queue SET status = :status, retries = retries + 1, last_error = :error WHERE id = :id")
    suspend fun updateStatus(id: Long, status: String, error: String?): Int

    @Query("UPDATE sms_queue SET status = 'SYNCED' WHERE id IN (:ids)")
    suspend fun markSynced(ids: List<Long>): Int

    @Query("UPDATE sms_queue SET status = 'PENDING', retries = 0, last_error = NULL WHERE status = 'FAILED'")
    suspend fun retryAllFailed(): Int

    @Query("SELECT COUNT(*) FROM sms_queue WHERE status = 'PENDING'")
    fun observePendingCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM sms_queue WHERE status = 'FAILED'")
    fun observeFailedCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM sms_queue WHERE status = 'SYNCED'")
    fun observeSyncedCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM sms_queue")
    suspend fun getTotalCount(): Int

    @Query("DELETE FROM sms_queue WHERE status = 'SYNCED'")
    suspend fun clearSynced(): Int

    @Query("SELECT * FROM sms_queue WHERE status = 'FAILED' ORDER BY received_at DESC")
    suspend fun getFailedItems(): List<SmsQueueEntity>
}
