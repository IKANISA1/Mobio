package rw.mobi.app

import android.content.Context
import android.view.View
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal class AccessibilityFocusChannel(
    private val activity: FlutterActivity,
    private val flutterEngine: FlutterEngine,
) {
    private var disposed = false
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "rw.mobi.app/accessibility_focus",
    )

    init {
        channel.setMethodCallHandler { call, result ->
            activity.runOnUiThread {
                if (call.method != "restoreFocus") {
                    result.notImplemented()
                    return@runOnUiThread
                }
                val nodeId = (call.arguments as? Map<*, *>)?.get("nodeId") as? Int
                result.success(
                    !disposed && nodeId != null && nodeId >= 0 && restoreFocus(nodeId),
                )
            }
        }
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
    }

    @Suppress("DEPRECATION") // Recycle provider snapshots on pre-API-33 Android.
    private fun restoreFocus(nodeId: Int): Boolean {
        try {
            if (activity.isFinishing || activity.isDestroyed) return false
            val view = activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
                ?: return false
            if (!view.isAttachedToWindow || !view.isAttachedToFlutterEngine ||
                view.attachedFlutterEngine !== flutterEngine ||
                view.visibility != View.VISIBLE || !view.isShown || !view.hasWindowFocus()
            ) return false

            val manager = activity.getSystemService(Context.ACCESSIBILITY_SERVICE)
                as? AccessibilityManager ?: return false
            if (!manager.isEnabled || !manager.isTouchExplorationEnabled) return false
            val provider = view.accessibilityNodeProvider ?: return false
            val target = provider.createAccessibilityNodeInfo(nodeId) ?: return false
            try {
                // The Dart caller also verifies its current owner route and live
                // trigger. Flutter's provider reports visibleToUser unconditionally.
                if (!target.isEnabled || !target.isFocusable || !target.isFocused) return false
                if (target.isAccessibilityFocused) return true
                val current = provider.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                if (current != null) {
                    current.recycle()
                    return false
                }
                if (!provider.performAction(
                        nodeId,
                        AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS,
                        null,
                    )
                ) return false

                val focusedTarget = provider.createAccessibilityNodeInfo(nodeId) ?: return false
                try {
                    return focusedTarget.isAccessibilityFocused
                } finally {
                    focusedTarget.recycle()
                }
            } finally {
                target.recycle()
            }
        } catch (_: IllegalStateException) {
            return false
        } catch (_: IllegalArgumentException) {
            return false
        } catch (_: SecurityException) {
            return false
        }
    }
}
