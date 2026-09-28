package com.momobio.app

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object BridgeSupervisor {
    private const val periodicWorkName = "mo-mobio-sms-bridge-periodic-sync"
    private const val immediateWorkName = "mo-mobio-sms-bridge-immediate-sync"

    fun start(context: Context) {
        val appContext = context.applicationContext
        if (!CollectorRuntime.ready(appContext)) return
        schedule(appContext)
        val intent = Intent(appContext, BridgeForegroundService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        } catch (_: IllegalStateException) {
            enqueueImmediate(appContext)
        } catch (_: SecurityException) {
            enqueueImmediate(appContext)
        }
    }

    fun stop(context: Context) {
        val app = context.applicationContext
        WorkManager.getInstance(app).cancelUniqueWork(periodicWorkName)
        WorkManager.getInstance(app).cancelUniqueWork(immediateWorkName)
        app.stopService(Intent(app, BridgeForegroundService::class.java))
    }

    fun schedule(context: Context) {
        if (!CollectorRuntime.ready(context.applicationContext)) return
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<BridgeSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            periodicWorkName,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    fun enqueueImmediate(context: Context) {
        if (!CollectorRuntime.ready(context.applicationContext)) return
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<BridgeSyncWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            immediateWorkName,
            ExistingWorkPolicy.KEEP,
            request,
        )
    }
}
