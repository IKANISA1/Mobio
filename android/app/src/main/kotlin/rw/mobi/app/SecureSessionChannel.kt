package rw.mobi.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** One fixed-purpose channel; never accepts filenames, key aliases, or arbitrary keys. */
object SecureSessionChannel {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private const val ALIAS_PREFIX = "rw.mobi.app.session.v1."

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "rw.mobi.app/secure_session").setMethodCallHandler { call, result ->
            if (call.method !in setOf("read", "write", "clear", "reset")) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val namespace = call.argument<String>("namespace")
            val value = call.argument<String>("value")
            if (namespace == null || !Regex("^[a-f0-9]{64}$").matches(namespace) ||
                (call.method == "write" && (value == null || value.toByteArray(Charsets.UTF_8).size !in 1..65536))) {
                result.error("AUTH_STORAGE_ARGUMENT", "Invalid session storage request.", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    // Neither session envelopes nor locks participate in backup/restore.
                    val directory = File(app.noBackupFilesDir, "mobio_auth_v1")
                    check(directory.isDirectory || directory.mkdirs()) { "STORAGE_DIRECTORY_FAILED" }
                    val answer = RandomAccessFile(File(directory, "$namespace.lock"), "rw").use { file ->
                        file.channel.lock().use {
                            val slot = AtomicFile(File(directory, "$namespace.bin"))
                            when (call.method) {
                                "read" -> {
                                    val envelope = try { slot.openRead().use { input ->
                                        val bytes = input.readBytesBounded(65568)
                                        bytes
                                    } } catch (e: java.io.FileNotFoundException) {
                                        if (File(directory, "$namespace.bin").exists() ||
                                            File(directory, "$namespace.bin.bak").exists() ||
                                            File(directory, "$namespace.bin.new").exists()) throw e
                                        null
                                    }
                                    if (envelope == null) null else {
                                        val key = loadKey(namespace, create = false)
                                            ?: throw IllegalStateException("SESSION_KEY_MISSING")
                                        SessionCipher(key).decrypt(namespace, envelope)
                                    }
                                }
                                "write" -> {
                                    val cipher = SessionCipher(loadKey(namespace, create = true)!!)
                                    val encrypted = cipher.encrypt(namespace, value!!)
                                    val output = slot.startWrite()
                                    try {
                                        output.write(encrypted)
                                        slot.finishWrite(output)
                                    } catch (e: Exception) {
                                        slot.failWrite(output)
                                        throw e
                                    }
                                    // Read-back is part of success, not just a queued filesystem write.
                                    check(slot.openRead().use { cipher.decrypt(namespace, it.readBytesBounded(65568)) } == value)
                                    true
                                }
                                else -> {
                                    slot.delete()
                                    check(listOf(".bin", ".bin.bak", ".bin.new").none {
                                        File(directory, namespace + it).exists()
                                    }) { "SESSION_DELETE_FAILED" }
                                    if (call.method == "reset") {
                                        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                                        store.deleteEntry(ALIAS_PREFIX + namespace)
                                    }
                                    true
                                }
                            }
                        }
                    }
                    main.post { result.success(answer) }
                } catch (_: Exception) {
                    // Never forward key aliases, token bytes, native exception strings or paths.
                    main.post { result.error("AUTH_STORAGE_UNAVAILABLE",
                        "Saved login could not be accessed safely.", null) }
                }
            }
        }
    }

    private fun loadKey(namespace: String, create: Boolean): SecretKey? {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = ALIAS_PREFIX + namespace
        if (store.containsAlias(alias)) return store.getKey(alias, null) as SecretKey
        if (!create) return null // Never create a new key to "repair" existing ciphertext.
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true).build())
        return generator.generateKey()
    }

    private fun java.io.InputStream.readBytesBounded(maximum: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            val count = read(buffer)
            if (count < 0) break
            check(out.size() + count <= maximum) { "SESSION_FILE_TOO_LARGE" }
            out.write(buffer, 0, count)
        }
        return out.toByteArray()
    }
}
