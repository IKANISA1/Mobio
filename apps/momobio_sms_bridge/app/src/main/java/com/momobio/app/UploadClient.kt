package com.momobio.app

import android.os.SystemClock
import android.util.Log
import java.io.Closeable
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class UploadResult(
    val ok: Boolean,
    val uploadedHashes: Set<String> = emptySet(),
    val message: String,
    val outcome: String = if (ok) "acknowledged" else "unavailable",
    val retryAfterMillis: Long? = null,
    val serverAcknowledged: Boolean = false,
    val automaticAllocationEnabled: Boolean? = null,
)

class UploadClient internal constructor(
    private val signHeaders: (ByteArray) -> Map<String, String>,
    private val supabaseUrl: String,
    private val anonKey: String,
    private val openConnection: (String) -> HttpURLConnection,
    private val logFailure: (String) -> Unit,
    private val monotonicMillis: () -> Long = { System.nanoTime() / 1_000_000 },
    private val deadlinePolicy: UploadDeadlinePolicy = UploadDeadlinePolicy(),
    private val watchDeadline: (Long, () -> Unit) -> Closeable = ::pollingUploadWatchdog,
) {
    constructor(
        identity: CollectorIdentity,
        supabaseUrl: String = BuildConfig.SUPABASE_URL,
        anonKey: String = BuildConfig.SUPABASE_ANON_KEY,
    ) : this(identity::headers, supabaseUrl, anonKey,
        { URL(it).openConnection() as HttpURLConnection },
        { Log.e("MoMobioBridge", it) }, monotonicMillis = SystemClock::elapsedRealtime)

    private val batchSize = 50

    // Preserve the existing callers and trailing durable-acknowledgement lambda.
    fun upload(
        messages: List<MomoSms>,
        onUploaded: ((Set<String>) -> Unit)? = null,
    ): UploadResult = upload(messages, UploadCancellation(), { true }, onUploaded)

    fun upload(
        messages: List<MomoSms>,
        cancellation: UploadCancellation,
        mayStartRequest: () -> Boolean = { true },
        onUploaded: ((Set<String>) -> Unit)? = null,
    ): UploadResult {
        if (!CollectorTransportPolicy.validEndpoint(supabaseUrl) || anonKey.isBlank()) {
            return UploadResult(ok = false, message = "Secure upload config missing", outcome = "configuration_missing")
        }
        val endpoint = "${supabaseUrl.trimEnd('/')}/functions/v1/momobio-sms-ingest"
        val uploaded = mutableSetOf<String>()
        var serverAcknowledged = false
        val deadline = UploadDeadline(cancellation, deadlinePolicy, monotonicMillis, watchDeadline)
        return try {
            if (messages.isEmpty()) {
                val health = uploadBatch(endpoint, emptyList(), 0, deadline, mayStartRequest, onUploaded)
                serverAcknowledged = health.serverAcknowledged
                deadline.checkpoint()
                health
            } else {
                for ((index, chunk) in messages.asSequence().chunked(batchSize).withIndex()) {
                    val result = uploadBatch(endpoint, chunk, index, deadline, mayStartRequest, onUploaded)
                    uploaded += result.uploadedHashes
                    serverAcknowledged = serverAcknowledged || result.serverAcknowledged
                    deadline.checkpoint()
                    if (!result.ok) return result.copy(
                        uploadedHashes = uploaded.toSet(),
                        message = "Uploaded ${uploaded.size}/${messages.size}; ${result.message}",
                        serverAcknowledged = serverAcknowledged,
                    )
                }
                deadline.checkpoint()
                UploadResult(
                    ok = true,
                    uploadedHashes = uploaded.toSet(),
                    message = "Uploaded ${uploaded.size}",
                    serverAcknowledged = true,
                )
            }
        } catch (stopped: UploadStopped) {
            UploadResult(false, uploadedHashes = uploaded.toSet(),
                message = "Uploaded ${uploaded.size}/${messages.size}; ${stopped.reason.safeMessage}",
                outcome = stopped.reason.outcome, serverAcknowledged = serverAcknowledged)
        } finally {
            // Actual request sender and abort cleanup are terminal before the lease owner returns.
            deadline.close()
        }
    }

    private fun uploadBatch(
        endpoint: String,
        messages: List<MomoSms>,
        index: Int,
        deadline: UploadDeadline,
        mayStartRequest: () -> Boolean,
        onUploaded: ((Set<String>) -> Unit)?,
    ): UploadResult {
        val request = deadline.startRequest(index, mayStartRequest)
        return try {
            val body = if (messages.isEmpty()) """{"action":"health"}""" else
                """{"messages":[${messages.joinToString(",") { it.toJson() }}]}"""
            val bytes = body.toByteArray(Charsets.UTF_8)
            deadline.checkpoint(request)
            if (bytes.size > 512_000) return UploadResult(false, message = "Batch exceeds upload limit", outcome = "oversized_batch")
            val activeConnection = openConnection(endpoint)
            // Keep the opened connection before configuration/signing can fail.
            request.ownConnection(activeConnection)
            deadline.checkpoint(request)
            activeConnection.apply {
                instanceFollowRedirects = false
                requestMethod = "POST"
                connectTimeout = deadline.phaseTimeout(request, 15_000)
                readTimeout = deadline.phaseTimeout(request, 60_000)
                doOutput = true
                setRequestProperty("content-type", "application/json")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("authorization", "Bearer $anonKey")
                for ((name, value) in signHeaders(bytes)) setRequestProperty(name, value)
            }
            deadline.beforeSend(request, mayStartRequest)
            activeConnection.connectTimeout = deadline.phaseTimeout(request, 15_000)
            activeConnection.readTimeout = deadline.phaseTimeout(request, 60_000)
            val output = activeConnection.outputStream
            val closeOutput = request.ownStream(output)
            try {
                deadline.checkpoint(request)
                output.write(bytes)
                deadline.checkpoint(request)
            } finally { closeOutput() }
            deadline.checkpoint(request)
            activeConnection.readTimeout = deadline.phaseTimeout(request, 60_000)
            val responseCode = activeConnection.responseCode
            deadline.checkpoint(request)
            val retryAfter = CollectorTransportPolicy.retryAfterMillis(
                activeConnection.getHeaderField("Retry-After"), System.currentTimeMillis())
            deadline.checkpoint(request)
            val responseText = if (responseCode in 200..299) {
                readBoundedResponse(activeConnection.inputStream, request, deadline)
            } else {
                // Do not echo provider bodies (which may contain sensitive information).
                activeConnection.errorStream?.let { request.ownStream(it).invoke() }
                ""
            }
            deadline.checkpoint(request)
            if (responseCode in 200..299) {
                val response = JSONObject(responseText)
                deadline.checkpoint(request)
                if (messages.isEmpty()) {
                    val healthy = response.optBoolean("success") &&
                        response.optString("kind") == "collector_health" && response.optBoolean("collector_enrolled") &&
                        response.opt("automatic_allocation_enabled") is Boolean
                    if (healthy) deadline.claimAcknowledgement(request)
                    return UploadResult(healthy, message = if (healthy) "Server verified collector; no queued receipts"
                        else "Collector health not acknowledged", outcome = if (healthy) "healthy" else "invalid_acknowledgement",
                        serverAcknowledged = healthy,
                        automaticAllocationEnabled = if (healthy) response.optBoolean("automatic_allocation_enabled") else null)
                }
                val results = response.optJSONArray("results")
                val expected = messages.map { it.messageHash }.toSet()
                val acknowledged = mutableSetOf<String>()
                if (response.optBoolean("success") && results != null) {
                    for (index in 0 until results.length()) {
                        val row = results.optJSONObject(index) ?: continue
                        val hash = row.optString("message_hash")
                        if (hash in expected && row.optString("status") in setOf("matched", "duplicate", "unmatched", "ambiguous", "ignored", "accepted")) acknowledged += hash
                    }
                }
                if (acknowledged.isNotEmpty()) {
                    deadline.claimAcknowledgement(request)
                    try {
                        onUploaded?.invoke(acknowledged.toSet())
                    } catch (error: Exception) {
                        logFailure("Queue acknowledgement failed: ${error.javaClass.simpleName}")
                        return UploadResult(false, uploadedHashes = acknowledged.toSet(),
                            message = "Server acknowledged ${acknowledged.size}/${messages.size}; local queue save failed",
                            serverAcknowledged = true)
                    }
                }
                UploadResult(
                    ok = acknowledged == expected,
                    uploadedHashes = acknowledged,
                    message = if (acknowledged == expected) "Uploaded ${acknowledged.size}" else "Incomplete server acknowledgement",
                    serverAcknowledged = acknowledged.isNotEmpty(),
                )
            } else {
                logFailure("Upload failed $responseCode")
                UploadResult(ok = false, message = when (responseCode) {
                    401, 403 -> "Collector enrollment required"
                    409 -> "Retrying collector request"
                    429 -> "Sync limit reached; retrying later"
                    else -> "Upload failed $responseCode"
                }, outcome = when (responseCode) {
                    401, 403 -> "enrollment_required"
                    429 -> "rate_limited"
                    in 300..399 -> "redirect_rejected"
                    else -> "http_error"
                }, retryAfterMillis = retryAfter)
            }
        } catch (stopped: UploadStopped) {
            throw stopped
        } catch (error: Exception) {
            deadline.checkpoint(request)
            logFailure("Upload failed: ${error.javaClass.simpleName}")
            UploadResult(ok = false, message = "Sync unavailable; messages remain queued")
        } finally {
            deadline.finishRequest(request)
        }
    }
    private fun readBoundedResponse(
        input: java.io.InputStream,
        request: OwnedUploadRequest,
        deadline: UploadDeadline,
    ): String {
        val closeInput = request.ownStream(input)
        return try {
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            while (true) {
                deadline.checkpoint(request)
                val n = input.read(buffer)
                deadline.checkpoint(request)
                if (n < 0) break
                check(output.size() + n <= 262_144) { "Response size exceeded" }
                output.write(buffer, 0, n)
            }
            output.toString("UTF-8")
        } finally { closeInput() }
    }
}
