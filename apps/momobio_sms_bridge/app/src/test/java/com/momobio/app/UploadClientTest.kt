package com.momobio.app

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/** Real upload orchestration with synthetic transport/signing; no socket or Android component. */
class UploadClientTest {
    private fun messages(count: Int) = (1..count).map {
        MomoSms("QA", "Synthetic receipt $it 🚌\nLiteral \\n", 1_780_000_000_000 + it.toLong())
    }

    @Test fun emptyQueueDoesNotRequireConfigurationOrTouchTransport() {
        val fixture = UploadFixture()
        assertTrue(fixture.client("", "").upload(emptyList()).ok)
        assertTrue(fixture.endpoints.isEmpty())
        assertTrue(fixture.signedBytes.isEmpty())
    }

    @Test fun missingConfigurationRetainsQueueWithoutSigningOrConnecting() {
        for ((url, key) in listOf("" to "fixture", "https://collector.invalid" to "")) {
            val fixture = UploadFixture()
            val result = fixture.client(url, key).upload(messages(1))
            assertFalse(result.ok)
            assertEquals("Upload config missing", result.message)
            assertTrue(fixture.endpoints.isEmpty())
            assertTrue(fixture.signedBytes.isEmpty())
        }
    }

    @Test fun exactUtf8RequestBytesAreSignedAndWrittenOnce() {
        val fixture = UploadFixture()
        val input = messages(2)
        val result = fixture.client().upload(input)
        assertTrue(result.ok)
        val connection = fixture.connections.single()
        assertArrayEquals(fixture.signedBytes.single(), connection.written.toByteArray())
        val body = JSONObject(connection.written.toString(Charsets.UTF_8))
        assertEquals(input[0].body, body.getJSONArray("messages").getJSONObject(0).getString("body"))
        assertEquals("POST", connection.requestMethod)
        assertEquals(15_000, connection.connectTimeout)
        assertEquals(60_000, connection.readTimeout)
        assertEquals("application/json", connection.getRequestProperty("content-type"))
        assertEquals("unit-test-not-a-credential", connection.getRequestProperty("apikey"))
        assertEquals("Bearer unit-test-not-a-credential", connection.getRequestProperty("authorization"))
        assertEquals("synthetic-signature", connection.getRequestProperty("x-mobio-signature"))
        assertEquals(listOf("https://collector.invalid/functions/v1/momobio-sms-ingest"), fixture.endpoints)
        assertEquals(1, connection.disconnects)
    }

    @Test fun onlyExpectedHashesWithAcceptedStatusesAreAcknowledged() {
        val input = messages(6)
        val statuses = listOf("matched", "duplicate", "unmatched", "ambiguous", "ignored", "accepted")
        val fixture = UploadFixture { FakeConnection().apply {
            responseBody = {
                val rows = JSONArray()
                input.zip(statuses).forEach { (message, status) -> rows.put(row(message.messageHash, status)) }
                rows.put(row("foreign-hash", "accepted"))
                response(rows)
            }
        } }
        val result = fixture.client().upload(input)
        assertTrue(result.ok)
        assertEquals(input.map { it.messageHash }.toSet(), result.uploadedHashes)
    }

    @Test fun partialAcknowledgementPersistsOnlyKnownAcceptedRows() {
        val input = messages(2)
        val fixture = UploadFixture { FakeConnection().apply {
            responseBody = { response(JSONArray().put(row(input[0].messageHash, "accepted"))
                .put(row(input[1].messageHash, "failed")).put(row("foreign", "accepted"))) }
        } }
        val saved = mutableListOf<Set<String>>()
        val result = fixture.client().upload(input) { saved += it.toSet() }
        assertFalse(result.ok)
        assertEquals(setOf(input[0].messageHash), result.uploadedHashes)
        assertEquals(listOf(result.uploadedHashes), saved)
    }

    @Test fun completeUploadsUseFiftyMessageBatchesAndDistinctSignatures() {
        val fixture = UploadFixture()
        val input = messages(121)
        val saved = mutableListOf<Set<String>>()
        val result = fixture.client().upload(input) { saved += it.toSet() }
        assertTrue(result.ok)
        assertEquals(listOf(50, 50, 21), saved.map { it.size })
        assertEquals(input.map { it.messageHash }.toSet(), result.uploadedHashes)
        assertEquals(3, fixture.signedBytes.size)
        assertEquals(listOf(50, 50, 21), fixture.connections.map {
            JSONObject(it.written.toString(Charsets.UTF_8)).getJSONArray("messages").length()
        })
        assertTrue(fixture.connections.all { it.disconnects == 1 })
    }

    @Test fun laterBatchFailureReturnsEarlierAcknowledgementsWithoutSendingMore() {
        val fixture = UploadFixture { index -> FakeConnection().apply { if (index == 1) status = 503 } }
        val input = messages(121)
        val saved = mutableListOf<Set<String>>()
        val result = fixture.client().upload(input) { saved += it.toSet() }
        assertFalse(result.ok)
        assertEquals(input.take(50).map { it.messageHash }.toSet(), result.uploadedHashes)
        assertEquals(listOf(result.uploadedHashes), saved)
        assertEquals(2, fixture.connections.size)
    }

    @Test fun connectionCreationFailureReturnsRecoverableResult() {
        val fixture = UploadFixture { throw IOException(privateDiagnostic) }
        val result = fixture.client().upload(messages(1))
        assertSafeFailure(result, fixture)
        assertTrue(fixture.connections.isEmpty())
    }

    @Test fun signingFailureDisconnectsWithoutSendingReceiptBytes() {
        val fixture = UploadFixture().apply { signingFailure = IllegalStateException(privateDiagnostic) }
        val result = fixture.client().upload(messages(1))
        assertSafeFailure(result, fixture)
        assertEquals(0, fixture.connections.single().written.size())
        assertEquals(1, fixture.connections.single().disconnects)
    }

