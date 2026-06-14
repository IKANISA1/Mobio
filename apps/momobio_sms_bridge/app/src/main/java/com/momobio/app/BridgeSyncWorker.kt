package com.momobio.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.work.Worker
import androidx.work.WorkerParameters

class BridgeSyncWorker(
    context: Context,
    workerParams: WorkerParameters,
) : Worker(context, workerParams) {
    override fun doWork(): Result {
        val queue = SmsQueue(applicationContext)
        if (hasReadSms()) {
            queue.enqueue(readAllSms(applicationContext.contentResolver))
        }

        val result = UploadClient().upload(queue.all()) { uploadedHashes ->
            queue.markUploaded(uploadedHashes)
        }

        return if (result.ok) Result.success() else Result.retry()
    }

    private fun hasReadSms(): Boolean =
        applicationContext.checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
}
