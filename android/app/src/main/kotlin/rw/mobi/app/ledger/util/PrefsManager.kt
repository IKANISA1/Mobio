package rw.mobi.app.ledger.util

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Manages encrypted preferences using Android Keystore.
 * Stores: auth token, agent ID, MoMo number, DB encryption key, onboarding state.
 */
object PrefsManager {

    private const val PREFS_NAME = "payledger_encrypted_prefs"

    private var encryptedPrefs: SharedPreferences? = null

    fun getEncryptedPrefs(context: Context): SharedPreferences {
        return encryptedPrefs ?: synchronized(this) {
            encryptedPrefs ?: createEncryptedPrefs(context).also { encryptedPrefs = it }
        }
    }

    private fun createEncryptedPrefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    // --- Agent/Auth keys ---

    fun getAgentId(context: Context): String? =
        getEncryptedPrefs(context).getString("agent_id", null)

    fun setAgentId(context: Context, agentId: String) {
        getEncryptedPrefs(context).edit().putString("agent_id", agentId).apply()
    }

    fun getMoMoNumber(context: Context): String? =
        getEncryptedPrefs(context).getString("momo_number", null)

    fun setMoMoNumber(context: Context, number: String) {
        getEncryptedPrefs(context).edit().putString("momo_number", number).apply()
    }

    fun getAuthToken(context: Context): String? =
        getEncryptedPrefs(context).getString("auth_token", null)

    fun setAuthToken(context: Context, token: String) {
        getEncryptedPrefs(context).edit().putString("auth_token", token).apply()
    }

    fun getCountryCode(context: Context): String? =
        getEncryptedPrefs(context).getString("country_code", null)

    fun setCountryCode(context: Context, code: String) {
        getEncryptedPrefs(context).edit().putString("country_code", code).apply()
    }

    fun getCountryFlag(context: Context): String? =
        getEncryptedPrefs(context).getString("country_flag", null)

    fun setCountryFlag(context: Context, flag: String) {
        getEncryptedPrefs(context).edit().putString("country_flag", flag).apply()
    }

    fun getDialingCode(context: Context): String? =
        getEncryptedPrefs(context).getString("dialing_code", null)

    fun setDialingCode(context: Context, code: String) {
        getEncryptedPrefs(context).edit().putString("dialing_code", code).apply()
    }

    fun getNetworkName(context: Context): String? =
        getEncryptedPrefs(context).getString("network_name", null)

    fun setNetworkName(context: Context, name: String) {
        getEncryptedPrefs(context).edit().putString("network_name", name).apply()
    }

    // --- Onboarding state ---

    fun isOnboardingComplete(context: Context): Boolean =
        getEncryptedPrefs(context).getBoolean("onboarding_complete", false)

    fun setOnboardingComplete(context: Context, complete: Boolean) {
        getEncryptedPrefs(context).edit().putBoolean("onboarding_complete", complete).apply()
    }

    fun isBackfillComplete(context: Context): Boolean =
        getEncryptedPrefs(context).getBoolean("backfill_complete", false)

    fun setBackfillComplete(context: Context, complete: Boolean) {
        getEncryptedPrefs(context).edit().putBoolean("backfill_complete", complete).apply()
    }

    // --- Provider cache timing ---

    fun getLastProviderRefresh(context: Context): Long =
        getEncryptedPrefs(context).getLong("last_provider_refresh", 0L)

    fun setLastProviderRefresh(context: Context, timestamp: Long) {
        getEncryptedPrefs(context).edit().putLong("last_provider_refresh", timestamp).apply()
    }
}
