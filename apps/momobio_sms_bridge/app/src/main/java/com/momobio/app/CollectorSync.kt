package com.momobio.app

import android.content.Context

/** All UI, service and WorkManager upload attempts use the same OS-backed lease. */
object CollectorSync {
    fun run(context: Context): UploadResult = run(context, UploadCancellation())

    fun run(context: Context, cancellation: UploadCancellation): UploadResult {
        if (cancellation.isCancelled()) return UploadResult(false,
            message = UploadStop.CANCELLED.safeMessage, outcome = UploadStop.CANCELLED.outcome)
        val app = context.applicationContext
        if (!CollectorRuntime.policy.configured) return UploadResult(false,
            message="Approved sender/receipt policy is missing", outcome="policy_missing")
        if (!CollectorRuntime.ready(app)) return UploadResult(false,
            message="Collection notice and SMS permission are required", outcome="consent_or_permission_required")
        return CollectorLease.withLease(java.io.File(app.noBackupFilesDir,"collector-sync.lock")) {
            val queue = DurableSmsQueue(app)
            val now = System.currentTimeMillis()
            if (!queue.permittedAttempt(now)) {
                UploadResult(false,message="Retry is scheduled; receipts remain stored",outcome="backoff")
            } else {
                val batch = queue.batch()
                val allowed = batch.filter { CollectorRuntime.policy.accepts(it.sender,it.body,it.receivedAtMillis) }
                queue.quarantine((batch - allowed.toSet()).map { it.messageHash }.toSet(),"policy_review")
                // Recheck a notice/permission change after potentially slow disk work.
                if (!CollectorRuntime.ready(app)) return@withLease UploadResult(false,
                    message="Collection is paused; stored receipts are unchanged", outcome="collection_paused")
                val result = UploadClient(CollectorIdentity(app)).upload(
                    allowed, cancellation, { CollectorRuntime.ready(app) },
                ) { queue.markUploaded(it) }
                queue.recordOutcome(result)
                result
            }
        } ?: UploadResult(false,message="Another sync owns the queue",outcome="busy")
    }
}
