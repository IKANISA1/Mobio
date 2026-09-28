package rw.mobi.app

import java.io.File
import java.nio.file.Files
import javax.crypto.KeyGenerator

/** Real JCA AES/GCM operations with ephemeral JVM keys, not Android Keystore. */
fun main() {
    val generator = KeyGenerator.getInstance("AES").apply { init(256) }
    val cipher = SessionCipher(generator.generateKey())
    val other = SessionCipher(generator.generateKey())
    val namespace = "a".repeat(64)
    var passed = 0
    fun checkCase(name: String, body: () -> Unit) {
        body(); passed++; println("PASS $name")
    }
    fun rejects(body: () -> Unit) {
        var thrown = false
        try { body() } catch (_: Exception) { thrown = true }
        check(thrown) { "Expected rejection" }
    }
    listOf("x", "{\"synthetic\":true}", "Muraho Rwanda 👋", "é漢字\n\t🙂", " ", "x".repeat(65536)).forEachIndexed { index, text ->
        checkCase("roundtrip-$index") { check(cipher.decrypt(namespace, cipher.encrypt(namespace, text)) == text) }
    }
    val payload = "synthetic-session-test-only-never-a-real-credential"
    val envelope = cipher.encrypt(namespace, payload)
    checkCase("no-plaintext-in-envelope") { check(!String(envelope, Charsets.ISO_8859_1).contains(payload)) }
    checkCase("wrong-key") { rejects { other.decrypt(namespace, envelope) } }
    checkCase("wrong-namespace") { rejects { cipher.decrypt("b".repeat(64), envelope) } }
    checkCase("nonce-randomization") {
        val values = (1..128).map { cipher.encrypt(namespace, payload).copyOfRange(4, 16).toList() }
        check(values.toSet().size == 128)
    }
    checkCase("empty-plaintext") { rejects { cipher.encrypt(namespace, "") } }
    checkCase("oversized-ascii") { rejects { cipher.encrypt(namespace, "x".repeat(65537)) } }
    checkCase("oversized-unicode") { rejects { cipher.encrypt(namespace, "🙂".repeat(16385)) } }
    listOf("", "A".repeat(64), "a".repeat(63), "a".repeat(65), "../secret", "x/y", "a".repeat(63)+"\n").forEachIndexed { i, value ->
        checkCase("namespace-rejection-$i") { rejects { cipher.encrypt(value, payload) }; rejects { cipher.decrypt(value, envelope) } }
    }
    listOf(0, 1, 3, 4, 10, 16, 20, 31, 32, envelope.size - 1).forEach { count ->
        checkCase("truncation-$count") { rejects { cipher.decrypt(namespace, envelope.copyOf(count)) } }
    }
    listOf(0, 3, 4, 8, 15, 16, 22, envelope.size-1).forEach { position ->
        checkCase("tamper-$position") {
            val mutated = envelope.copyOf(); mutated[position] = (mutated[position].toInt() xor 1).toByte()
            rejects { cipher.decrypt(namespace, mutated) }
        }
    }
    checkCase("oversized-envelope") { rejects { cipher.decrypt(namespace, ByteArray(65569)) } }
    checkCase("trailing-ciphertext") { rejects { cipher.decrypt(namespace, envelope + byteArrayOf(0)) } }
    checkCase("real-file-roundtrip") {
        val root = Files.createTempDirectory("mobio-cipher-test-").toFile()
        try {
            val file = File(root, "session.bin"); file.writeBytes(envelope)
            check(cipher.decrypt(namespace, file.readBytes()) == payload)
            check(!file.readText(Charsets.ISO_8859_1).contains(payload))
        } finally { root.deleteRecursively() }
    }
    println("RESULT: $passed passed; JCA/JVM only, not Android Keystore, Flutter or device acceptance")
}
