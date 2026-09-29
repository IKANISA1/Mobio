package com.momobio.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.security.MessageDigest

/** Bounded, transactional queue with a durable overflow tier. Never evicts raw evidence. */
class DurableSmsQueue(context: Context) {
    private val app = context.applicationContext
    private val helper = database(app)
    private val db: SQLiteDatabase get() = helper.writableDatabase

    data class Admission(val accepted: Int, val duplicate: Int, val blocked: Int, val deferred: Int)
    data class Health(val pending: Int, val quarantined: Int, val bytes: Long,
                      val oldestPendingAt: Long?, val capacityBlocked: Long,
                      val lastAckAt: Long, val lastError: String?, val nextAttemptAt: Long,
                      val overflowPending: Int, val unreconciledRefusals: Int,
                      val capacityWarning: Boolean)

    init { migrateLegacy() }

    fun enqueue(messages: List<MomoSms>, now: Long = System.currentTimeMillis()): Admission = tx { d ->
        var accepted = 0; var duplicate = 0; var blocked = 0; var deferred = 0
        trimAcknowledgements(d, now)
        promoteOverflow(d)
        for (m in messages) {
            if (exists(d, m.messageHash)) { duplicate++; continue }
            val payload = m.toJson()
            val bytes = payload.toByteArray(Charsets.UTF_8).size
            if (bytes > MAX_RECORD_BYTES || !m.messageHash.matches(Regex("[a-f0-9]{64}"))) {
                recordRefusal(d, m, now, if (bytes > MAX_RECORD_BYTES) "oversize" else "invalid_hash")
                blocked++; continue
            }
            val activeFull = scalar(d, "SELECT count(*) FROM receipts WHERE state != 'acknowledged'") >= MAX_ACTIVE_ROWS ||
                scalar(d, "SELECT coalesce(sum(payload_bytes),0) FROM receipts") + bytes > MAX_ACTIVE_BYTES
            if (activeFull) {
                val overflowFull = scalar(d, "SELECT count(*) FROM overflow_receipts") >= MAX_OVERFLOW_ROWS ||
                    scalar(d, "SELECT coalesce(sum(payload_bytes),0) FROM overflow_receipts") + bytes > MAX_OVERFLOW_BYTES
                if (overflowFull) {
                    recordRefusal(d, m, now, "capacity")
                    blocked++; continue
                }
                insertOverflow(d, m.messageHash, payload, bytes, m.receivedAtMillis, now)
                markRecovered(d, m.messageHash, now)
                accepted++; deferred++; continue
            }
            insert(d, m.messageHash, payload, bytes, m.receivedAtMillis, now, "pending", null)
            markRecovered(d, m.messageHash, now)
            accepted++
        }
        if (blocked > 0) put(d, "capacity_blocked", (getLong(d, "capacity_blocked") + blocked).toString())
        Admission(accepted, duplicate, blocked, deferred)
    }

    fun batch(limit: Int = 50, now: Long = System.currentTimeMillis()): List<MomoSms> = tx { d ->
        promoteOverflow(d)
        // Retention is a review boundary, NOT a silent discard of unresolved money evidence.
        d.execSQL(ReceiptQueueSql.EXPIRE,
            arrayOf(now - MAX_PENDING_AGE_MS))
        val result = mutableListOf<MomoSms>()
        var wireBytes = 32 // Envelope and comma overhead are bounded independently.
        d.rawQuery(ReceiptQueueSql.BATCH,
            arrayOf(limit.coerceIn(1, 50).toString())).use { c ->
            while (c.moveToNext()) {
                val hash = c.getString(0); val raw = c.getString(1)
                val parsed = MomoSms.fromJson(raw)
                if (parsed == null || parsed.messageHash != hash ||
                    MomoSms(parsed.sender, parsed.body, parsed.receivedAtMillis).messageHash != hash) {
                    d.execSQL("UPDATE receipts SET state='quarantined',reason='invalid_payload' WHERE message_hash=?", arrayOf(hash))
                } else {
                    val messageBytes = raw.toByteArray(Charsets.UTF_8).size + 1
                    if (wireBytes + messageBytes > MAX_BATCH_BYTES) break
                    result += parsed
                    wireBytes += messageBytes
                }
            }
        }
        result
    }

    fun quarantine(hashes: Set<String>, reason: String) = tx { d ->
        require(reason.matches(Regex("[a-z_]{1,64}")))
        for (hash in hashes) d.execSQL(ReceiptQueueSql.QUARANTINE,
            arrayOf(reason, hash))
    }

