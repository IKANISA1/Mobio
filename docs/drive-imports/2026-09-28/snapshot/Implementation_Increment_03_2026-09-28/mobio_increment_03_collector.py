#!/usr/bin/env python3
# Mobio Increment 03: institutional collector delivery hardening.
# Authored 2026-09-28. NOT executed, compiled, installed, or deployed in this session.
# Run with Python 3.10+. This transport file may contain a UTF-8 BOM/CRLF.
from __future__ import annotations
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile


BASE = 'apps/momobio_sms_bridge/'
JAVA = BASE + 'app/src/main/java/com/momobio/app/'
TEST = BASE + 'app/src/test/java/com/momobio/app/'
DEVICE_TEST = BASE + 'app/src/androidTest/java/com/momobio/app/'
FILES: dict[str, str] = {}


FILES[JAVA + 'ReceiptAdmissionPolicy.kt'] = r'''package com.momobio.app


import android.content.Context
import java.security.MessageDigest
import java.util.Locale
import org.json.JSONObject


/** Local minimization only. A sender string or a phrase is NOT proof of payment. */
class ReceiptAdmissionPolicy private constructor(
    val version: String,
    private val rules: List<Rule>,
    val fingerprint: String,
) {
    data class Rule(val sender: String, val phrases: List<String>)


    fun admits(message: MomoSms): Boolean {
        if (message.receivedAtMillis <= 0L || message.sender.length > 64 ||
            message.body.toByteArray(Charsets.UTF_8).size > MAX_BODY_BYTES ||
            !validHash(message)) return false
        val sender = canonical(message.sender)
        val body = canonical(message.body)
        return rules.any { it.sender == sender && it.phrases.all(body::contains) }
    }


    companion object {
        const val NOTICE_VERSION = "collector-receipts-2026-09-28"
        const val MAX_BODY_BYTES = 16 * 1024
        const val NOTICE = "This is for a dedicated institutional mobile-money SIM, not a personal SMS inbox. " +
            "Only new messages matching the configured sender and all required receipt phrases are admitted. " +
            "Their full receipt text, sender and timestamp are uploaded to the configured Mobio backend and its parsing processor. " +
            "This can include payer and financial details. Delivery acknowledgement is not payment confirmation. " +
            "Previously queued messages are reviewed against this filter; malformed or excluded legacy records stay in local quarantine, not the upload queue. " +
            "Pause stops new collection and requests; a request already in flight may finish. " +
            "The operator must approve the actual filter, processor, retention and privacy notice before deployment."
        private const val PREFS = "mobio_collector_policy_v1"
        private val hashPattern = Regex("[a-f0-9]{64}")
        private fun canonical(value: String) = value.trim().lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ")
        internal fun digest(value: String): String = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        internal fun validHash(message: MomoSms): Boolean = hashPattern.matches(message.messageHash) &&
            MomoSms(message.sender, message.body, message.receivedAtMillis).messageHash == message.messageHash


        fun parse(raw: String): ReceiptAdmissionPolicy {
            require(raw.toByteArray(Charsets.UTF_8).size in 1..32_768) { "Invalid policy size" }
            val root = JSONObject(raw)
            require(root.keys().asSequence().toSet() == setOf("version", "rules")) { "Invalid policy fields" }
            val version = (root.opt("version") as? String)?.trim().orEmpty()
            require(Regex("[A-Za-z0-9_.-]{1,80}").matches(version)) { "A policy version is required" }
            val rows = root.getJSONArray("rules")
            require(rows.length() in 1..20) { "Configure 1 to 20 receipt rules" }
            val rules = (0 until rows.length()).map { i ->
                val row = rows.getJSONObject(i)
                require(row.keys().asSequence().toSet() == setOf("sender", "contains_all")) { "Invalid rule fields" }
                val senderText = row.opt("sender") as? String ?: error("Sender must be text")
                require(senderText.isNotBlank() && senderText.length <= 64 && senderText.none { it.code < 32 }) { "Invalid sender" }
                val terms = row.getJSONArray("contains_all")
                require(terms.length() in 1..6) { "Receipt phrases are required" }
                val phrases = (0 until terms.length()).map { j ->
                    val text = terms.opt(j) as? String ?: error("Receipt phrases must be text")
                    require(text.trim().length in 3..120 && text.none { it.code < 32 }) { "Invalid receipt phrase" }
                    canonical(text)
                }
                Rule(canonical(senderText), phrases)
            }
            require(rules.map { it.sender }.toSet().size == rules.size) { "Duplicate sender rule" }
            return ReceiptAdmissionPolicy(version, rules, digest(raw.trim()))
        }


        fun savedJson(context: Context): String = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("policy_json", "").orEmpty()


        fun active(context: Context): ReceiptAdmissionPolicy? = try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val policy = parse(prefs.getString("policy_json", "").orEmpty())
            if (prefs.getBoolean("paused", true) ||
                prefs.getString("notice_version", null) != NOTICE_VERSION ||
                prefs.getString("consented_policy", null) != policy.fingerprint) null else policy
        } catch (_: Exception) { null }


        fun saveAndConsent(context: Context, raw: String, explicitlyAccepted: Boolean) {
            require(explicitlyAccepted) { "Explicit institutional-device consent is required" }
            val policy = parse(raw)
            check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("policy_json", raw.trim()).putString("consented_policy", policy.fingerprint)
                .putString("notice_version", NOTICE_VERSION).putLong("accepted_at", System.currentTimeMillis())
                .putBoolean("paused", false).commit()) { "Unable to save collector policy" }
        }


        fun pause(context: Context) {
            check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("paused", true).commit()) { "Unable to pause collector" }
        }


        fun recordCaptureFailure(context: Context) {
            // Best effort: completely full/corrupt storage can also prevent this diagnostic.
            runCatching { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("capture_failure_unresolved", true).apply() }
        }
        fun hasCaptureFailure(context: Context): Boolean = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean("capture_failure_unresolved", false)
    }
}
'''


FILES[JAVA + 'CollectorRetryPolicy.kt'] = r'''package com.momobio.app


import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.ThreadLocalRandom


/** Pure timing policy. Persist its result once; do not recompute it in every caller. */
object CollectorRetryPolicy {
    fun retryAfterMillis(raw: String?, nowMillis: Long): Long {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return 0L
        if (text.all { it in '0'..'9' }) {
            val seconds = text.toLongOrNull() ?: return Long.MAX_VALUE
            return if (seconds > Long.MAX_VALUE / 1000L) Long.MAX_VALUE else seconds * 1000L
        }
        return try {
            val target = ZonedDateTime.parse(text, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli()
            if (target <= nowMillis) 0L else target - nowMillis
        } catch (_: Exception) { 0L }
    }


    fun delayMillis(failures: Int, serverDelay: Long = 0L, jitter: Int = ThreadLocalRandom.current().nextInt(1001)): Long {
        val base = minOf(30_000L * (1L shl (failures - 1).coerceIn(0, 6)), 1_800_000L)
        val randomized = minOf(1_800_000L, base + base / 4L * jitter.coerceIn(0, 1000) / 1000L)
        return maxOf(randomized, serverDelay.coerceAtLeast(0L))
    }


    fun saturatedAdd(now: Long, delay: Long): Long {
        require(now >= 0L && delay >= 0L)
        return if (delay > Long.MAX_VALUE - now) Long.MAX_VALUE else now + delay
    }
}
'''


