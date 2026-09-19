package com.momobio.app

import org.junit.Assert.*
import org.junit.Test

class SmsReceiptDecoderTest {
    private val timestamp = 1_780_000_000_000L

    @Test fun singlePartRetainsExactTextTimestampAndHash() {
        val part = SmsReceiptPart("QA", "Synthetic receipt 5,000 RWF", timestamp)
        assertEquals(listOf(MomoSms(part.sender, part.body, timestamp)), receivedSmsReceipts(listOf(part)))
    }

    @Test fun multipartReceiptPreservesAmountAndReferenceInOneRecord() {
        val parts = listOf(SmsReceiptPart("QA", "You received 5,000 RWF ", timestamp),
            SmsReceiptPart("QA", "with reference SYNTHETIC-ONLY.", timestamp))
        assertEquals(listOf(MomoSms("QA", "You received 5,000 RWF with reference SYNTHETIC-ONLY.", timestamp)), receivedSmsReceipts(parts))
    }

    @Test fun multipartTextPreservesUnicodeWhitespaceAndOrder() {
        val bodies = listOf("  Synthetic 🚌\n", "reference \\n", "\t5,000 RWF  ")
        val result = receivedSmsReceipts(bodies.map { SmsReceiptPart("QA", it, timestamp) })
        assertEquals(listOf(MomoSms("QA", bodies.joinToString(""), timestamp)), result)
    }

    @Test fun metadataComesFromFirstSegmentOfTheCompletedBroadcast() {
        // Android's gateway display address can appear only on the first part.
        val parts = listOf(SmsReceiptPart("QA", "Synthetic ", timestamp),
            SmsReceiptPart("gateway", "receipt", timestamp + 1000))
        assertEquals(listOf(MomoSms("QA", "Synthetic receipt", timestamp)), receivedSmsReceipts(parts))
    }

    @Test fun repeatedDeliveryProducesTheSameWholeMessageHash() {
        val parts = listOf(SmsReceiptPart("QA", "Synthetic ", timestamp), SmsReceiptPart("QA", "receipt", timestamp))
        val first = receivedSmsReceipts(parts).single()
        assertEquals(MomoSms("QA", "Synthetic receipt", timestamp).messageHash, first.messageHash)
        assertEquals(first, receivedSmsReceipts(parts.toList()).single())
    }

    @Test fun emptyBroadcastProducesNoQueueEntry() {
        assertTrue(receivedSmsReceipts(emptyList()).isEmpty())
    }
}
