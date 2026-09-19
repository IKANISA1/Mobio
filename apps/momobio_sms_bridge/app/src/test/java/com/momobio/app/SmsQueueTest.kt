package com.momobio.app

import android.content.SharedPreferences
import java.lang.reflect.Proxy
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

/** Actual queue algorithms with an in-memory preference double, not Android disk proof. */
class SmsQueueTest {
    private fun sms(index: Int) = MomoSms("QA", "Synthetic receipt $index", 1_780_000_000_000 + index)

    private fun race(prefs: PreferencesDouble, first: () -> Unit, second: () -> Unit) {
        val reads = CountDownLatch(2)
        val readCount = AtomicInteger()
        // Each read captures its value before this hook. Separate queue locks
        // allow both stale snapshots through; a shared lock serializes them.
        prefs.afterPendingRead = {
            if (readCount.incrementAndGet() <= 2) {
                reads.countDown()
                reads.await(1, TimeUnit.SECONDS)
            }
        }
        val pool = Executors.newFixedThreadPool(2)
        val ready = CountDownLatch(2)
        val start = CountDownLatch(1)
        try {
            val jobs = listOf(first, second).map { action ->
                pool.submit { ready.countDown(); start.await(); action() }
            }
            assertTrue(ready.await(5, TimeUnit.SECONDS))
            start.countDown()
            jobs.forEach { it.get(10, TimeUnit.SECONDS) }
        } finally {
            prefs.afterPendingRead = null
            pool.shutdownNow()
        }
    }

    @Test fun separateQueueInstancesDoNotLoseConcurrentIncomingMessages() {
        val prefs = PreferencesDouble()
        race(prefs,
            { SmsQueue(prefs.api).enqueue(listOf(sms(1))) },
            { SmsQueue(prefs.api).enqueue(listOf(sms(2))) },
        )
        assertEquals(setOf(sms(1), sms(2)), SmsQueue(prefs.api).all().toSet())
    }

    @Test fun acknowledgementAndIncomingMessageRemainConsistent() {
        val prefs = PreferencesDouble()
        SmsQueue(prefs.api).enqueue(listOf(sms(1)))
        race(prefs,
            { SmsQueue(prefs.api).markUploaded(setOf(sms(1).messageHash)) },
            { SmsQueue(prefs.api).enqueue(listOf(sms(1), sms(2))) },
        )
        assertEquals(listOf(sms(2)), SmsQueue(prefs.api).all())
        SmsQueue(prefs.api).enqueue(listOf(sms(1)))
        assertEquals(listOf(sms(2)), SmsQueue(prefs.api).all())
    }

    @Test fun interruptionAfterOneDurableWriteCannotResurrectAcknowledgedMessage() {
        val prefs = PreferencesDouble()
        SmsQueue(prefs.api).enqueue(listOf(sms(1), sms(2)))
        prefs.afterDurableWrite = { throw IllegalStateException("Simulated process interruption after durable write") }
        try {
            SmsQueue(prefs.api).markUploaded(setOf(sms(1).messageHash))
            fail("Expected the simulated interruption")
        } catch (error: IllegalStateException) {
            assertEquals("Simulated process interruption after durable write", error.message)
            // Reopen only the committed snapshot, as a later process would.
        }
        val restored = SmsQueue(PreferencesDouble(prefs.durable).api)
        restored.enqueue(listOf(sms(1)))
        assertEquals(listOf(sms(2)), restored.all())
    }

    @Test fun persistenceFailureIsReportedToTheCaller() {
        val prefs = PreferencesDouble()
        prefs.commitSucceeds = false
        assertThrows(IllegalStateException::class.java) { SmsQueue(prefs.api).enqueue(listOf(sms(1))) }
        assertThrows(IllegalStateException::class.java) { SmsQueue(prefs.api).markUploaded(setOf(sms(1).messageHash)) }
    }

    @Test fun duplicateDeliveryDoesNotRequeueAnAcknowledgedMessage() {
        val prefs = PreferencesDouble()
        val queue = SmsQueue(prefs.api)
        queue.enqueue(listOf(sms(1), sms(1), sms(2)))
        assertEquals(2, queue.count())
        queue.markUploaded(setOf(sms(1).messageHash))
        SmsQueue(prefs.api).enqueue(listOf(sms(1)))
        assertEquals(listOf(sms(2)), queue.all())
    }
}

/** Implements only the Android interface methods the queue actually uses. */
private class PreferencesDouble(initial: Map<String, String> = emptyMap()) {
    private val lock = Any()
    private val values = initial.toMutableMap()
    @Volatile var durable: Map<String, String> = initial.toMap()
    @Volatile var commitSucceeds = true
    @Volatile var afterPendingRead: (() -> Unit)? = null
    @Volatile var afterDurableWrite: (() -> Unit)? = null

    val api = Proxy.newProxyInstance(
        SharedPreferences::class.java.classLoader, arrayOf(SharedPreferences::class.java),
    ) { proxy, method, args ->
        when (method.name) {
            "getString" -> {
                val value = synchronized(lock) { values[args!![0] as String] ?: args[1] }
                if (args!![0] == "pending") afterPendingRead?.invoke()
                value
            }
            "edit" -> editor()
            "equals" -> proxy === args!![0]
            "hashCode" -> System.identityHashCode(proxy)
            "toString" -> "PreferencesDouble"
            else -> error("Unexpected preference method: ${method.name}")
        }
    } as SharedPreferences

    private fun editor(): SharedPreferences.Editor {
        val changes = mutableMapOf<String, String?>()
        return Proxy.newProxyInstance(
            SharedPreferences.Editor::class.java.classLoader, arrayOf(SharedPreferences.Editor::class.java),
        ) { proxy, method, args ->
            when (method.name) {
                "putString" -> { changes[args!![0] as String] = args[1] as String?; proxy }
                "commit", "apply" -> {
                    synchronized(lock) {
                        changes.forEach { (key, value) -> if (value == null) values.remove(key) else values[key] = value }
                        if (commitSucceeds) durable = values.toMap()
                    }
                    if (commitSucceeds) afterDurableWrite?.invoke()
                    if (method.name == "commit") commitSucceeds else null
                }
                "equals" -> proxy === args!![0]
                "hashCode" -> System.identityHashCode(proxy)
                "toString" -> "EditorDouble"
                else -> error("Unexpected editor method: ${method.name}")
            }
        } as SharedPreferences.Editor
    }
}
