package com.momobio.app

import android.content.Context

class SmsQueue(context: Context) {
    private val prefs = context.getSharedPreferences("momo_sms_queue", Context.MODE_PRIVATE)

    @Synchronized
    fun enqueue(messages: List<MomoSms>) {
        if (messages.isEmpty()) return
        val uploaded = uploadedHashes()
        val existing = all().associateBy { it.messageHash }.toMutableMap()
        for (message in messages) {
            if (!uploaded.contains(message.messageHash)) {
                existing[message.messageHash] = message
            }
        }
        prefs.edit().putString("pending", existing.values.joinToString("\n") { it.toJson() }).apply()
    }

    @Synchronized
    fun all(): List<MomoSms> =
        prefs.getString("pending", null)
            ?.lineSequence()
            ?.mapNotNull { MomoSms.fromJson(it) }
            ?.toList()
            ?: emptyList()

    @Synchronized
    fun remove(uploadedHashes: Set<String>) {
        if (uploadedHashes.isEmpty()) return
        val remaining = all().filterNot { uploadedHashes.contains(it.messageHash) }
        prefs.edit().putString("pending", remaining.joinToString("\n") { it.toJson() }).apply()
    }

    @Synchronized
    fun markUploaded(uploadedHashes: Set<String>) {
        if (uploadedHashes.isEmpty()) return
        remove(uploadedHashes)
        val uploaded = uploadedHashes().toMutableSet()
        uploaded += uploadedHashes
        prefs.edit().putString("uploaded", uploaded.joinToString("\n")).apply()
    }

    fun count(): Int = all().size

    private fun uploadedHashes(): Set<String> =
        prefs.getString("uploaded", null)
            ?.lineSequence()
            ?.filter { it.isNotBlank() }
            ?.toSet()
            ?: emptySet()
}
