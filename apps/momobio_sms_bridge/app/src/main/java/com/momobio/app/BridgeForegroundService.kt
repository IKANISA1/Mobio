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

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(notificationId, notification("Mo Mobio is active", "Watching SMS and syncing payments."))
        BridgeSupervisor.schedule(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        runSync()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        executor.shutdownNow()
        BridgeSupervisor.enqueueImmediate(applicationContext)
        super.onDestroy()
    }

    private fun runSync() {
        if (syncInFlight) return
        syncInFlight = true
        executor.execute {
            val result = try {
                syncOnce()
            } catch (error: Throwable) {
                Log.e(logTag, "Foreground sync failed", error)
                UploadResult(false, message = "${error.javaClass.simpleName}: ${error.message ?: "Sync failed"}")
            } finally {
                syncInFlight = false
            }

            updateNotification(result)
            handler.postDelayed({ runSync() }, if (result.ok) idleDelayMillis else retryDelayMillis)
        }
    }

    private fun syncOnce(): UploadResult {
        val queue = SmsQueue(applicationContext)
        val messages = queue.all()
        return UploadClient().upload(messages) { uploadedHashes ->
            queue.markUploaded(uploadedHashes)
        }
    }

    private fun updateNotification(result: UploadResult) {
        val manager = getSystemService(NotificationManager::class.java)
        val queueCount = SmsQueue(applicationContext).count()
        val title = if (result.ok && queueCount == 0) "Mo Mobio is active" else "Mo Mobio sync pending"
        val body = if (result.ok) {
            "${result.message}; queued $queueCount"
        } else {
            "${result.message}; queued $queueCount"
        }
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
        private const val idleDelayMillis = 5 * 60 * 1000L
        private const val retryDelayMillis = 30 * 1000L
    }
}
