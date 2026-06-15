package com.momobio.app

import java.security.MessageDigest

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
            val sender = Regex(""""sender"\s*:\s*"((?:\\.|[^"])*)"""").find(value)?.groupValues?.get(1)?.unescapeJson()
            val body = Regex(""""body"\s*:\s*"((?:\\.|[^"])*)"""").find(value)?.groupValues?.get(1)?.unescapeJson()
            val receivedAt = Regex(""""received_at_millis"\s*:\s*(\d+)""").find(value)?.groupValues?.get(1)?.toLongOrNull()
            val messageHash = Regex(""""message_hash"\s*:\s*"((?:\\.|[^"])*)"""").find(value)?.groupValues?.get(1)?.unescapeJson()
            if (sender.isNullOrBlank() || body.isNullOrBlank() || receivedAt == null || messageHash.isNullOrBlank()) return null
            return MomoSms(sender, body, receivedAt, messageHash)
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

private fun String.unescapeJson(): String =
    replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\")
