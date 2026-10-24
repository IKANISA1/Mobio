package com.momobio.app

import java.io.Closeable
import java.io.IOException
import java.net.HttpURLConnection
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** One caller owns this single-use handle. It cannot cancel another uploader. */
class UploadCancellation {
    private val lock = Any()
    @Volatile private var cancelled = false
    private var consumed = false
    private var listener: (() -> Unit)? = null

    fun cancel() {
        val notify = synchronized(lock) {
            cancelled = true
            listener
        }
        // The listener launches owned aborts, never blocking an Android stop callback.
        notify?.invoke()
    }

    internal fun isCancelled(): Boolean = cancelled

    internal fun <T> fence(action: () -> T): T = synchronized(lock) {
        if (cancelled) throw UploadStopped(UploadStop.CANCELLED)
        action()
    }

    internal fun bind(onCancel: () -> Unit): Closeable {
        val notify = synchronized(lock) {
            check(!consumed) { "Upload cancellation handle is single-use" }
            consumed = true
            listener = onCancel
            cancelled
        }
        if (notify) onCancel()
        return Closeable { synchronized(lock) { listener = null } }
    }
}

/** Engineering upload budgets; no queue retention or evidentiary period. */
internal data class UploadDeadlinePolicy(
    val overallMillis: Long = 120_000,
    val requestMillis: Long = 75_000,
    val maxChunks: Int = 4,
    val watchdogPollMillis: Long = 50,
) {
    init {
        require(overallMillis > 0 && requestMillis > 0 && maxChunks > 0 && watchdogPollMillis > 0)
    }
}

internal enum class UploadStop(val outcome: String, val safeMessage: String) {
    CANCELLED("upload_cancelled", "Sync stopped; unresolved messages remain queued"),
    DEADLINE("upload_deadline", "Upload time limit reached; unresolved messages remain queued"),
    PAUSED("collection_paused", "Collection is paused; unresolved messages remain queued"),
    CHUNK_LIMIT("upload_chunk_limit", "Upload batch limit reached; remaining messages stay queued"),
}

internal class UploadStopped(val reason: UploadStop) : IOException(reason.safeMessage)

internal fun pollingUploadWatchdog(pollMillis: Long, tick: () -> Unit): Closeable {
    val executor = Executors.newSingleThreadScheduledExecutor { task ->
        Thread(task, "collector-upload-deadline").apply { isDaemon = true }
    }
    val watch = executor.scheduleWithFixedDelay(
        { tick() }, pollMillis, pollMillis, TimeUnit.MILLISECONDS,
    )
    return Closeable {
        watch.cancel(false)
        executor.shutdown()
    }
}

/**
 * Sender stays synchronous in CollectorLease. No future timeout releases its lease.
 * Watchdog scheduling uses relative waits; every tick reads the injected monotonic
 * clock. Android's public constructor injects elapsedRealtime including device sleep.
 */