FILES[JAVA + 'DurableSmsQueue.kt'] = r'''package com.momobio.app


import android.content.ContentValues
import android.content.Context
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.database.sqlite.SQLiteOpenHelper
import android.os.SystemClock
import android.provider.Settings
import java.io.Closeable
import java.io.File
import java.util.UUID


interface CollectorClock {
    fun wallMillis(): Long
    fun elapsedMillis(): Long
    fun bootId(): Int
}


private class AndroidCollectorClock(private val context: Context) : CollectorClock {
    override fun wallMillis() = System.currentTimeMillis()
    override fun elapsedMillis() = SystemClock.elapsedRealtime()
    override fun bootId(): Int = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
        .also { check(it >= 0) { "Boot identity unavailable; upload lease cannot be proven" } }
}


data class CollectorQueueSnapshot(
    val pending: Int, val quarantine: Int, val bytes: Long,
    val oldestQueuedAt: Long?, val lastAcknowledgedAt: Long?,
    val nextAttemptAt: Long, val lastStatus: String,
)


data class CollectorBatchLease internal constructor(
    val token: String, val boot: Int, val untilElapsed: Long,
    val messages: List<MomoSms>,
)


/**
 * Private SQLite queue. All public mutations are transactional and throw on storage failure.
 * Unacknowledged/quarantined payloads are never evicted to make room. Capacity exhaustion
 * is a reconciliation incident, not a successful capture. Run this class off the UI thread.
 */
class DurableSmsQueue(
    context: Context,
    databaseName: String = "collector-receipts-v1.sqlite",
    private val legacyPreferencesName: String = "momo_sms_queue",
    private val maxRecords: Int = 10_000,
    private val maxPayloadBytes: Long = 32L * 1024 * 1024,
    private val clock: CollectorClock = AndroidCollectorClock(context.applicationContext),
) : Closeable {
    private val app = context.applicationContext
    private val helper: QueueDb
    init {
        require(Regex("[A-Za-z0-9_.-]{1,120}").matches(databaseName) && databaseName != "." && databaseName != "..")
        require(maxRecords in 1..100_000 && maxPayloadBytes in 1024..134_217_728L)
        helper = QueueDb(app, File(app.noBackupFilesDir, databaseName).absolutePath)
        helper.setWriteAheadLoggingEnabled(true)
    }


    private class QueueDb(context: Context, path: String) : SQLiteOpenHelper(
        context, path, null, 1,
        DatabaseErrorHandler { throw SQLiteException("Queue corrupt; preserve files for authorized reconciliation") },
    ) {
        override fun onConfigure(db: SQLiteDatabase) {
            super.onConfigure(db)
            db.execSQL("PRAGMA synchronous=FULL")
            db.execSQL("PRAGMA busy_timeout=5000")
        }
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""CREATE TABLE receipts (
                hash TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL,
                payload_bytes INTEGER NOT NULL CHECK(payload_bytes >= 0),
                queued_at INTEGER NOT NULL, received_at INTEGER,
                state TEXT NOT NULL CHECK(state IN ('pending','quarantine')), reason TEXT NOT NULL
            )""")
            db.execSQL("CREATE INDEX receipts_pending_order ON receipts(state,queued_at,hash)")
            db.execSQL("CREATE TABLE acknowledgements (hash TEXT PRIMARY KEY NOT NULL, acknowledged_at INTEGER NOT NULL)")
            db.execSQL("CREATE INDEX acknowledgements_age ON acknowledgements(acknowledged_at)")
            db.execSQL("CREATE TABLE metadata (key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)")
            db.execSQL("""CREATE TABLE runtime (
                id INTEGER PRIMARY KEY CHECK(id=1), lease_token TEXT, lease_boot INTEGER,
                lease_until INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0,
                failures INTEGER NOT NULL DEFAULT 0, last_ack INTEGER, last_status TEXT NOT NULL DEFAULT 'never_contacted'
            )""")
            db.execSQL("INSERT INTO runtime(id) VALUES(1)")
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            throw SQLiteException("Explicit lossless queue upgrade required")
        }
        override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            throw SQLiteException("Queue downgrade is not supported")
        }
    }


    private inline fun <T> transaction(action: (SQLiteDatabase) -> T): T {
        val db = helper.writableDatabase
        db.beginTransactionNonExclusive()
        return try { action(db).also { db.setTransactionSuccessful() } } finally { db.endTransaction() }
    }
    private data class Budget(var records: Int, var bytes: Long)
    private fun budget(db: SQLiteDatabase) = db.rawQuery("SELECT count(*),coalesce(sum(payload_bytes),0) FROM receipts", null).use {
        check(it.moveToFirst()); Budget(it.getInt(0), it.getLong(1))
    }
    private fun exists(db: SQLiteDatabase, table: String, hash: String): Boolean {
        require(table == "receipts" || table == "acknowledgements")
        return db.rawQuery("SELECT 1 FROM $table WHERE hash=?", arrayOf(hash)).use { it.moveToFirst() }
    }
    private fun insertReceipt(db: SQLiteDatabase, budget: Budget, hash: String, payload: String,
                              receivedAt: Long?, state: String, reason: String): Boolean {
        if (exists(db, "receipts", hash) || (state == "pending" && exists(db, "acknowledgements", hash))) return false
        val bytes = payload.toByteArray(Charsets.UTF_8).size.toLong()
        check(budget.records < maxRecords && bytes <= maxPayloadBytes - budget.bytes) { "Queue capacity exhausted; reconciliation required" }
        val values = ContentValues().apply {
            put("hash", hash); put("payload", payload); put("payload_bytes", bytes)
            put("queued_at", clock.wallMillis()); put("received_at", receivedAt)
            put("state", state); put("reason", reason)
        }
        db.insertOrThrow("receipts", null, values)
        budget.records++; budget.bytes += bytes
        return true
    }
    private fun maintainAcknowledgements(db: SQLiteDatabase) {
        // Engineering defaults, subject to the operator's retention approval.
        // Financial duplicate protection must also remain authoritative on the server.
        val cutoff = (clock.wallMillis() - ACK_RETENTION_MILLIS).coerceAtLeast(0L)
        db.delete("acknowledgements", "acknowledged_at < ?", arrayOf(cutoff.toString()))
        db.execSQL("DELETE FROM acknowledgements WHERE hash IN (SELECT hash FROM acknowledgements ORDER BY acknowledged_at DESC,hash DESC LIMIT -1 OFFSET 100000)")
    }


    fun enqueue(messages: List<MomoSms>, policy: ReceiptAdmissionPolicy): Int = transaction { db ->
        require(messages.size <= 50) { "Capture batch too large" }
        maintainAcknowledgements(db)
        val capacity = budget(db)
        var inserted = 0
        for (message in messages) {
            if (policy.admits(message) && insertReceipt(db, capacity, message.messageHash,
                    message.toJson(), message.receivedAtMillis, "pending", "")) inserted++
        }
        inserted
    }


    /** Only call after obtaining an active operator policy, outside the broadcast deadline. */
    fun migrateLegacy(policy: ReceiptAdmissionPolicy) {
        val prefs = app.getSharedPreferences(legacyPreferencesName, Context.MODE_PRIVATE)
        synchronized(legacyLock) {
            val pending = prefs.getString("pending", "").orEmpty()
            val uploaded = prefs.getString("uploaded", "").orEmpty()
            val totalBytes = pending.toByteArray(Charsets.UTF_8).size.toLong() + uploaded.toByteArray(Charsets.UTF_8).size
            check(totalBytes <= maxPayloadBytes) { "Legacy queue exceeds migration budget; original retained" }
            val signature = ReceiptAdmissionPolicy.digest(pending + "\u0000" + uploaded)
            transaction { db ->
                val previous = db.rawQuery("SELECT value FROM metadata WHERE key='legacy_migration'", null)
                    .use { if (it.moveToFirst()) it.getString(0) else null }
                if (previous != null) {
                    check((pending.isEmpty() && uploaded.isEmpty()) || previous == signature) {
                        "Legacy queue changed after migration; preserve both stores for reconciliation"
                    }
                } else {
                    val capacity = budget(db)
                    val acknowledged = uploaded.lineSequence().filter { it.isNotBlank() }.toList()
                    val records = pending.lineSequence().filter { it.isNotBlank() }.toList()
                    check(acknowledged.size <= 100_000 && records.size <= maxRecords) { "Legacy queue row budget exceeded" }
                    for ((index, line) in acknowledged.withIndex()) {
                        if (Regex("[a-f0-9]{64}").matches(line)) {
                            db.insertWithOnConflict("acknowledgements", null, ContentValues().apply {
                                put("hash", line); put("acknowledged_at", clock.wallMillis())
                            }, SQLiteDatabase.CONFLICT_IGNORE)
                        } else insertReceipt(db, capacity, ReceiptAdmissionPolicy.digest("legacy-ack:$index:$line"),
                            line, null, "quarantine", "malformed_legacy_ack")
                    }
                    for ((index, line) in records.withIndex()) {
                        val message = MomoSms.fromJson(line)
                        if (message != null && ReceiptAdmissionPolicy.validHash(message)) {
                            if (!exists(db, "acknowledgements", message.messageHash)) {
                                val admitted = policy.admits(message)
                                insertReceipt(db, capacity, message.messageHash, line, message.receivedAtMillis,
                                    if (admitted) "pending" else "quarantine", if (admitted) "" else "legacy_policy_review")
                            }
                        } else insertReceipt(db, capacity, ReceiptAdmissionPolicy.digest("legacy-pending:$index:$line"),
                            line, null, "quarantine", "malformed_legacy_record")
                    }
                    db.insertOrThrow("metadata", null, ContentValues().apply {
                        put("key", "legacy_migration"); put("value", signature)
                    })
                }
            }
            // Never erase the source before the SQLite transaction has committed.
            if (pending.isNotEmpty() || uploaded.isNotEmpty()) {
                check(prefs.getString("pending", "").orEmpty() == pending && prefs.getString("uploaded", "").orEmpty() == uploaded) {
                    "Legacy source changed during migration; original retained"
                }
                check(prefs.edit().remove("pending").remove("uploaded").commit()) { "Legacy cleanup failed; retry migration safely" }
            }
        }
    }


    fun claim(policy: ReceiptAdmissionPolicy): CollectorBatchLease? = transaction { db ->
        val nowElapsed = clock.elapsedMillis()
        val boot = clock.bootId()
        val blocked = db.rawQuery("SELECT lease_token,lease_boot,lease_until,next_attempt FROM runtime WHERE id=1", null).use {
            check(it.moveToFirst())
            (!it.isNull(0) && it.getInt(1) == boot && it.getLong(2) > nowElapsed) || it.getLong(3) > clock.wallMillis()
        }
        if (blocked) return@transaction null
        val selected = mutableListOf<MomoSms>()
        var requestBytes = 32
        db.rawQuery("SELECT hash,payload FROM receipts WHERE state='pending' ORDER BY queued_at,hash LIMIT 200", null).use { cursor ->
            while (cursor.moveToNext()) {
                val hash = cursor.getString(0)
                if (exists(db, "acknowledgements", hash)) {
                    db.delete("receipts", "hash=? AND state='pending'", arrayOf(hash))
                    continue
                }
                val message = MomoSms.fromJson(cursor.getString(1))
                if (message == null || message.messageHash != hash || !policy.admits(message)) {
                    db.update("receipts", ContentValues().apply { put("state", "quarantine"); put("reason", "current_policy_or_integrity_review") }, "hash=?", arrayOf(hash))
                    continue
                }
                val size = message.toJson().toByteArray(Charsets.UTF_8).size + 1
                if (selected.size >= BATCH_SIZE || requestBytes + size > MAX_REQUEST_BYTES) break
                selected += message; requestBytes += size
            }
        }
        if (selected.isEmpty()) return@transaction null
        val lease = CollectorBatchLease(UUID.randomUUID().toString(), boot, nowElapsed + LEASE_MILLIS, selected.toList())
        db.update("runtime", ContentValues().apply {
            put("lease_token", lease.token); put("lease_boot", lease.boot); put("lease_until", lease.untilElapsed)
            put("last_status", "sending")
        }, "id=1", null)
        lease
    }


    /** Fenced acknowledgement: a timed-out old worker cannot erase a newer worker's data. */
    fun finish(lease: CollectorBatchLease, result: UploadResult): Boolean = transaction { db ->
        val current = db.rawQuery("SELECT lease_token,lease_boot,lease_until,failures FROM runtime WHERE id=1", null).use {
            check(it.moveToFirst())
            if (it.getString(0) != lease.token || it.getInt(1) != lease.boot || lease.boot != clock.bootId() ||
                it.getLong(2) <= clock.elapsedMillis()) null else it.getInt(3)
        } ?: return@transaction false
        val offered = lease.messages.map { it.messageHash }.toSet()
        require(offered.containsAll(result.uploadedHashes)) { "Foreign acknowledgement rejected" }
        require(!result.ok || result.uploadedHashes == offered) { "Incomplete acknowledgement cannot be successful" }
        for (hash in result.uploadedHashes) {
            db.insertWithOnConflict("acknowledgements", null, ContentValues().apply {
                put("hash", hash); put("acknowledged_at", clock.wallMillis())
            }, SQLiteDatabase.CONFLICT_REPLACE)
            db.delete("receipts", "hash=? AND state='pending'", arrayOf(hash))
        }
        maintainAcknowledgements(db)
        val failures = if (result.ok) 0 else (current + 1).coerceAtMost(30)
        val next = if (result.ok) 0L else if (!result.retryable) Long.MAX_VALUE else
            CollectorRetryPolicy.saturatedAdd(clock.wallMillis().coerceAtLeast(0L),
                CollectorRetryPolicy.delayMillis(failures, result.retryAfterMillis))
        db.update("runtime", ContentValues().apply {
            putNull("lease_token"); putNull("lease_boot"); put("lease_until", 0L)
            put("failures", failures); put("next_attempt", next)
            put("last_status", when {
                result.ok -> "acknowledged_not_payment_confirmation"
                !result.retryable -> "configuration_or_protocol_review_required"
                result.uploadedHashes.isNotEmpty() -> "partial_acknowledgement_retry_pending"
                else -> "delivery_retry_pending"
            })
            if (result.uploadedHashes.isNotEmpty()) put("last_ack", clock.wallMillis())
        }, "id=1", null)
        true
    }


    fun resetRetryAfterOperatorReview() = transaction { db ->
        // Does not break an active lease, discard receipt data, or override retryable server waits.
        db.update("runtime", ContentValues().apply { put("next_attempt", 0L); put("failures", 0) },
            "id=1 AND last_status='configuration_or_protocol_review_required'", null)
        Unit
    }


    fun snapshot(): CollectorQueueSnapshot = transaction { db ->
        var pending = 0; var review = 0; var bytes = 0L; var oldest: Long? = null
        db.rawQuery("SELECT state,count(*),coalesce(sum(payload_bytes),0),min(queued_at) FROM receipts GROUP BY state", null).use {
            while (it.moveToNext()) {
                if (it.getString(0) == "pending") { pending = it.getInt(1); oldest = if (it.isNull(3)) null else it.getLong(3) }
                else review += it.getInt(1)
                bytes += it.getLong(2)
            }
        }
        db.rawQuery("SELECT last_ack,next_attempt,last_status FROM runtime WHERE id=1", null).use {
            check(it.moveToFirst())
            CollectorQueueSnapshot(pending, review, bytes, oldest, if (it.isNull(0)) null else it.getLong(0), it.getLong(1), it.getString(2))
        }
    }
    override fun close() = helper.close()


    companion object {
        const val BATCH_SIZE = 10
        const val MAX_REQUEST_BYTES = 128 * 1024
        const val LEASE_MILLIS = 180_000L
        private const val ACK_RETENTION_MILLIS = 30L * 24 * 60 * 60 * 1000
        private val legacyLock = Any()
    }
}
'''


