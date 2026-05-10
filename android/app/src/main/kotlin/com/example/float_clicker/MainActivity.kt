package com.example.float_clicker

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
    private lateinit var multiPointOverlayManager: MultiPointOverlayManager
    private lateinit var multiProfileExecutionOverlayManager: MultiProfileExecutionOverlayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val overlayPermissionCheckRunnable = object : Runnable {
        override fun run() {
            if (::singlePointOverlayManager.isInitialized && singlePointOverlayManager.isShowing && !canDrawOverlays()) {
                singlePointOverlayManager.handleOverlayPermissionRevoked()
                if (::channel.isInitialized) {
                    channel.invokeMethod("permissionSnapshotChanged", getPermissionSnapshot())
                }
            }
            if (::multiPointOverlayManager.isInitialized && multiPointOverlayManager.isShowing && !canDrawOverlays()) {
                multiPointOverlayManager.handleOverlayPermissionRevoked()
                if (::channel.isInitialized) {
                    channel.invokeMethod("permissionSnapshotChanged", getPermissionSnapshot())
                }
            }
            if (
                ::multiProfileExecutionOverlayManager.isInitialized &&
                multiProfileExecutionOverlayManager.isShowing &&
                !canDrawOverlays()
            ) {
                multiProfileExecutionOverlayManager.handleOverlayPermissionRevoked()
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
        if (!isConnected && ::multiPointOverlayManager.isInitialized) {
            multiPointOverlayManager.handleAccessibilityServiceDisconnected()
        }
        if (!isConnected && ::multiProfileExecutionOverlayManager.isInitialized) {
            multiProfileExecutionOverlayManager.handleAccessibilityServiceDisconnected()
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
        multiPointOverlayManager = MultiPointOverlayManager(
            context = this,
            onOverlayStateChanged = { snapshot ->
                channel.invokeMethod(
                    "multiPointOverlayStateChanged",
                    snapshot.toMap(),
                )
            },
            onTargetPositionChanged = { targetId, point ->
                // P3.5 只回传坐标变化，不触发真实点击；点击中心点换算留给 P4 调度。
                channel.invokeMethod(
                    "onMultiPointTargetPositionChanged",
                    mapOf(
                        "id" to targetId,
                        "x" to point.x,
                        "y" to point.y,
                    ),
                )
            },
        )
        multiProfileExecutionOverlayManager = MultiProfileExecutionOverlayManager(
            context = this,
            onButtonPositionChanged = { profileId, point ->
                channel.invokeMethod(
                    "onLoadedProfileButtonPositionChanged",
                    mapOf(
                        "profileId" to profileId,
                        "x" to point.x,
                        "y" to point.y,
                    ),
                )
            },
            onPanelStateChanged = { isPanelCollapsed ->
                channel.invokeMethod(
                    "onMultiProfileExecutionPanelStateChanged",
                    mapOf("isPanelCollapsed" to isPanelCollapsed),
                )
            },
            onLauncherPositionChanged = { point ->
                channel.invokeMethod(
                    "onMultiProfileExecutionLauncherPositionChanged",
                    mapOf(
                        "x" to point.x,
                        "y" to point.y,
                    ),
                )
            },
        )

        // Flutter 侧只负责页面和配置；所有需要 Android 系统能力的操作都从这个通道进入。
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionSnapshot" -> result.success(getPermissionSnapshot())
                "getSinglePointOverlaySnapshot" -> {
                    result.success(singlePointOverlayManager.snapshot.toMap())
                }
                "getMultiPointOverlaySnapshot" -> {
                    result.success(multiPointOverlayManager.snapshot.toMap())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                "sendAppToBackground" -> {
                    // 主页返回键只把 App 退到后台，悬浮窗生命周期继续交给“关闭模式”和权限异常收尾控制。
                    moveTaskToBack(true)
                    result.success(null)
                }
                "showSinglePointOverlay" -> {
                    // 悬浮窗权限必须在创建 WindowManager overlay 前确认，否则 addView 会失败。
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_denied", "悬浮窗权限未开启，请先在系统设置中允许显示在其他应用上层。", null)
                        return@setMethodCallHandler
                    }
                    if (multiPointOverlayManager.isShowing) {
                        result.error("mode_conflict", "多点模式已开启，请先关闭多点模式。", null)
                        return@setMethodCallHandler
                    }
                    if (multiProfileExecutionOverlayManager.isShowing) {
                        result.error("mode_conflict", "多配置执行控件已开启，请先关闭执行控件。", null)
                        return@setMethodCallHandler
                    }
                    val shown = singlePointOverlayManager.show(singlePointOverlaySettingsFrom(call.arguments))
                    if (shown) {
                        result.success(null)
                    } else {
                        result.error("overlay_window_unavailable", "悬浮窗创建失败，请确认悬浮窗权限仍然可用后重试。", null)
                    }
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
                    multiPointOverlayManager.updateAppearanceSettings(overlayAppearanceSettingsFrom(call.arguments))
                    multiProfileExecutionOverlayManager.updateAppearanceSettings(overlayAppearanceSettingsFrom(call.arguments))
                    result.success(null)
                }
                "showMultiPointOverlay" -> {
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_denied", "悬浮窗权限未开启，请先在系统设置中允许显示在其他应用上层。", null)
                        return@setMethodCallHandler
                    }
                    if (singlePointOverlayManager.isShowing) {
                        result.error("mode_conflict", "单点模式已开启，请先关闭单点模式。", null)
                        return@setMethodCallHandler
                    }
                    if (multiProfileExecutionOverlayManager.isShowing) {
                        result.error("mode_conflict", "多配置执行控件已开启，请先关闭执行控件。", null)
                        return@setMethodCallHandler
                    }
                    val shown = multiPointOverlayManager.show(multiPointOverlaySettingsFrom(call.arguments))
                    if (shown) {
                        result.success(null)
                    } else {
                        result.error("overlay_window_unavailable", "多点悬浮窗创建失败，请确认悬浮窗权限仍然可用后重试。", null)
                    }
                }
                "hideMultiPointOverlay" -> {
                    multiPointOverlayManager.hide()
                    result.success(null)
                }
                "updateMultiPointTargets" -> {
                    multiPointOverlayManager.updateTargets(multiPointTargetsFrom(call.arguments))
                    result.success(null)
                }
                "updateMultiPointSettings" -> {
                    multiPointOverlayManager.updateClickSettings(multiPointOverlaySettingsFrom(call.arguments))
                    result.success(null)
                }
                "updateMultiPointOverlayUiSettings" -> {
                    multiPointOverlayManager.updateOverlayUiState(multiPointOverlayUiStateFrom(call.arguments))
                    result.success(null)
                }
                "startMultiPointClicking" -> {
                    when (multiPointOverlayManager.start()) {
                        MultiPointClickStartResult.STARTED -> result.success(null)
                        MultiPointClickStartResult.NO_ENABLED_TARGETS -> result.error(
                            "no_enabled_targets",
                            "请至少启用 1 个点位后再执行。",
                            null,
                        )
                        MultiPointClickStartResult.ACCESSIBILITY_SERVICE_UNAVAILABLE -> result.error(
                            "accessibility_service_unavailable",
                            "无障碍服务未连接，请先在系统设置中开启 Float Clicker 无障碍服务。",
                            null,
                        )
                        MultiPointClickStartResult.INVALID_TASK_STATE -> result.error(
                            "invalid_task_state",
                            "当前多点任务状态不支持开始执行。",
                            null,
                        )
                    }
                }
                "pauseMultiPointClicking" -> {
                    val paused = multiPointOverlayManager.pause()
                    if (paused) {
                        result.success(null)
                    } else {
                        result.error("invalid_task_state", "当前没有正在执行的多点任务，无法暂停。", null)
                    }
                }
                "resumeMultiPointClicking" -> {
                    when (multiPointOverlayManager.resume()) {
                        MultiPointClickResumeResult.RESUMED,
                        MultiPointClickResumeResult.FINISHED -> result.success(null)
                        MultiPointClickResumeResult.NO_ENABLED_TARGETS -> result.error(
                            "no_enabled_targets",
                            "请至少启用 1 个点位后再继续。",
                            null,
                        )
                        MultiPointClickResumeResult.ACCESSIBILITY_SERVICE_UNAVAILABLE -> result.error(
                            "accessibility_service_unavailable",
                            "无障碍服务未连接，请先在系统设置中开启 Float Clicker 无障碍服务。",
                            null,
                        )
                        MultiPointClickResumeResult.INVALID_TASK_STATE -> result.error(
                            "invalid_task_state",
                            "当前多点任务状态不支持继续执行。",
                            null,
                        )
                    }
                }
                "endMultiPointClicking" -> {
                    multiPointOverlayManager.end()
                    result.success(null)
                }
                "showMultiProfileExecutionOverlay" -> {
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission_denied", "悬浮窗权限未开启，请先在系统设置中允许显示在其他应用上层。", null)
                        return@setMethodCallHandler
                    }
                    if (singlePointOverlayManager.isShowing || multiPointOverlayManager.isShowing) {
                        // P7.2.1 只验证多配置执行控件展示；先和已有编辑悬浮层互斥，避免两个体系同时抢控制权。
                        result.error("mode_conflict", "请先关闭当前悬浮模式，再开启多配置执行控件。", null)
                        return@setMethodCallHandler
                    }
                    val shown = multiProfileExecutionOverlayManager.show(
                        loadedProfiles = loadedMultiPointProfilesFrom(call.arguments),
                        appearanceSettings = overlayAppearanceSettingsFrom(call.arguments),
                        isPanelCollapsed = multiProfileExecutionPanelCollapsedFrom(call.arguments),
                        launcherPosition = multiProfileExecutionLauncherPositionFrom(call.arguments),
                    )
                    if (shown) {
                        result.success(null)
                    } else {
                        result.error("profile_empty", "没有可显示的已加载配置。", null)
                    }
                }
                "updateMultiProfileExecutionOverlay" -> {
                    val updated = multiProfileExecutionOverlayManager.update(
                        loadedProfiles = loadedMultiPointProfilesFrom(call.arguments),
                        appearanceSettings = overlayAppearanceSettingsFrom(call.arguments),
                        isPanelCollapsed = multiProfileExecutionPanelCollapsedFrom(call.arguments),
                        launcherPosition = multiProfileExecutionLauncherPositionFrom(call.arguments),
                    )
                    if (updated) {
                        result.success(null)
                    } else {
                        result.error("overlay_window_unavailable", "多配置执行控件刷新失败，请关闭后重试。", null)
                    }
                }
                "hideMultiProfileExecutionOverlay" -> {
                    multiProfileExecutionOverlayManager.hide()
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
        if (::multiPointOverlayManager.isInitialized) {
            multiPointOverlayManager.hide()
        }
        if (::multiProfileExecutionOverlayManager.isInitialized) {
            multiProfileExecutionOverlayManager.hide()
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
        if (::multiPointOverlayManager.isInitialized) {
            multiPointOverlayManager.handleConfigurationChanged()
        }
        if (::multiProfileExecutionOverlayManager.isInitialized) {
            multiProfileExecutionOverlayManager.handleConfigurationChanged()
        }
    }

    private fun getPermissionSnapshot(): Map<String, Boolean> {
        return mapOf(
            "accessibilityGranted" to AccessibilityServiceStateHelper.isAccessibilityServiceEnabled(this),
            "accessibilityConnected" to AccessibilityServiceStateHelper.isAccessibilityServiceConnected(),
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

    private fun multiPointOverlaySettingsFrom(arguments: Any?): MultiPointOverlaySettings {
        val map = arguments as? Map<*, *> ?: return MultiPointOverlaySettings()
        // P3 只使用 Overlay 和点位字段；点击参数先保存进设置结构，真实调度留给 P4。
        return MultiPointOverlaySettings(
            intervalMs = (map["intervalMs"] as? Number)?.toInt() ?: 500,
            repeatCount = (map["repeatCount"] as? Number)?.toInt() ?: 10,
            infiniteLoop = map["infiniteLoop"] as? Boolean ?: false,
            tapDurationMs = (map["tapDurationMs"] as? Number)?.toInt() ?: 50,
            targets = multiPointTargetsFrom(arguments),
            overlayUiState = multiPointOverlayUiStateFrom(arguments),
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

    private fun multiPointOverlayUiStateFrom(arguments: Any?): MultiPointOverlayUiState {
        val map = arguments as? Map<*, *> ?: return MultiPointOverlayUiState()
        return MultiPointOverlayUiState(
            interactionMode = OverlayInteractionMode.fromWireName(map["interactionMode"] as? String),
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

    private fun multiPointTargetsFrom(arguments: Any?): List<MultiPointTargetState> {
        val map = arguments as? Map<*, *> ?: return defaultMultiPointTargets()
        val rawTargets = map["targets"] as? List<*> ?: return defaultMultiPointTargets()
        val parsedTargets = rawTargets.mapIndexedNotNull { index, value ->
            MultiPointTargetState.fromMap(value, fallbackOrder = index + 1)
        }
        return parsedTargets.ifEmpty { defaultMultiPointTargets() }
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

    private fun canDrawOverlays(): Boolean {
        return Settings.canDrawOverlays(this)
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    companion object {
        private const val overlayPermissionCheckIntervalMs = 1_000L
    }
}
