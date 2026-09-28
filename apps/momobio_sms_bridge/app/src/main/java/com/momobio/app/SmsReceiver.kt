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
                if (admitted.blocked > 0) {
                    Log.e("MoMobioBridge", "Queue capacity blocked eligible receipts; reconciliation required")
                }
                BridgeSupervisor.enqueueImmediate(context.applicationContext)
                BridgeSupervisor.start(context.applicationContext)
                // The service/worker uploads outside the broadcast's time limit.
            } catch (error: Exception) {
                Log.e("MoMobioBridge", "SMS queue/scheduling failed: ${error.javaClass.simpleName}")
            } finally {
                pending.finish()
            }
        }.start()
    }
}