FILES[JAVA + 'UploadClient.kt'] = r'''package com.momobio.app


import android.util.Log
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean


/** ok means every submitted hash was acknowledged, never that a payment settled. */
data class UploadResult(
    val ok: Boolean,
    val uploadedHashes: Set<String> = emptySet(),
    val message: String,
    val retryAfterMillis: Long = 0L,
    val retryable: Boolean = true,
    val serverContacted: Boolean = false,
)


class UploadClient internal constructor(
    private val signHeaders: (ByteArray) -> Map<String, String>,
    private val supabaseUrl: String,
    private val anonKey: String,
    private val openConnection: (String) -> HttpURLConnection,
    private val logFailure: (String) -> Unit,
) {
    constructor(
        identity: CollectorIdentity,
        supabaseUrl: String = BuildConfig.SUPABASE_URL,
        anonKey: String = BuildConfig.SUPABASE_ANON_KEY,
    ) : this(identity::headers, supabaseUrl, anonKey,
        { URL(it).openConnection() as HttpURLConnection },
        { Log.e("MoMobioBridge", it) })


    @Volatile internal var canTransmit: () -> Boolean = { true }
    private val batchSize = 50 // Transport compatibility. The durable worker offers at most ten.


    fun upload(messages: List<MomoSms>, onUploaded: ((Set<String>) -> Unit)? = null): UploadResult {
        configurationError(supabaseUrl, anonKey)?.let { return UploadResult(false, message = it, retryable = false) }
        if (messages.isEmpty()) return UploadResult(true, message = "No new SMS; connectivity not checked")
        val endpoint = "${supabaseUrl.trim().trimEnd('/')}/functions/v1/momobio-sms-ingest"
        val uploaded = mutableSetOf<String>()
        for (chunk in messages.chunked(batchSize)) {
            if (!canTransmit()) return UploadResult(false, uploaded, "Collection paused or work stopped")
            val result = uploadBatch(endpoint, chunk)
            uploaded += result.uploadedHashes
            if (result.uploadedHashes.isNotEmpty()) {
                try { onUploaded?.invoke(result.uploadedHashes) }
                catch (error: Exception) {
                    logFailure("Queue acknowledgement failed: ${error.javaClass.simpleName}")
                    return UploadResult(false, uploaded.toSet(), "Server acknowledged ${uploaded.size}/${messages.size}; local queue save failed", serverContacted = true)
                }
            }
            if (!result.ok) return result.copy(uploadedHashes = uploaded.toSet(), message = "Uploaded ${uploaded.size}/${messages.size}; ${result.message}")
        }
        return UploadResult(true, uploaded.toSet(), "Uploaded ${uploaded.size}", serverContacted = true)
    }


    private fun uploadBatch(endpoint: String, messages: List<MomoSms>): UploadResult {
        val bytes = ("{\"messages\":[" + messages.joinToString(",") { it.toJson() } + "]}").toByteArray(Charsets.UTF_8)
        if (bytes.size > MAX_REQUEST_BYTES || messages.map { it.messageHash }.toSet().size != messages.size) {
            return UploadResult(false, message = "Request requires local review", retryable = false)
        }
        var connection: HttpURLConnection? = null
        val timedOut = AtomicBoolean(false)
        var contacted = false
        val deadline = Executors.newSingleThreadScheduledExecutor { action ->
            Thread(action, "collector-request-deadline").apply { isDaemon = true }
        }
        try {
            val active = openConnection(endpoint)
            connection = active
            val expiry = deadline.schedule({
                timedOut.set(true)
                runCatching { active.disconnect() }
            }, 90, TimeUnit.SECONDS)
            try {
                active.requestMethod = "POST"
                active.connectTimeout = 15_000
                active.readTimeout = 60_000
                active.instanceFollowRedirects = false
                active.doOutput = true
                active.setFixedLengthStreamingMode(bytes.size)
                active.setRequestProperty("content-type", "application/json")
                active.setRequestProperty("apikey", anonKey)
                active.setRequestProperty("authorization", "Bearer $anonKey")
                for ((name, value) in signHeaders(bytes)) active.setRequestProperty(name, value)
                if (!canTransmit() || timedOut.get()) return UploadResult(false, message = "Collection paused or work stopped")
                active.outputStream.use { it.write(bytes) }
                val code = active.responseCode
                contacted = true
                if (timedOut.get()) return UploadResult(false, message = "Upload outcome unknown; safe retry pending", serverContacted = true)
                if (code !in 200..299) {
                    // Never read/log untrusted provider error bodies or follow a redirect with signed credentials.
                    logFailure("Upload failed $code")
                    val retryable = code in setOf(401, 403, 408, 409, 425, 429) || code in 500..599
                    val delay = maxOf(
                        CollectorRetryPolicy.retryAfterMillis(active.getHeaderField("Retry-After"), System.currentTimeMillis()),
                        if (code == 401 || code == 403) 900_000L else 0L,
                    )
                    return UploadResult(false, message = when (code) {
                        401, 403 -> "Collector enrollment required"
                        409 -> "Retrying collector request"
                        429 -> "Sync limit reached; retrying later"
                        else -> "Upload failed $code"
                    }, retryAfterMillis = delay, retryable = retryable, serverContacted = true)
                }
                val declaredLength = active.getHeaderField("Content-Length")?.toLongOrNull()
                if (declaredLength != null && (declaredLength < 0L || declaredLength > MAX_RESPONSE_BYTES)) {
                    return UploadResult(false, message = "Response size requires review", retryable = false, serverContacted = true)
                }
                val responseText = active.inputStream.use { readBounded(it, timedOut) }
                if (timedOut.get()) return UploadResult(false, message = "Upload outcome unknown; safe retry pending", serverContacted = true)
                val response = JSONObject(responseText)
                val rows = response.optJSONArray("results")
                val expected = messages.map { it.messageHash }.toSet()
                val acknowledged = mutableSetOf<String>()
                val seen = mutableSetOf<String>()
                if (response.opt("success") == true && rows != null && rows.length() <= 100) {
                    for (index in 0 until rows.length()) {
                        val row = rows.optJSONObject(index) ?: continue
                        val hash = row.opt("message_hash") as? String ?: continue
                        val status = row.opt("status") as? String ?: continue
                        if (hash in expected) {
                            check(seen.add(hash)) { "Duplicate acknowledgement row" }
                            if (status in ACK_STATUSES) acknowledged += hash
                        }
                    }
                }
                return UploadResult(acknowledged == expected, acknowledged,
                    if (acknowledged == expected) "Uploaded ${acknowledged.size}" else "Incomplete server acknowledgement",
                    serverContacted = true)
            } finally { expiry.cancel(false) }
        } catch (error: Exception) {
            logFailure("Upload failed: ${error.javaClass.simpleName}")
            return UploadResult(false, message = "Sync unavailable; messages remain queued", serverContacted = contacted)
        } finally {
            deadline.shutdownNow()
            connection?.disconnect()
        }
    }


    private fun readBounded(input: InputStream, timedOut: AtomicBoolean): String {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            check(!timedOut.get()) { "Response deadline reached" }
            val count = input.read(buffer)
            if (count < 0) break
            check(count <= MAX_RESPONSE_BYTES - output.size()) { "Response exceeds limit" }
            output.write(buffer, 0, count)
        }
        return output.toString(Charsets.UTF_8.name())
    }


    companion object {
        private const val MAX_REQUEST_BYTES = 128 * 1024
        private const val MAX_RESPONSE_BYTES = 256 * 1024
        private val ACK_STATUSES = setOf("matched", "duplicate", "unmatched", "ambiguous", "ignored", "accepted")
        fun configurationError(url: String, key: String): String? {
            if (url.isBlank() || key.isBlank()) return "Upload config missing"
            return try {
                val uri = URI(url.trim())
                if (uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null ||
                    uri.rawQuery != null || uri.rawFragment != null || uri.path !in listOf("", "/") ||
                    key.any { it == '\r' || it == '\n' }) "HTTPS origin configuration required" else null
            } catch (_: Exception) { "HTTPS origin configuration required" }
        }
    }
}
'''


