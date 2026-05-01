package com.mobi.ledger.util

import java.security.MessageDigest

object HashUtils {
    /**
     * Generate a SHA-256 hash for deduplication.
     * Salted with agentId (member_id) to prevent collisions across users.
     */
    fun sha256(agentId: String, content: String): String {
        val input = agentId + content
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