    fun markUploaded(hashes: Set<String>, now: Long = System.currentTimeMillis()) = tx { d ->
        var changed = 0
        d.compileStatement(ReceiptQueueSql.ACKNOWLEDGE).use { statement ->
            for (hash in hashes) {
                // Unknown hashes cannot create history or claim a receipt acknowledgement.
                statement.clearBindings()
                statement.bindLong(1, now)
                statement.bindString(2, hash)
                changed += statement.executeUpdateDelete()
            }
        }
        if (changed > 0) put(d, "last_ack_at", now.toString())
        trimAcknowledgements(d, now)
        promoteOverflow(d)
    }
    fun count(): Int = (scalar(db, "SELECT count(*) FROM receipts WHERE state='pending'") +
        scalar(db, "SELECT count(*) FROM overflow_receipts")).toInt()
    fun health(): Health = tx { d ->
        val overflow = scalar(d,"SELECT count(*) FROM overflow_receipts").toInt()
        val activePending = scalar(d,"SELECT count(*) FROM receipts WHERE state='pending'").toInt()
        val quarantined = scalar(d,"SELECT count(*) FROM receipts WHERE state='quarantined'").toInt()
        val activeBytes = scalar(d,"SELECT coalesce(sum(payload_bytes),0) FROM receipts")
        val overflowBytes = scalar(d,"SELECT coalesce(sum(payload_bytes),0) FROM overflow_receipts")
        val oldestActive = scalar(d,"SELECT coalesce(min(admitted_at),0) FROM receipts WHERE state='pending'")
        val oldestOverflow = scalar(d,"SELECT coalesce(min(admitted_at),0) FROM overflow_receipts")
        Health(activePending + overflow, quarantined,
            activeBytes + overflowBytes,
            listOf(oldestActive,oldestOverflow).filter { it > 0 }.minOrNull(),
            getLong(d,"capacity_blocked"),getLong(d,"last_ack_at"), get(d,"last_error").takeIf { !it.isNullOrBlank() },
            getLong(d,"next_attempt_at"),overflow,
            scalar(d,"SELECT count(*) FROM receipt_refusals WHERE recovered_at IS NULL").toInt(),
            (activePending + quarantined).toLong() * 5 >= MAX_ACTIVE_ROWS.toLong() * 4 ||
                activeBytes * 5 >= MAX_ACTIVE_BYTES * 4 ||
                overflow.toLong() * 5 >= MAX_OVERFLOW_ROWS.toLong() * 4 ||
                overflowBytes * 5 >= MAX_OVERFLOW_BYTES * 4)
    }
    fun permittedAttempt(now: Long): Boolean = getLong(db,"next_attempt_at") <= now
    fun recordOutcome(result: UploadResult, now: Long = System.currentTimeMillis()) = tx { d ->
        put(d,"last_attempt_at",now.toString())
        put(d,"last_error",if (result.ok) "" else result.outcome)
        if (result.serverAcknowledged) put(d,"last_server_ack_at",now.toString())
        result.automaticAllocationEnabled?.let { put(d,"automatic_allocation_enabled",it.toString()) }
        val failures = if (result.ok) 0 else (getLong(d,"failures") + 1).coerceAtMost(30).toInt()
        put(d,"failures",failures.toString())
        val next = if (result.ok) {
            // Drain pending receipts promptly, but do not send repeated empty heartbeats.
            if (scalar(d, "SELECT count(*) FROM receipts WHERE state='pending'") > 0) 0L
            else now + HEALTH_INTERVAL_MS
        } else now + CollectorTransportPolicy.backoffMillis(failures, result.retryAfterMillis, Math.random())
        put(d,"next_attempt_at",next.toString())
    }
    fun serverAcknowledgedAt(): Long = getLong(db,"last_server_ack_at")

    fun automaticAllocationEnabled(): Boolean? = when (get(db,"automatic_allocation_enabled")) {
        "true" -> true
        "false" -> false
        else -> null
    }

