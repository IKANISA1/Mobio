package com.momobio.app

import android.content.ContentResolver
import android.net.Uri
import android.provider.Telephony
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

fun readAllSms(
    contentResolver: ContentResolver,
): List<MomoSms> {
    val uri = Uri.parse("content://sms/inbox")
    val projection = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE)
    val rows = mutableListOf<MomoSms>()
    contentResolver.query(uri, projection, null, null, "${Telephony.Sms.DATE} DESC")?.use { cursor ->
        val senderIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
        val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
        val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
        while (cursor.moveToNext()) {
            val sender = cursor.getString(senderIndex) ?: ""
            val body = cursor.getString(bodyIndex) ?: ""
            val receivedAt = cursor.getLong(dateIndex)
            rows += MomoSms(sender = sender, body = body, receivedAtMillis = receivedAt)
        }
    }
    return rows
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
