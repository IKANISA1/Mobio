package com.momobio.app

import android.content.Context
import android.content.SharedPreferences

class SmsQueue internal constructor(private val prefs: SharedPreferences) {
    constructor(context: Context) : this(context.getSharedPreferences("momo_sms_queue", Context.MODE_PRIVATE))

    // Android shares this preference instance across callers in this process.
    // Lock it, since receiver, worker and service each create their own queue.
    fun enqueue(messages: List<MomoSms>) = synchronized(prefs) {
        if (messages.isEmpty()) return@synchronized
        val uploaded = uploadedHashes()
        val existing = all().associateBy { it.messageHash }.toMutableMap()
        for (message in messages) {
            if (!uploaded.contains(message.messageHash)) {
                existing[message.messageHash] = message
            }
        }
        save(prefs.edit().putString("pending", existing.values.joinToString("\n") { it.toJson() }))
    }

    fun all(): List<MomoSms> = synchronized(prefs) {
        prefs.getString("pending", null)
            ?.lineSequence()
            ?.mapNotNull { MomoSms.fromJson(it) }
            ?.toList()
            ?: emptyList()
    }

    fun remove(uploadedHashes: Set<String>) = synchronized(prefs) {
        if (uploadedHashes.isEmpty()) return@synchronized
        val remaining = all().filterNot { uploadedHashes.contains(it.messageHash) }
        save(prefs.edit().putString("pending", remaining.joinToString("\n") { it.toJson() }))
    }

    fun markUploaded(uploadedHashes: Set<String>) = synchronized(prefs) {
        if (uploadedHashes.isEmpty()) return@synchronized
        val remaining = all().filterNot { uploadedHashes.contains(it.messageHash) }
        val uploaded = uploadedHashes().toMutableSet()
        uploaded += uploadedHashes
        // Acknowledgement removal and deduplication history are one transaction.
        save(prefs.edit()
            .putString("pending", remaining.joinToString("\n") { it.toJson() })
            .putString("uploaded", uploaded.joinToString("\n")))
    }

    fun count(): Int = all().size

    private fun save(editor: SharedPreferences.Editor) {
        // Queue mutations run on background threads. Do not report a successful
        // save before Android has returned the result of its disk write.
        check(editor.commit()) { "Unable to persist the SMS queue" }
    }

    private fun uploadedHashes(): Set<String> =
        prefs.getString("uploaded", null)
            ?.lineSequence()
            ?.filter { it.isNotBlank() }
            ?.toSet()
            ?: emptySet()
}
