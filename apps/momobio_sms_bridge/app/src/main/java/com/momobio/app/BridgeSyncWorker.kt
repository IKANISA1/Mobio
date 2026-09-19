package com.momobio.app

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class BridgeSyncWorker(
    context: Context,
    workerParams: WorkerParameters,
) : Worker(context, workerParams) {
    override fun doWork(): Result = try {
        val queue = SmsQueue(applicationContext)
        val result = UploadClient(CollectorIdentity(applicationContext)).upload(queue.all()) { uploadedHashes ->
            queue.markUploaded(uploadedHashes)
        }

        if (result.ok) Result.success() else Result.retry()
    } catch (error: Exception) {
        Log.e("MoMobioBridge", "Background sync failed: ${error.javaClass.simpleName}")
        Result.retry()
    }
}
