package rw.mobi.app.ledger.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import rw.mobi.app.ledger.util.PrefsManager
import rw.mobi.app.ledger.worker.SyncWorker

/**
 * Boot completed receiver.
 * Re-registers the WorkManager sync job after device reboot
 * to ensure any pending SMS in the queue get synced.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        // Only enqueue if the user has completed onboarding
        if (PrefsManager.isOnboardingComplete(context)) {
            SyncWorker.enqueue(context)
        }
    }
}
