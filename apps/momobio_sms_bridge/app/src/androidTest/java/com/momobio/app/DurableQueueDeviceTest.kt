package com.momobio.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.util.concurrent.Executors

/** Actual Android adapter tests, intentionally confined to the permission-free QA package. */
@RunWith(AndroidJUnit4::class)
class DurableQueueDeviceTest {
    private lateinit var context: Context
    private lateinit var db: SQLiteDatabase
    private lateinit var queue: DurableSmsQueue
    private val now = 1_800_000_000_000L
    private fun receipt(i: Int) = MomoSms("QA_ONLY", "Synthetic receipt $i", now+i)

    @Before fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        check(context.packageName == "com.momobio.app.qa") { "Never run against an operational collector" }
        queue = DurableSmsQueue(context)
        db = SQLiteDatabase.openDatabase(context.getDatabasePath("momobio_receipts.db").path, null, SQLiteDatabase.OPEN_READWRITE)
        // Only synthetic, isolated QA storage is reset. Enrollment keys are not touched.
        db.execSQL("DELETE FROM receipts")
        db.execSQL("DELETE FROM overflow_receipts")
        db.execSQL("DELETE FROM receipt_refusals")
        db.execSQL("DELETE FROM queue_metadata")
        db.execSQL("INSERT INTO queue_metadata(key,value) VALUES ('legacy_imported','1')")
        assertTrue(context.getSharedPreferences("momo_sms_queue", Context.MODE_PRIVATE).edit().clear().commit())
    }
    @After fun close() { if (::db.isInitialized) db.close() }

    @Test fun durableAdmissionPartialAckAndReopen() {
        assertEquals(2, queue.enqueue(listOf(receipt(1), receipt(2)), now).accepted)
        queue.markUploaded(setOf(receipt(1).messageHash), now+1)
        val reopened = DurableSmsQueue(context)
        assertEquals(listOf(receipt(2)), reopened.batch(now=now+2))
        assertEquals(1, reopened.enqueue(listOf(receipt(1)), now+2).duplicate)
        db.rawQuery("SELECT payload,payload_bytes FROM receipts WHERE message_hash=?", arrayOf(receipt(1).messageHash)).use {
            assertTrue(it.moveToFirst()); assertTrue(it.isNull(0)); assertEquals(0, it.getInt(1))
        }
    }
    @Test fun unknownAckDoesNotClaimObservedReceipt() {
        queue.enqueue(listOf(receipt(1)), now)
        queue.markUploaded(setOf("f".repeat(64)), now+1)
        assertEquals(0L, queue.health().lastAckAt)
        assertEquals(1, queue.count())
    }
    @Test fun policyReviewCannotBeAcknowledgedAccidentally() {
        queue.enqueue(listOf(receipt(1)), now)
        queue.quarantine(setOf(receipt(1).messageHash), "policy_review")
        queue.markUploaded(setOf(receipt(1).messageHash), now+1)
        assertEquals(1, queue.health().quarantined)
        assertTrue(queue.batch(now=now+2).isEmpty())
    }
    @Test fun pendingAgeMovesToQuarantineWithoutErasing() {
        queue.enqueue(listOf(receipt(1)), now-DurableSmsQueue.MAX_PENDING_AGE_MS-1)
        assertTrue(queue.batch(now=now).isEmpty())
        assertEquals(1, queue.health().quarantined)
        assertTrue(queue.health().bytes > 0)
    }
    @Test fun corruptLegacyRowIsPreservedAndValidRowsMigrateOnce() {
        db.execSQL("DELETE FROM queue_metadata WHERE key='legacy_imported'")
        assertTrue(context.getSharedPreferences("momo_sms_queue",Context.MODE_PRIVATE).edit()
            .putString("pending", receipt(1).toJson()+"\n{corrupt")
            .putString("uploaded", "invalid-ack-row").commit())
        val migrated = DurableSmsQueue(context)
        assertEquals(1, migrated.count()); assertEquals(2, migrated.health().quarantined)
        assertFalse(context.getSharedPreferences("momo_sms_queue",Context.MODE_PRIVATE).contains("pending"))
        assertEquals(1, DurableSmsQueue(context).count())
    }
    @Test fun concurrentDuplicateAdmissionCreatesOnePendingReceipt() {
        val executor=Executors.newFixedThreadPool(4)
        try {
            val attempts = (1..20).map { executor.submit<Int> { DurableSmsQueue(context).enqueue(listOf(receipt(1)),now).accepted } }
            assertEquals(1, attempts.sumOf { it.get() })
            assertEquals(1, queue.count())
        } finally { executor.shutdownNow() }
    }
    @Test fun saturatedActiveQueueRetainsRawOverflowAcrossReopenAndPromotesAfterAck() {
        val seed = db.compileStatement("INSERT INTO receipts(message_hash,payload,payload_bytes,received_at,admitted_at,state) " +
            "VALUES (?,?,?,?,?,'pending')")
        db.beginTransaction()
        try {
            for (i in 0 until DurableSmsQueue.MAX_ACTIVE_ROWS) {
                val message = receipt(100 + i)
                val raw = message.toJson()
                seed.clearBindings()
                seed.bindString(1,message.messageHash)
                seed.bindString(2,raw)
                seed.bindLong(3,raw.toByteArray(Charsets.UTF_8).size.toLong())
                seed.bindLong(4,message.receivedAtMillis)
                seed.bindLong(5,now + i)
                seed.executeInsert()
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
            seed.close()
        }
        val deferred = receipt(20_000)
        val admission = queue.enqueue(listOf(deferred),now)
        assertEquals(1,admission.accepted)
        assertEquals(1,admission.deferred)
        assertEquals(0,admission.blocked)
        val reopened = DurableSmsQueue(context)
        assertEquals(1,reopened.health().overflowPending)
        assertTrue(reopened.health().capacityWarning)
        assertEquals(10_001,reopened.count())
        assertEquals(1,reopened.enqueue(listOf(deferred),now).duplicate)
        assertEquals(deferred.toJson(),db.rawQuery(
            "SELECT payload FROM overflow_receipts WHERE message_hash=?",arrayOf(deferred.messageHash)).use {
            assertTrue(it.moveToFirst());it.getString(0)
        })
        reopened.markUploaded(setOf(receipt(100).messageHash),now+1)
        assertEquals(0,reopened.health().overflowPending)
        assertTrue(reopened.batch(now=now+2).contains(deferred))
    }
    @Test fun backoffAndHealthArePersistedIndependentlyOfQueueSize() {
        queue.recordOutcome(UploadResult(false, message="rate limited", outcome="rate_limited", retryAfterMillis=120_000), now)
        assertFalse(DurableSmsQueue(context).permittedAttempt(now+60_000))
        assertEquals(0L, queue.serverAcknowledgedAt())
        queue.recordOutcome(UploadResult(true,message="healthy",serverAcknowledged=true,automaticAllocationEnabled=false),now+120_000)
        assertEquals(now+120_000, queue.serverAcknowledgedAt())
        assertEquals(false, queue.automaticAllocationEnabled())
        assertFalse(queue.permittedAttempt(now+120_001))
    }
    @Test fun byteBoundedBatchCannotExceedTransportBodyBudget() {
        val messages=(1..50).map { MomoSms("QA_ONLY", "Synthetic "+"x".repeat(8_000),now+it) }
        assertEquals(50, queue.enqueue(messages,now).accepted)
        val batch=queue.batch(now=now+1)
        val bytes=("{\"messages\":["+batch.joinToString(",") { it.toJson() }+"]}").toByteArray(Charsets.UTF_8).size
        assertTrue(batch.isNotEmpty()); assertTrue(batch.size < 50)
        assertTrue(bytes <= DurableSmsQueue.MAX_BATCH_BYTES)
    }
}
