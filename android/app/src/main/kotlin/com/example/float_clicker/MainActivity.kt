package com.example.float_clicker

import android.content.ComponentName
import android.content.res.Configuration
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "float_clicker/android_permissions"
    private lateinit var channel: MethodChannel
    private lateinit var singlePointOverlayManager: SinglePointOverlayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val overlayPermissionCheckRunnable = object : Runnable {
        override fun run() {
            if (::singlePointOverlayManager.isInitialized && singlePointOverlayManager.isShowing && !canDrawOverlays()) {
                singlePointOverlayManager.handleOverlayPermissionRevoked()
                if (::channel.isInitialized) {
                    channel.invokeMethod("permissionSnapshotChanged", getPermissionSnapshot())
                }
            }
            mainHandler.postDelayed(this, overlayPermissionCheckIntervalMs)
        }
    }
    private val accessibilityConnectionListener: (Boolean) -> Unit = { isConnected ->
        if (::channel.isInitialized) {
            channel.invokeMethod(
                "permissionSnapshotChanged",
                getPermissionSnapshot(),
            )
        }
        if (!isConnected && ::singlePointOverlayManager.isInitialized) {
            singlePointOverlayManager.handleAccessibilityServiceDisconnected()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        singlePointOverlayManager = SinglePointOverlayManager(this) { snapshot ->
            channel.invokeMethod(
                "singlePointOverlayStateChanged",
                snapshot.toMap(),
            )
        }

        // Flutter 侧只负责页面和配置；所有需要 Android 系统能力的操作都从这个通道进入。
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionSnapshot" -> result.success(getPermissionSnapshot())
                "getSinglePointOverlaySnapshot" -> {
                    result.success(singlePointOverlayManager.snapshot.toMap())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "showSinglePointOverlay" -> {
                    // 悬浮窗权限必须在创建 WindowManager overlay 前确认，否则 addView 会失败。
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_denied", "悬浮窗权限未开启，请先在系统设置中允许显示在其他应用上层。", null)
                        return@setMethodCallHandler
                    }
                    singlePointOverlayManager.show(singlePointOverlaySettingsFrom(call.arguments))
                    result.success(null)
                }
                "updateSinglePointSettings" -> {
                    singlePointOverlayManager.updateClickSettings(singlePointOverlaySettingsFrom(call.arguments))
                    result.success(null)
                }
                "hideSinglePointOverlay" -> {
                    singlePointOverlayManager.hide()
                    result.success(null)
                }
                "startSinglePointClicking" -> {
                    // start() 会继续检查无障碍服务实例；服务未连接时返回 false 给 Flutter 提示用户。
                    val started = singlePointOverlayManager.start()
                    if (started) {
                        result.success(null)
                    } else {
                        result.error("accessibility_service_unavailable", "无障碍服务未连接，请先在系统设置中开启 Float Clicker 无障碍服务。", null)
                    }
                }
                "stopSinglePointClicking" -> {
                    singlePointOverlayManager.stop()
                    result.success(null)
                }
                "pauseSinglePointClicking" -> {
                    val paused = singlePointOverlayManager.pause()
                    if (paused) {
                        result.success(null)
                    } else {
                        result.error("invalid_task_state", "当前没有正在执行的点击任务，无法暂停。", null)
                    }
                }
                "resumeSinglePointClicking" -> {
                    val resumed = singlePointOverlayManager.resume()
                    if (resumed) {
                        result.success(null)
                    } else {
                        result.error(
                            "accessibility_service_unavailable",
                            "无障碍服务未连接，或当前任务不是暂停状态，无法继续点击。",
                            null,
                        )
                    }
                }
                "endSinglePointClicking" -> {
                    singlePointOverlayManager.end()
                    result.success(null)
                }
                "updateSinglePointOverlayUiSettings" -> {
                    singlePointOverlayManager.updateInteractionState(overlayInteractionStateFrom(call.arguments))
                    result.success(null)
                }
                "updateGlobalOverlayAppearanceSettings" -> {
                    singlePointOverlayManager.updateAppearanceSettings(overlayAppearanceSettingsFrom(call.arguments))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        AccessibilityServiceStateBus.addListener(accessibilityConnectionListener)
        mainHandler.postDelayed(overlayPermissionCheckRunnable, overlayPermissionCheckIntervalMs)
    }

    override fun onDestroy() {
        if (::singlePointOverlayManager.isInitialized) {
            singlePointOverlayManager.hide()
        }
        mainHandler.removeCallbacks(overlayPermissionCheckRunnable)
        AccessibilityServiceStateBus.removeListener(accessibilityConnectionListener)
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (::singlePointOverlayManager.isInitialized) {
            singlePointOverlayManager.handleConfigurationChanged()
        }
    }

    private fun getPermissionSnapshot(): Map<String, Boolean> {
        return mapOf(
            "accessibilityGranted" to isAccessibilityServiceEnabled(),
            "accessibilityConnected" to (FloatClickerAccessibilityService.instance != null),
            "overlayGranted" to canDrawOverlays(),
        )
    }

    private fun singlePointOverlaySettingsFrom(arguments: Any?): SinglePointOverlaySettings {
        val map = arguments as? Map<*, *> ?: return SinglePointOverlaySettings()
        // Flutter 传参不可信，原生侧仍保留默认值，避免缺字段时崩溃。
        return SinglePointOverlaySettings(
            intervalMs = (map["intervalMs"] as? Number)?.toInt() ?: 500,
            repeatCount = (map["repeatCount"] as? Number)?.toInt() ?: 10,
            infiniteLoop = map["infiniteLoop"] as? Boolean ?: false,
            tapDurationMs = (map["tapDurationMs"] as? Number)?.toInt() ?: 50,
            interactionState = overlayInteractionStateFrom(arguments),
            appearanceSettings = overlayAppearanceSettingsFrom(arguments),
        )
    }

    private fun overlayAppearanceSettingsFrom(arguments: Any?): OverlayAppearanceSettings {
        val map = arguments as? Map<*, *> ?: return OverlayAppearanceSettings()
        val legacyScale = (map["overlayControlScale"] as? Number)?.toFloat()
            ?: OverlayAppearanceSettings.DEFAULT_SCALE
        // overlayControlScale 是旧协议的单比例字段；新协议缺某个分项时仍用它补齐，避免版本交错时尺寸回到默认值。
        return OverlayAppearanceSettings(
            targetPointScale = (map["targetPointScale"] as? Number)?.toFloat() ?: legacyScale,
            toolbarScale = (map["toolbarScale"] as? Number)?.toFloat() ?: legacyScale,
            actionButtonScale = (map["actionButtonScale"] as? Number)?.toFloat() ?: legacyScale,
        ).normalized
    }

    private fun overlayInteractionStateFrom(arguments: Any?): OverlayInteractionState {
        val map = arguments as? Map<*, *> ?: return OverlayInteractionState()
        return OverlayInteractionState(
            interactionMode = OverlayInteractionMode.fromWireName(map["interactionMode"] as? String),
            targetPosition = overlayPointFrom(map, "targetPositionX", "targetPositionY", OverlayPoint(280, 260)),
            toolbarPosition = overlayPointFrom(map, "toolbarPositionX", "toolbarPositionY", OverlayPoint(18, 180)),
            collapsedToolbarPosition = overlayPointFrom(
                map,
                "collapsedToolbarPositionX",
                "collapsedToolbarPositionY",
                OverlayPoint(18, 180),
            ),
            actionButtonPosition = overlayPointFrom(
                map,
                "actionButtonPositionX",
                "actionButtonPositionY",
                OverlayPoint(18, 260),
            ),
            isToolbarCollapsed = map["isToolbarCollapsed"] as? Boolean ?: false,
        )
    }

    private fun overlayPointFrom(
        map: Map<*, *>,
        xKey: String,
        yKey: String,
        fallback: OverlayPoint,
    ): OverlayPoint {
        return OverlayPoint(
            x = (map[xKey] as? Number)?.toInt() ?: fallback.x,
            y = (map[yKey] as? Number)?.toInt() ?: fallback.y,
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

    companion object {
        private const val overlayPermissionCheckIntervalMs = 1_000L
    }
}
