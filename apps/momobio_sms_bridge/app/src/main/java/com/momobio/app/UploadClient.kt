package com.momobio.app

import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

data class UploadResult(
    val ok: Boolean,
    val uploadedHashes: Set<String> = emptySet(),
    val message: String,
)

class UploadClient(
    private val supabaseUrl: String = BuildConfig.SUPABASE_URL,
    private val anonKey: String = BuildConfig.SUPABASE_ANON_KEY,
) {
    private val logTag = "MoMobioBridge"
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
            if (result.ok && result.uploadedHashes.isNotEmpty()) {
                onUploaded?.invoke(result.uploadedHashes)
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
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 60_000
            doOutput = true
            setRequestProperty("content-type", "application/json")
            setRequestProperty("apikey", anonKey)
            setRequestProperty("authorization", "Bearer $anonKey")
        }

        return try {
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val responseCode = connection.responseCode
            val responseText = if (responseCode in 200..299) {
                connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
            }
            if (responseCode in 200..299) {
                UploadResult(
                    ok = true,
                    uploadedHashes = messages.map { it.messageHash }.toSet(),
                    message = "Uploaded ${messages.size}",
                )
            } else {
                Log.e(logTag, "Upload failed $responseCode: ${responseText.take(500)}")
                UploadResult(ok = false, message = "Upload failed $responseCode: ${responseText.take(120)}")
            }
        } catch (error: Exception) {
            Log.e(logTag, "Upload exception", error)
            UploadResult(ok = false, message = "${error.javaClass.simpleName}: ${error.message ?: "Upload failed"}")
        } finally {
            connection.disconnect()
        }
    }
}
