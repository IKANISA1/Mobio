package com.mobi.ledger.data.remote

import android.content.Context
import com.mobi.ledger.util.PrefsManager
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest

object SupabaseManager {
    private var clientInstance: SupabaseClient? = null

    fun getClient(context: Context): SupabaseClient {
        return clientInstance ?: synchronized(this) {
            val prefs = PrefsManager.getEncryptedPrefs(context)
            val url = prefs.getString("supabase_url", "") ?: ""
            val anonKey = prefs.getString("supabase_anon_key", "") ?: ""

            val client = createSupabaseClient(url, anonKey) {
                install(Postgrest)
                install(Functions)
            }
            clientInstance = client
            client
        }
    }

    // For background workers that need the latest token
    fun getClientWithToken(context: Context): SupabaseClient {
        val client = getClient(context)
        // Note: The jan-tennert/supabase-kt client handles token refreshing
        // if the session is managed. For background workers, we might need
        // to manually set the token from PrefsManager if it was updated by Flutter.
        return client
    }
}
