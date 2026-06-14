package com.momobio.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BridgeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                BridgeSupervisor.schedule(context.applicationContext)
                BridgeSupervisor.enqueueImmediate(context.applicationContext)
                BridgeSupervisor.start(context.applicationContext)
            }
        }
    }
}