internal class UploadDeadline(
    private val cancellation: UploadCancellation,
    private val policy: UploadDeadlinePolicy,
    private val nowMillis: () -> Long,
    watch: (Long, () -> Unit) -> Closeable,
) : Closeable {
    private val lock = Any()
    private val overallEnd = endAt(nowMillis(), policy.overallMillis)
    private var reason: UploadStop? = null
    private var active: OwnedUploadRequest? = null
    private val registration = cancellation.bind { stop(UploadStop.CANCELLED) }
    private val watchdog = watch(policy.watchdogPollMillis) { expire() }

    fun startRequest(index: Int, mayStart: () -> Boolean): OwnedUploadRequest {
        checkpoint()
        if (index >= policy.maxChunks) stop(UploadStop.CHUNK_LIMIT)
        // A disclosure/permission pause only gates a new request, never translates
        // an existing durable receipt into a failed receipt.
        if (!mayStart()) stop(UploadStop.PAUSED)
        checkpoint()
        val request = synchronized(lock) {
            check(active == null) { "Another request is still owned" }
            if (cancellation.isCancelled()) throw UploadStopped(UploadStop.CANCELLED)
            reason?.let { throw UploadStopped(it) }
            val now = nowMillis()
            if (now >= overallEnd) throw UploadStopped(UploadStop.DEADLINE)
            OwnedUploadRequest(minOf(overallEnd, endAt(now, policy.requestMillis))).also { active = it }
        }
        return request
    }

    fun checkpoint(request: OwnedUploadRequest? = null) {
        if (cancellation.isCancelled() || Thread.currentThread().isInterrupted) stop(UploadStop.CANCELLED)
        expire(request)
        synchronized(lock) { reason }?.let { throw UploadStopped(it) }
    }

    fun beforeSend(request: OwnedUploadRequest, mayStart: () -> Boolean) {
        checkpoint(request)
        if (!mayStart()) {
            stop(UploadStop.PAUSED)
            throw UploadStopped(UploadStop.PAUSED)
        }
    }

    fun phaseTimeout(request: OwnedUploadRequest, phaseLimitMillis: Int): Int {
        checkpoint(request)
        val remaining = minOf(overallEnd, request.endMillis) - nowMillis()
        if (remaining <= 0) {
            stop(UploadStop.DEADLINE)
            throw UploadStopped(UploadStop.DEADLINE)
        }
        // Never turn a zero remaining budget into URLConnection's infinite timeout.
        return minOf(remaining, phaseLimitMillis.toLong()).coerceAtLeast(1).toInt()
    }

    /**
     * Linearization point for an already parsed, validated response. A cancellation
     * before this gate cannot start a durable queue acknowledgement. An admitted
     * SQLite acknowledgement may finish afterward; its known receipt is retained.
     * No Android stop callback waits for SQLite while acquiring this short fence.
     */
    fun claimAcknowledgement(request: OwnedUploadRequest) {
        checkpoint(request)
        val expired = synchronized(lock) {
            reason?.let { throw UploadStopped(it) }
            cancellation.fence {
                check(active === request)
                nowMillis() >= minOf(overallEnd, request.endMillis)
            }
        }
        if (expired) {
            stop(UploadStop.DEADLINE)
            throw UploadStopped(UploadStop.DEADLINE)
        }
    }

    fun finishRequest(request: OwnedUploadRequest) {
        try {
            request.finish()
        } finally {
            expire(request)
            synchronized(lock) { if (active === request) active = null }
        }
    }

    private fun expire(request: OwnedUploadRequest? = null) {
        val expired = synchronized(lock) {
            nowMillis() >= overallEnd ||
                (request ?: active)?.let { nowMillis() >= it.endMillis } == true
        }
        if (expired) stop(UploadStop.DEADLINE)
    }

    private fun stop(value: UploadStop) {
        val request = synchronized(lock) {
            if (reason == null) reason = value
            active
        }
        request?.abort()
    }

    override fun close() {
        watchdog.close()
        registration.close()
        check(synchronized(lock) { active == null }) { "Sender still owns a request" }
    }

    private fun endAt(now: Long, duration: Long): Long =
        if (now > Long.MAX_VALUE - duration) Long.MAX_VALUE else now + duration
}

/**
 * Only this request's connection/streams are registered. Closing/disconnect may
 * block in a platform implementation: independently launched aborts do not block
 * each other or onStopped, and finish waits for all actual cleanup terminals.
 * Android HttpURLConnection cancellation still needs the proposed device proof.
 */
internal class OwnedUploadRequest(val endMillis: Long) {
    private class Resource(val close: () -> Unit) {
        private val claimed = AtomicBoolean(false)
        fun closeOnce() {
            if (claimed.compareAndSet(false, true)) {
                try { close() } catch (_: Exception) { /* No private transport text. */ }
            }
        }
    }
    private val lock = Any()
    private val resources = mutableListOf<Resource>()
    private val abortThreads = mutableListOf<Thread>()
    private var aborted = false
    private var finished = false

    fun ownConnection(connection: HttpURLConnection) = own { connection.disconnect() }

    fun ownStream(stream: Closeable): () -> Unit = own { stream.close() }

    private fun own(close: () -> Unit): () -> Unit {
        val resource = Resource(close)
        synchronized(lock) {
            check(!finished) { "Request is already terminal" }
            resources += resource
            if (aborted) launch(resource)
        }
        return resource::closeOnce
    }

    fun abort() {
        synchronized(lock) {
            if (aborted || finished) return
            aborted = true
            // Separate tasks prevent a blocking stream close hiding disconnect.
            resources.forEach(::launch)
        }
    }

    private fun launch(resource: Resource) {
        Thread({ resource.closeOnce() }, "collector-upload-abort").apply {
            isDaemon = true
            abortThreads += this
            start() // Under lock, so finish never sees an unstarted owned thread.
        }
    }

    fun finish() {
        val owned = synchronized(lock) { resources.toList() }
        // Streams precede normal disconnect, preserving successful upload cleanup.
        owned.asReversed().forEach { it.closeOnce() }
        val tasks = synchronized(lock) {
            finished = true
            abortThreads.toList()
        }
        var interrupted = false
        for (thread in tasks) {
            while (thread.isAlive) {
                try { thread.join() } catch (_: InterruptedException) { interrupted = true }
            }
        }
        if (interrupted) Thread.currentThread().interrupt()
    }
}
