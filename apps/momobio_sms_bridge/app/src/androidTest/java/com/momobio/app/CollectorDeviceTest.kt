package com.momobio.app

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.util.Base64
import android.provider.Telephony
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Local device-only checks: no SMS permission, backend call or enrollment grant. */
@RunWith(AndroidJUnit4::class)
class CollectorDeviceTest {
    private fun qaContext(): Context = InstrumentationRegistry.getInstrumentation().targetContext.also {
        check(it.packageName == "com.momobio.app.qa") { "Collector tests require the isolated QA application" }
    }

    private fun queueContext(namespace: String): Context = object : ContextWrapper(qaContext()) {
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
            baseContext.getSharedPreferences("device_test_${namespace}_$name", mode)
    }

    @Test fun qaPackageHasNoPermissionsOrApplicationComponents() {
        val context = qaContext()
        @Suppress("DEPRECATION")
        val info = context.packageManager.getPackageInfo(context.packageName,
            PackageManager.GET_PERMISSIONS or PackageManager.GET_ACTIVITIES or
                PackageManager.GET_RECEIVERS or PackageManager.GET_SERVICES or PackageManager.GET_PROVIDERS)
        assertTrue(info.requestedPermissions.isNullOrEmpty())
        assertTrue(info.activities.isNullOrEmpty())
        assertTrue(info.receivers.isNullOrEmpty())
        assertTrue(info.services.isNullOrEmpty())
        assertTrue(info.providers.isNullOrEmpty())
        assertEquals("", BuildConfig.SUPABASE_URL)
        assertEquals("", BuildConfig.SUPABASE_ANON_KEY)
    }

    @Test fun androidJsonParserPreservesReceiptTextAndRejectsInvalidRecords() {
        val bodies = listOf("Literal \\n \\r \\t and final slash \\",
            "Unicode 🚌\nreal line\twith tab", (0..31).map { it.toChar() }.joinToString("") + "receipt")
        for (body in bodies) {
            val message = MomoSms("QA", body, 1_780_000_000_010)
            assertEquals(message, MomoSms.fromJson(message.toJson()))
        }
        val valid = MomoSms("QA", "Synthetic receipt", 1_780_000_000_010).toJson()
        assertNull(MomoSms.fromJson(valid.dropLast(1)))
        assertNull(MomoSms.fromJson(valid.replace("1780000000010", "1780000000010.5")))
        assertNull(MomoSms.fromJson(valid.replace("1780000000010", "-1")))
    }

