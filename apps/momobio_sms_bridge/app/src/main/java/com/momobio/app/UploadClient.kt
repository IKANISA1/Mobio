package com.momobio.app

import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class UploadResult(
    val ok: Boolean,
    val uploadedHashes: Set<String> = emptySet(),
    val message: String,
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
        if (messages.isEmpty()) return UploadResult(ok = true, message = "No new SMS")
        if (supabaseUrl.isBlank() || anonKey.isBlank()) {
            return UploadResult(ok = false, message = "Upload config missing")
        }

        val endpoint = "${supabaseUrl.trimEnd('/')}/functions/v1/momobio-sms-ingest"
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
        )
    }

    private fun uploadBatch(endpoint: String, messages: List<MomoSms>): UploadResult {
        val body = """{"messages":[${messages.joinToString(",") { it.toJson() }}]}"""
        val bytes = body.toByteArray(Charsets.UTF_8)
        var connection: HttpURLConnection? = null
        return try {
            val activeConnection = openConnection(endpoint)
            // Keep the opened connection before configuration/signing can fail.
            connection = activeConnection
            activeConnection.apply {
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
            val responseText = if (responseCode in 200..299) {
                activeConnection.inputStream.bufferedReader().use { it.readText() }
            } else {
                activeConnection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
            }
            if (responseCode in 200..299) {
                val response = JSONObject(responseText)
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
                )
            } else {
                logFailure("Upload failed $responseCode")
                UploadResult(ok = false, message = when (responseCode) {
                    401, 403 -> "Collector enrollment required"
                    409 -> "Retrying collector request"
                    429 -> "Sync limit reached; retrying later"
                    else -> "Upload failed $responseCode"
                })
            }
        } catch (error: Exception) {
            logFailure("Upload failed: ${error.javaClass.simpleName}")
            UploadResult(ok = false, message = "Sync unavailable; messages remain queued")
        } finally {
            connection?.disconnect()
        }
    }
}
