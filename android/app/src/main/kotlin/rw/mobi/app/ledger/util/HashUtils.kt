package rw.mobi.app.ledger.util

import java.security.MessageDigest

/**
 * SHA-256 hashing utility for SMS deduplication.
 */
object HashUtils {

    /**
     * Generate SHA-256 hash of agent_id + raw SMS body.
     * Used as deduplication key across device and server.
     */
    fun sha256(agentId: String, rawSms: String): String {
        val input = "$agentId:$rawSms"
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
