package rw.mobi.app.ledger.data.remote

import android.content.Context
import rw.mobi.app.ledger.util.PrefsManager
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Agent ID management.
 * Generates globally unique 6-digit numeric IDs and registers with Supabase.
 */
object AgentManager {

    /**
     * Generate a unique 6-digit Agent ID.
     * Checks Supabase for collisions, retries up to 10 times.
     */
    suspend fun generateAgentId(): String {
        repeat(10) {
            val candidate = (100000..999999).random().toString()
            val result = SupabaseManager.client.from("users")
                .select {
                    filter { eq("agent_id", candidate) }
                }
                .decodeList<Map<String, String>>()

            if (result.isEmpty()) return candidate
        }
        throw IllegalStateException("Could not generate unique Agent ID after 10 attempts")
    }

    /**
     * Register a new agent in the users table.
     * Links anonymous auth UUID to agent_id + MoMo number.
     */
    suspend fun registerAgent(
        context: Context,
        agentId: String,
        momoNumber: String,
        networkName: String,
        countryCode: String
    ) {
        val userId = AuthManager.getCurrentUserId()
            ?: throw IllegalStateException("Not authenticated")

        SupabaseManager.client.from("users").insert(buildJsonObject {
            put("id", userId)
            put("agent_id", agentId)
            put("momo_number", momoNumber)
            put("network", networkName)
            put("country_code", countryCode)
        })

        // Persist locally
        PrefsManager.setAgentId(context, agentId)
        PrefsManager.setMoMoNumber(context, momoNumber)
        PrefsManager.setNetworkName(context, networkName)
        PrefsManager.setCountryCode(context, countryCode)
    }
}
