package com.mobi.ledger.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.mobi.ledger.data.local.LedgerDatabase
import com.mobi.ledger.data.local.SmsQueueEntity
import com.mobi.ledger.data.local.SmsStatus
import com.mobi.ledger.util.HashUtils
import com.mobi.ledger.util.PrefsManager
import com.mobi.ledger.worker.SyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val fullBody = messages.joinToString("") { it.messageBody ?: "" }
        val sender = messages.firstOrNull()?.originatingAddress ?: return

        if (fullBody.isBlank()) return

        val agentId = PrefsManager.getAgentId(context) ?: return

        val pendingResult = goAsync()
        val db = LedgerDatabase.getInstance(context)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val cachedSenderIds = db.providerDao().getActiveSenderIds()
                if (cachedSenderIds.isEmpty()) return@launch

                val isMoMo = cachedSenderIds.any { senderId ->
                    sender.contains(senderId, ignoreCase = true)
                }
                if (!isMoMo) return@launch

                val smsHash = HashUtils.sha256(agentId, fullBody)

                db.smsQueueDao().insertIfNotExists(
                    SmsQueueEntity(
                        smsHash = smsHash,
                        agentId = agentId,
                        rawSms = fullBody,
                        sender = sender,
                        receivedAt = System.currentTimeMillis(),
                        status = SmsStatus.PENDING.name
                    )
                )

                SyncWorker.enqueue(context)
            } catch (e: Exception) {
                android.util.Log.e("SmsReceiver", "Failed to queue SMS", e)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
