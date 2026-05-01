package com.mobi.ledger.data.repository

import android.content.Context
import android.net.Uri
import com.mobi.ledger.data.local.LedgerDatabase
import com.mobi.ledger.data.local.SmsQueueEntity
import com.mobi.ledger.data.local.SmsStatus
import com.mobi.ledger.util.HashUtils
import com.mobi.ledger.util.PrefsManager
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant

class SmsRepository(private val context: Context) {

    private val db = LedgerDatabase.getInstance(context)
    private val dao = db.smsQueueDao()
    private val httpClient = OkHttpClient()

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

        val momoSms = mutableListOf<Pair<String, String>>()
        cursor.use {
            while (it.moveToNext()) {
                val address = it.getString(0) ?: continue
                val body = it.getString(1) ?: continue
                val date = it.getLong(2)
                if (senderIds.any { id -> address.contains(id, ignoreCase = true) }) {
                    momoSms.add(Pair(address, body))
                }
            }
        }

        val total = momoSms.size
        if (total == 0) {
            onProgress(0, 0)
            return 0
        }

        var queued = 0
        momoSms.forEachIndexed { idx, sms ->
            val hash = HashUtils.sha256(agentId, sms.second)
            val insertResult = dao.insertIfNotExists(
                SmsQueueEntity(
                    smsHash = hash,
                    agentId = agentId,
                    rawSms = sms.second,
                    sender = sms.first,
                    receivedAt = System.currentTimeMillis(), // Approximate if backfilling
                    status = SmsStatus.PENDING.name
                )
            )
            if (insertResult != -1L) queued++
            onProgress(idx + 1, total)
        }

        return queued
    }

    suspend fun uploadPendingBatch(agentId: String): Int {
        val batch = dao.getPendingBatch(50)
        if (batch.isEmpty()) return 0

        val batchJson = buildJsonArray {
            batch.forEach { sms ->
                add(buildJsonObject {
                    put("raw_sms", sms.rawSms)
                    put("sms_hash", sms.smsHash)
                    put("sender", sms.sender)
                    put("received_at", Instant.ofEpochMilli(sms.receivedAt).toString())
                })
            }
        }

        val requestBody = buildJsonObject {
            put("agent_id", agentId)
            put("batch", batchJson)
        }

        return try {
            invokeParseSms(requestBody.toString())
            val ids = batch.map { it.id }
            dao.markSynced(ids)
            batch.size
        } catch (e: Exception) {
            batch.forEach { sms ->
                val newStatus = if (sms.retries >= 4) SmsStatus.FAILED.name else SmsStatus.PENDING.name
                dao.updateStatus(sms.id, newStatus, e.message)
            }
            0
        }
    }

    private fun invokeParseSms(jsonBody: String) {
        val prefs = PrefsManager.getEncryptedPrefs(context)
        val supabaseUrl = prefs.getString("supabase_url", null)
            ?: throw IllegalStateException("Missing Supabase URL")
        val anonKey = prefs.getString("supabase_anon_key", null)
            ?: throw IllegalStateException("Missing Supabase anon key")
        val accessToken = prefs.getString("access_token", null)
            ?: throw IllegalStateException("Missing Supabase access token")

        val endpoint = "${supabaseUrl.trimEnd('/')}/functions/v1/parse-sms"
        val body = jsonBody.toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("apikey", anonKey)
            .addHeader("Authorization", "Bearer $accessToken")
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()

        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                val responseBody = response.body?.string()
                throw IllegalStateException(
                    "parse-sms failed (${response.code}): ${responseBody ?: response.message}"
                )
            }
        }
    }

    fun observePendingCount(): Flow<Int> = dao.observePendingCount()
    fun observeFailedCount(): Flow<Int> = dao.observeFailedCount()
    suspend fun retryAllFailed() = dao.retryAllFailed()
    suspend fun clearSynced() = dao.clearSynced()
}
