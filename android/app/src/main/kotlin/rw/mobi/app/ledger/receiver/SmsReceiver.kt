package rw.mobi.app.ledger.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import rw.mobi.app.ledger.data.local.PayLedgerDatabase
import rw.mobi.app.ledger.data.local.SmsQueueEntity
import rw.mobi.app.ledger.data.local.SmsStatus
import rw.mobi.app.ledger.util.HashUtils
import rw.mobi.app.ledger.util.PrefsManager
import rw.mobi.app.ledger.worker.SyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * BroadcastReceiver for incoming SMS.
 * - Fires for every SMS, checks sender against cached MoMo provider sender IDs
 * - Non-MoMo SMS discarded in < 1ms (no network call)
 * - Matching SMS written to Room DB offline queue
 * - Enqueues WorkManager sync job
 *
 * H3: Uses goAsync() to extend receiver lifecycle for the coroutine.
 * Without goAsync(), Android may kill the process before the Room insert completes.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val fullBody = messages.joinToString("") { it.messageBody ?: "" }
        val sender = messages.firstOrNull()?.originatingAddress ?: return

        if (fullBody.isBlank()) return

        // Get agent ID — if not onboarded yet, skip
        val agentId = PrefsManager.getAgentId(context) ?: return

        // H3: Extend receiver lifecycle with goAsync()
        val pendingResult = goAsync()

        val db = PayLedgerDatabase.getInstance(context)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val cachedSenderIds = db.providerDao().getActiveSenderIds()
                if (cachedSenderIds.isEmpty()) return@launch

                // Fast filter: check if sender address contains any known MoMo sender ID
                val isMoMo = cachedSenderIds.any { senderId ->
                    sender.contains(senderId, ignoreCase = true)
                }
                if (!isMoMo) return@launch

                // Generate dedup hash and queue
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

                // Trigger sync
                SyncWorker.enqueue(context)
            } catch (e: Exception) {
                // Fail silently — SMS is lost but should not crash the receiver
                android.util.Log.e("SmsReceiver", "Failed to queue SMS", e)
            } finally {
                // H3: Always release the async lock when done
                pendingResult.finish()
            }
        }
    }
}
