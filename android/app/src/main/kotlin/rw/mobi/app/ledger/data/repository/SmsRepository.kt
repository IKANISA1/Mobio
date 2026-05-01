package rw.mobi.app.ledger.data.repository

import android.content.Context
import android.net.Uri
import android.provider.Telephony
import rw.mobi.app.ledger.data.local.PayLedgerDatabase
import rw.mobi.app.ledger.data.local.SmsQueueEntity
import rw.mobi.app.ledger.data.local.SmsStatus
import rw.mobi.app.ledger.data.remote.SupabaseManager
import rw.mobi.app.ledger.domain.model.RawSmsItem
import rw.mobi.app.ledger.util.HashUtils
import rw.mobi.app.ledger.util.PrefsManager
import io.github.jan.supabase.functions.functions
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Repository for SMS queue management.
 * Handles: queueing incoming SMS, 12-month backfill, batch upload to Edge Function.
 */
class SmsRepository(private val context: Context) {

    private val db = PayLedgerDatabase.getInstance(context)
    private val dao = db.smsQueueDao()

    /**
     * Queue a single incoming SMS for sync.
     * Called from BroadcastReceiver — must be fast, no network calls.
     */
    suspend fun queueSms(agentId: String, rawSms: String, sender: String) {
        val smsHash = HashUtils.sha256(agentId, rawSms)
        dao.insertIfNotExists(
            SmsQueueEntity(
                smsHash = smsHash,
                agentId = agentId,
                rawSms = rawSms,
                sender = sender,
                receivedAt = System.currentTimeMillis(),
                status = SmsStatus.PENDING.name
            )
        )
    }

    /**
     * Run 12-month backfill from device SMS inbox.
     * Filters by cached MoMo sender IDs. Reports progress via callback.
     */
    suspend fun runBackfill(
        agentId: String,
        senderIds: List<String>,
        onProgress: (found: Int, total: Int) -> Unit
    ): Int {
        val since = System.currentTimeMillis() - (365L * 24 * 60 * 60 * 1000)
        val uri = Uri.parse("content://sms/inbox")

        val cursor = context.contentResolver.query(
            uri,
            arrayOf("address", "body", "date"),
            "date > ?",
            arrayOf(since.toString()),
            "date DESC"
        ) ?: return 0

        val momoSms = mutableListOf<RawSmsItem>()
        cursor.use {
            while (it.moveToNext()) {
                val address = it.getString(0) ?: continue
                val body = it.getString(1) ?: continue
                val date = it.getLong(2)
                if (senderIds.any { id -> address.contains(id, ignoreCase = true) }) {
                    momoSms.add(RawSmsItem(address, body, date))
                }
            }
        }

        val total = momoSms.size
        if (total == 0) {
            onProgress(0, 0)
            return 0
        }

        // Queue all found SMS into Room DB (deduplicated)
        var queued = 0
        momoSms.forEachIndexed { idx, sms ->
            val hash = HashUtils.sha256(agentId, sms.body)
            val insertResult = dao.insertIfNotExists(
                SmsQueueEntity(
                    smsHash = hash,
                    agentId = agentId,
                    rawSms = sms.body,
                    sender = sms.sender,
                    receivedAt = sms.timestamp,
                    status = SmsStatus.PENDING.name
                )
            )
            if (insertResult != -1L) queued++
            onProgress(idx + 1, total)
        }

        return queued
    }

    /**
     * Upload a batch of pending SMS to Edge Function.
     * Returns number of successfully uploaded items.
     */
    suspend fun uploadPendingBatch(agentId: String): Int {
        val batch = dao.getPendingBatch(50)
        if (batch.isEmpty()) return 0

        val batchJson = buildJsonArray {
            batch.forEach { sms ->
                add(buildJsonObject {
                    put("raw_sms", sms.rawSms)
                    put("sms_hash", sms.smsHash)
                    put("sender", sms.sender)
                    put("received_at", java.time.Instant.ofEpochMilli(sms.receivedAt).toString())
                })
            }
        }

        val requestBody = buildJsonObject {
            put("agent_id", agentId)
            put("batch", batchJson)
        }

        return try {
            val response = SupabaseManager.client.functions.invoke("parse-sms", requestBody)

            // Mark all as synced on success
            val ids = batch.map { it.id }
            dao.markSynced(ids)
            batch.size
        } catch (e: Exception) {
            // Mark individual items for retry
            batch.forEach { sms ->
                val newStatus = if (sms.retries >= 4) SmsStatus.FAILED.name else SmsStatus.PENDING.name
                dao.updateStatus(sms.id, newStatus, e.message)
            }
            0
        }
    }

    // --- Observation flows ---

    fun observePendingCount(): Flow<Int> = dao.observePendingCount()

    fun observeFailedCount(): Flow<Int> = dao.observeFailedCount()

    suspend fun getFailedItems() = dao.getFailedItems()

    suspend fun retryAllFailed() = dao.retryAllFailed()

    suspend fun clearSynced() = dao.clearSynced()
}
