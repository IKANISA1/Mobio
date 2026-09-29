package com.momobio.app

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.ClipData
import android.content.ClipboardManager
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
    private val queue: DurableSmsQueue get() = DurableSmsQueue(applicationContext)
    @Volatile private var syncInFlight = false
    private val retryDelayMillis = 15_000L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        status = statusLine()
        upload = supportLine()
        enableButton = actionButton("Enable SMS access", periwinkle).apply {
            setOnClickListener { showCollectionNotice() }
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
                addView(spacer(12))
                addView(actionButton("Pause collection", neutralPanel).apply {
                    setOnClickListener {
                        try {
                            CollectorRuntime.revokeNotice(applicationContext)
                            BridgeSupervisor.stop(applicationContext)
                            refreshStatus()
                        } catch (_: Exception) {
                            upload.text = "Could not save the pause. Revoke SMS permission in Android settings."
                        }
                    }
                })
                addView(spacer(12))
                addView(actionButton("Copy enrollment request", neutralPanel).apply {
                    setOnClickListener {
                        val enrollment = CollectorIdentity(applicationContext).enrollmentRequest()
                        getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("Mo Mobio enrollment", enrollment))
                        upload.text = "Public enrollment request copied. Ask your administrator to register this phone."
                    }
                })
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
        if (isFinishing || isDestroyed || !CollectorRuntime.ready(applicationContext) || syncInFlight) return false
        syncInFlight = true
        status.setTextColor(periwinkle)
        status.text = "Syncing"
        upload.text = "Checking stored receipts…"
        Thread {
            val result = try {
                CollectorSync.run(applicationContext)
            } catch (error: Exception) {
                Log.e(logTag, "SMS sync failed: ${error.javaClass.simpleName}")
                UploadResult(false, message = "Queue or sync unavailable; receipts need review", outcome = "storage_error")
            } finally {
                syncInFlight = false
            }
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                refreshStatus(if (!result.ok && result.outcome !in setOf("busy", "backoff")) result.message else null)
                if (CollectorRuntime.ready(applicationContext)) {
                    upload.postDelayed({ syncAutomatically() }, retryDelayMillis)
                }
            }
        }.start()
        return true
    }

    private fun showCollectionNotice() {
        if (!CollectorRuntime.policy.configured) {
            upload.text = "An administrator must supply the approved sender and receipt-format configuration."
            return
        }
        AlertDialog.Builder(this)
            .setTitle("Institutional receipt collection")
            .setMessage("Use a dedicated institutional phone and SIM, not a personal inbox. " +
                "Only new notifications from configured senders matching the approved receipt markers are stored. " +
                "Eligible message bodies, sender, receipt time and a deduplication hash are sent to Mobio's Supabase backend; " +
                "the backend uses OpenAI to extract receipt fields. The server decides allocation. " +
                "Acknowledged local bodies are removed. Unresolved receipts are retained locally for review; " +
                "after 30 days they stop automatic upload. Contact the designated fleet administrator for review or deletion. " +
                "Revoking SMS permission stops further collection. Do not enable on a personal SIM.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Enable on institutional device") { _, _ ->
                try {
                    CollectorRuntime.acceptNotice(applicationContext)
                    requestPermissions(requiredPermissions(), 7)
                } catch (_: Exception) {
                    upload.text = "The notice decision could not be saved. Collection remains disabled."
                }
            }.show()
    }

    @Volatile private var refreshInFlight = false
    private fun refreshStatus(syncError: String? = null) {
        if (isFinishing || isDestroyed || refreshInFlight) return
        refreshInFlight = true
        Thread {
            try {
                val storage = queue
                val health = storage.health()
                val lastServer = storage.serverAcknowledgedAt()
                val allocation = storage.automaticAllocationEnabled()
                val state = when {
                    !CollectorRuntime.policy.configured -> "Configuration needed"
                    !CollectorRuntime.consented(applicationContext) -> "Notice required"
                    !hasSmsAccess() -> "Permission needed"
                    health.unreconciledRefusals > 0 || health.capacityBlocked > 0 -> "Receipt reconciliation required"
                    health.overflowPending > 0 -> "Overflow receipts queued"
                    health.capacityWarning -> "Queue capacity warning"
                    health.quarantined > 0 -> "Receipts need review"
                    syncError != null -> "Sync unavailable"
                    health.lastError != null -> "Sync pending"
                    lastServer == 0L -> "Server enrollment not verified"
                    health.pending > 0 -> "Sync pending"
                    System.currentTimeMillis() - lastServer !in 0..15L * 60 * 1000 -> "Server verification expired"
                    else -> "Server acknowledged"
                }
                runOnUiThread {
                    if (isFinishing || isDestroyed) return@runOnUiThread
                    status.text = state
                    status.setTextColor(if (state == "Server acknowledged") mintGreen else orangeRed)
                    upload.text = (syncError?.let { it + "\n" } ?: "") + "Allocation policy: ${when (allocation) { true -> "enabled"; false -> "disabled"; else -> "not verified" }}\n" +
                        "Queued: ${health.pending}; overflow: ${health.overflowPending}; review: ${health.quarantined}; " +
                        "refusals: ${health.unreconciledRefusals}; historical blocks: ${health.capacityBlocked}\n" +
                        "Oldest pending: ${health.oldestPendingAt?.let { java.util.Date(it).toString() } ?: "none"}\n" +
                        "Last server acknowledgment: ${lastServer.takeIf { it > 0 }?.let { java.util.Date(it).toString() } ?: "not observed"}"
                    enableButton.visibility = if (CollectorRuntime.ready(applicationContext)) View.GONE else View.VISIBLE
                }
            } catch (_: Exception) {
                runOnUiThread {
                    if (!isFinishing && !isDestroyed) {
                        status.text = "Stored receipts need recovery"
                        upload.text = "Do not clear app data or reinstall. Contact the fleet administrator."
                        status.setTextColor(orangeRed)
                    }
                }
            } finally { refreshInFlight = false }
        }.start()
    }

    override fun onDestroy() {
        // Delayed callbacks check isDestroyed before doing work.
        super.onDestroy()
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
