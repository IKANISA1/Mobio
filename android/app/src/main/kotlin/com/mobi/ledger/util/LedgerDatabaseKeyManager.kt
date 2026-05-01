package com.mobi.ledger.util

import android.content.Context
import android.util.Base64
import android.util.Log
import java.security.SecureRandom
import net.zetetic.database.sqlcipher.SQLiteDatabase

object LedgerDatabaseKeyManager {
    private const val TAG = "LedgerDbKeyManager"
    private const val DATABASE_NAME = "mobi_ledger.db"
    private const val PREF_DB_PASSPHRASE = "ledger_db_passphrase_v1"
    private const val PREF_DB_KEY_MODE = "ledger_db_key_mode"
    private const val MODE_KEYSTORE = "keystore_per_install"
    private const val MODE_LEGACY_FIXED = "legacy_fixed"
    private const val LEGACY_PASSPHRASE = "mobi_secure_passphrase"

    fun getOrCreatePassphrase(context: Context): ByteArray {
        val appContext = context.applicationContext
        val prefs = PrefsManager.getEncryptedPrefs(appContext)
        val storedPassphrase = prefs.getString(PREF_DB_PASSPHRASE, null)

        if (!storedPassphrase.isNullOrBlank()) {
            return storedPassphrase.toByteArray(Charsets.UTF_8)
        }

        val newPassphrase = generatePassphrase()
        val dbFile = appContext.getDatabasePath(DATABASE_NAME)

        if (dbFile.exists()) {
            val rekeyed = rekeyLegacyDatabase(dbFile.absolutePath, newPassphrase)
            if (rekeyed) {
                prefs.edit()
                    .putString(PREF_DB_PASSPHRASE, newPassphrase)
                    .putString(PREF_DB_KEY_MODE, MODE_KEYSTORE)
                    .apply()
                return newPassphrase.toByteArray(Charsets.UTF_8)
            }

            prefs.edit().putString(PREF_DB_KEY_MODE, MODE_LEGACY_FIXED).apply()
            return LEGACY_PASSPHRASE.toByteArray(Charsets.UTF_8)
        }

        prefs.edit()
            .putString(PREF_DB_PASSPHRASE, newPassphrase)
            .putString(PREF_DB_KEY_MODE, MODE_KEYSTORE)
            .apply()
        return newPassphrase.toByteArray(Charsets.UTF_8)
    }

    private fun generatePassphrase(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun rekeyLegacyDatabase(path: String, newPassphrase: String): Boolean {
        var database: SQLiteDatabase? = null

        return try {
            System.loadLibrary("sqlcipher")
            database = SQLiteDatabase.openDatabase(
                path,
                LEGACY_PASSPHRASE.toByteArray(Charsets.UTF_8),
                null,
                SQLiteDatabase.OPEN_READWRITE,
                null
            )
            database.rawQuery("select count(*) from sqlite_master", emptyArray<String>()).use {
                it.moveToFirst()
            }
            database.changePassword(newPassphrase.toByteArray(Charsets.UTF_8))
            true
        } catch (error: Throwable) {
            Log.w(
                TAG,
                "Could not rekey legacy ledger database; preserving legacy access",
                error
            )
            false
        } finally {
            database?.close()
        }
    }
}
