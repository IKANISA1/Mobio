package com.momobio.app

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Written, unexecuted: exercise real orchestration and the OS lease, not constants. */
class UploadDeadlineTest {
    private fun messages(count: Int) = (1..count).map {
        MomoSms("QA", "Synthetic deadline receipt " + it, 1_780_000_000_000 + it.toLong())
    }

    @Test fun cancelledBeforeStartCannotOpenSignOrAcknowledge() {
        val cancel = UploadCancellation().apply { cancel() }
        val fixture = DeadlineFixture()
        val receipts = mutableListOf<Set<String>>()
        val result = fixture.client().upload(messages(1), cancel) { receipts += it }
        assertEquals("upload_cancelled", result.outcome)
        assertEquals(0, fixture.opens.get())
        assertEquals(0, fixture.signs.get())
        assertTrue(receipts.isEmpty())
    }

    @Test fun cancellingAnotherOwnersHandleCannotDisconnectThisSender() {
        val fixture = DeadlineFixture()
        val connection = DeadlineConnection().apply { blockedPhase = "write" }
        fixture.factory = { connection }
        val owner = UploadCancellation()
        val foreign = UploadCancellation()
        val result = AtomicReference<UploadResult>()
        val sender = Thread { result.set(fixture.client().upload(messages(1), owner)) }
        sender.start()
        try {
            assertTrue(connection.entered.await(2, TimeUnit.SECONDS))
            foreign.cancel()
            assertEquals("upload_cancelled", DeadlineFixture().client().upload(messages(1), foreign).outcome)
            assertTrue(sender.isAlive)
            assertEquals(0, connection.disconnects.get())
            owner.cancel()
            sender.join(2_000)
            assertFalse(sender.isAlive)
            assertEquals("upload_cancelled", result.get().outcome)
            assertEquals(1, connection.disconnects.get())
        } finally {
            owner.cancel()
            connection.release.countDown()
            sender.join(2_000)
        }
    }

    @Test fun aContinuousBodyCrossingEitherMonotonicBudgetCannotAcknowledge() {
        for (policy in listOf(
            UploadDeadlinePolicy(overallMillis = 70, requestMillis = 200),
            UploadDeadlinePolicy(overallMillis = 200, requestMillis = 70),
        )) {
            val fixture = DeadlineFixture()
            val connection = DeadlineConnection().apply {
                afterByte = { fixture.clock.addAndGet(40) }
            }
            fixture.factory = { connection }
            val receipts = mutableListOf<Set<String>>()
            val result = fixture.client(policy).upload(messages(1)) { receipts += it }
            assertEquals("upload_deadline", result.outcome)
            assertTrue(connection.readBytes.get() > 0)
            assertTrue(fixture.clock.get() >= 70)
            assertTrue(receipts.isEmpty())
            assertTrue(result.uploadedHashes.isEmpty())
            assertEquals(1, connection.disconnects.get())
            assertEquals(1, connection.inputCloses.get())
        }
    }

    @Test fun blockedWriteAndReadAreReleasedByTheirOwnedStreamAbort() {
        for (phase in listOf("write", "read", "headers")) {
            val fixture = DeadlineFixture()
            val connection = DeadlineConnection().apply { blockedPhase = phase }
            fixture.factory = { connection }
            val cancel = UploadCancellation()
            val receipts = mutableListOf<Set<String>>()
            val result = AtomicReference<UploadResult>()
            val sender = Thread { result.set(fixture.client().upload(messages(1), cancel) { receipts += it }) }
            sender.start()
            try {
                assertTrue(connection.entered.await(2, TimeUnit.SECONDS))
                fixture.clock.set(500)
                fixture.tick.get()!!.invoke()
                assertTrue(connection.disconnected.await(2, TimeUnit.SECONDS))
                sender.join(2_000)
                assertFalse("Actual sender must be terminal", sender.isAlive)
                assertEquals("upload_deadline", result.get().outcome)
                assertTrue(receipts.isEmpty())
                assertEquals(1, connection.disconnects.get())
                if (phase == "write") assertEquals(1, connection.outputCloses.get())
                if (phase == "read") assertEquals(1, connection.inputCloses.get())
            } finally {
                cancel.cancel()
                connection.release.countDown()
                sender.join(2_000)
            }
        }
    }

