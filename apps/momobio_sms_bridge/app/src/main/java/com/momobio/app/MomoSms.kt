package com.momobio.app

import java.security.MessageDigest
import org.json.JSONException
import org.json.JSONObject

data class MomoSms(
    val sender: String,
    val body: String,
    val receivedAtMillis: Long,
    val messageHash: String = hash(sender, body, receivedAtMillis),
) {
    fun toJson(): String =
        """{"sender":${sender.json()},"body":${body.json()},"received_at_millis":$receivedAtMillis,"message_hash":${messageHash.json()}}"""

    companion object {
        fun fromJson(value: String): MomoSms? {
            return try {
                val record = JSONObject(value)
                val sender = record.opt("sender") as? String
                val body = record.opt("body") as? String
                val timestamp = record.opt("received_at_millis") as? Number
                val receivedAt = timestamp?.toString()?.toLongOrNull()
                val messageHash = record.opt("message_hash") as? String
                if (sender.isNullOrBlank() || body.isNullOrBlank() ||
                    receivedAt == null || receivedAt < 0 || messageHash.isNullOrBlank()) {
                    null
                } else {
                    MomoSms(sender, body, receivedAt, messageHash)
                }
            } catch (_: JSONException) {
                null
            }
        }
    }
}

private fun hash(sender: String, body: String, receivedAtMillis: Long): String {
    val bytes = MessageDigest.getInstance("SHA-256")
        .digest("$sender\n$body\n$receivedAtMillis".toByteArray(Charsets.UTF_8))
    return bytes.joinToString("") { "%02x".format(it) }
}

fun String.json(): String = buildString {
    append('"')
    for (char in this@json) {
        when (char) {
            '\\' -> append("\\\\")
            '"' -> append("\\\"")
            '\n' -> append("\\n")
            '\r' -> append("\\r")
            '\t' -> append("\\t")
            '\b' -> append("\\b")
            '\u000C' -> append("\\f")
            in '\u0000'..'\u001F' -> append("\\u%04x".format(char.code))
            else -> append(char)
        }
    }
    append('"')
}