    private fun migrateLegacy() {
        val prefs = app.getSharedPreferences("momo_sms_queue",Context.MODE_PRIVATE)
        tx { d ->
            if (get(d,"legacy_imported") == "1") return@tx
            val pending = prefs.getString("pending",null).orEmpty()
            val uploaded = prefs.getString("uploaded",null).orEmpty()
            // Never truncate or delete an oversized legacy queue. Stop and reconcile explicitly.
            check(pending.toByteArray(Charsets.UTF_8).size + uploaded.toByteArray(Charsets.UTF_8).size <= MAX_ACTIVE_BYTES) {
                "Legacy queue requires supervised capacity migration"
            }
            val pendingLines = pending.lineSequence().filter { it.isNotBlank() }.toList()
            val ackLines = uploaded.lineSequence().filter { it.isNotBlank() }.toList()
            val acked = ackLines.filter { it.matches(Regex("[a-f0-9]{64}")) }.toSet()
            val invalidAckLines = ackLines.filter { it !in acked }
            check(pendingLines.size + invalidAckLines.size <= MAX_ACTIVE_ROWS && acked.size <= MAX_ACK_ROWS &&
                (pendingLines + invalidAckLines).all { it.toByteArray(Charsets.UTF_8).size <= MAX_RECORD_BYTES }) {
                "Legacy queue requires supervised row migration"
            }
            val now = System.currentTimeMillis()
            for (raw in pendingLines) {
                val m = MomoSms.fromJson(raw)
                val valid = m != null && MomoSms(m.sender,m.body,m.receivedAtMillis).messageHash == m.messageHash
                val hash = if (valid) m!!.messageHash else digest(raw)
                if (exists(d,hash)) continue
                if (hash in acked) continue
                insert(d,hash,raw,raw.toByteArray(Charsets.UTF_8).size,m?.receivedAtMillis ?: 0,now,
                    if (valid) "pending" else "quarantined",if(valid) null else "legacy_corrupt_payload")
            }
            for (hash in acked) if(!exists(d,hash)) {
                d.execSQL("INSERT INTO receipts(message_hash,payload,payload_bytes,received_at,admitted_at,state,acknowledged_at) VALUES (?,NULL,0,0,?,'acknowledged',?)",arrayOf<Any>(hash,now,now))
            }
            // Preserve malformed legacy acknowledgement rows for a local review rather than losing them.
            for (raw in invalidAckLines) {
                val hash = digest("legacy_ack:" + raw)
                if (!exists(d,hash)) insert(d,hash,raw,raw.toByteArray(Charsets.UTF_8).size,0,now,"quarantined","legacy_corrupt_ack")
            }
            put(d,"legacy_imported","1")
        }
        // Erase legacy raw values only AFTER the database commit. A crash before this
        // cleanup is harmless because the durable imported marker makes retry idempotent.
        if (get(db,"legacy_imported") == "1" && !prefs.edit().remove("pending").remove("uploaded").commit()) {
            throw IllegalStateException("Legacy queue imported; preference cleanup pending")
        }
    }

    private fun insert(d: SQLiteDatabase, hash: String, payload: String, size: Int, received: Long,
                       admitted: Long, state: String, reason: String?) {
        val values = ContentValues().apply {
            put("message_hash",hash);put("payload",payload);put("payload_bytes",size)
            put("received_at",received);put("admitted_at",admitted);put("state",state);put("reason",reason)
        }
        check(d.insertOrThrow("receipts",null,values) >= 0)
    }
    private fun insertOverflow(d: SQLiteDatabase, hash: String, payload: String, size: Int,
                               received: Long, admitted: Long) {
        val values = ContentValues().apply {
            put("message_hash",hash);put("payload",payload);put("payload_bytes",size)
            put("received_at",received);put("admitted_at",admitted)
        }
        check(d.insertOrThrow("overflow_receipts",null,values) >= 0)
    }
    private fun recordRefusal(d: SQLiteDatabase, m: MomoSms, now: Long, reason: String) {
        val values = ContentValues().apply {
            put("message_hash",m.messageHash);put("received_at",m.receivedAtMillis)
            put("first_refused_at",now);put("last_refused_at",now)
            put("attempts",0);put("reason",reason)
        }
        d.insertWithOnConflict("receipt_refusals",null,values,SQLiteDatabase.CONFLICT_IGNORE)
        val updated = d.compileStatement("UPDATE receipt_refusals SET attempts=attempts+1,last_refused_at=?," +
            "reason=?,recovered_at=NULL WHERE message_hash=?").use { statement ->
            statement.bindLong(1,now)
            statement.bindString(2,reason)
            statement.bindString(3,m.messageHash)
            statement.executeUpdateDelete()
        }
        check(updated == 1) { "Refusal ledger write failed; preserve device for recovery" }
    }
    private fun markRecovered(d: SQLiteDatabase, hash: String, now: Long) {
        d.execSQL("UPDATE receipt_refusals SET recovered_at=? WHERE message_hash=? AND recovered_at IS NULL",
            arrayOf<Any>(now,hash))
    }
    private data class OverflowRecord(val hash: String, val payload: String, val size: Int,
                                      val received: Long, val admitted: Long)
    private fun promoteOverflow(d: SQLiteDatabase) {
        // A broadcast/worker transaction must not scan and move the whole backlog.
        repeat(MAX_PROMOTIONS_PER_TX) {
            val next = d.rawQuery(ReceiptQueueSql.OVERFLOW_HEAD,null).use { c ->
                if (c.moveToFirst()) OverflowRecord(c.getString(0),c.getString(1),c.getInt(2),c.getLong(3),c.getLong(4))
                else null
            } ?: return
            check(!existsActive(d,next.hash)) { "Overflow identity collision; preserve database for review" }
            if (scalar(d,"SELECT count(*) FROM receipts WHERE state != 'acknowledged'") >= MAX_ACTIVE_ROWS ||
                scalar(d,"SELECT coalesce(sum(payload_bytes),0) FROM receipts") + next.size > MAX_ACTIVE_BYTES) return
            insert(d,next.hash,next.payload,next.size,next.received,next.admitted,"pending",null)
            check(d.delete("overflow_receipts","message_hash=?",arrayOf(next.hash)) == 1)
        }
    }
    private fun trimAcknowledgements(d: SQLiteDatabase, now: Long) {
        d.execSQL(ReceiptQueueSql.PRUNE_AGE,arrayOf(now - ACK_RETENTION_MS))
        d.execSQL(ReceiptQueueSql.PRUNE_ROWS,arrayOf(MAX_ACK_ROWS))
    }
    private fun existsActive(d: SQLiteDatabase, hash: String): Boolean = d.rawQuery(
        "SELECT 1 FROM receipts WHERE message_hash=?",arrayOf(hash)).use { it.moveToFirst() }
    private fun exists(d: SQLiteDatabase, hash: String): Boolean = existsActive(d,hash) || d.rawQuery(
        "SELECT 1 FROM overflow_receipts WHERE message_hash=?",arrayOf(hash)).use { it.moveToFirst() }
    private fun scalar(d: SQLiteDatabase, sql: String): Long = d.rawQuery(sql,null).use { it.moveToFirst();it.getLong(0) }
    private fun get(d: SQLiteDatabase, key: String): String? = d.rawQuery(
        "SELECT value FROM queue_metadata WHERE key=?",arrayOf(key)).use { if(it.moveToFirst()) it.getString(0) else null }
    private fun getLong(d: SQLiteDatabase, key: String): Long = get(d,key)?.toLongOrNull() ?: 0
    private fun put(d: SQLiteDatabase, key: String, value: String) { d.execSQL(
        "INSERT OR REPLACE INTO queue_metadata(key,value) VALUES (?,?)",arrayOf(key,value)) }
    private fun <T> tx(action: (SQLiteDatabase) -> T): T {
        val d=db;d.beginTransaction()
        try { val result=action(d);d.setTransactionSuccessful();return result } finally { d.endTransaction() }
    }

