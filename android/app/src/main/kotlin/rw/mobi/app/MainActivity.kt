package rw.mobi.app

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.nfc.tech.Ndef
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var nativeNfcReaderChannel: MethodChannel? = null
    private var nativeReaderRequested = false
    private var pendingNativeNfcPayload: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/install_referrer",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getInstallReferrer") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            readInstallReferrer(result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/biopay_qr_export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePngToGallery") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val bytes = call.argument<ByteArray>("bytes")
            val fileName = call.argument<String>("fileName")
            if (bytes == null || fileName.isNullOrBlank()) {
                result.error("INVALID_ARGUMENTS", "PNG bytes and fileName are required.", null)
                return@setMethodCallHandler
            }

            savePngToGallery(bytes, fileName, result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/biopay_device_nfc",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val payload = call.argument<String>("payload")
                    if (payload.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "BioPay NFC payload is required.", null)
                        return@setMethodCallHandler
                    }
                    val prefs = getSharedPreferences(BioPayHostApduService.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean(BioPayHostApduService.KEY_ENABLED, true)
                        .putString(BioPayHostApduService.KEY_PAYLOAD, payload)
                        .putString(BioPayHostApduService.KEY_TOKEN, call.argument<String>("token"))
                        .putString(BioPayHostApduService.KEY_EXPIRES_AT, call.argument<String>("expiresAt"))
                        .apply()
                    result.success(biopayDeviceNfcStatus())
                }
                "stop" -> {
                    val prefs = getSharedPreferences(BioPayHostApduService.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit().putBoolean(BioPayHostApduService.KEY_ENABLED, false).apply()
                    result.success(biopayDeviceNfcStatus())
                }
                "status" -> result.success(biopayDeviceNfcStatus())
                else -> result.notImplemented()
            }
        }
        nativeNfcReaderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/biopay_native_nfc_reader",
        )
        nativeNfcReaderChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    nativeReaderRequested = true
                    enableNativeNfcReader()
                    result.success(nativeNfcReaderStatus())
                }
                "stop" -> {
                    nativeReaderRequested = false
                    disableNativeNfcReader()
                    result.success(nativeNfcReaderStatus())
                }
                "status" -> result.success(nativeNfcReaderStatus())
                "consumePendingPayload" -> {
                    result.success(pendingNativeNfcPayload)
                    pendingNativeNfcPayload = null
                }
                else -> result.notImplemented()
            }
        }
        handleNfcIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        if (nativeReaderRequested) {
            enableNativeNfcReader()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNfcIntent(intent)
    }

    override fun onPause() {
        disableNativeNfcReader()
        super.onPause()
    }

    override fun onTagDiscovered(tag: Tag) {
        if (!nativeReaderRequested) return
        try {
            val devicePayload = readDeviceHcePayload(tag)
            if (!devicePayload.isNullOrBlank()) {
                emitNativeNfcPayload("device_hce", devicePayload)
                return
            }

            val cardPayload = readNdefPayload(tag)
            if (!cardPayload.isNullOrBlank()) {
                emitNativeNfcPayload("ndef_card", cardPayload)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Native NFC reader failed", error)
        }
    }

    private fun handleNfcIntent(intent: Intent?) {
        if (intent == null || !isNfcIntent(intent)) return
        try {
            payloadFromNdefIntent(intent)?.let {
                emitNativeNfcPayload("closed_app_ndef", it)
                return
            }

            @Suppress("DEPRECATION")
            val tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG) as? Tag
                ?: return
            readDeviceHcePayload(tag)?.let {
                emitNativeNfcPayload("closed_app_device_hce", it)
                return
            }
            readNdefPayload(tag)?.let {
                emitNativeNfcPayload("closed_app_ndef_tag", it)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Unable to handle NFC launch intent", error)
        }
    }

    private fun isNfcIntent(intent: Intent): Boolean {
        return intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TECH_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TAG_DISCOVERED
    }

    private fun enableNativeNfcReader() {
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        if (!adapter.isEnabled) return
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        adapter.enableReaderMode(this, this, flags, null)
    }

    private fun disableNativeNfcReader() {
        try {
            NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
        } catch (error: Exception) {
            Log.w(TAG, "Unable to disable native NFC reader", error)
        }
    }

    private fun nativeNfcReaderStatus(): Map<String, Any?> {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        val supported = packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)
        return mapOf(
            "supported" to supported,
            "nfcEnabled" to (adapter?.isEnabled == true),
            "enabled" to (nativeReaderRequested && adapter?.isEnabled == true),
            "readerMode" to "native_android_reader_mode",
        )
    }

    private fun readDeviceHcePayload(tag: Tag): String? {
        val isoDep = IsoDep.get(tag) ?: return null
        isoDep.use {
            it.connect()
            it.timeout = 750
            val response = it.transceive(hexToBytes("00A4040007${BioPayHostApduService.BIOPAY_AID}00"))
            if (response.size < 3) return null
            if (response[response.size - 2] != 0x90.toByte() || response.last() != 0x00.toByte()) {
                return null
            }
            return String(response.copyOfRange(0, response.size - 2), Charsets.UTF_8).trim()
        }
    }

    private fun readNdefPayload(tag: Tag): String? {
        val ndef = Ndef.get(tag) ?: return null
        ndef.use {
            it.connect()
            val message = it.cachedNdefMessage ?: it.ndefMessage ?: return null
            for (record in message.records) {
                val payload = payloadFromRecord(record)
                if (!payload.isNullOrBlank()) return payload
            }
        }
        return null
    }

    private fun payloadFromRecord(record: NdefRecord): String? {
        record.toUri()?.let { return it.toString() }

        if (record.tnf == NdefRecord.TNF_WELL_KNOWN &&
            record.type.contentEquals(NdefRecord.RTD_TEXT) &&
            record.payload.isNotEmpty()
        ) {
            val languageLength = record.payload[0].toInt() and 0x3F
            val textStart = 1 + languageLength
            if (textStart < record.payload.size) {
                return String(
                    record.payload,
                    textStart,
                    record.payload.size - textStart,
                    Charsets.UTF_8,
                ).trim()
            }
        }

        if (record.payload.isNotEmpty()) {
            return String(record.payload, Charsets.UTF_8).trim()
        }
        return null
    }

    @Suppress("DEPRECATION")
    private fun payloadFromNdefIntent(intent: Intent): String? {
        val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            ?: return null
        for (raw in rawMessages) {
            val message = raw as? NdefMessage ?: continue
            for (record in message.records) {
                val payload = payloadFromRecord(record)
                if (!payload.isNullOrBlank()) return payload
            }
        }
        return null
    }

    private fun emitNativeNfcPayload(kind: String, payload: String) {
        val message = mapOf("kind" to kind, "payload" to payload)
        pendingNativeNfcPayload = message
        mainHandler.post {
            nativeNfcReaderChannel?.invokeMethod(
                "onNfcPayload",
                message,
            )
        }
    }

    private fun hexToBytes(hex: String): ByteArray {
        return hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }

    private fun biopayDeviceNfcStatus(): Map<String, Any?> {
        val supported = packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
        val adapter = NfcAdapter.getDefaultAdapter(this)
        val prefs = getSharedPreferences(BioPayHostApduService.PREFS_NAME, MODE_PRIVATE)
        val enabled = supported && adapter?.isEnabled == true &&
            prefs.getBoolean(BioPayHostApduService.KEY_ENABLED, false)
        return mapOf(
            "supported" to supported,
            "nfcEnabled" to (adapter?.isEnabled == true),
            "enabled" to enabled,
            "token" to prefs.getString(BioPayHostApduService.KEY_TOKEN, null),
            "expiresAt" to prefs.getString(BioPayHostApduService.KEY_EXPIRES_AT, null),
            "aid" to BioPayHostApduService.BIOPAY_AID,
            "reason" to when {
                !supported -> "Android HCE is not supported on this device."
                adapter?.isEnabled != true -> "NFC is disabled."
                else -> null
            },
        )
    }

    private fun readInstallReferrer(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(this).build()
        client.startConnection(
            object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (responseCode != InstallReferrerClient.InstallReferrerResponse.OK) {
                        client.endConnection()
                        result.success(null)
                        return
                    }

                    try {
                        val response: ReferrerDetails = client.installReferrer
                        result.success(
                            mapOf(
                                "installReferrer" to response.installReferrer,
                                "installBeginTimestampSeconds" to response.installBeginTimestampSeconds,
                                "referrerClickTimestampSeconds" to response.referrerClickTimestampSeconds,
                            ),
                        )
                    } catch (error: Exception) {
                        result.error(
                            "INSTALL_REFERRER_READ_FAILED",
                            error.message,
                            null,
                        )
                    } finally {
                        client.endConnection()
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    result.success(null)
                }
            },
        )
    }

    private fun savePngToGallery(
        bytes: ByteArray,
        fileName: String,
        result: MethodChannel.Result,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Mobio")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                    put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
                    put(MediaStore.Images.Media.DATE_TAKEN, System.currentTimeMillis())
                }
                val uri = resolver.insert(
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                    values,
                ) ?: throw IllegalStateException("Unable to create image entry.")

                resolver.openOutputStream(uri)?.use { output ->
                    output.write(bytes)
                } ?: throw IllegalStateException("Unable to open image output stream.")

                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success(true)
                return
            }

            val directory = File(
                getExternalFilesDir(Environment.DIRECTORY_PICTURES),
                "Mobio",
            )
            if (!directory.exists()) {
                directory.mkdirs()
            }
            val file = File(directory, fileName)
            file.writeBytes(bytes)
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf("image/png"),
            ) { _, _ -> result.success(true) }
        } catch (error: Exception) {
            result.error("BIOPAY_QR_SAVE_FAILED", error.message, null)
        }
    }

    companion object {
        private const val TAG = "MobiMainActivity"
    }
}