FILES[JAVA + 'CollectorSyncCoordinator.kt'] = r'''package com.momobio.app


import android.Manifest
import android.content.Context
import android.content.pm.PackageManager


class CollectorSyncCoordinator(context: Context) {
    private val app = context.applicationContext
    data class Outcome(val retry: Boolean, val pending: Boolean, val message: String, val mayContinue: Boolean = false)


    fun runOnce(shouldStop: () -> Boolean = { false }): Outcome {
        val policy = ReceiptAdmissionPolicy.active(app) ?: return Outcome(false, false, "Policy or consent required; collection paused")
        if (app.checkSelfPermission(Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
            return Outcome(false, false, "SMS permission required")
        }
        UploadClient.configurationError(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY)?.let {
            return Outcome(false, false, it)
        }
        if (shouldStop()) return Outcome(false, false, "Work stopped")
        return DurableSmsQueue(app).use { queue ->
            queue.migrateLegacy(policy)
            val lease = queue.claim(policy)
            if (lease == null) {
                val state = queue.snapshot()
                val manualReview = state.nextAttemptAt == Long.MAX_VALUE
                return@use Outcome(state.pending > 0 && !manualReview, state.pending > 0,
                    if (manualReview) "Operator review required" else "Idle, leased, or awaiting retry; no connection check")
            }
            val client = UploadClient(CollectorIdentity(app))
            client.canTransmit = {
                !shouldStop() && ReceiptAdmissionPolicy.active(app)?.fingerprint == policy.fingerprint
            }
            val result = client.upload(lease.messages)
            val saved = queue.finish(lease, result)
            val pending = queue.snapshot().pending > 0
            Outcome(!saved || (!result.ok && result.retryable), pending,
                if (saved) result.message else "Stale upload result; queue retained",
                mayContinue = saved && result.ok && pending)
        }
    }
}
'''


FILES[JAVA + 'BridgeSyncWorker.kt'] = r'''package com.momobio.app


import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters


class BridgeSyncWorker(context: Context, workerParams: WorkerParameters) : Worker(context, workerParams) {
    override fun doWork(): Result = try {
        val outcome = CollectorSyncCoordinator(applicationContext).runOnce { isStopped }
        if (outcome.retry) Result.retry() else {
            if (outcome.mayContinue && !isStopped) BridgeSupervisor.enqueueContinuation(applicationContext)
            Result.success()
        }
    } catch (error: Exception) {
        ReceiptAdmissionPolicy.recordCaptureFailure(applicationContext)
        Log.e("MoMobioBridge", "Collector delivery blocked: ${error.javaClass.simpleName}")
        Result.retry()
    }
}
'''


FILES[JAVA + 'BridgeSupervisor.kt'] = r'''package com.momobio.app


import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit


/** WorkManager owns network scheduling. UI and broadcasts never start competing upload loops. */
object BridgeSupervisor {
    private const val periodicWorkName = "mo-mobio-sms-bridge-periodic-sync"
    private const val immediateWorkName = "mo-mobio-sms-bridge-immediate-sync"
    private fun enabled(context: Context) = ReceiptAdmissionPolicy.active(context.applicationContext) != null
    private fun constraints() = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()


    fun start(context: Context) { schedule(context); enqueueImmediate(context) }
    fun schedule(context: Context) {
        if (!enabled(context)) return
        val request = PeriodicWorkRequestBuilder<BridgeSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints()).setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            periodicWorkName, ExistingPeriodicWorkPolicy.KEEP, request)
    }
    fun enqueueImmediate(context: Context) {
        if (!enabled(context)) return
        val request = OneTimeWorkRequestBuilder<BridgeSyncWorker>().setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(immediateWorkName, ExistingWorkPolicy.KEEP, request)
    }
    internal fun enqueueContinuation(context: Context) {
        if (!enabled(context)) return
        val request = OneTimeWorkRequestBuilder<BridgeSyncWorker>().setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(immediateWorkName, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
    }
    fun pause(context: Context) {
        ReceiptAdmissionPolicy.pause(context.applicationContext)
        WorkManager.getInstance(context.applicationContext).apply {
            cancelUniqueWork(periodicWorkName); cancelUniqueWork(immediateWorkName)
        }
    }
}
'''


FILES[JAVA + 'BridgeForegroundService.kt'] = r'''package com.momobio.app


import android.app.Service
import android.content.Intent
import android.os.IBinder


/** Not registered in the new manifest. Kept as an inert compatibility class, not an always-on service. */
class BridgeForegroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
'''


FILES[JAVA + 'SmsReceiver.kt'] = r'''package com.momobio.app


import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log


class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val app = context.applicationContext
        val policy = ReceiptAdmissionPolicy.active(app) ?: return
        val pending = goAsync()
        Thread {
            try {
                // Recheck consent after thread dispatch, before any queue mutation.
                if (ReceiptAdmissionPolicy.active(app)?.fingerprint != policy.fingerprint) return@Thread
                val receipts = decodeIncomingSms(intent).filter(policy::admits)
                if (receipts.isEmpty()) return@Thread
                DurableSmsQueue(app).use { it.enqueue(receipts, policy) }
                BridgeSupervisor.enqueueImmediate(app)
            } catch (error: Exception) {
                ReceiptAdmissionPolicy.recordCaptureFailure(app)
                Log.e("MoMobioBridge", "Receipt capture failed: ${error.javaClass.simpleName}")
            } finally { pending.finish() }
        }.start()
    }
}
'''


FILES[JAVA + 'CollectorUiController.kt'] = r'''package com.momobio.app


import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.View
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean


/** UI schedules work and reads health; it never performs uploads. */
class CollectorUiController(
    private val activity: Activity,
    private val status: TextView,
    private val details: TextView,
    private val enableButton: Button,
) : AutoCloseable {
    private val app = activity.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val reading = AtomicBoolean(false)
    private var resumed = false
    private var generation = 0
    private var dialog: AlertDialog? = null
    private val tick = object : Runnable {
        override fun run() { if (resumed) { refresh(); handler.postDelayed(this, 5_000) } }
    }


    fun resumeUi() {
        resumed = true; generation++
        handler.removeCallbacks(tick); handler.post(tick)
    }
    fun pauseUi() {
        resumed = false; generation++; handler.removeCallbacksAndMessages(null)
        dialog?.dismiss(); dialog = null
    }
    override fun close() { pauseUi(); executor.shutdownNow() }


    fun requestSync(): Boolean {
        if (ReceiptAdmissionPolicy.active(app) == null) { refresh(); return false }
        BridgeSupervisor.start(app)
        refresh()
        return true
    }
    fun refresh() {
        if (executor.isShutdown || !reading.compareAndSet(false, true)) return
        val expected = generation
        executor.execute {
            val snapshot = runCatching { DurableSmsQueue(app).use { it.snapshot() } }
            reading.set(false) // Never strand polling when lifecycle callbacks discard the UI result.
            val policy = ReceiptAdmissionPolicy.active(app)
            val permission = app.checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
            val config = UploadClient.configurationError(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY)
            val captureFailure = ReceiptAdmissionPolicy.hasCaptureFailure(app)
            handler.post {
                if (!resumed || expected != generation || activity.isFinishing || activity.isDestroyed) return@post
                val state = snapshot.getOrNull()
                enableButton.visibility = View.VISIBLE
                enableButton.text = if (policy == null) "Configure receipt collection" else "Review collection settings"
                status.setTextColor(if (state == null || captureFailure || state.quarantine > 0 || config != null)
                    android.graphics.Color.rgb(255, 94, 67) else android.graphics.Color.rgb(136, 133, 240))
                status.text = when {
                    state == null -> "Storage unavailable"
                    policy == null -> "Collection paused"
                    !permission -> "Permission needed"
                    config != null -> "Configuration needed"
                    captureFailure || state.quarantine > 0 -> "Reconciliation needed"
                    state.nextAttemptAt == Long.MAX_VALUE -> "Operator review required"
                    state.pending > 0 -> "Delivery pending"
                    state.lastAcknowledgedAt == null -> "Awaiting first acknowledgement"
                    else -> "No pending receipts"
                }
                if (state == null) {
                    details.text = "Queue count and delivery state are unknown. Do not clear app storage. Ask the operator to preserve and inspect it."
                } else {
                    val lastAck = state.lastAcknowledgedAt?.let { DateFormat.getDateTimeInstance().format(Date(it)) } ?: "None observed"
                    val oldest = state.oldestQueuedAt?.let { DateFormat.getDateTimeInstance().format(Date(it)) } ?: "None"
                    details.text = "Pending: ${state.pending} | Review: ${state.quarantine}\nOldest queued: $oldest\nLast delivery acknowledgement: $lastAck\n" +
                        (config?.let { "$it\n" } ?: "") +
                        (if (captureFailure) "An unresolved capture/storage failure requires reconciliation.\n" else "") +
                        "Server enrollment/revocation is not continuously verified. Acknowledgement is not payment confirmation."
                }
            }
        }
    }


    fun configure() {
        if (activity.isFinishing || activity.isDestroyed) return
        val input = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            minLines = 5
            maxLines = 10
            setText(ReceiptAdmissionPolicy.savedJson(app))
            hint = "Paste the operator-approved JSON policy. No sender or merchant is preselected."
        }
        val accepted = CheckBox(activity).apply {
            text = "This is an authorized institutional SIM. I have read the notice and the operator-approved data handling terms."
        }
        val notice = TextView(activity).apply { text = ReceiptAdmissionPolicy.NOTICE }
        val errorView = TextView(activity)
        val content = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 16, 24, 16)
            addView(notice); addView(input); addView(accepted); addView(errorView)
        }
        dialog?.dismiss()
        val currentDialog = AlertDialog.Builder(activity).setTitle("Institutional receipt collection")
            .setView(ScrollView(activity).apply { addView(content) })
            .setNegativeButton("Cancel", null).setPositiveButton("Save and enable", null).create()
        dialog = currentDialog
        currentDialog.setOnShowListener {
            currentDialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val raw = input.text.toString()
                try { ReceiptAdmissionPolicy.parse(raw); require(accepted.isChecked) }
                catch (_: Exception) {
                    errorView.text = "Enter a valid approved policy and explicitly accept the institutional-device notice."
                    return@setOnClickListener
                }
                currentDialog.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = false
                val expected = generation
                executor.execute {
                    val saved = runCatching {
                        DurableSmsQueue(app).use { it.snapshot() } // Initialize private SQLite before enabling capture.
                        ReceiptAdmissionPolicy.saveAndConsent(app, raw, true)
                    }.isSuccess
                    handler.post {
                        if (!resumed || expected != generation || activity.isDestroyed) return@post
                        if (!saved) {
                            errorView.text = "Settings could not be saved. Collection remains unchanged."
                            currentDialog.getButton(AlertDialog.BUTTON_POSITIVE).isEnabled = true
                        } else {
                            currentDialog.dismiss(); dialog = null
                            if (app.checkSelfPermission(Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
                                activity.requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), 7)
                            } else requestSync()
                            refresh()
                        }
                    }
                }
            }
        }
        currentDialog.show()
    }


    fun pauseCollection() {
        if (executor.isShutdown) return
        executor.execute {
            val paused = runCatching { BridgeSupervisor.pause(app) }.isSuccess
            handler.post {
                if (!resumed || activity.isDestroyed) return@post
                details.text = if (paused) "New collection and scheduled work paused. An already-sent request may still finish." else "Pause could not be saved; operator action required."
                refresh()
            }
        }
    }
    fun retryAfterReview() {
        if (executor.isShutdown) return
        dialog?.dismiss()
        dialog = AlertDialog.Builder(activity).setTitle("Retry after operator review")
            .setMessage("Confirm the configuration/enrollment issue was reviewed. This does not erase receipts, clear quarantine, override a server Retry-After deadline, or certify payments.")
            .setNegativeButton("Cancel", null).setPositiveButton("Retry") { _, _ ->
                executor.execute {
                    val ready = runCatching { DurableSmsQueue(app).use { it.resetRetryAfterOperatorReview() } }.isSuccess
                    if (ready) BridgeSupervisor.start(app)
                    handler.post { if (resumed && !activity.isDestroyed) refresh() }
                }
            }.show()
    }
}
'''


