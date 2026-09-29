package com.momobio.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val pending = goAsync()
        Thread {
            try {
                if (!CollectorRuntime.ready(context.applicationContext)) return@Thread
                val messages = decodeIncomingSms(intent).filter {
                    CollectorRuntime.policy.accepts(it.sender, it.body, it.receivedAtMillis)
                }
                if (messages.isEmpty()) return@Thread
                val queue = DurableSmsQueue(context.applicationContext)
                val admitted = queue.enqueue(messages)
                if (admitted.deferred > 0) {
                    Log.w("MoMobioBridge", "Eligible receipts saved in overflow; queue drain required")
                }
                if (admitted.blocked > 0) {
                    Log.e("MoMobioBridge", "Raw receipt not retained; refusal hashes saved for reconciliation")
                }
                BridgeSupervisor.enqueueImmediate(context.applicationContext)
                BridgeSupervisor.start(context.applicationContext)
                // The service/worker uploads outside the broadcast's time limit.
            } catch (error: Exception) {
                Log.e("MoMobioBridge", "SMS queue/scheduling failed: ${error.javaClass.simpleName}")
                // Best effort visible recovery alarm even when SQLite cannot commit.
                try { BridgeSupervisor.start(context.applicationContext) } catch (_: Exception) { }
            } finally {
                pending.finish()
            }
        }.start()
    }
}
