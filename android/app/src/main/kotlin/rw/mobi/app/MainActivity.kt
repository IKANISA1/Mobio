package rw.mobi.app

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.nfc.FormatException
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Build
import android.os.Bundle
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
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var nativeNfcReaderChannel: MethodChannel? = null
    private var nativeReaderRequested = false
    private var pendingNativeNfcPayload: Map<String, String>? = null
    @Volatile private var nativeNfcWriterRequest: NativeNfcWriterRequest? = null
    @Volatile private var nativeNfcWriterResult: MethodChannel.Result? = null
    @Volatile private var nativeNfcWriterProcessing = false
    private var nativeNfcWriterTimeout: Runnable? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/biopay_nfc_writer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeCard" -> startNativeNfcWriter(call, result, lockOnly = false)
                "lockVerifiedCard" -> startNativeNfcWriter(call, result, lockOnly = true)
                "cancel" -> {
                    cancelNativeNfcWriter("CANCELLED", "NFC write cancelled.", null)
                    result.success(null)
                }
                "status" -> result.success(nativeNfcWriterStatus())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rw.mobi.app/biopay_ussd_dialer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchUssd" -> launchNativeUssd(call, result)
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
        handleBioPayLaunchIntent(intent)
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
        handleBioPayLaunchIntent(intent)
    }

    override fun onPause() {
        if (nativeNfcWriterResult != null && !isFinishing && !isDestroyed) {
            cancelNativeNfcWriter("INTERRUPTED", "NFC write interrupted.", null)
        }
        disableNativeNfcReader()
        super.onPause()
    }

    override fun onTagDiscovered(tag: Tag) {
        val writerRequest = nativeNfcWriterRequest
        if (writerRequest != null) {
            handleNativeNfcWriterTag(tag, writerRequest)
            return
        }
        if (System.currentTimeMillis() < suppressBioPayNfcLaunchUntilMs) {
            ignoreNativeNfcTag(tag)
            return
        }
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

    private fun handleBioPayLaunchIntent(intent: Intent?) {
        if (intent == null) return
        if (isBioPayNfcViewIntent(intent)) {
            if (System.currentTimeMillis() < suppressBioPayNfcLaunchUntilMs) {
                Log.d(TAG, "Suppressing BioPay NFC self-launch after writer completion.")
                return
            }
            val payload = intent.dataString?.trim()
            if (!payload.isNullOrBlank()) {
                emitNativeNfcPayload("biopay_nfc_app_link", payload)
            }
            return
        }
        handleNfcIntent(intent)
    }

    private fun launchNativeUssd(call: MethodCall, result: MethodChannel.Result) {
        val rawUri = call.argument<String>("uri")?.trim().orEmpty()
        val uri = try {
            Uri.parse(rawUri)
        } catch (_: Exception) {
            null
        }
        if (uri == null || uri.scheme != "tel" || uri.schemeSpecificPart.isNullOrBlank()) {
            result.error("INVALID_ARGUMENTS", "A tel: USSD URI is required.", null)
            return
        }

        startNativeUssdDialer(uri, result)
    }

    private fun startNativeUssdDialer(uri: Uri, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_DIAL, uri)
        try {
            if (intent.resolveActivity(packageManager) == null) {
                result.success(mapOf("launched" to false, "mode" to "unavailable"))
                return
            }
            startActivity(intent)
            result.success(mapOf("launched" to true, "mode" to "action_dial"))
        } catch (error: Exception) {
            Log.w(TAG, "Native USSD ACTION_DIAL failed", error)
            result.success(mapOf("launched" to false, "mode" to "failed"))
        }
    }

    private fun handleNfcIntent(intent: Intent) {
        if (!isNfcIntent(intent)) return
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

    private fun isBioPayNfcViewIntent(intent: Intent): Boolean {
        if (intent.action != Intent.ACTION_VIEW) return false
        val data = intent.data ?: return false
        val path = data.path ?: return false
        return (data.scheme == "https" &&
            data.host == "mobio.ikanisa.com" &&
            path.startsWith("/biopay/nfc")) ||
            (data.scheme == "mobio" &&
                data.host == "biopay" &&
                path.startsWith("/nfc"))
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
        if (isFinishing || isDestroyed) return
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

    private fun startNativeNfcWriter(
        call: MethodCall,
        result: MethodChannel.Result,
        lockOnly: Boolean,
    ) {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        val supported = packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)
        if (!supported || adapter == null) {
            result.error("NFC_NOT_SUPPORTED", "NFC is not supported.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("NFC_DISABLED", "NFC is disabled.", null)
            return
        }
        if (nativeNfcWriterRequest != null || nativeNfcWriterResult != null) {
            result.error("NFC_BUSY", "Another NFC write is already active.", null)
            return
        }

        val request = NativeNfcWriterRequest(
            appLink = call.argument<String>("appLink")?.trim().orEmpty(),
            jsonPayload = call.argument<String>("jsonPayload")?.trim().orEmpty(),
            mimeType = call.argument<String>("mimeType")?.trim().orEmpty(),
            packageName = call.argument<String>("packageName")?.trim().orEmpty(),
            receiverType = call.argument<String>("receiverType")?.trim().orEmpty(),
            receiver = call.argument<String>("receiver")?.trim().orEmpty(),
            lockOnly = lockOnly,
        )
        if (!request.isValid) {
            result.error("INVALID_ARGUMENTS", "BioPay NFC payload is required.", null)
            return
        }

        nativeNfcWriterRequest = request
        nativeNfcWriterResult = result
        nativeNfcWriterProcessing = false
        enableNativeNfcWriter()

        val timeout = Runnable {
            cancelNativeNfcWriter("NFC_TIMEOUT", "NFC card write timed out.", null)
        }
        nativeNfcWriterTimeout = timeout
        mainHandler.postDelayed(timeout, 25_000)
    }

    private fun enableNativeNfcWriter() {
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        if (!adapter.isEnabled) return
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
        val options = Bundle().apply {
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
        }
        adapter.enableReaderMode(this, this, flags, options)
    }

    private fun handleNativeNfcWriterTag(tag: Tag, request: NativeNfcWriterRequest) {
        if (nativeNfcWriterProcessing) return
        nativeNfcWriterProcessing = true
        try {
            val response = if (request.lockOnly) {
                lockNativeNfcTag(tag, request)
            } else {
                writeNativeNfcTag(tag, request)
            }
            ignoreNativeNfcTag(tag)
            completeNativeNfcWriter(response)
        } catch (error: NativeNfcWriterException) {
            completeNativeNfcWriter(error.code, error.message ?: "NFC card write failed.")
        } catch (error: Exception) {
            Log.w(TAG, "Native NFC writer failed", error)
            completeNativeNfcWriter("NFC_WRITE_FAILED", error.message ?: "NFC card write failed.")
        }
    }

    private fun writeNativeNfcTag(tag: Tag, request: NativeNfcWriterRequest): Map<String, Any?> {
        val ndef = Ndef.get(tag)
        if (ndef != null) {
            ndef.use {
                it.connect()
                if (!it.isWritable) {
                    throw NativeNfcWriterException("NFC_NOT_WRITABLE", "NFC card is not writable.")
                }
                val message = selectNativeNfcMessage(request, it.maxSize)
                it.writeNdefMessage(message)
                val selectedPayload = payloadFromMessage(message)
                val readBackPayload = readBackPayloadAfterWrite(it, request, selectedPayload)
                if (!request.matches(readBackPayload)) {
                    throw NativeNfcWriterException(
                        "NFC_VERIFY_FAILED",
                        "NFC card verification failed.",
                    )
                }
                return nativeNfcWriterResponse(
                    tag = tag,
                    ndef = it,
                    message = message,
                    readBackPayload = readBackPayload,
                    verified = true,
                    formatted = false,
                    locked = false,
                )
            }
        }

        val formattable = NdefFormatable.get(tag)
            ?: throw NativeNfcWriterException("NFC_NOT_WRITABLE", "NFC card is not NDEF writable.")
        formattable.use {
            it.connect()
            val message = formatNativeNfcTag(it, request)
            return nativeNfcWriterResponse(
                tag = tag,
                ndef = null,
                message = message,
                readBackPayload = request.appLink,
                verified = true,
                formatted = true,
                locked = false,
            )
        }
    }

    private fun lockNativeNfcTag(tag: Tag, request: NativeNfcWriterRequest): Map<String, Any?> {
        val ndef = Ndef.get(tag)
            ?: throw NativeNfcWriterException("NFC_NOT_WRITABLE", "This is not an NDEF card.")
        ndef.use {
            it.connect()
            val readBackMessage = it.ndefMessage ?: it.cachedNdefMessage
            val readBackPayload = payloadFromMessage(readBackMessage)
            if (!request.matches(readBackPayload)) {
                throw NativeNfcWriterException(
                    "NFC_VERIFY_FAILED",
                    "This is not the verified BioPay NFC card.",
                )
            }
            if (!it.isWritable || !it.canMakeReadOnly()) {
                throw NativeNfcWriterException(
                    "NFC_LOCK_UNSUPPORTED",
                    "This NFC card cannot be locked by this device.",
                )
            }
            if (!it.makeReadOnly()) {
                throw NativeNfcWriterException("NFC_LOCK_FAILED", "Failed to lock NFC card.")
            }
            return nativeNfcWriterResponse(
                tag = tag,
                ndef = it,
                message = readBackMessage ?: selectNativeNfcMessage(request, it.maxSize),
                readBackPayload = readBackPayload,
                verified = true,
                formatted = false,
                locked = true,
            )
        }
    }

    private fun formatNativeNfcTag(
        formattable: NdefFormatable,
        request: NativeNfcWriterRequest,
    ): NdefMessage {
        var lastError: Exception? = null
        for (message in buildNativeNfcMessages(request)) {
            try {
                formattable.format(message)
                return message
            } catch (error: FormatException) {
                lastError = error
            } catch (error: IOException) {
                lastError = error
            }
        }
        throw NativeNfcWriterException(
            "NFC_FORMAT_FAILED",
            lastError?.message ?: "NFC card could not be formatted.",
        )
    }

    private fun selectNativeNfcMessage(request: NativeNfcWriterRequest, maxSize: Int): NdefMessage {
        val candidates = buildNativeNfcMessages(request)
        if (maxSize <= 0) return candidates[1]
        for (message in candidates) {
            if (message.toByteArray().size <= maxSize) return message
        }
        throw NativeNfcWriterException("NFC_TOO_SMALL", "NFC card is too small.")
    }

    private fun buildNativeNfcMessages(request: NativeNfcWriterRequest): List<NdefMessage> {
        val appLinkRecord = NdefRecord.createUri(request.appLink)
        val mimeRecord = NdefRecord.createMime(
            request.mimeType,
            request.jsonPayload.toByteArray(Charsets.UTF_8),
        )
        val aarRecord = NdefRecord.createApplicationRecord(request.packageName)
        return listOf(
            NdefMessage(arrayOf(appLinkRecord, mimeRecord, aarRecord)),
            NdefMessage(arrayOf(appLinkRecord, aarRecord)),
            NdefMessage(arrayOf(appLinkRecord)),
        )
    }

    private fun nativeNfcWriterResponse(
        tag: Tag,
        ndef: Ndef?,
        message: NdefMessage,
        readBackPayload: String?,
        verified: Boolean,
        formatted: Boolean,
        locked: Boolean,
    ): Map<String, Any?> {
        return mapOf(
            "tagId" to tag.id.toHex(),
            "standard" to nativeNfcTagStandard(tag),
            "type" to nativeNfcTagType(tag),
            "ndefAvailable" to (ndef != null || formatted),
            "ndefWritable" to when {
                locked -> false
                ndef != null -> ndef.isWritable
                else -> true
            },
            "ndefCanMakeReadOnly" to (ndef?.canMakeReadOnly() == true && !locked),
            "ndefCapacity" to ndef?.maxSize,
            "encodedSize" to message.toByteArray().size,
            "recordCount" to message.records.size,
            "readBackRecordCount" to message.records.size,
            "readBackRecordTypes" to message.records.map { nativeNfcRecordLabel(it) },
            "readBackPayload" to readBackPayload,
            "verified" to verified,
            "formatted" to formatted,
            "locked" to locked,
            "writerMode" to "native_android_reader_mode",
        )
    }

    private fun completeNativeNfcWriter(response: Map<String, Any?>) {
        val result = nativeNfcWriterResult ?: return
        clearNativeNfcWriterState()
        suppressBioPayNfcLaunchUntilMs = System.currentTimeMillis() + NFC_SELF_LAUNCH_SUPPRESSION_MS
        mainHandler.postAtFrontOfQueue {
            result.success(response)
            mainHandler.postDelayed({
                disableNativeNfcReader()
                if (nativeReaderRequested) enableNativeNfcReader()
            }, NFC_POST_WRITE_READER_SETTLE_MS)
        }
    }

    private fun completeNativeNfcWriter(code: String, message: String) {
        val result = nativeNfcWriterResult ?: return
        clearNativeNfcWriterState()
        mainHandler.postAtFrontOfQueue {
            result.error(code, message, null)
            mainHandler.post {
                disableNativeNfcReader()
                if (nativeReaderRequested) enableNativeNfcReader()
            }
        }
    }

    private fun cancelNativeNfcWriter(code: String, message: String, details: Any?) {
        val result = nativeNfcWriterResult
        if (result == null && nativeNfcWriterRequest == null) return
        clearNativeNfcWriterState()
        mainHandler.post {
            disableNativeNfcReader()
            if (nativeReaderRequested) enableNativeNfcReader()
            result?.error(code, message, details)
        }
    }

    private fun clearNativeNfcWriterState() {
        nativeNfcWriterTimeout?.let { mainHandler.removeCallbacks(it) }
        nativeNfcWriterTimeout = null
        nativeNfcWriterRequest = null
        nativeNfcWriterResult = null
        nativeNfcWriterProcessing = false
    }

    private fun nativeNfcWriterStatus(): Map<String, Any?> {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        return mapOf(
            "supported" to packageManager.hasSystemFeature(PackageManager.FEATURE_NFC),
            "nfcEnabled" to (adapter?.isEnabled == true),
            "active" to (nativeNfcWriterRequest != null),
            "writerMode" to "native_android_reader_mode",
        )
    }

    private fun ignoreNativeNfcTag(tag: Tag) {
        try {
            val ignored = NfcAdapter.getDefaultAdapter(this)
                ?.ignore(tag, NFC_TAG_IGNORE_DEBOUNCE_MS.toInt(), null, mainHandler)
            if (ignored != true) {
                Log.d(TAG, "NFC tag debounce was not accepted by the platform.")
            }
        } catch (error: Exception) {
            Log.w(TAG, "Unable to debounce written NFC tag", error)
        }
    }

    private fun readBackPayloadAfterWrite(
        ndef: Ndef,
        request: NativeNfcWriterRequest,
        selectedPayload: String?,
    ): String? {
        repeat(4) { attempt ->
            val payload = try {
                payloadFromMessage(ndef.ndefMessage ?: ndef.cachedNdefMessage)
            } catch (_: Exception) {
                null
            }
            if (request.matches(payload)) return payload
            if (attempt < 3) {
                try {
                    Thread.sleep(80L * (attempt + 1))
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return payload
                }
            }
        }

        if (request.matches(selectedPayload)) {
            Log.d(TAG, "Using selected NDEF payload after platform read-back cache lag.")
            return selectedPayload
        }
        return null
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

    private fun payloadFromMessage(message: NdefMessage?): String? {
        if (message == null) return null
        for (record in message.records) {
            val payload = payloadFromRecord(record)
            if (!payload.isNullOrBlank()) return payload
        }
        return null
    }

    private fun nativeNfcRecordLabel(record: NdefRecord): String {
        record.toMimeType()?.let { return "mime:$it" }
        record.toUri()?.let { return "uri" }
        return "tnf:${record.tnf}"
    }

    private fun nativeNfcTagStandard(tag: Tag): String {
        val techs = tag.techList.toSet()
        return when {
            techs.contains("android.nfc.tech.IsoDep") -> "ISO 14443-4"
            techs.contains("android.nfc.tech.NfcA") -> "ISO 14443-3 (Type A)"
            techs.contains("android.nfc.tech.NfcB") -> "ISO 14443-3 (Type B)"
            techs.contains("android.nfc.tech.NfcF") -> "ISO 18092"
            techs.contains("android.nfc.tech.NfcV") -> "ISO 15693"
            else -> "unknown"
        }
    }

    private fun nativeNfcTagType(tag: Tag): String {
        val techs = tag.techList.toSet()
        return when {
            techs.contains("android.nfc.tech.Ndef") -> "ndef"
            techs.contains("android.nfc.tech.NdefFormatable") -> "ndef_formatable"
            techs.contains("android.nfc.tech.IsoDep") -> "iso7816"
            techs.contains("android.nfc.tech.MifareUltralight") -> "mifare_ultralight"
            techs.contains("android.nfc.tech.MifareClassic") -> "mifare_classic"
            else -> "unknown"
        }
    }

    private fun ByteArray.toHex(): String {
        return joinToString(separator = "") { "%02X".format(it) }
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
        private const val BIOPAY_NFC_MIME_TYPE = "application/vnd.rw.mobi.biopay.nfc"
        private const val NFC_SELF_LAUNCH_SUPPRESSION_MS = 10_000L
        private const val NFC_POST_WRITE_READER_SETTLE_MS = 8_000L
        private const val NFC_TAG_IGNORE_DEBOUNCE_MS = 8_000L
        @Volatile private var suppressBioPayNfcLaunchUntilMs = 0L
    }

    private data class NativeNfcWriterRequest(
        val appLink: String,
        val jsonPayload: String,
        val mimeType: String,
        val packageName: String,
        val receiverType: String,
        val receiver: String,
        val lockOnly: Boolean,
    ) {
        val isValid: Boolean
            get() = appLink.isNotBlank() &&
                jsonPayload.isNotBlank() &&
                mimeType == BIOPAY_NFC_MIME_TYPE &&
                packageName.isNotBlank() &&
                receiverType.isNotBlank() &&
                receiver.isNotBlank()

        fun matches(rawPayload: String?): Boolean {
            val value = rawPayload?.trim()
            if (value.isNullOrBlank()) return false
            if (value == appLink || value == jsonPayload) return true
            return try {
                val uri = Uri.parse(value)
                val type = uri.getQueryParameter("type")
                val targetReceiver = uri.getQueryParameter("receiver")
                val biopayLink = (uri.scheme == "mobio" &&
                    uri.host == "biopay" &&
                    uri.path == "/nfc") ||
                    ((uri.scheme == "https" || uri.scheme == "http") &&
                        uri.host == "mobio.ikanisa.com" &&
                        uri.path == "/biopay/nfc")
                biopayLink && type == receiverType && targetReceiver == receiver
            } catch (_: Exception) {
                value.contains("\"receiver_type\":\"$receiverType\"") &&
                    value.contains("\"receiver\":\"$receiver\"")
            }
        }
    }

    private class NativeNfcWriterException(
        val code: String,
        override val message: String,
    ) : Exception(message)
}
