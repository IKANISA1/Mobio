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
                val messages = decodeIncomingSms(intent)
                if (messages.isEmpty()) return@Thread
                val queue = SmsQueue(context.applicationContext)
                queue.enqueue(messages)
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