FILES[BASE + 'app/src/main/res/xml/collector_data_extraction_rules.xml'] = r'''<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup disableIfNoEncryptionCapabilities="true">
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </device-transfer>
</data-extraction-rules>
'''


FILES[BASE + 'docs/receipt-policy.synthetic-example.json'] = r'''{
  "version": "synthetic-tests-only-v1",
  "rules": [{"sender": "QA-RECEIPT", "contains_all": ["received", "transaction"]}]
}
'''


FILES[TEST + 'ReceiptAdmissionPolicyTest.kt'] = r'''package com.momobio.app


import org.junit.Assert.*
import org.junit.Test


class ReceiptAdmissionPolicyTest {
    private val json = """{"version":"qa-v1","rules":[{"sender":"QA-RECEIPT","contains_all":["received","transaction"]}]}"""
    private fun receipt(sender: String = "QA-RECEIPT", text: String = "Received synthetic funds. Transaction QA123") =
        MomoSms(sender, text, 1_800_000_000_000L)


    @Test fun configuredSenderAndAllPhrasesAreRequired() {
        val policy = ReceiptAdmissionPolicy.parse(json)
        assertTrue(policy.admits(receipt()))
        assertFalse(policy.admits(receipt("PERSONAL")))
        assertFalse(policy.admits(receipt(text = "Received a personal message")))
        assertFalse(policy.admits(receipt(text = "Transaction without receipt phrase")))
    }
    @Test fun normalizationIsLocaleStableButDoesNotUseSubstringSenderMatching() {
        val policy = ReceiptAdmissionPolicy.parse(json)
        assertTrue(policy.admits(receipt(" qa-receipt ", "RECEIVED\n synthetic TRANSACTION")))
        assertFalse(policy.admits(receipt("QA-RECEIPT-OTHER")))
    }
    @Test fun forgedHashAndOversizedMessagesAreRejected() {
        val policy = ReceiptAdmissionPolicy.parse(json)
        assertFalse(policy.admits(receipt().copy(messageHash = "a".repeat(64))))
        assertFalse(policy.admits(receipt(text = "received transaction " + "x".repeat(20_000))))
        assertFalse(policy.admits(MomoSms("QA-RECEIPT", "received transaction", 0)))
    }
    @Test fun invalidOrOverbroadPoliciesCannotBeInstalled() {
        val invalid = listOf("{}", "[]", json.replace("\"received\",\"transaction\"", ""),
            json.replace("QA-RECEIPT", ""), json.replace("\"rules\":", "\"extra\":true,\"rules\":"))
        invalid.forEach { value ->
            var rejected = false
            try { ReceiptAdmissionPolicy.parse(value) } catch (_: Exception) { rejected = true }
            assertTrue(value, rejected)
        }
    }
    @Test fun duplicateSendersAndRegexStyleShortcutsAreNotAcceptedAsWildcardRules() {
        val duplicate = """{"version":"qa","rules":[{"sender":"QA","contains_all":["received"]},{"sender":"qa","contains_all":["received"]}]}"""
        assertThrows(Exception::class.java) { ReceiptAdmissionPolicy.parse(duplicate) }
        val literal = ReceiptAdmissionPolicy.parse(json.replace("received", "rec.*ved"))
        assertFalse(literal.admits(receipt()))
    }
}
'''


FILES[TEST + 'CollectorRetryPolicyTest.kt'] = r'''package com.momobio.app


import org.junit.Assert.*
import org.junit.Test


class CollectorRetryPolicyTest {
    @Test fun secondsDateAndMissingRetryAfter() {
        assertEquals(60_000L, CollectorRetryPolicy.retryAfterMillis("60", 0L))
        assertEquals(0L, CollectorRetryPolicy.retryAfterMillis(null, 0L))
        assertEquals(0L, CollectorRetryPolicy.retryAfterMillis("invalid", 0L))
        val epoch = java.time.Instant.parse("2026-09-28T00:00:00Z").toEpochMilli()
        assertEquals(60_000L, CollectorRetryPolicy.retryAfterMillis("Mon, 28 Sep 2026 00:01:00 GMT", epoch))
        assertEquals(0L, CollectorRetryPolicy.retryAfterMillis("Mon, 28 Sep 2026 00:00:00 GMT", epoch + 1))
    }
    @Test fun retryAfterIsNeverClampedBelowServerInstruction() {
        assertEquals(7_200_000L, CollectorRetryPolicy.delayMillis(1, 7_200_000L, 0))
        assertEquals(Long.MAX_VALUE, CollectorRetryPolicy.retryAfterMillis("9".repeat(80), 0L))
    }
    @Test fun backoffIsBoundedAndHasDeterministicJitterSeam() {
        assertEquals(30_000L, CollectorRetryPolicy.delayMillis(1, 0, 0))
        assertEquals(37_500L, CollectorRetryPolicy.delayMillis(1, 0, 1000))
        assertEquals(60_000L, CollectorRetryPolicy.delayMillis(2, 0, 0))
        assertEquals(1_800_000L, CollectorRetryPolicy.delayMillis(30, 0, 1000))
    }
    @Test fun overflowCannotMakeRetryImmediatelyDue() {
        assertEquals(Long.MAX_VALUE, CollectorRetryPolicy.saturatedAdd(10, Long.MAX_VALUE))
        assertEquals(20L, CollectorRetryPolicy.saturatedAdd(10, 10))
        assertThrows(IllegalArgumentException::class.java) { CollectorRetryPolicy.saturatedAdd(-1, 10) }
    }
}
'''


FILES[DEVICE_TEST + 'DurableSmsQueueComponentTest.kt'] = r'''package com.momobio.app


import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID


/** Real Android SQLite tests with synthetic receipts. No SMS permission or network is needed. */
@RunWith(AndroidJUnit4::class)
class DurableSmsQueueComponentTest {
    private lateinit var context: Context
    private lateinit var dbName: String
    private lateinit var prefsName: String
    private val opened = mutableListOf<DurableSmsQueue>()
    private lateinit var time: TestClock
    private val policy = ReceiptAdmissionPolicy.parse("""{"version":"qa","rules":[{"sender":"QA-RECEIPT","contains_all":["received","transaction"]}]}""")
    private class TestClock : CollectorClock {
        var wall = 1_800_000_000_000L; var elapsed = 1_000L; var boot = 2
        override fun wallMillis() = wall
        override fun elapsedMillis() = elapsed
        override fun bootId() = boot
    }
    @Before fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        dbName = "queue-test-${UUID.randomUUID()}.sqlite"
        prefsName = "queue-test-${UUID.randomUUID()}"
        time = TestClock()
    }
    @After fun cleanup() {
        opened.forEach { runCatching { it.close() } }; opened.clear()
        // Delete only this test's randomized private stores.
        for (suffix in listOf("", "-wal", "-shm", "-journal")) File(context.noBackupFilesDir, dbName + suffix).delete()
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).edit().clear().commit()
    }
    private fun queue(limit: Int = 100) = DurableSmsQueue(context, dbName, prefsName, limit, 1024 * 1024L, time).also { opened += it }
    private fun sms(i: Int) = MomoSms("QA-RECEIPT", "received synthetic funds; transaction QA$i", time.wall + i)
    private fun acknowledge(lease: CollectorBatchLease) = UploadResult(true, lease.messages.map { it.messageHash }.toSet(), "synthetic acknowledgement")


    @Test fun separateConnectionsShareLeaseAndAtomicAcknowledgements() {
        val first = queue(); val second = queue()
        first.enqueue(listOf(sms(1), sms(2)), policy)
        val lease = first.claim(policy)!!
        assertNull(second.claim(policy))
        assertTrue(first.finish(lease, acknowledge(lease)))
        assertEquals(0, second.snapshot().pending)
        assertEquals(0, second.enqueue(listOf(sms(1)), policy))
        assertNotNull(second.snapshot().lastAcknowledgedAt)
    }
    @Test fun expiredOrRebootedLeaseCannotDeleteNewLeaseData() {
        val first = queue(); val second = queue()
        first.enqueue(listOf(sms(1)), policy)
        val old = first.claim(policy)!!
        time.elapsed += DurableSmsQueue.LEASE_MILLIS + 1
        val newer = second.claim(policy)!!
        assertFalse(first.finish(old, acknowledge(old)))
        assertEquals(1, second.snapshot().pending)
        time.boot++; time.elapsed = 100L
        val afterBoot = first.claim(policy)!!
        assertFalse(second.finish(newer, acknowledge(newer)))
        assertTrue(first.finish(afterBoot, acknowledge(afterBoot)))
    }
    @Test fun foreignAndFalseSuccessAcknowledgementsRollBack() {
        val q = queue(); q.enqueue(listOf(sms(1), sms(2)), policy)
        val lease = q.claim(policy)!!
        assertThrows(IllegalArgumentException::class.java) { q.finish(lease, UploadResult(false, setOf("foreign"), "fixture")) }
        assertThrows(IllegalArgumentException::class.java) { q.finish(lease, UploadResult(true, setOf(sms(1).messageHash), "fixture")) }
        assertEquals(2, q.snapshot().pending)
        assertTrue(q.finish(lease, acknowledge(lease)))
    }
    @Test fun partialAcknowledgementPersistsAndServerRetryAfterSurvivesReopen() {
        val q = queue(); q.enqueue(listOf(sms(1), sms(2)), policy)
        val lease = q.claim(policy)!!
        assertTrue(q.finish(lease, UploadResult(false, setOf(sms(1).messageHash), "partial", retryAfterMillis = 7_200_000L)))
        val next = q.snapshot().nextAttemptAt
        val expectedSecondHash = sms(2).messageHash
        assertTrue(next >= time.wall + 7_200_000L)
        q.close(); opened.remove(q)
        val reopened = queue()
        assertEquals(1, reopened.snapshot().pending)
        assertNull(reopened.claim(policy))
        reopened.resetRetryAfterOperatorReview()
        assertEquals(next, reopened.snapshot().nextAttemptAt)
        time.wall = next + 1; time.elapsed += 7_200_001L
        val remaining = reopened.claim(policy)!!
        assertEquals(listOf(expectedSecondHash), remaining.messages.map { it.messageHash })
    }
    @Test fun capacityFailureDoesNotPartiallyAppendABatch() {
        val q = queue(1)
        assertThrows(IllegalStateException::class.java) { q.enqueue(listOf(sms(1), sms(2)), policy) }
        assertEquals(0, q.snapshot().pending)
    }
    @Test fun malformedAndExcludedLegacyRecordsAreQuarantinedBeforeSourceRemoval() {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().putString("pending", sms(1).toJson() + "\nnot-json\n" + MomoSms("PERSONAL", "not a receipt", time.wall).toJson()).commit()
        val q = queue(); q.migrateLegacy(policy)
        assertEquals(1, q.snapshot().pending)
        assertEquals(2, q.snapshot().quarantine)
        assertFalse(prefs.contains("pending"))
        q.migrateLegacy(policy)
        assertEquals(2, q.snapshot().quarantine)
    }
    @Test fun failedLegacyMigrationKeepsOriginalAndRollsBackDestination() {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val original = sms(1).toJson() + "\n" + sms(2).toJson()
        prefs.edit().putString("pending", original).commit()
        val q = queue(1)
        assertThrows(IllegalStateException::class.java) { q.migrateLegacy(policy) }
        assertEquals(original, prefs.getString("pending", null))
        assertEquals(0, q.snapshot().pending)
    }
    @Test fun changedPolicyMovesQueuedReceiptsToReviewWithoutSending() {
        val q = queue(); q.enqueue(listOf(sms(1)), policy)
        val changed = ReceiptAdmissionPolicy.parse("""{"version":"qa2","rules":[{"sender":"OTHER","contains_all":["received"]}]}""")
        assertNull(q.claim(changed))
        assertEquals(0, q.snapshot().pending)
        assertEquals(1, q.snapshot().quarantine)
    }
    @Test fun nonretryableOutcomeRequiresExplicitReviewRatherThanHotLoop() {
        val q = queue(); q.enqueue(listOf(sms(1)), policy)
        val lease = q.claim(policy)!!
        assertTrue(q.finish(lease, UploadResult(false, message = "review", retryable = false)))
        assertEquals(Long.MAX_VALUE, q.snapshot().nextAttemptAt)
        assertNull(q.claim(policy))
        q.resetRetryAfterOperatorReview()
        assertNotNull(q.claim(policy))
    }
}
'''