    @Test fun anUncooperativeHeaderCannotReleaseLeaseOrAcknowledgeLate() {
        val fixture = DeadlineFixture()
        val connection = DeadlineConnection().apply {
            blockedPhase = "headers"
            ignoreAbort = true
        }
        fixture.factory = { connection }
        val cancel = UploadCancellation()
        val receipts = mutableListOf<Set<String>>()
        val result = AtomicReference<UploadResult>()
        val lease = File.createTempFile("collector-owned-", ".lock")
        val sender = Thread {
            CollectorLease.withLease(lease) {
                result.set(fixture.client().upload(messages(51), cancel) { receipts += it })
            }
        }
        sender.start()
        try {
            assertTrue(connection.entered.await(2, TimeUnit.SECONDS))
            cancel.cancel()
            assertTrue(connection.disconnected.await(2, TimeUnit.SECONDS))
            assertTrue(sender.isAlive)
            assertNull("No competing sender may acquire the OS lease", CollectorLease.withLease(lease) { true })
            assertTrue(receipts.isEmpty())
            connection.release.countDown()
            sender.join(2_000)
            assertFalse(sender.isAlive)
            assertEquals("upload_cancelled", result.get().outcome)
            assertTrue(result.get().uploadedHashes.isEmpty())
            assertTrue(receipts.isEmpty())
            assertEquals(1, fixture.opens.get())
            assertEquals(true, CollectorLease.withLease(lease) { true })
        } finally {
            cancel.cancel()
            connection.release.countDown()
            sender.join(2_000)
            lease.delete()
        }
    }

    @Test fun laterCancelledChunkRetainsEarlierCommittedReceiptsAndNeverStartsThird() {
        val fixture = DeadlineFixture()
        val second = DeadlineConnection().apply { blockedPhase = "read" }
        fixture.factory = { if (it == 1) second else DeadlineConnection() }
        val input = messages(121)
        val cancel = UploadCancellation()
        val receipts = mutableListOf<Set<String>>()
        val result = AtomicReference<UploadResult>()
        val sender = Thread { result.set(fixture.client().upload(input, cancel) { receipts += it.toSet() }) }
        sender.start()
        try {
            assertTrue(second.entered.await(2, TimeUnit.SECONDS))
            cancel.cancel()
            sender.join(2_000)
            assertFalse(sender.isAlive)
            val first = input.take(50).map { it.messageHash }.toSet()
            assertEquals(listOf(first), receipts)
            assertEquals(first, result.get().uploadedHashes)
            assertTrue(result.get().serverAcknowledged)
            assertEquals("upload_cancelled", result.get().outcome)
            assertEquals(2, fixture.opens.get())
        } finally {
            cancel.cancel()
            second.release.countDown()
            sender.join(2_000)
        }
    }

    @Test fun disclosurePausePreservesCurrentReceiptAndPreventsNextChunk() {
        val fixture = DeadlineFixture()
        val input = messages(51)
        var ready = true
        val receipts = mutableListOf<Set<String>>()
        val result = fixture.client().upload(input, UploadCancellation(), { ready }) {
            receipts += it.toSet()
            ready = false
        }
        val first = input.take(50).map { it.messageHash }.toSet()
        assertEquals(listOf(first), receipts)
        assertEquals(first, result.uploadedHashes)
        assertEquals("collection_paused", result.outcome)
        assertEquals(1, fixture.opens.get())
    }

    @Test fun chunkBudgetStopsBeforeOpeningMoreAndPreservesCommittedReceipts() {
        val fixture = DeadlineFixture()
        val input = messages(121)
        val receipts = mutableListOf<Set<String>>()
        val result = fixture.client(UploadDeadlinePolicy(maxChunks = 1))
            .upload(input) { receipts += it.toSet() }
        val first = input.take(50).map { it.messageHash }.toSet()
        assertEquals(listOf(first), receipts)
        assertEquals(first, result.uploadedHashes)
        assertEquals("upload_chunk_limit", result.outcome)
        assertEquals(1, fixture.opens.get())
    }

