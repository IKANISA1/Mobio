package com.momobio.app

import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.IOException
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

/**
 * Written, unexecuted JVM loopback tests. Production configuration remains HTTPS;
 * only the injected test connection maps the synthetic endpoint to local HTTP.
 * JDK success is not Android/OEM/TLS cancellation acceptance.
 */
class UploadSocketDeadlineTest {
    @Test fun stalledHeadersTerminateActualSenderWithoutAcknowledgement() = runPeer(slowBody = false)

    @Test fun bodyBytesWithinEveryReadTimeoutStillHitTotalDeadline() = runPeer(slowBody = true)

    private fun runPeer(slowBody: Boolean) {
        val peer = DeadlinePeer(slowBody)
        val signed = AtomicReference<ByteArray>()
        val commits = AtomicInteger(0)
        val result = AtomicReference<UploadResult>()
        val cancel = UploadCancellation()
        val client = UploadClient(
            signHeaders = { signed.set(it.copyOf()); mapOf("x-mobio-signature" to "synthetic-signature") },
            supabaseUrl = "https://collector.invalid/", anonKey = "synthetic-public-key",
            openConnection = { URL("http://127.0.0.1:" + peer.port + "/functions/v1/momobio-sms-ingest")
                .openConnection() as HttpURLConnection },
            logFailure = {},
            monotonicMillis = { System.nanoTime() / 1_000_000 },
            deadlinePolicy = UploadDeadlinePolicy(overallMillis = 1_000, requestMillis = 350, watchdogPollMillis = 10),
        )
        val input = listOf(MomoSms("QA", "Synthetic loopback receipt", 1_780_000_000_001))
        val started = System.nanoTime()
        val sender = Thread { result.set(client.upload(input, cancel) { commits.incrementAndGet() }) }
        sender.start()
        try {
            assertTrue("Peer must receive the actual signed request body", peer.received.await(2, TimeUnit.SECONDS))
            sender.join(2_000)
            val elapsedMillis = (System.nanoTime() - started) / 1_000_000
            assertFalse("Owned sender must actually terminate", sender.isAlive)
            assertFalse(result.get().ok)
            assertTrue(result.get().uploadedHashes.isEmpty())
            assertEquals(0, commits.get())
            assertArrayEquals(signed.get(), peer.body.get())
            assertTrue("Deadline must bound actual socket I/O", elapsedMillis < 2_000)
            if (slowBody) {
                assertTrue(peer.bodyBytesSent.get() > 0)
                assertEquals("upload_deadline", result.get().outcome)
            }
            assertTrue("Owned disconnect must terminate the peer", peer.terminal.await(2, TimeUnit.SECONDS))
        } finally {
            cancel.cancel()
            peer.close()
            sender.join(2_000)
            assertFalse("Fixture cleanup must not leave a sender", sender.isAlive)
        }
    }
}

private class DeadlinePeer(private val slowBody: Boolean) : Closeable {
    private val server = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
    val port: Int get() = server.localPort
    val received = CountDownLatch(1)
    val terminal = CountDownLatch(1)
    val body = AtomicReference<ByteArray>()
    val bodyBytesSent = AtomicInteger(0)
    private val socket = AtomicReference<Socket>()
    private val thread = Thread {
        try {
            server.accept().use { connection ->
                socket.set(connection)
                connection.soTimeout = 2_000
                val input = connection.getInputStream()
                val headerBytes = ByteArrayOutputStream()
                while (true) {
                    val next = input.read()
                    check(next >= 0)
                    headerBytes.write(next)
                    check(headerBytes.size() <= 16_384)
                    if (headerBytes.toString("US-ASCII").endsWith("\r\n\r\n")) break
                }
                val length = headerBytes.toString("US-ASCII").lineSequence()
                    .first { it.startsWith("content-length:", ignoreCase = true) }
                    .substringAfter(':').trim().toInt()
                val bytes = ByteArray(length)
                var offset = 0
                while (offset < length) {
                    val read = input.read(bytes, offset, length - offset)
                    check(read > 0)
                    offset += read
                }
                body.set(bytes)
                received.countDown()
                if (slowBody) {
                    val hash = JSONObject(bytes.toString(Charsets.UTF_8)).getJSONArray("messages")
                        .getJSONObject(0).getString("message_hash")
                    val response = JSONObject().put("success", true).put("results",
                        JSONArray().put(JSONObject().put("message_hash", hash).put("status", "accepted")))
                        .toString().toByteArray(Charsets.UTF_8)
                    val output = connection.getOutputStream()
                    output.write(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " +
                        response.size + "\r\nConnection: close\r\n\r\n").toByteArray(Charsets.US_ASCII))
                    output.flush()
                    for (byte in response) {
                        output.write(byte.toInt())
                        output.flush()
                        bodyBytesSent.incrementAndGet()
                        Thread.sleep(20) // Progress stays well within the per-read timeout.
                    }
                } else {
                    // No response headers: observe transport closure rather than synthesize success.
                    while (input.read() >= 0) { }
                }
            }
        } catch (_: IOException) {
            // Expected when the owned client aborts or fixture cleanup closes sockets.
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            terminal.countDown()
        }
    }.apply { name = "collector-deadline-loopback"; isDaemon = true; start() }

    override fun close() {
        socket.get()?.close()
        server.close()
        thread.join(2_000)
    }
}
