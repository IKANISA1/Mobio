package com.momobio.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.util.UUID

/** Non-exportable device key. The server receives only its public enrollment. */
class CollectorIdentity(context: Context) {
    private val prefs = context.getSharedPreferences("momobio_collector", Context.MODE_PRIVATE)

    fun enrollmentRequest(): String = synchronized(lock) {
        val id = collectorId()
        val publicKey = store().getCertificate(alias).publicKey as RSAPublicKey
        val modulus = publicKey.modulus.toByteArray().let { if (it[0] == 0.toByte()) it.copyOfRange(1, it.size) else it }
        val n = encode(modulus)
        JSONObject().put("collector_id", id)
            .put("public_key", JSONObject().put("kty", "RSA").put("n", n).put("e", "AQAB"))
            .put("fingerprint", hash("RSA\n$n\nAQAB".toByteArray(Charsets.UTF_8))).toString()
    }

    fun headers(body: ByteArray): Map<String, String> = synchronized(lock) {
        val id = collectorId()
        val timestamp = System.currentTimeMillis().toString()
        val nonce = UUID.randomUUID().toString()
        val canonical = signingPayload(id, timestamp, nonce, hash(body))
        val signer = Signature.getInstance("SHA256withRSA")
        signer.initSign(store().getKey(alias, null) as PrivateKey)
        signer.update(canonical.toByteArray(Charsets.UTF_8))
        mapOf("x-mobio-collector-id" to id, "x-mobio-timestamp" to timestamp,
            "x-mobio-nonce" to nonce, "x-mobio-signature" to encode(signer.sign()))
    }

    private fun collectorId(): String {
        val keys = store()
        var id = prefs.getString("collector_id", null)
        if (!keys.containsAlias(alias)) {
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore").apply {
                initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                    .setKeySize(2048).setDigests(KeyProperties.DIGEST_SHA256)
                    .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1).build())
            }.generateKeyPair()
            id = null
        }
        if (id == null) {
            id = UUID.randomUUID().toString()
            check(prefs.edit().putString("collector_id", id).commit()) { "Unable to persist collector enrollment" }
        }
        return id
    }

    private fun store(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    companion object {
        private const val alias = "momobio-collector-signing-v1"
        private val lock = Any()
        internal fun signingPayload(id: String, timestamp: String, nonce: String, bodyHash: String): String =
            "mobio-collector-v1\nPOST\n/momobio-sms-ingest\n$id\n$timestamp\n$nonce\n$bodyHash"
        private fun hash(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }
        private fun encode(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }
}
