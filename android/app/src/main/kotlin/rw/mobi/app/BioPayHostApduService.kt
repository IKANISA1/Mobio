package rw.mobi.app

import android.content.SharedPreferences
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.SystemClock
import java.time.Instant

class BioPayHostApduService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return status("6F00")
        if (!BioPayNfcPolicy.isSelectAid(commandApdu)) return status("6D00")
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        if (!isActive(prefs)) {
            clearAdvertisement(prefs)
            return status("6A82")
        }
        val payload = prefs.getString(KEY_PAYLOAD, null) ?: return status("6A82")
        return payload.toByteArray(Charsets.UTF_8) + status("9000")
    }

    override fun onDeactivated(reason: Int) = Unit

    private fun status(hex: String) = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    companion object {
        const val BIOPAY_AID = BioPayNfcPolicy.AID
        const val PREFS_NAME = "biopay_device_nfc"
        const val KEY_ENABLED = "enabled"
        const val KEY_PAYLOAD = "payload"
        const val KEY_TOKEN = "token"
        const val KEY_EXPIRES_AT = "expiresAt"
        const val KEY_STARTED_AT = "startedAtMillis"
        const val KEY_STARTED_ELAPSED = "startedElapsedMillis"
        const val KEY_DEADLINE_ELAPSED = "deadlineElapsedMillis"
        const val KEY_PROCESS_INSTANCE = "processInstance"

        fun isActive(prefs: SharedPreferences): Boolean {
            val expiry = try {
                Instant.parse(prefs.getString(KEY_EXPIRES_AT, null)).toEpochMilli()
            } catch (_: Exception) { return false }
            val value = BioPayNfcPolicy.Advertisement(
                prefs.getBoolean(KEY_ENABLED, false), prefs.getString(KEY_PAYLOAD, null), expiry,
                prefs.getLong(KEY_STARTED_AT, 0L), prefs.getLong(KEY_STARTED_ELAPSED, -1L),
                prefs.getLong(KEY_DEADLINE_ELAPSED, 0L), prefs.getString(KEY_PROCESS_INSTANCE, null),
            )
            return BioPayNfcPolicy.active(value, System.currentTimeMillis(), SystemClock.elapsedRealtime())
        }

        fun clearAdvertisement(prefs: SharedPreferences): Boolean = prefs.edit().clear().commit()
    }
}