FILES[TEST + 'CollectorTransportBoundsTest.kt'] = r'''package com.momobio.app


import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.junit.Assert.*
import org.junit.Test


class CollectorTransportBoundsTest {
    private val message = MomoSms("QA-RECEIPT", "received transaction QA1", 1_800_000_000_000L)
    private class Connection : HttpURLConnection(URL("https://collector.invalid")) {
        val written = ByteArrayOutputStream()
        var code = 200
        var body = "{}"
        var declared: String? = null
        var retry: String? = null
        var errorBodyRead = false
        var responseBodyRead = false
        override fun getOutputStream() = written
        override fun getResponseCode() = code
        override fun getHeaderField(name: String?): String? = when (name) {
            "Content-Length" -> declared; "Retry-After" -> retry; else -> null
        }
        override fun getInputStream(): ByteArrayInputStream { responseBodyRead = true; return ByteArrayInputStream(body.toByteArray()) }
        override fun getErrorStream(): ByteArrayInputStream { errorBodyRead = true; return ByteArrayInputStream("private provider details".toByteArray()) }
        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy() = false
    }
    private fun client(connection: Connection, url: String = "https://collector.invalid") = UploadClient(
        { mapOf("x-mobio-signature" to "synthetic") }, url, "synthetic-key", { connection }, {})


    @Test fun emptyQueueDoesNotCertifyMissingConfiguration() {
        val result = client(Connection(), "").upload(emptyList())
        assertFalse(result.ok); assertFalse(result.serverContacted)
    }
    @Test fun originPolicyRejectsCleartextCredentialsQueriesAndPaths() {
        for (url in listOf("http://collector.invalid", "https://u:p@collector.invalid", "https://collector.invalid/?x=1", "https://collector.invalid/path")) {
            assertNotNull(UploadClient.configurationError(url, "synthetic-key"))
        }
        assertNull(UploadClient.configurationError("https://collector.invalid/", "synthetic-key"))
    }
    @Test fun redirectsNeverReceiveSignedReceiptData() {
        val connection = Connection().apply { code = 302 }
        val result = client(connection).upload(listOf(message))
        assertFalse(connection.instanceFollowRedirects)
        assertFalse(result.ok); assertFalse(result.retryable); assertFalse(connection.errorBodyRead)
    }
    @Test fun providerDelayIsReturnedWithoutReadingErrorBody() {
        val connection = Connection().apply { code = 429; retry = "7200" }
        val result = client(connection).upload(listOf(message))
        assertEquals(7_200_000L, result.retryAfterMillis)
        assertTrue(result.retryable); assertFalse(connection.errorBodyRead)
    }
    @Test fun oversizedSuccessResponseDoesNotAcknowledgeAnything() {
        val connection = Connection().apply { declared = "9999999" }
        val result = client(connection).upload(listOf(message))
        assertFalse(result.ok); assertTrue(result.uploadedHashes.isEmpty()); assertFalse(connection.responseBodyRead)
    }
    @Test fun duplicateAcknowledgementRowsAreRejected() {
        val row = """{"message_hash":"${message.messageHash}","status":"accepted"}"""
        val connection = Connection().apply { body = """{"success":true,"results":[$row,$row]}""" }
        val result = client(connection).upload(listOf(message))
        assertFalse(result.ok); assertTrue(result.uploadedHashes.isEmpty())
    }
    @Test fun stringTrueIsNotAnAcknowledgementEnvelope() {
        val connection = Connection().apply { body = """{"success":"true","results":[{"message_hash":"${message.messageHash}","status":"accepted"}]}""" }
        assertTrue(client(connection).upload(listOf(message)).uploadedHashes.isEmpty())
    }
    @Test fun pauseBeforeTransmissionKeepsRequestUnsent() {
        val connection = Connection()
        val uploader = client(connection).apply { canTransmit = { false } }
        assertFalse(uploader.upload(listOf(message)).ok)
        assertEquals(0, connection.written.size())
    }
}
'''


FILES['scripts/tests/test_collector_increment03_contracts.py'] = r'''"""Source-contract checks only. These do not replace Android SQLite or transport tests."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'apps/momobio_sms_bridge'
JAVA = BASE / 'app/src/main/java/com/momobio/app'


class CollectorContracts(unittest.TestCase):
    def test_only_coordinator_creates_upload_client_in_production_components(self):
        for name in ('MainActivity.kt', 'SmsReceiver.kt', 'BridgeSyncWorker.kt', 'BridgeForegroundService.kt'):
            source = (JAVA / name).read_text()
            self.assertNotIn('UploadClient(', source, name)
            self.assertIsNone(re.search(r'\bSmsQueue\(', source), name)


    def test_manifest_has_no_always_on_service_and_excludes_transfer(self):
        source = (BASE / 'app/src/main/AndroidManifest.xml').read_text()
        self.assertNotIn('.BridgeForegroundService', source)
        self.assertNotIn('FOREGROUND_SERVICE', source)
        self.assertIn('collector_data_extraction_rules', source)
        self.assertIn('android:allowBackup="false"', source)


    def test_lease_ack_and_migration_guards_remain(self):
        source = (JAVA / 'DurableSmsQueue.kt').read_text()
        for marker in ('beginTransactionNonExclusive', 'setTransactionSuccessful', 'legacy_migration',
                       'offered.containsAll(result.uploadedHashes)', 'lease.boot != clock.bootId()',
                       'malformed_legacy_record', 'Queue capacity exhausted'):
            self.assertIn(marker, source)


    def test_work_manager_is_not_an_upload_retry_hot_loop(self):
        supervisor = (JAVA / 'BridgeSupervisor.kt').read_text()
        worker = (JAVA / 'BridgeSyncWorker.kt').read_text()
        self.assertIn('ExistingWorkPolicy.KEEP', supervisor)
        self.assertNotIn('startForegroundService', supervisor)
        self.assertIn('outcome.mayContinue', worker)


    def test_ui_does_not_call_empty_queue_running(self):
        source = (JAVA / 'CollectorUiController.kt').read_text()
        self.assertNotIn('"Running"', source)
        self.assertIn('Awaiting first acknowledgement', source)
        self.assertIn('Acknowledgement is not payment confirmation', source)


if __name__ == '__main__':
    unittest.main()
'''


FILES['scripts/ci/verify_collector_increment03.sh'] = r'''#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
command -v python3 >/dev/null || { echo "UNAVAILABLE: python3 required" >&2; exit 2; }
python3 scripts/tests/test_collector_increment03_contracts.py
# A missing compiler is not a passed CI lane. Use the project's approved installed Gradle.
gradle_bin="${GRADLE_BIN:-gradle}"
command -v "$gradle_bin" >/dev/null || { echo "UNAVAILABLE: approved Gradle executable required" >&2; exit 2; }
"$gradle_bin" -p apps/momobio_sms_bridge --no-daemon --console=plain :app:testQaUnitTest :app:assembleQa
if [[ "${1:-}" == "--device" ]]; then
  command -v adb >/dev/null || { echo "UNAVAILABLE: adb required" >&2; exit 2; }
  [[ -n "${ANDROID_SERIAL:-}" ]] || { echo "UNAVAILABLE: explicitly select ANDROID_SERIAL for synthetic QA tests" >&2; exit 2; }
  adb -s "$ANDROID_SERIAL" get-state
  "$gradle_bin" -p apps/momobio_sms_bridge --no-daemon --console=plain :app:connectedQaAndroidTest
  echo "Collector QA component lane completed; not production/operator acceptance."
elif [[ -n "${1:-}" ]]; then
  echo "Unknown argument; expected --device or no argument" >&2; exit 2
else
  echo "Collector unit/build lane completed. Android SQLite/device tests NOT RUN."
fi
'''




