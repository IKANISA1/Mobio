package rw.mobi.app.ledger.data.remote

import android.content.Context
import rw.mobi.app.ledger.util.PrefsManager
import io.github.jan.supabase.auth.auth

/**
 * Handles Supabase anonymous authentication.
 * No email, no password — zero-friction onboarding.
 */
object AuthManager {

    /**
     * Ensure user is authenticated. Returns access token.
     * Uses anonymous auth — creates new user on first launch, reuses on subsequent.
     */
    suspend fun ensureAuth(context: Context): String {
        val stored = PrefsManager.getAuthToken(context)
        if (stored != null) {
            try {
                // Try to refresh existing session
                SupabaseManager.client.auth.refreshCurrentSession()
                return SupabaseManager.client.auth.currentAccessTokenOrNull() ?: stored
            } catch (e: Exception) {
                // Token might be expired beyond refresh — re-auth
            }
        }

        // Sign in anonymously
        SupabaseManager.client.auth.signInAnonymously()
        val token = SupabaseManager.client.auth.currentAccessTokenOrNull()
            ?: throw IllegalStateException("Anonymous auth failed — no token returned")

        PrefsManager.setAuthToken(context, token)
        return token
    }

    /**
     * Get the current Supabase user ID (UUID).
     */
    fun getCurrentUserId(): String? {
        return SupabaseManager.client.auth.currentUserOrNull()?.id
    }
}
