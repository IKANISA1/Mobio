package rw.mobi.app.ledger.data.remote

import android.content.Context
import rw.mobi.app.ledger.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.ktor.client.engine.okhttp.OkHttp

/**
 * Supabase client singleton.
 * Configured with anonymous auth, postgrest, realtime, and edge functions.
 */
object SupabaseManager {

    lateinit var client: SupabaseClient
        private set

    var isInitialized = false
        private set

    fun initialize(context: Context) {
        if (isInitialized) return

        client = createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            install(Auth)
            install(Postgrest)
            install(Realtime)
            install(Functions)

            // Use OkHttp engine for Ktor
            httpEngine = OkHttp.create()
        }

        isInitialized = true
    }
}