def normalize(value: str) -> str:
    return value.lstrip('\ufeff').replace('\r\n', '\n').replace('\r', '\n').rstrip('\n') + '\n'




def once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise ValueError(f'Source drift at {label}; reconcile rather than overwrite')
    return source.replace(old, new, 1)




def replace_count(source: str, old: str, new: str, count: int, label: str) -> str:
    if source.count(old) != count:
        raise ValueError(f'Source drift at {label}')
    return source.replace(old, new)




def section(source: str, start: str, end: str, replacement: str, label: str) -> str:
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError(f'Ambiguous section: {label}')
    a, b = source.index(start), source.index(end)
    if b <= a:
        raise ValueError(f'Invalid section ordering: {label}')
    return source[:a] + replacement + source[b:]




def patch_activity(source: str) -> str:
    source = once(source, '    private lateinit var queue: SmsQueue', '    private lateinit var delivery: CollectorUiController', 'activity queue field')
    source = once(source, '    @Volatile private var syncInFlight = false\n    private val retryDelayMillis = 15_000L\n', '', 'activity retry loop fields')
    source = once(source, '        queue = SmsQueue(applicationContext)\n', '', 'activity queue initialization')
    source = once(source, 'setOnClickListener { requestPermissions(requiredPermissions(), 7) }', 'setOnClickListener { delivery.configure() }', 'consent before permissions')
    source = once(source, '        setContentView(\n', '        delivery = CollectorUiController(this, status, upload, enableButton)\n\n        setContentView(\n', 'controller initialization')
    source = once(source, '                addView(enableButton)\n', '''                addView(enableButton)
                addView(spacer(8))
                addView(actionButton("Pause collection", neutralPanel).apply {
                    setOnClickListener { delivery.pauseCollection() }
                })
                addView(spacer(8))
                addView(actionButton("Retry after operator review", neutralPanel).apply {
                    setOnClickListener { delivery.retryAfterReview() }
                })
''', 'collector controls')
    source = once(source, '        super.onResume()\n', '        super.onResume()\n        delivery.resumeUi()\n', 'foreground health polling')
    source = replace_count(source, '        requestBatteryOptimizationExemptionIfReady()\n', '', 2, 'remove battery exemption prompts')
    source = replace_count(source, '        if (syncInFlight) return\n', '', 2, 'remove old UI concurrency flags')
    source = section(source, '    private fun syncAutomatically(): Boolean {', '    private fun hasSmsAccess(): Boolean =', '''    override fun onPause() {
        delivery.pauseUi()
        super.onPause()
    }


    override fun onDestroy() {
        delivery.close()
        super.onDestroy()
    }


    private fun syncAutomatically(): Boolean = delivery.requestSync()
    private fun refreshStatus() = delivery.refresh()


''', 'remove direct UI upload orchestration')
    source = section(source, '    private fun requiredPermissions(): Array<String> =', '    private fun brandLockup(): View =', '', 'remove obsolete permissions and exemption helper')
    source = once(source, '        setContentView(\n            LinearLayout(this).apply {', '        setContentView(\n            android.widget.ScrollView(this).apply {\n                addView(LinearLayout(this@MainActivity).apply {', 'scrollable collector controls')
    source = once(source, '            },\n        )\n        BridgeSupervisor.schedule', '                })\n            },\n        )\n        BridgeSupervisor.schedule', 'close scroll container')
    # The original decorative methods, enrollment request and branding stay intact.
    return source




