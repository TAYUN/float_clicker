package com.example.float_clicker

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "float_clicker/android_permissions"
    private lateinit var singlePointOverlayManager: SinglePointOverlayManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        singlePointOverlayManager = SinglePointOverlayManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionSnapshot" -> result.success(getPermissionSnapshot())
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "showSinglePointOverlay" -> {
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_denied", "Overlay permission is not granted.", null)
                        return@setMethodCallHandler
                    }
                    singlePointOverlayManager.show(singlePointOverlaySettingsFrom(call.arguments))
                    result.success(null)
                }
                "updateSinglePointSettings" -> {
                    singlePointOverlayManager.updateSettings(singlePointOverlaySettingsFrom(call.arguments))
                    result.success(null)
                }
                "hideSinglePointOverlay" -> {
                    singlePointOverlayManager.hide()
                    result.success(null)
                }
                "startSinglePointClicking" -> {
                    val started = singlePointOverlayManager.start()
                    if (started) {
                        result.success(null)
                    } else {
                        result.error("accessibility_service_unavailable", "Accessibility service is not running.", null)
                    }
                }
                "stopSinglePointClicking" -> {
                    singlePointOverlayManager.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (::singlePointOverlayManager.isInitialized) {
            singlePointOverlayManager.hide()
        }
        super.onDestroy()
    }

    private fun getPermissionSnapshot(): Map<String, Boolean> {
        return mapOf(
            "accessibilityGranted" to isAccessibilityServiceEnabled(),
            "overlayGranted" to canDrawOverlays(),
        )
    }

    private fun singlePointOverlaySettingsFrom(arguments: Any?): SinglePointOverlaySettings {
        val map = arguments as? Map<*, *> ?: return SinglePointOverlaySettings()
        return SinglePointOverlaySettings(
            intervalMs = (map["intervalMs"] as? Number)?.toInt() ?: 500,
            repeatCount = (map["repeatCount"] as? Number)?.toInt() ?: 10,
            infiniteLoop = map["infiniteLoop"] as? Boolean ?: false,
            tapDurationMs = (map["tapDurationMs"] as? Number)?.toInt() ?: 50,
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = ComponentName(this, FloatClickerAccessibilityService::class.java)
            .flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        // 系统保存的是冒号分隔的服务列表，逐项比较能避免包名局部匹配造成误判。
        return enabledServices.split(':').any { serviceName ->
            serviceName.equals(expectedService, ignoreCase = true)
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        }
    }
}
