package com.momobio.app

import java.net.URI
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.security.MessageDigest

/** Local data-minimization policy only. The backend alone allocates payments. */
data class CollectorPolicy(
    val version: String,
    val allowedSenders: Set<String>,
    val receiptMarkers: Set<String>,
) {
    val configured: Boolean get() = version.matches(Regex("[A-Za-z0-9._-]{1,64}")) &&
        allowedSenders.isNotEmpty() && receiptMarkers.isNotEmpty() &&
        allowedSenders.size <= 20 && receiptMarkers.size <= 20 &&
        allowedSenders.all { it.isNotBlank() && it.length <= 64 && it.none { c -> c < ' ' } } &&
        receiptMarkers.all { it.length in 3..100 && it.none { c -> c < ' ' } }

    // Consent binds the complete policy, not merely a manually bumped label.
    val fingerprint: String get() {
        val canonical = (listOf(version) + allowedSenders.sorted().map { "s:" + it } +
            receiptMarkers.sorted().map { "m:" + it }).joinToString("\n")
        return MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    fun accepts(sender: String, body: String, receivedAtMillis: Long): Boolean {
        if (!configured || sender.isBlank() || body.isBlank() || receivedAtMillis <= 0) return false
        if (sender.toByteArray(Charsets.UTF_8).size > 100 ||
            body.toByteArray(Charsets.UTF_8).size > MAX_BODY_BYTES || '\u0000' in body) return false
        return allowedSenders.any { it.equals(sender.trim(), ignoreCase = true) } &&
            receiptMarkers.any { body.contains(it, ignoreCase = true) }
    }

    companion object {
        const val MAX_BODY_BYTES = 8192
        fun fromCsv(version: String, senders: String, markers: String): CollectorPolicy =
            CollectorPolicy(version.trim(), split(senders), split(markers))
        private fun split(raw: String): Set<String> = raw.split(',').map { it.trim() }
            .filter { it.isNotBlank() }.toSet()
    }
}

object CollectorTransportPolicy {
    fun validEndpoint(baseUrl: String): Boolean = try {
        val u = URI(baseUrl)
        u.scheme == "https" && !u.host.isNullOrBlank() && u.rawUserInfo == null &&
            u.rawQuery == null && u.rawFragment == null && u.port in setOf(-1, 443) &&
            u.rawPath.orEmpty() in setOf("", "/")
    } catch (_: Exception) { false }

    // Engineering cap: honor Retry-After up to seven days; longer responses require
    // operational review. No raw header is logged or used as a URL.
    fun retryAfterMillis(value: String?, nowMillis: Long): Long? {
        if (value.isNullOrBlank() || value.length > 128) return null
        val raw = value.trim()
        raw.toLongOrNull()?.let {
            if (it < 0) return null
            return it.coerceAtMost(7 * 24 * 60 * 60).times(1000L)
        }
        return try {
            (ZonedDateTime.parse(raw, DateTimeFormatter.RFC_1123_DATE_TIME)
                .toInstant().toEpochMilli() - nowMillis).coerceIn(0, MAX_BACKOFF_MS)
        } catch (_: Exception) { null }
    }

    fun backoffMillis(failures: Int, retryAfter: Long? = null, jitter: Double = 0.5): Long {
        val base = (30_000L * (1L shl (failures - 1).coerceIn(0, 10))).coerceAtMost(3_600_000L)
        val factor = 1.0 + (if (jitter.isFinite()) jitter.coerceIn(0.0, 1.0) else 0.5) * 0.25
        return maxOf((base * factor).toLong(), retryAfter?.coerceIn(0, MAX_BACKOFF_MS) ?: 0)
    }
    const val MAX_BACKOFF_MS = 7L * 24 * 60 * 60 * 1000
}
