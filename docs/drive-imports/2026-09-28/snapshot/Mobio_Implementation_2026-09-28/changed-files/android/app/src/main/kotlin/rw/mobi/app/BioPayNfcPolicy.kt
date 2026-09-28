package rw.mobi.app

import java.time.Instant
import java.util.UUID

/** Pure policy, shared by the channel/status and the native APDU boundary. */
object BioPayNfcPolicy {
    const val AID = "F04D4F42494F00"
    const val MAX_RESPONSE_BYTES = 230
    const val MAX_ADVERTISEMENT_MILLIS = 300_000L
    // Never persisted as an authority across process death or reboot.
    val processInstance: String = UUID.randomUUID().toString()

    data class Advertisement(
        val enabled: Boolean,
        val payload: String?,
        val expiresAtMillis: Long,
        val startedAtMillis: Long,
        val startedElapsedMillis: Long,
        val deadlineElapsedMillis: Long,
        val instance: String?,
    )

    fun prepare(payload: String?, expiresAt: String?, wallNow: Long, elapsedNow: Long): Advertisement? {
        if (payload.isNullOrBlank() || payload.toByteArray(Charsets.UTF_8).size > MAX_RESPONSE_BYTES ||
            wallNow <= 0L || elapsedNow < 0L) return null
        val requestedExpiry = try { Instant.parse(expiresAt).toEpochMilli() } catch (_: Exception) { return null }
        if (requestedExpiry <= wallNow) return null
        val duration = minOf(requestedExpiry - wallNow, MAX_ADVERTISEMENT_MILLIS)
        if (elapsedNow > Long.MAX_VALUE - duration || wallNow > Long.MAX_VALUE - duration) return null
        return Advertisement(true, payload, wallNow + duration, wallNow, elapsedNow,
            elapsedNow + duration, processInstance)
    }

    fun active(value: Advertisement, wallNow: Long, elapsedNow: Long): Boolean {
        val payload = value.payload
        return value.enabled && value.instance == processInstance &&
            !payload.isNullOrBlank() && payload.toByteArray(Charsets.UTF_8).size <= MAX_RESPONSE_BYTES &&
            value.startedAtMillis > 0 && value.expiresAtMillis > value.startedAtMillis &&
            value.expiresAtMillis - value.startedAtMillis <= MAX_ADVERTISEMENT_MILLIS &&
            value.startedElapsedMillis >= 0 && value.deadlineElapsedMillis > value.startedElapsedMillis &&
            value.deadlineElapsedMillis - value.startedElapsedMillis <= MAX_ADVERTISEMENT_MILLIS &&
            wallNow >= value.startedAtMillis && wallNow < value.expiresAtMillis &&
            elapsedNow >= value.startedElapsedMillis && elapsedNow < value.deadlineElapsedMillis
    }

    fun isSelectAid(command: ByteArray?): Boolean {
        if (command == null) return false
        val expected = ("00A4040007" + AID).chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        return command.contentEquals(expected) ||
            (command.size == expected.size + 1 && command.last() == 0.toByte() &&
                command.copyOfRange(0, expected.size).contentEquals(expected))
    }
}
