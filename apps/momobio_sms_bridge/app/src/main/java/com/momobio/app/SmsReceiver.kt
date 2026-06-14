package com.momobio.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val pending = goAsync()
        Thread {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    .map {
                        MomoSms(
                            sender = it.displayOriginatingAddress ?: it.originatingAddress ?: "",
                            body = it.messageBody ?: "",
                            receivedAtMillis = it.timestampMillis,
                        )
                    }
                val queue = SmsQueue(context.applicationContext)
                queue.enqueue(messages)
                BridgeSupervisor.enqueueImmediate(context.applicationContext)
                BridgeSupervisor.start(context.applicationContext)
                val result = UploadClient().upload(queue.all())
                queue.markUploaded(result.uploadedHashes)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
