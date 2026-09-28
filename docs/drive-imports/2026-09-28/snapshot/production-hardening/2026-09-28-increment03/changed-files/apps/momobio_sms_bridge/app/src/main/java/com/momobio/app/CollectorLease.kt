package com.momobio.app

import java.io.File
import java.io.RandomAccessFile
import java.nio.channels.OverlappingFileLockException

/** Cross-thread and cross-process exclusion; process exit releases the OS lease. */
object CollectorLease {
    fun <T> withLease(path: File, action: () -> T): T? = RandomAccessFile(path, "rw").use { file ->
        val lease = try { file.channel.tryLock() } catch (_: OverlappingFileLockException) { null }
        if (lease == null) return null
        lease.use { action() }
    }
}
