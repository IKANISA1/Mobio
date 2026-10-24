package com.momobio.app

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class BridgeSyncWorker(
    context: Context,
    workerParams: WorkerParameters,
) : Worker(context, workerParams) {
    private val uploadCancellation = UploadCancellation()

    override fun onStopped() {
        uploadCancellation.cancel()
        super.onStopped()
    }

    override fun doWork(): Result = try {
        if (isStopped) uploadCancellation.cancel()
        val result = CollectorSync.run(applicationContext, uploadCancellation)

        if (result.ok && DurableSmsQueue(applicationContext).count() == 0) Result.success()
        else Result.retry() // Continue draining bounded batches without replacing active work.
    } catch (error: Exception) {
        Log.e("MoMobioBridge", "Background sync failed: ${error.javaClass.simpleName}")
        Result.retry()
    }
}
