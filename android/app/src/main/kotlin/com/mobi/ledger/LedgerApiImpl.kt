package com.mobi.ledger

import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.mobi.ledger.data.local.LedgerDatabase
import com.mobi.ledger.util.PrefsManager
import com.mobi.ledger.worker.SyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LedgerApiImpl(private val context: Context) : LedgerApi {

    override fun isSmsPermissionGranted(callback: (Result<Boolean>) -> Unit) {
        val granted = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
        callback(Result.success(granted))
    }

    override fun requestSmsPermission(callback: (Result<Boolean>) -> Unit) {
        // Permission request must be handled in Activity.
        // This is a placeholder; Flutter's permission_handler is usually preferred,
        // but we'll return false here to indicate it should be handled via platform channel or plugin.
        callback(Result.success(false))
    }

    override fun startLedgerService(agentId: String, supabaseUrl: String, supabaseAnonKey: String) {
        PrefsManager.getEncryptedPrefs(context).edit().apply {
            putString("agent_id", agentId)
            putString("supabase_url", supabaseUrl)
            putString("supabase_anon_key", supabaseAnonKey)
            apply()
        }
        SyncWorker.enqueue(context)
    }

    override fun stopLedgerService() {
        // Optional: cancel WorkManager jobs if needed
    }

    override fun getSyncStatus(callback: (Result<LedgerSyncStatus>) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            val db = LedgerDatabase.getInstance(context)
            val dao = db.smsQueueDao()

            val pending = dao.observePendingCount().first()
            val failed = dao.observeFailedCount().first()
            val synced = dao.observeSyncedCount().first()

            val prefs = PrefsManager.getEncryptedPrefs(context)
            val lastSync = prefs.getLong("last_sync_at", 0L)
            val lastError = prefs.getString("last_sync_error", null)

            withContext(Dispatchers.Main) {
                callback(Result.success(LedgerSyncStatus(
                    pendingCount = pending.toLong(),
                    failedCount = failed.toLong(),
                    syncedCount = synced.toLong(),
                    lastSyncTimestamp = lastSync,
                    lastError = lastError
                )))
            }
        }
    }

    override fun syncNow(callback: (Result<Unit>) -> Unit) {
        SyncWorker.enqueue(context)
        callback(Result.success(Unit))
    }

    override fun setCredentials(agentId: String, accessToken: String, callback: (Result<Unit>) -> Unit) {
        PrefsManager.getEncryptedPrefs(context).edit().apply {
            putString("agent_id", agentId)
            putString("access_token", accessToken)
            apply()
        }
        callback(Result.success(Unit))
    }
}
