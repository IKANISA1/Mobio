package com.momobio.app

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    private val logTag = "MoMobioBridge"
    private val periwinkle = Color.rgb(136, 133, 240)
    private val mintGreen = Color.rgb(60, 208, 112)
    private val orangeRed = Color.rgb(255, 94, 67)
    private val primaryWhite = Color.WHITE
    private val neutralInk = Color.rgb(24, 17, 29)
    private val neutralPanel = Color.rgb(36, 25, 45)
    private val mutedText = Color.rgb(216, 207, 228)

    private lateinit var status: TextView
    private lateinit var upload: TextView
    private lateinit var enableButton: Button
    private lateinit var queue: SmsQueue
    @Volatile private var syncInFlight = false
    private val retryDelayMillis = 15_000L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        queue = SmsQueue(applicationContext)
        status = statusLine()
        upload = supportLine()
        enableButton = actionButton("Enable SMS access", periwinkle).apply {
            setOnClickListener { requestPermissions(requiredPermissions(), 7) }
        }

        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.TOP
                setPadding(dp(20), dp(72), dp(20), dp(28))
                setBackgroundColor(neutralInk)
                addView(brandLockup())
                addView(spacer(18))
                addView(panel())
                addView(spacer(18))
                addView(enableButton)
            },
        )
        BridgeSupervisor.schedule(applicationContext)
        BridgeSupervisor.start(applicationContext)
        if (!syncAutomatically()) {
            refreshStatus()
        }
    }

    override fun onResume() {
        super.onResume()
        BridgeSupervisor.start(applicationContext)
        requestBatteryOptimizationExemptionIfReady()
        if (syncInFlight) return
        if (!syncAutomatically()) {
            refreshStatus()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        BridgeSupervisor.start(applicationContext)
        requestBatteryOptimizationExemptionIfReady()
        if (syncInFlight) return
        if (!syncAutomatically()) {
            refreshStatus()
        }
    }

    private fun syncAutomatically(): Boolean {
        if (!hasSmsAccess() || syncInFlight) return false
        syncInFlight = true
        status.setTextColor(periwinkle)
        status.text = "Syncing"
        upload.text = "Queued: ${queue.count()}"
        Thread {
            val result = try {
                val messages = queue.all()
                var uploadedCount = 0
                runOnUiThread {
                    upload.text = "Queued: ${messages.size}"
                }
                UploadClient().upload(messages) { uploadedHashes ->
                    uploadedCount += uploadedHashes.size
                    queue.markUploaded(uploadedHashes)
                    runOnUiThread {
                        upload.text = "Uploaded $uploadedCount/${messages.size}\nQueued: ${queue.count()}"
                    }
                }
            } catch (error: Throwable) {
                Log.e(logTag, "SMS sync failed", error)
                UploadResult(
                    ok = false,
                    message = "${error.javaClass.simpleName}: ${error.message ?: "Sync failed"}",
                )
            } finally {
                syncInFlight = false
            }
            runOnUiThread {
                val remaining = queue.count()
                val fullySynced = result.ok && remaining == 0
                status.setTextColor(if (fullySynced) mintGreen else orangeRed)
                status.text = if (fullySynced) "Running" else "Upload error"
                upload.text = when {
                    fullySynced && result.message == "No new SMS" -> "No new SMS\nQueued: $remaining"
                    fullySynced -> "${result.message}\nQueued: $remaining"
                    result.ok -> "Pending sync\nQueued: $remaining"
                    else -> "${result.message}\nQueued: $remaining"
                }
                enableButton.visibility = View.GONE
                if (remaining > 0 && hasSmsAccess()) {
                    upload.postDelayed({ syncAutomatically() }, retryDelayMillis)
                }
            }
        }.start()
        return true
    }

    private fun refreshStatus() {
        val ready = hasSmsAccess()
        status.setTextColor(if (ready) mintGreen else orangeRed)
        status.text = if (ready) {
            if (queue.count() == 0) "Running" else "Upload error"
        } else {
            "Permission needed"
        }
        upload.text = "Queued: ${queue.count()}"
        enableButton.visibility = if (ready) View.GONE else View.VISIBLE
    }

    private fun hasSmsAccess(): Boolean =
        checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.POST_NOTIFICATIONS,
            )
        } else {
            arrayOf(Manifest.permission.RECEIVE_SMS)
        }

    private fun requestBatteryOptimizationExemptionIfReady() {
        if (!hasSmsAccess() || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val prefs = getSharedPreferences("momo_sms_bridge_runtime", MODE_PRIVATE)
        if (prefs.getBoolean("battery_optimization_request_shown", false)) return
        val powerManager = getSystemService(PowerManager::class.java)
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) return
        try {
            prefs.edit().putBoolean("battery_optimization_request_shown", true).apply()
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } catch (_: SecurityException) {
            Log.w(logTag, "Battery optimization exemption request was blocked")
        }
    }

    private fun brandLockup(): View =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            addView(ImageView(this@MainActivity).apply {
                setImageResource(R.drawable.mobio_logo_transparent)
                contentDescription = "Mo Mobio"
                adjustViewBounds = true
                scaleType = ImageView.ScaleType.FIT_START
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(56),
                )
            })
            addView(TextView(this@MainActivity).apply {
                text = "Mo Mobio"
                setTextColor(primaryWhite)
                textSize = 20f
                typeface = Typeface.DEFAULT_BOLD
                includeFontPadding = false
                setPadding(0, dp(8), 0, 0)
            })
        }

    private fun panel(): View =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(18))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            background = rounded(neutralPanel, dp(18), periwinkle, 1)
            addView(TextView(this@MainActivity).apply {
                text = "Status"
                setTextColor(mutedText)
                textSize = 13f
                includeFontPadding = false
            })
            addView(status)
            addView(spacer(10))
            addView(upload)
        }

    private fun statusLine(): TextView =
        TextView(this).apply {
            setTextColor(mintGreen)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            includeFontPadding = false
        }

    private fun supportLine(): TextView =
        TextView(this).apply {
            setTextColor(mutedText)
            textSize = 15f
            setLineSpacing(0f, 1.08f)
        }

    private fun actionButton(label: String, color: Int): Button =
        Button(this).apply {
            text = label
            setTextColor(primaryWhite)
            textSize = 15f
            isAllCaps = false
            typeface = Typeface.DEFAULT_BOLD
            minHeight = dp(52)
            background = rounded(color, dp(12))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56),
            )
        }

    private fun spacer(height: Int): View =
        View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(height))
        }

    private fun rounded(
        color: Int,
        radius: Int,
        strokeColor: Int? = null,
        strokeWidth: Int = 0,
    ): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius.toFloat()
            if (strokeColor != null && strokeWidth > 0) {
                setStroke(dp(strokeWidth), strokeColor)
            }
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
