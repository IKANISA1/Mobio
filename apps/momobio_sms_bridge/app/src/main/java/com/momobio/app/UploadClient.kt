package com.momobio.app

import android.util.Log
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
) {
    constructor(
        identity: CollectorIdentity,
        supabaseUrl: String = BuildConfig.SUPABASE_URL,
        anonKey: String = BuildConfig.SUPABASE_ANON_KEY,
    ) : this(identity::headers, supabaseUrl, anonKey,
        { URL(it).openConnection() as HttpURLConnection },
        { Log.e("MoMobioBridge", it) })

    private val batchSize = 50

    fun upload(
        messages: List<MomoSms>,
        onUploaded: ((Set<String>) -> Unit)? = null,
    ): UploadResult {
        if (!CollectorTransportPolicy.validEndpoint(supabaseUrl) || anonKey.isBlank()) {
            return UploadResult(ok = false, message = "Secure upload config missing", outcome = "configuration_missing")
        }

        val endpoint = "${supabaseUrl.trimEnd('/')}/functions/v1/momobio-sms-ingest"
        if (messages.isEmpty()) return uploadBatch(endpoint, emptyList())
        val uploaded = mutableSetOf<String>()
        for (chunk in messages.chunked(batchSize)) {
            val result = uploadBatch(endpoint, chunk)
            uploaded += result.uploadedHashes
            if (result.uploadedHashes.isNotEmpty()) {
                try {
                    onUploaded?.invoke(result.uploadedHashes)
                } catch (error: Exception) {
                    logFailure("Queue acknowledgement failed: ${error.javaClass.simpleName}")
                    return UploadResult(
                        ok = false,
                        uploadedHashes = uploaded.toSet(),
                        message = "Server acknowledged ${uploaded.size}/${messages.size}; local queue save failed",
                    )
                }
            }
            if (!result.ok) {
                return result.copy(
                    uploadedHashes = uploaded,
                    message = "Uploaded ${uploaded.size}/${messages.size}; ${result.message}",
                )
            }
        }
        return UploadResult(
            ok = true,
            uploadedHashes = uploaded,
            message = "Uploaded ${uploaded.size}",
            serverAcknowledged = true,
        )
    }

    private fun uploadBatch(endpoint: String, messages: List<MomoSms>): UploadResult {
        val body = if (messages.isEmpty()) """{"action":"health"}""" else
            """{"messages":[${messages.joinToString(",") { it.toJson() }}]}"""
        val bytes = body.toByteArray(Charsets.UTF_8)
        if (bytes.size > 512_000) return UploadResult(false, message = "Batch exceeds upload limit", outcome = "oversized_batch")
        var connection: HttpURLConnection? = null
        return try {
            val activeConnection = openConnection(endpoint)
            // Keep the opened connection before configuration/signing can fail.
            connection = activeConnection
            activeConnection.apply {
                instanceFollowRedirects = false
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 60_000
                doOutput = true
                setRequestProperty("content-type", "application/json")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("authorization", "Bearer $anonKey")
                for ((name, value) in signHeaders(bytes)) setRequestProperty(name, value)
            }
            activeConnection.outputStream.use { it.write(bytes) }
            val responseCode = activeConnection.responseCode
            val retryAfter = CollectorTransportPolicy.retryAfterMillis(
                activeConnection.getHeaderField("Retry-After"), System.currentTimeMillis())
            val responseText = if (responseCode in 200..299) {
                readBoundedResponse(activeConnection.inputStream)
            } else {
                // Do not echo provider bodies (which may contain sensitive information).
                activeConnection.errorStream?.close()
                ""
            }
            if (responseCode in 200..299) {
                val response = JSONObject(responseText)
                if (messages.isEmpty()) {
                    val healthy = response.optBoolean("success") &&
                        response.optString("kind") == "collector_health" && response.optBoolean("collector_enrolled") &&
                        response.opt("automatic_allocation_enabled") is Boolean
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
        } catch (error: Exception) {
            logFailure("Upload failed: ${error.javaClass.simpleName}")
            UploadResult(ok = false, message = "Sync unavailable; messages remain queued")
        } finally {
            connection?.disconnect()
        }
    }
    private fun readBoundedResponse(input: java.io.InputStream): String = input.use { stream ->
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            val n = stream.read(buffer)
            if (n < 0) break
            check(output.size() + n <= 262_144) { "Response size exceeded" }
            output.write(buffer, 0, n)
        }
        output.toString("UTF-8")
    }

}
