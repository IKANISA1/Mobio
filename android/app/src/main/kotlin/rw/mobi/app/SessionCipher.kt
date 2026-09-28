package rw.mobi.app

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Versioned authenticated envelope. Key storage is injected by Android Keystore.
 * No raw key export, caller-selected IV, plaintext fallback, or custom cipher.
 */
class SessionCipher(private val key: SecretKey) {
    companion object {
        const val MAX_PLAINTEXT_BYTES = 65536
        private val MAGIC = byteArrayOf(0x4d, 0x42, 0x53, 0x01)
        private const val NONCE_BYTES = 12
        private const val TAG_BITS = 128
        fun requireNamespace(namespace: String) {
            require(Regex("^[a-f0-9]{64}$").matches(namespace)) { "INVALID_STORAGE_NAMESPACE" }
        }
    }

    fun encrypt(namespace: String, text: String): ByteArray {
        requireNamespace(namespace)
        val plain = text.toByteArray(Charsets.UTF_8)
        require(plain.isNotEmpty() && plain.size <= MAX_PLAINTEXT_BYTES) { "INVALID_SESSION_SIZE" }
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            // Android Keystore requires a provider-generated random IV.
            cipher.init(Cipher.ENCRYPT_MODE, key)
            cipher.updateAAD(aad(namespace))
            val iv = cipher.iv
            check(iv.size == NONCE_BYTES) { "INVALID_CIPHER_NONCE" }
            return MAGIC + iv + cipher.doFinal(plain)
        } finally {
            plain.fill(0)
        }
    }

    fun decrypt(namespace: String, envelope: ByteArray): String {
        requireNamespace(namespace)
        require(envelope.size in (MAGIC.size + NONCE_BYTES + 17)..(MAX_PLAINTEXT_BYTES + 32)) {
            "INVALID_SESSION_ENVELOPE"
        }
        require(envelope.copyOfRange(0, MAGIC.size).contentEquals(MAGIC)) { "INVALID_SESSION_VERSION" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS,
            envelope.copyOfRange(MAGIC.size, MAGIC.size + NONCE_BYTES)))
        cipher.updateAAD(aad(namespace))
        val plain = cipher.doFinal(envelope.copyOfRange(MAGIC.size + NONCE_BYTES, envelope.size))
        try {
            return Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(plain)).toString()
        } finally {
            plain.fill(0)
        }
    }

    private fun aad(namespace: String) = "rw.mobi.app/session/v1/$namespace".toByteArray(Charsets.US_ASCII)
}