    @Test fun platformMultipartIntentProducesOneExactReceipt() {
        qaContext()
        val bodies = listOf("Synthetic receipt 5,000 RWF ", "reference QA-ONLY\n🚌")
        // Parse synthetic GSM UCS2 PDUs through Android's actual API. This
        // intent is never broadcast and no telephony permission is granted.
        fun pdu(body: String, sequence: Int): ByteArray {
            val payload = byteArrayOf(5, 0, 3, 42, 2, sequence.toByte()) + body.toByteArray(Charsets.UTF_16BE)
            return ByteArrayOutputStream().apply {
                write(0) // SMSC omitted
                write(0x40) // SMS-DELIVER with user-data header
                write(12)
                write(0x91) // Synthetic international originating address
                write(byteArrayOf(0x52, 0x70, 0, 0, 0, 0x10))
                write(0) // PID
                write(8) // UCS2
                write(byteArrayOf(0x62, 0x90.toByte(), 0x41, 0x21, 0, 0, 0))
                write(payload.size)
                write(payload)
            }.toByteArray()
        }
        val intent = Intent(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
            .putExtra("format", "3gpp")
            .putExtra("pdus", arrayOf(pdu(bodies[0], 1), pdu(bodies[1], 2)) as java.io.Serializable)
        val expected = MomoSms("+250700000001", bodies.joinToString(""),
            Instant.parse("2026-09-14T12:00:00Z").toEpochMilli())
        assertEquals(listOf(expected), decodeIncomingSms(intent))
    }

    @Test fun keystoreIdentityPersistsAndBindsExactBody() {
        val context = qaContext()
        val identity = CollectorIdentity(context)
        val enrollment = JSONObject(identity.enrollmentRequest())
        val expected = context.getSharedPreferences("device_test_identity", Context.MODE_PRIVATE)
        val fingerprint = enrollment.getString("fingerprint")
        val collectorId = enrollment.getString("collector_id")
        // Run this test again after process death and an APK update, without clearing data.
        if (expected.contains("fingerprint")) {
            assertEquals(expected.getString("fingerprint", null), fingerprint)
            assertEquals(expected.getString("collector_id", null), collectorId)
        } else {
            assertTrue(expected.edit().putString("fingerprint", fingerprint)
                .putString("collector_id", collectorId).commit())
        }
        assertEquals(fingerprint, JSONObject(CollectorIdentity(context).enrollmentRequest()).getString("fingerprint"))
        val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "momobio-collector-signing-v1"
        assertNull("Private key must not be exportable", keys.getKey(alias, null).encoded)
        val body = "{\"messages\":[],\"qa\":\"Unicode 🚌\\n\"}".toByteArray(Charsets.UTF_8)
        val headers = identity.headers(body)
        assertEquals(collectorId, headers.getValue("x-mobio-collector-id"))
        UUID.fromString(headers.getValue("x-mobio-nonce"))
        assertTrue(kotlin.math.abs(System.currentTimeMillis() - headers.getValue("x-mobio-timestamp").toLong()) < 10_000)
        val signature = Base64.decode(headers.getValue("x-mobio-signature"), Base64.URL_SAFE or Base64.NO_WRAP)
        fun verifies(bytes: ByteArray): Boolean {
            val hash = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
            val payload = CollectorIdentity.signingPayload(collectorId,
                headers.getValue("x-mobio-timestamp"), headers.getValue("x-mobio-nonce"), hash)
            return Signature.getInstance("SHA256withRSA").run {
                initVerify(keys.getCertificate(alias).publicKey)
                update(payload.toByteArray(Charsets.UTF_8))
                verify(signature)
            }
        }
        assertTrue(verifies(body))
        assertFalse("Changed bytes must invalidate the signature", verifies(body + byteArrayOf(32)))
        assertNotEquals(headers.getValue("x-mobio-nonce"), identity.headers(body).getValue("x-mobio-nonce"))
    }

    @Test fun queueAndAcknowledgementSurviveAnotherProcessRun() {
        val context = queueContext("continuity")
        val first = MomoSms("QA", "Synthetic first receipt; never upload", 1_780_000_000_001)
        val second = MomoSms("QA", "Synthetic queued receipt 🚌\nsecond line", 1_780_000_000_002)
        val state = context.getSharedPreferences("state", Context.MODE_PRIVATE)
        val queue = SmsQueue(context)
        if (!state.getBoolean("initialized", false)) {
            queue.enqueue(listOf(first, second))
            queue.markUploaded(setOf(first.messageHash))
            assertTrue(state.edit().putBoolean("initialized", true).commit())
        }
        assertEquals(listOf(second), SmsQueue(context).all())
        queue.enqueue(listOf(first))
        assertEquals("A duplicate acknowledgement must remain durable", listOf(second), SmsQueue(context).all())
    }

    @Test fun concurrentAcknowledgementAndEnqueueDoNotLosePendingReceipts() {
        val context = queueContext(UUID.randomUUID().toString())
        val first = (1..100).map { MomoSms("QA", "Synthetic receipt $it", 1_780_000_000_000 + it.toLong()) }
        val next = (101..200).map { MomoSms("QA", "Synthetic receipt $it", 1_780_000_000_000 + it.toLong()) }
        SmsQueue(context).enqueue(first)
        val executor = Executors.newFixedThreadPool(3)
        val start = CountDownLatch(1)
        try {
            val jobs = listOf(
                executor.submit { start.await(); SmsQueue(context).markUploaded(first.take(50).map { it.messageHash }.toSet()) },
                executor.submit { start.await(); SmsQueue(context).enqueue(next) },
                executor.submit { start.await(); SmsQueue(context).enqueue(first) },
            )
            start.countDown()
            jobs.forEach { it.get(15, TimeUnit.SECONDS) }
            assertEquals((first.drop(50) + next).toSet(), SmsQueue(context).all().toSet())
        } finally {
            executor.shutdownNow()
            context.getSharedPreferences("momo_sms_queue", Context.MODE_PRIVATE).edit().clear().commit()
        }
    }
}