    @Test fun requestConfigurationFailureDisconnectsTheOpenedConnection() {
        val fixture = UploadFixture { FakeConnection().apply { failureAt = "headers" } }
        val result = fixture.client().upload(messages(1))
        assertSafeFailure(result, fixture)
        assertEquals(1, fixture.connections.single().disconnects)
    }

    @Test fun requestWriteFailureRetainsMessagesAndDisconnects() {
        val fixture = UploadFixture { FakeConnection().apply { failureAt = "write" } }
        val result = fixture.client().upload(messages(1))
        assertSafeFailure(result, fixture)
        assertTrue(result.uploadedHashes.isEmpty())
        assertEquals(1, fixture.connections.single().disconnects)
    }

    @Test fun responseReadFailureRetainsMessagesAndDisconnects() {
        val fixture = UploadFixture { FakeConnection().apply { failureAt = "read" } }
        assertSafeFailure(fixture.client().upload(messages(1)), fixture)
        assertEquals(1, fixture.connections.single().disconnects)
    }

    @Test fun malformedSuccessBodyCannotAcknowledgeReceipts() {
        val fixture = UploadFixture { FakeConnection().apply { responseBody = { privateDiagnostic } } }
        val result = fixture.client().upload(messages(1))
        assertSafeFailure(result, fixture)
        assertTrue(result.uploadedHashes.isEmpty())
    }

    @Test fun localAcknowledgementFailureReturnsRetryWithoutSendingNextBatch() {
        val fixture = UploadFixture()
        val input = messages(51)
        val result = fixture.client().upload(input) { throw IllegalStateException(privateDiagnostic) }
        assertSafeFailure(result, fixture)
        assertEquals(input.take(50).map { it.messageHash }.toSet(), result.uploadedHashes)
        assertEquals(1, fixture.connections.size)
        assertEquals(1, fixture.connections.single().disconnects)
    }

    @Test fun unsuccessfulEnvelopeDoesNotAcknowledgeEvenMatchingRows() {
        val input = messages(1)
        val fixture = UploadFixture { FakeConnection().apply {
            responseBody = { JSONObject(response(JSONArray().put(row(input[0].messageHash, "accepted"))))
                .put("success", false).toString() }
        } }
        val result = fixture.client().upload(input)
        assertFalse(result.ok)
        assertTrue(result.uploadedHashes.isEmpty())
    }

    @Test fun rejectedRequestsUseSafeStatusMessages() {
        for ((code, message) in mapOf(401 to "Collector enrollment required", 403 to "Collector enrollment required",
            409 to "Retrying collector request", 429 to "Sync limit reached; retrying later", 500 to "Upload failed 500")) {
            val fixture = UploadFixture { FakeConnection().apply { status = code } }
            val result = fixture.client().upload(messages(1))
            assertSafeFailure(result, fixture)
            assertTrue(result.message.endsWith(message))
            assertTrue(result.uploadedHashes.isEmpty())
        }
    }

    private fun assertSafeFailure(result: UploadResult, fixture: UploadFixture) {
        assertFalse(result.ok)
        assertFalse(result.message.contains(privateDiagnostic))
        assertFalse(fixture.logs.any { it.contains(privateDiagnostic) })
    }
}

private const val privateDiagnostic = "synthetic private receipt diagnostic"
private fun row(hash: String, status: String) = JSONObject().put("message_hash", hash).put("status", status)
private fun response(rows: JSONArray) = JSONObject().put("success", true).put("results", rows).toString()

private class UploadFixture(val factory: (Int) -> FakeConnection = { FakeConnection() }) {
    val endpoints = mutableListOf<String>()
    val connections = mutableListOf<FakeConnection>()
    val signedBytes = mutableListOf<ByteArray>()
    val logs = mutableListOf<String>()
    var signingFailure: Exception? = null
    fun client(url: String = "https://collector.invalid/", key: String = "unit-test-not-a-credential") = UploadClient(
        signHeaders = { bytes -> signingFailure?.let { throw it }; signedBytes += bytes.copyOf(); mapOf("x-mobio-signature" to "synthetic-signature") },
        supabaseUrl = url, anonKey = key,
        openConnection = { endpoint -> endpoints += endpoint; factory(endpoints.lastIndex).also { connections += it } },
        logFailure = { logs += it },
    )
}

private class FakeConnection : HttpURLConnection(URL("https://collector.invalid")) {
    val written = ByteArrayOutputStream()
    var disconnects = 0
    var status = 200
    var failureAt = ""
    var responseBody: () -> String = {
        val messages = JSONObject(written.toString(Charsets.UTF_8)).getJSONArray("messages")
        val rows = JSONArray()
        for (index in 0 until messages.length()) rows.put(row(messages.getJSONObject(index).getString("message_hash"), "accepted"))
        response(rows)
    }
    private fun failAt(stage: String) { if (failureAt == stage) throw IOException(privateDiagnostic) }
    override fun setRequestProperty(name: String, value: String) { failAt("headers"); super.setRequestProperty(name, value) }
    override fun getOutputStream(): ByteArrayOutputStream { failAt("write"); return written }
    override fun getResponseCode(): Int = status
    override fun getInputStream(): ByteArrayInputStream { failAt("read"); return ByteArrayInputStream(responseBody().toByteArray(Charsets.UTF_8)) }
    override fun getErrorStream() = ByteArrayInputStream(privateDiagnostic.toByteArray(Charsets.UTF_8))
    override fun disconnect() { disconnects++ }
    override fun usingProxy() = false
    override fun connect() = Unit
}
