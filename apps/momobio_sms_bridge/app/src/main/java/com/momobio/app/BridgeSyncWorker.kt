package com.momobio.app

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class BridgeSyncWorker(
    context: Context,
    workerParams: WorkerParameters,
) : Worker(context, workerParams) {
    override fun doWork(): Result {
        val queue = SmsQueue(applicationContext)
        val result = UploadClient().upload(queue.all()) { uploadedHashes ->
            queue.markUploaded(uploadedHashes)
        }

        return if (result.ok) Result.success() else Result.retry()
    }
}
