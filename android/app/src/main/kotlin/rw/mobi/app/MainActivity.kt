package rw.mobi.app

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
}
