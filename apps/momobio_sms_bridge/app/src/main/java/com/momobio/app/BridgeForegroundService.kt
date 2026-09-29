package com.momobio.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import java.util.concurrent.Executors

class BridgeForegroundService : Service() {
    private val logTag = "MoMobioBridge"
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    @Volatile private var syncInFlight = false
    @Volatile private var destroyed = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(notificationId, notification("Mo Mobio collector", "Only approved receipt notifications are collected; checking connection."))
        BridgeSupervisor.schedule(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!CollectorRuntime.ready(applicationContext)) {
            stopSelf()
            return START_NOT_STICKY
        }
        runSync()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        destroyed = true
        handler.removeCallbacksAndMessages(null)
        executor.shutdownNow()
        BridgeSupervisor.enqueueImmediate(applicationContext)
        super.onDestroy()
    }

    private fun runSync() {
        if (syncInFlight || destroyed || !CollectorRuntime.ready(applicationContext)) return
        syncInFlight = true
        executor.execute {
            val result = try {
                syncOnce()
            } catch (error: Exception) {
                Log.e(logTag, "Foreground sync failed: ${error.javaClass.simpleName}")
                UploadResult(false, message = "Sync unavailable; queued messages will be retried")
            } finally {
                syncInFlight = false
            }

            if (!destroyed) {
                try {
                    updateNotification(result)
                } catch (_: Exception) {
                    // A queue failure must not silently terminate the sync executor.
                    getSystemService(NotificationManager::class.java).notify(notificationId,
                        notification("Mo Mobio recovery required", "Do not clear app data. Contact the fleet administrator."))
                }
                handler.postDelayed({ runSync() }, retryDelayMillis)
            }
        }
    }

    private fun syncOnce(): UploadResult {
        return CollectorSync.run(applicationContext)
    }

    private fun updateNotification(result: UploadResult) {
        val manager = getSystemService(NotificationManager::class.java)
        val health = DurableSmsQueue(applicationContext).health()
        val title = when {
            health.unreconciledRefusals > 0 || health.capacityBlocked > 0L -> "Mo Mobio receipt recovery required"
            health.capacityWarning -> "Mo Mobio queue capacity warning"
            result.ok && health.pending == 0 && health.quarantined == 0 -> "Mo Mobio server acknowledged"
            else -> "Mo Mobio needs attention"
        }
        val body = "${result.message}; queued ${health.pending}; overflow ${health.overflowPending}; " +
            "review ${health.quarantined}; refusals ${health.unreconciledRefusals}"
        manager.notify(notificationId, notification(title, body))
    }

    private fun notification(title: String, body: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return Notification.Builder(this, notificationChannelId)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle(title)
            .setContentText(body)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            notificationChannelId,
            "Mo Mobio active bridge",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the Mo Mobio SMS payment bridge active."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val notificationId = 31045
        private const val notificationChannelId = "mo_mobio_sms_bridge_active"
        private const val retryDelayMillis = 30 * 1000L
    }
}
