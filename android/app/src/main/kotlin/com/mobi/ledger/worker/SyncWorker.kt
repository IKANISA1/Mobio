package com.mobi.ledger.worker

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.mobi.ledger.data.repository.SmsRepository
import com.mobi.ledger.util.PrefsManager
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.withTimeout

class SyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "SyncWorker"
        private const val UNIQUE_WORK_NAME = "mobi_ledger_sms_sync"

        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<SyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    1,
                    TimeUnit.MINUTES
                )
                .addTag(TAG)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    UNIQUE_WORK_NAME,
                    ExistingWorkPolicy.KEEP,
                    request
                )
        }
    }

    override suspend fun doWork(): Result {
        val agentId = PrefsManager.getAgentId(applicationContext)
        if (agentId == null) {
            Log.w(TAG, "No agent ID — skipping sync")
            return Result.success()
        }

        val repository = SmsRepository(applicationContext)

        return try {
            var totalSynced = 0
            var batchSynced: Int

            withTimeout(120_000L) {
                do {
                    batchSynced = repository.uploadPendingBatch(agentId)
                    totalSynced += batchSynced
                } while (batchSynced > 0)
            }

            Log.i(TAG, "Sync complete: $totalSynced SMS uploaded")

            if (totalSynced > 0) {
                PrefsManager.getEncryptedPrefs(applicationContext)
                    .edit()
                    .putLong("last_sync_at", System.currentTimeMillis())
                    .apply()
            }

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed", e)
            if (runAttemptCount < 5) {
                Result.retry()
            } else {
                Log.e(TAG, "Max retries exceeded — marking as failure")
                Result.failure()
            }
        }
    }
}