    @Test fun cancellationDuringAdmittedDurableCommitIsNonBlockingAndRetainsItsReceipt() {
        val fixture = DeadlineFixture()
        val cancel = UploadCancellation()
        val enteredCommit = CountDownLatch(1)
        val releaseCommit = CountDownLatch(1)
        val receipts = mutableListOf<Set<String>>()
        val result = AtomicReference<UploadResult>()
        val input = messages(51)
        val sender = Thread {
            result.set(fixture.client().upload(input, cancel) {
                enteredCommit.countDown()
                releaseCommit.await()
                receipts += it.toSet()
            })
        }
        sender.start()
        try {
            assertTrue(enteredCommit.await(2, TimeUnit.SECONDS))
            val cancelled = CountDownLatch(1)
            Thread { cancel.cancel(); cancelled.countDown() }.start()
            assertTrue("Stop callback must not wait for SQLite", cancelled.await(1, TimeUnit.SECONDS))
            assertTrue(sender.isAlive)
            releaseCommit.countDown()
            sender.join(2_000)
            assertFalse(sender.isAlive)
            val first = input.take(50).map { it.messageHash }.toSet()
            assertEquals(listOf(first), receipts)
            assertEquals(first, result.get().uploadedHashes)
            assertEquals("upload_cancelled", result.get().outcome)
            assertEquals(1, fixture.opens.get())
        } finally {
            releaseCommit.countDown()
            cancel.cancel()
            sender.join(2_000)
        }
    }
}

private class DeadlineFixture {
    val clock = AtomicLong(0)
    val tick = AtomicReference<() -> Unit>()
    val opens = AtomicInteger(0)
    val signs = AtomicInteger(0)
    var factory: (Int) -> DeadlineConnection = { DeadlineConnection() }
    fun client(policy: UploadDeadlinePolicy = UploadDeadlinePolicy(overallMillis = 400, requestMillis = 300)) =
        UploadClient(
            signHeaders = { signs.incrementAndGet(); mapOf("x-mobio-signature" to "synthetic-signature") },
            supabaseUrl = "https://collector.invalid/", anonKey = "synthetic-public-key",
            openConnection = { factory(opens.getAndIncrement()) }, logFailure = {},
            monotonicMillis = clock::get, deadlinePolicy = policy,
            watchDeadline = { _, action -> tick.set(action); Closeable {} },
        )
}

private class DeadlineConnection : HttpURLConnection(URL("https://collector.invalid")) {
    val written = ByteArrayOutputStream()
    val disconnects = AtomicInteger(0)
    val inputCloses = AtomicInteger(0)
    val outputCloses = AtomicInteger(0)
    val readBytes = AtomicInteger(0)
    val entered = CountDownLatch(1)
    val release = CountDownLatch(1)
    val disconnected = CountDownLatch(1)
    var blockedPhase = ""
    var ignoreAbort = false
    var afterByte: () -> Unit = {}
    private fun block(phase: String) {
        if (blockedPhase != phase) return
        entered.countDown()
        release.await()
    }
    override fun getOutputStream(): OutputStream = object : OutputStream() {
        override fun write(value: Int) { written.write(value) }
        override fun write(bytes: ByteArray, offset: Int, count: Int) {
            block("write")
            written.write(bytes, offset, count)
        }
        override fun close() {
            outputCloses.incrementAndGet()
            if (!ignoreAbort && blockedPhase == "write") release.countDown()
        }
    }
    override fun getResponseCode(): Int { block("headers"); return 200 }
    override fun getInputStream(): InputStream {
        val messages = JSONObject(written.toString(Charsets.UTF_8)).getJSONArray("messages")
        val rows = JSONArray()
        for (i in 0 until messages.length()) rows.put(JSONObject()
            .put("message_hash", messages.getJSONObject(i).getString("message_hash")).put("status", "accepted"))
        val bytes = JSONObject().put("success", true).put("results", rows).toString().toByteArray()
        val source = ByteArrayInputStream(bytes)
        return object : InputStream() {
            override fun read(): Int {
                block("read")
                val next = source.read()
                if (next >= 0) { readBytes.incrementAndGet(); afterByte() }
                return next
            }
            override fun read(buffer: ByteArray, offset: Int, count: Int): Int {
                val next = read()
                if (next < 0) return -1
                buffer[offset] = next.toByte()
                return 1
            }
            override fun close() {
                inputCloses.incrementAndGet()
                if (!ignoreAbort && blockedPhase == "read") release.countDown()
            }
        }
    }
    override fun disconnect() {
        disconnects.incrementAndGet()
        disconnected.countDown()
        if (!ignoreAbort) release.countDown()
    }
    override fun connect() = Unit
    override fun usingProxy() = false
}
