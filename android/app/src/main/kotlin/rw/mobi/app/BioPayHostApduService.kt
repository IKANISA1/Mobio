package rw.mobi.app

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class BioPayHostApduService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return status("6F00")
        if (!isSelectAid(commandApdu)) return status("6D00")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return status("6A82")

        val payload = prefs.getString(KEY_PAYLOAD, null)
        if (payload.isNullOrBlank()) return status("6A82")

        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        if (payloadBytes.size > MAX_RESPONSE_BYTES) {
            Log.w(TAG, "BioPay HCE payload too large: ${payloadBytes.size}")
            return status("6700")
        }
        return payloadBytes + status("9000")
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "BioPay HCE deactivated: $reason")
    }

    private fun isSelectAid(commandApdu: ByteArray): Boolean {
        val command = commandApdu.toHex()
        return command.startsWith("00A40400") && command.contains(BIOPAY_AID)
    }

    private fun status(hex: String): ByteArray {
        return hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun ByteArray.toHex(): String {
        return joinToString(separator = "") { "%02X".format(it.toInt() and 0xFF) }
    }

    companion object {
        const val BIOPAY_AID = "F04D4F42494F00"
        const val PREFS_NAME = "biopay_device_nfc"
        const val KEY_ENABLED = "enabled"
        const val KEY_PAYLOAD = "payload"
        const val KEY_TOKEN = "token"
        const val KEY_EXPIRES_AT = "expiresAt"
        private const val MAX_RESPONSE_BYTES = 230
        private const val TAG = "BioPayHce"
    }
}
