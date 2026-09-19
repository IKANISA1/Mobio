package com.momobio.app

import android.content.Intent
import android.provider.Telephony

internal data class SmsReceiptPart(val sender: String, val body: String, val receivedAtMillis: Long)

internal fun decodeIncomingSms(intent: Intent): List<MomoSms> = receivedSmsReceipts(
    Telephony.Sms.Intents.getMessagesFromIntent(intent).map {
        SmsReceiptPart(
            sender = it.displayOriginatingAddress ?: it.originatingAddress ?: "",
            body = it.messageBody ?: "",
            receivedAtMillis = it.timestampMillis,
        )
    },
)

internal fun receivedSmsReceipts(parts: List<SmsReceiptPart>): List<MomoSms> {
    val first = parts.firstOrNull() ?: return emptyList()
    // Android delivers all completed SMS segments in sequence in one broadcast.
    // The first part owns the sender/timestamp; join text without adding spaces.
    return listOf(MomoSms(first.sender, parts.joinToString("") { it.body }, first.receivedAtMillis))
}