def patch_manifest(source: str) -> str:
    for permission in ('FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_SPECIAL_USE', 'POST_NOTIFICATIONS', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'):
        source = once(source, f'    <uses-permission android:name="android.permission.{permission}" />\n', '', permission)
    source = once(source, '        android:fullBackupContent="false"', '        android:fullBackupContent="false"\n        android:dataExtractionRules="@xml/collector_data_extraction_rules"', 'transfer exclusions')
    service = '''        <service
            android:name=".BridgeForegroundService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="always_on_sms_payment_bridge" />
        </service>'''
    return once(source, service, '', 'remove obsolete special-use service registration')




def patch_upload_test(source: str) -> str:
    source = once(source, 'emptyQueueDoesNotRequireConfigurationOrTouchTransport', 'emptyQueueRequiresConfigurationAndDoesNotTouchTransport', 'empty queue test name')
    return once(source, 'assertTrue(fixture.client("", "").upload(emptyList()).ok)', 'assertFalse(fixture.client("", "").upload(emptyList()).ok)', 'empty queue must not fake configured health')


README = r'''# Mobio Increment 03 — institutional SMS collector candidate


Authored 28 September 2026. Source and tests are supplied; this session did NOT execute the generator, compile Kotlin, run Gradle/SQLite/device tests, apply migrations, install an APK, or deploy anything. The original Drive repository files are unchanged.


## Relationship to other packages


Use the broader `production-hardening/2026-09-28-increment02` package as the server/client hardening baseline, not the older Increment01 source generator. Increment03 changes the separate `apps/momobio_sms_bridge` client. It does not replace Increment02's backend identity, strict receipt matching, booking, member-ID or face changes. Increment02's recorded test results are historical to that package and are not results for this candidate.


## Supplied implementation


- Explicit versioned on-device sender/all-phrases policy; no real sender, operator, merchant or payment identity is guessed. Only synthetic configuration is supplied. Sender matching is minimization, not authentication or proof of funds.
- Explicit institutional-device notice and consent bound to the policy digest. New collection remains paused until configured and accepted. Pause cancels scheduled jobs and prevents new sends; already-transmitted requests may still complete.
- SQLite queue under app-private no-backup storage. Transactions conserve admitted rows, separate review quarantine, and atomically record acknowledgement plus removal. There is no eviction of pending/quarantined payloads to free space.
- Legacy preference migration commits the destination before clearing source keys. Invalid hashes/JSON and excluded old messages go to local quarantine, never automatic upload. Oversized or conflicting migration inputs abort and retain the source.
- Shared database lease with token, monotonic expiry and boot identity. A stale worker cannot apply an acknowledgement after a newer lease. One worker uploads at most ten receipts/128 KiB per operation.
- Persisted backoff and Retry-After. Nonretryable failures stop automatic continuations until explicit operator review. Review retry does not override ordinary server retry waits.
- HTTP origin validation, disabled redirects, bounded request/response, fresh existing RSA request signatures, finite connect/read timeouts and a request-disconnect watchdog. No provider error-body logging. A timed-out send may have committed remotely; server-side idempotency remains mandatory.
- WorkManager is the network scheduler; UI, receiver and dormant service do not run competing upload loops. Unique receipt work uses KEEP rather than cancelling an active sender. The sticky special-use foreground-service declaration and battery-exemption prompts are removed, not relabelled to bypass policy.
- UI distinguishes paused/configuration/permission/storage/review/pending/first-ack states. Queue count is unknown when storage fails. A historical delivery acknowledgement is not a current enrollment check or a payment receipt.
- Source target SDK 36 and explicit cloud/device-transfer exclusions. These are source settings, not verified store, archive or handset compatibility.


## Engineering bounds and remaining decisions


Defaults: 10,000 retained payload rows including quarantine; 32 MiB payload budget; 16 KiB received-body limit; ten-message/128 KiB worker batches; 256 KiB HTTP responses; 180-second leases; local exponential delay capped at 30 minutes while honoring longer server instructions; acknowledged-hash retention 30 days and 100,000 rows. These are explicit engineering defaults requiring fleet/load/privacy review, not vendor limits or legal retention conclusions. SQLite/WAL, queue metadata and WorkManager overhead are additional storage; measure actual disk use.


Pending and quarantine have no automatic age-based deletion in this candidate. The operator must approve and implement audited quarantine resolution, retention/purge and lost-SMS reconciliation before production. Capacity exhaustion or disk/corruption failure can prevent new capture; a best-effort diagnostic cannot guarantee delivery when storage is unusable. No old inbox reread, always-on guarantee, automatic payment confirmation, operator API settlement, new device identity, or new biometric scope is introduced.


The request watchdog asks HttpURLConnection to disconnect; cancellation latency depends on the Android runtime/network and needs measurement. Lease fencing protects local state, not remote exactly-once behavior. The existing collector signature and the backend's durable receipt identity are still required. Backend admission-before-acknowledgement (M032) is not implemented by this client patch.


The active receiving filter may need new versions as the operator changes SMS wording. Validate real redacted fixtures before enabling; an incorrect filter can reject genuine receipts. No personal SIM deployment. A new filter invalidates prior consent and queued rows are re-evaluated before upload.


## Generate and integrate safely


Run this Python source bundle on Python 3.10+ against a clean review checkout:


    python3 mobio_increment_03_collector.py --repo /path/to/Mobio --output /path/to/Mobio-increment03-review


The generator checks required known source anchors, new-file collisions and unchanged input during generation. Anchor checks are NOT full baseline hash equivalence; inspect the full patch to reconcile unrelated changes. It never writes into the input checkout. It emits normalized UTF-8/LF files under overlay/, changes.patch, MANIFEST.json, VALIDATION.json and TASK_STATUS.json, plus a ZIP when actually run. None of those generated outputs or hashes should be described as created here merely because their generator is saved.


Review changes.patch and its before/after hashes. In a separate review checkout, run `git apply --check /path/to/output/changes.patch`, then apply only after review. Keep complete Increment02 changes and do not apply the older Increment01 generator on top. The legacy SmsQueue class is intentionally retained for old test compatibility, but production components must exclusively use DurableSmsQueue. Do not downgrade an enrolled device to an old collector that cannot read the new queue.


Use an approved installed Gradle and Android SDK/JDK for the app:


    python3 scripts/tests/test_collector_increment03_contracts.py
    bash scripts/ci/verify_collector_increment03.sh
    ANDROID_SERIAL=<explicit-synthetic-test-device> bash scripts/ci/verify_collector_increment03.sh --device


The unit/build lane is NOT the Android SQLite component lane. The script fails as UNAVAILABLE when required tooling is absent. Wire these checks into the actual protected hosted CI as a separate reviewed change; the supplied script alone does not establish required branch protection.


The synthetic component suite uses a unique private database and no live SMS/network. Also run the complete existing collector tests and inspect the generated merged qa manifest. Test actual managed-device upgrade with pending messages, process death, reboot, time changes, partial acknowledgement, network interruption, storage exhaustion/corruption and force-stop/Doze behavior. Check the receiver's broadcast time budget. Record actual signed package/version and keystore provenance; this candidate neither rotates exposed credentials nor signs with a debug key.


## Acceptance still open


M026 policy/notice deployment approval; M028 lossless migration/device failure tests and review/purge workflows; M029 multi-worker and live network tests; M030 managed-device/OEM acceptance; M034 fleet alerting and actual enrollment status; M049 archive/permission review; M077 hosted CI execution. Production signing (M025), backend intake (M032), trusted operator reconciliation (M023), staffing, privacy agreements and all unaffected audit tasks remain open.


No 95-task completion claim. No production-ready claim. No fresh test-pass count.


## Primary references consulted


- Android SQLiteOpenHelper: https://developer.android.com/reference/android/database/sqlite/SQLiteOpenHelper
- Android SQLiteDatabase transactions: https://developer.android.com/reference/android/database/sqlite/SQLiteDatabase
- WorkManager unique/cancelled work: https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/manage-work
- Android backup and transfer scope: https://developer.android.com/identity/data/autobackup


## Source provenance


Inspected Drive collector files: SmsQueue 1-yEWiItXERM_jmBtgePmT13WZUNUb0g-; UploadClient 1t8BMYWNouflvOFvwUCJp7uw0aY-VhSie; MainActivity 1VaIxl4s-bYjAbwW0zj8QP29_x09Ag4sb; SmsReceiver 14Xk8YpNg33EJncxUz4ZFh08gXr_v_0gT; BridgeSupervisor 1TCLP0gLC0lyCHAF9vvir7CxcwCzRi3Ob; BridgeSyncWorker 1ysH8gvegbp4je_iWDYiRCc4JEAEBq4Jd; BridgeForegroundService 1zOF5b5SZRaStwnUTMyR5r0ldDF-sK22H; manifest 11NMRpK90fFMXHMvdtiRYDPR0V7Pt-D1U; app build 13unWV3K7o-vQdJnFfdpVzk5xZckDNc47; UploadClientTest 1Urn2RmxCbyqzbvAQMZpG3nCSYJTugzg-. Shared MomoSms and CollectorIdentity were inspected and remain unchanged.
'''


FILES[BASE + 'docs/INCREMENT03_COLLECTOR.md'] = README


EXISTING = {
    JAVA + 'UploadClient.kt': ('private val batchSize = 50', 'class UploadClient internal constructor', 'No new SMS'),
    JAVA + 'SmsReceiver.kt': ('val queue = SmsQueue(context.applicationContext)', 'goAsync()'),
    JAVA + 'BridgeSyncWorker.kt': ('SmsQueue(applicationContext)', 'UploadClient(CollectorIdentity(applicationContext))'),
    JAVA + 'BridgeSupervisor.kt': ('ExistingWorkPolicy.REPLACE', 'startForegroundService(intent)'),
    JAVA + 'BridgeForegroundService.kt': ('return START_STICKY', 'private fun syncOnce(): UploadResult'),
    JAVA + 'MainActivity.kt': ('private lateinit var queue: SmsQueue', 'private fun syncAutomatically(): Boolean'),
    BASE + 'app/src/main/AndroidManifest.xml': ('always_on_sms_payment_bridge', 'android:allowBackup="false"'),
    BASE + 'app/build.gradle.kts': ('targetSdk = 35', 'testBuildType = "qa"'),
    TEST + 'UploadClientTest.kt': ('emptyQueueDoesNotRequireConfigurationOrTouchTransport', 'assertTrue(fixture.client("", "").upload(emptyList()).ok)'),
}




def safe_path(root: Path, relative: str) -> Path:
    part = Path(relative)
    if part.is_absolute() or '..' in part.parts:
        raise ValueError(f'Unsafe relative path: {relative}')
    candidate = root / part
    for item in (candidate, *candidate.parents):
        if item == root:
            break
        if item.is_symlink():
            raise ValueError(f'Symlink not allowed: {relative}')
    if not candidate.resolve().is_relative_to(root):
        raise ValueError(f'Path escapes root: {relative}')
    return candidate




def read_source(root: Path, relative: str) -> str:
    path = safe_path(root, relative)
    if not path.is_file() or path.stat().st_size > 2_000_000:
        raise ValueError(f'Missing or oversized baseline source: {relative}')
    return normalize(path.read_text(encoding='utf-8-sig'))




def main() -> int:
    parser = argparse.ArgumentParser(description='Generate a reviewable collector source overlay; never edit the checkout or deploy.')
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = args.repo.resolve(strict=True)
    output = args.output.resolve()
    if output.exists() or output == repo or output.is_relative_to(repo):
        parser.error('Use a new output directory outside the source checkout')
    original_raw_hashes = {path: hashlib.sha256(safe_path(repo, path).read_bytes()).hexdigest() for path in EXISTING}
    originals = {path: read_source(repo, path) for path in EXISTING}
    for path, anchors in EXISTING.items():
        if any(anchor not in originals[path] for anchor in anchors):
            raise ValueError(f'Baseline changed at {path}; reconcile the candidate with actual source')
    # Check unchanged data/signature types without replacing them.
    for path, marker in ((JAVA + 'MomoSms.kt', 'data class MomoSms('),
                         (JAVA + 'CollectorIdentity.kt', 'mobio-collector-v1')):
        if marker not in read_source(repo, path):
            raise ValueError(f'Shared collector contract changed: {path}')
    prepared = {path: normalize(source) for path, source in FILES.items()}
    prepared[JAVA + 'MainActivity.kt'] = normalize(patch_activity(originals[JAVA + 'MainActivity.kt']))
    prepared[BASE + 'app/src/main/AndroidManifest.xml'] = normalize(patch_manifest(originals[BASE + 'app/src/main/AndroidManifest.xml']))
    prepared[BASE + 'app/build.gradle.kts'] = normalize(once(originals[BASE + 'app/build.gradle.kts'], '        targetSdk = 35', '        targetSdk = 36', 'collector target SDK'))
    prepared[TEST + 'UploadClientTest.kt'] = normalize(patch_upload_test(originals[TEST + 'UploadClientTest.kt']))
    for path in prepared:
        if path not in originals and safe_path(repo, path).exists():
            raise ValueError(f'New-file collision: {path}; refusing to replace unrelated work')
    for path, before in originals.items():
        if read_source(repo, path) != before or hashlib.sha256(safe_path(repo, path).read_bytes()).hexdigest() != original_raw_hashes[path]:
            raise ValueError(f'Source changed during planning: {path}')
    # Sanity-check cross-file ownership before writing any candidate output.
    for name in ('MainActivity.kt', 'SmsReceiver.kt', 'BridgeSyncWorker.kt', 'BridgeForegroundService.kt'):
        candidate = prepared[JAVA + name]
        if 'UploadClient(' in candidate or re.search(r'\bSmsQueue\(', candidate):
            raise ValueError(f'Legacy upload/queue ownership remains in {name}')
    output.mkdir(parents=True, exist_ok=False)
    overlay = output / 'overlay'
    entries, diffs = [], []
    for path, source in sorted(prepared.items()):
        target = safe_path(overlay, path)
        target.parent.mkdir(parents=True, exist_ok=True)
        data = source.encode('utf-8')
        target.write_bytes(data)
        if path.endswith('.sh'):
            target.chmod(0o755)
        before = originals.get(path)
        entries.append({'path': path, 'bytes': len(data),
                        'before_sha256': original_raw_hashes.get(path),
                        'before_normalized_sha256': hashlib.sha256(before.encode()).hexdigest() if before is not None else None,
                        'after_sha256': hashlib.sha256(data).hexdigest()})
        diffs.extend(difflib.unified_diff((before or '').splitlines(keepends=True), source.splitlines(keepends=True),
                     fromfile='a/' + path if before is not None else '/dev/null', tofile='b/' + path))
    manifest = {'increment': '03', 'authored_date': '2026-09-28', 'input_repository_modified': False,
                'production_ready': False, 'deployed': False, 'baseline_guard': 'review-required anchors, not historical full-file hashes',
                'files': entries}
    validation = {'generator_executed': True, 'source_tests': 'not_run', 'gradle_compilation': 'not_run',
                  'android_sqlite_component_tests': 'not_run', 'device_operator_tests': 'not_run',
                  'production_ready': False, 'reason': 'This generator authors source only; execute the supplied QA lanes separately.'}
    tasks = [{'task_id': key, 'status': 'source_candidate_not_runtime_verified', 'remaining': detail} for key, detail in {
        'M026': 'Approve real filter/notice/processor/retention; run capture minimization and consent tests.',
        'M028': 'Execute real SQLite upgrade/failure tests and implement approved quarantine resolution/purge.',
        'M029': 'Run worker concurrency, network loss, stale-lease and Retry-After acceptance.',
        'M030': 'Verify managed-device boot, force-stop, Doze, OEM and upgrade behavior.',
        'M034': 'Verify device health UI, enrollment status and staffed fleet alerts.',
        'M049': 'Review emitted permissions, backup exclusions and target SDK on actual artifacts.',
        'M077': 'Run and make appropriate collector QA lanes mandatory in hosted CI.',
        'M090': 'Reconcile this candidate into the canonical reviewed repository; no live original was changed.'
    }.items()]
    for filename, value in [('MANIFEST.json', manifest), ('VALIDATION.json', validation), ('TASK_STATUS.json', tasks)]:
        (output / filename).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    (output / 'changes.patch').write_bytes(''.join(diffs).encode('utf-8'))
    (output / 'README.md').write_bytes(normalize(README).encode('utf-8'))
    archive = output / 'Mobio_Increment03_Collector_Candidate.zip'
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(output.rglob('*')):
            if path.is_file() and path != archive:
                bundle.write(path, path.relative_to(output))
    print(f'Generated {len(prepared)} reviewable source/test files at {output}. Original checkout unchanged.')
    print('Compilation, device/SQLite tests, actual deployment and all unaffected release gates remain open.')
    return 0




if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f'NOT COMPLETED: {error}', file=sys.stderr)
        raise SystemExit(2)