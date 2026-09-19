package com.momobio.app

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class MomoSmsTest {
    private fun receipt(body: String) = MomoSms("QA", body, 1_780_000_000_001)

    private fun assertRoundTrip(body: String) {
        val original = receipt(body)
        val json = original.toJson()
        assertEquals("Serialized JSON must preserve the text", body, JSONObject(json).getString("body"))
        assertEquals("Queue decoding must preserve every field and the hash", original, MomoSms.fromJson(json))
    }

    @Test fun unicodeAndRealLineBreaksRoundTrip() {
        assertRoundTrip("Synthetic receipt 🚌\nKigali\r\nLine\tthree")
    }

    @Test fun literalEscapeSequencesRemainLiteral() {
        assertRoundTrip("Literal \\n and \\r and \\t must remain text; C:\\new\\receipt")
    }

    @Test fun everyJsonControlCharacterRoundTrips() {
        assertRoundTrip("Controls:" + (0..31).map { it.toChar() }.joinToString(""))
    }

    @Test fun quotesAndTrailingBackslashesRoundTrip() {
        assertRoundTrip("A \\\"quoted\\\" marker and trailing \\")
    }

    @Test fun validUnicodeEscapesAreDecoded() {
        val original = receipt("Receipt 1 🚌")
        val encoded = original.toJson().replace("Receipt 1 🚌", "Receipt \\u0031 \\uD83D\\uDE8C")
        assertEquals(original, MomoSms.fromJson(encoded))
    }

    @Test fun incompleteJsonDoesNotBecomeAValidQueueRecord() {
        val valid = receipt("Synthetic receipt").toJson()
        assertNull(MomoSms.fromJson(valid.dropLast(1)))
        assertNull(MomoSms.fromJson("not-json $valid"))
    }

    @Test fun missingBlankAndWrongTypeFieldsAreRejected() {
        val valid = receipt("Synthetic receipt").toJson()
        for (field in listOf("sender", "body", "received_at_millis", "message_hash")) {
            assertNull("Missing $field", MomoSms.fromJson(JSONObject(valid).apply { remove(field) }.toString()))
        }
        for (field in listOf("sender", "body", "message_hash")) {
            assertNull("Blank $field", MomoSms.fromJson(JSONObject(valid).put(field, " ").toString()))
            assertNull("Non-string $field", MomoSms.fromJson(JSONObject(valid).put(field, 123).toString()))
        }
    }

    @Test fun fractionalNegativeAndOverflowTimestampsAreRejected() {
        val valid = receipt("Synthetic receipt").toJson()
        for (timestamp in listOf("1.5", "-1", "9223372036854775808")) {
            val changed = valid.replace("1780000000001", timestamp)
            assertNull(timestamp, MomoSms.fromJson(changed))
        }
    }
}
