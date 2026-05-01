package com.mobi.ledger.util

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

object PrefsManager {
    private const val PREFS_NAME = "mobi_ledger_secure_prefs"

    fun getEncryptedPrefs(context: Context): SharedPreferences {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        return EncryptedSharedPreferences.create(
            PREFS_NAME,
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun getAgentId(context: Context): String? {
        return getEncryptedPrefs(context).getString("agent_id", null)
    }

    fun getAccessToken(context: Context): String? {
        return getEncryptedPrefs(context).getString("access_token", null)
    }
}