    private class QueueDatabase(private val context: Context) : SQLiteOpenHelper(context,"momobio_receipts.db",null,2,
        android.database.DatabaseErrorHandler {
            // Android's default handler may delete a corrupt database. Financial
            // evidence must instead be preserved for a supervised recovery.
            throw android.database.sqlite.SQLiteDatabaseCorruptException("Receipt queue corruption; preserve for recovery")
        }) {
        override fun onConfigure(db: SQLiteDatabase) { db.setForeignKeyConstraintsEnabled(true) }
        override fun onCreate(db: SQLiteDatabase) {
            applySchema(db,"receipt_queue_v1.sql")
            applySchema(db,"receipt_queue_v2.sql")
        }
        private fun applySchema(db: SQLiteDatabase, asset: String) {
            val sql=context.assets.open(asset).bufferedReader().use { it.readText() }
            for (block in sql.split("-- @statement")) {
                val statement = block.lineSequence().filterNot { it.trim().startsWith("--") }.joinToString("\n").trim()
                if (statement.isNotEmpty()) db.execSQL(statement)
            }
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion == 1 && newVersion == 2) applySchema(db,"receipt_queue_v2.sql")
            else error("Unsupported queue migration; retain the database and perform a supervised upgrade")
        }
    }
    companion object {
        const val MAX_ACTIVE_ROWS = 10_000
        const val MAX_ACTIVE_BYTES = 16L * 1024 * 1024
        const val MAX_OVERFLOW_ROWS = 10_000
        const val MAX_OVERFLOW_BYTES = 16L * 1024 * 1024
        const val MAX_PROMOTIONS_PER_TX = 50
        const val MAX_RECORD_BYTES = 12 * 1024
        const val MAX_BATCH_BYTES = 400_000
        const val HEALTH_INTERVAL_MS = 5L * 60 * 1000
        const val MAX_ACK_ROWS = 100_000
        const val MAX_PENDING_AGE_MS = 30L * 24 * 60 * 60 * 1000
        const val ACK_RETENTION_MS = 90L * 24 * 60 * 60 * 1000
        @Volatile private var instance: QueueDatabase? = null
        private fun database(context: Context): QueueDatabase = instance ?: synchronized(this) {
            instance ?: QueueDatabase(context).also { instance=it }
        }
        private fun digest(value:String):String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
