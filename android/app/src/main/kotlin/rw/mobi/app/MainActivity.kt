package rw.mobi.app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
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
}
