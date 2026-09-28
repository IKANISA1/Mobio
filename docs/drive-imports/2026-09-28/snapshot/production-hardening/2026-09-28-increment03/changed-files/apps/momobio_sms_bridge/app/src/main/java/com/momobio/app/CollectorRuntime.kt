package com.momobio.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager

/** Capture is opt-in, versioned and restricted to configured receipt senders. */
object CollectorRuntime {
    const val NOTICE_VERSION = "collector-data-use-2026-09-28-v1"
    private const val PREFS = "momobio_collection_consent"
    val policy: CollectorPolicy get() = CollectorPolicy.fromCsv(
        BuildConfig.COLLECTOR_POLICY_VERSION, BuildConfig.COLLECTOR_ALLOWED_SENDERS,
        BuildConfig.COLLECTOR_RECEIPT_MARKERS,
    )
    fun consented(context: Context): Boolean = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getString("version", null) == NOTICE_VERSION + ":" + policy.fingerprint
    fun acceptNotice(context: Context) {
        check(policy.configured) { "Approved receipt-filter configuration is required" }
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("version", NOTICE_VERSION + ":" + policy.fingerprint)
            .putLong("accepted_at", System.currentTimeMillis()).commit()) { "Consent could not be saved" }
    }
    fun revokeNotice(context: Context) {
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit())
    }
    fun ready(context: Context): Boolean = policy.configured && consented(context) &&
        context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
}
