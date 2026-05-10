package com.example.float_clicker

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import android.widget.Toast

internal class MultiProfileExecutionOverlayManager(
    private val context: Context,
    private val onButtonPositionChanged: (String, OverlayPoint) -> Unit = { _, _ -> },
    private val onPanelStateChanged: (Boolean) -> Unit = {},
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val overlay = OverlayWindowHelper(context, windowManager)
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) {
                handleDisplayBoundsChanged()
            }
        }
    }
    private val displayBoundsRefreshRunnable = Runnable {
        if (!isShowing) {
            return@Runnable
        }

        if (!refreshOverlay()) {
            hide()
        }
    }
    private val buttonComponents = mutableMapOf<String, MultiProfileExecutionButtonComponent>()
    private val buttonPositions = mutableMapOf<String, OverlayPoint>()
    private val launcherComponent = MultiProfileExecutionLauncherComponent(
        context = context,
        overlayWindow = overlay,
        onClick = ::expandPanelFromLauncher,
    )
    private var taskStatus = MultiPointTaskStatus()
    private var runningProfileId: String? = null
    private var profiles = emptyList<LoadedMultiPointProfileState>()
    private var appearanceSettings = OverlayAppearanceSettings()
    private var metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    private var isDisplayListenerRegistered = false
    private var isPanelCollapsed = false

    var isShowing: Boolean = false
        private set

    fun show(
        loadedProfiles: List<LoadedMultiPointProfileState>,
        appearanceSettings: OverlayAppearanceSettings,
        isPanelCollapsed: Boolean,
    ): Boolean {
        profiles = normalizedProfiles(loadedProfiles)
        if (profiles.isEmpty()) {
            return false
        }
        this.appearanceSettings = appearanceSettings.normalized
        this.isPanelCollapsed = isPanelCollapsed
        metrics = OverlayComponentMetrics(overlay, this.appearanceSettings)
        isShowing = true
        if (!refreshOverlay()) {
            hide()
            return false
        }
        ensureDisplayListener()
        return true
    }

    fun update(
        loadedProfiles: List<LoadedMultiPointProfileState>,
        appearanceSettings: OverlayAppearanceSettings = this.appearanceSettings,
        isPanelCollapsed: Boolean = this.isPanelCollapsed,
    ): Boolean {
        val previousRunningProfileId = runningProfileId
        profiles = normalizedProfiles(loadedProfiles)
        this.appearanceSettings = appearanceSettings.normalized
        this.isPanelCollapsed = isPanelCollapsed
        metrics = OverlayComponentMetrics(overlay, this.appearanceSettings)
        if (
            previousRunningProfileId != null &&
            profiles.none { it.profileId == previousRunningProfileId }
        ) {
            endActiveTask("正在执行的配置已隐藏，任务已结束")
        }

        if (!isShowing) {
            return true
        }
        if (profiles.isEmpty()) {
            hide()
            return true
        }
        return refreshOverlay()
    }

    fun hide() {
        endActiveTask()
        isShowing = false
        isPanelCollapsed = false
        mainHandler.removeCallbacks(displayBoundsRefreshRunnable)
        removeButtonComponents()
        launcherComponent.remove()
        removeDisplayListener()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        if (isShowing && !refreshOverlay()) {
            hide()
        }
    }

    fun handleConfigurationChanged() {
        if (!isShowing) {
            return
        }

        handleDisplayBoundsChanged()
    }

    fun handleOverlayPermissionRevoked() {
        if (!isShowing) {
            return
        }

        hide()
        Toast.makeText(context.applicationContext, "悬浮窗权限已关闭，多配置执行控件已关闭", Toast.LENGTH_SHORT).show()
    }

    fun handleAccessibilityServiceDisconnected() {
        if (taskStatus.taskRunState == TaskRunState.IDLE) {
            return
        }

        endActiveTask("无障碍服务已断开，当前配置任务已结束")
    }

    private fun refreshButtons(): Boolean {
        launcherComponent.remove()
        val profileIds = profiles.map { it.profileId }.toSet()
        val removedIds = buttonComponents.keys - profileIds
        for (removedId in removedIds) {
            buttonComponents.remove(removedId)?.remove()
            buttonPositions.remove(removedId)
        }

        profiles.forEachIndexed { index, profile ->
            val position = coercedPositionFor(profile, index)
            buttonPositions[profile.profileId] = position
            val component = buttonComponents.getOrPut(profile.profileId) {
                MultiProfileExecutionButtonComponent(
                    context = context,
                    overlayWindow = overlay,
                    onPositionChanged = { point ->
                        buttonPositions[profile.profileId] = point
                        // P7.2.3 只在拖动结束时回传逻辑像素坐标，Flutter 负责持久化。
                        onButtonPositionChanged(profile.profileId, point)
                    },
                    onClick = {
                        handleButtonClick(profile.profileId)
                    },
                )
            }
            component.show(
                profile = profile,
                position = position,
                metrics = metrics,
                isRunning = runningProfileId == profile.profileId,
                isBlocked = runningProfileId != null && runningProfileId != profile.profileId,
            )
            if (!component.isShowing) {
                return false
            }
        }
        return true
    }

    private fun refreshOverlay(): Boolean {
        pruneRemovedProfiles()
        if (!isPanelCollapsed) {
            return refreshButtons()
        }

        // P7.3.1 收起态只保留一个固定位置恢复入口；拖动和持久化留到 P7.3.2。
        removeButtonComponents()
        val position = overlay.coercePositionPx(
            OverlayPoint(DEFAULT_START_X, DEFAULT_START_Y),
            widthPx = launcherSizePx(),
            heightPx = launcherSizePx(),
        )
        return launcherComponent.show(position = position, metrics = metrics)
    }

    private fun expandPanelFromLauncher() {
        isPanelCollapsed = false
        onPanelStateChanged(false)
        if (isShowing && !refreshOverlay()) {
            hide()
        }
    }

    private fun pruneRemovedProfiles() {
        val profileIds = profiles.map { it.profileId }.toSet()
        val removedIds = buttonComponents.keys - profileIds
        for (removedId in removedIds) {
            buttonComponents.remove(removedId)?.remove()
            buttonPositions.remove(removedId)
        }
        val removedPositionIds = buttonPositions.keys - profileIds
        for (removedId in removedPositionIds) {
            buttonPositions.remove(removedId)
        }
    }

    private fun removeButtonComponents() {
        buttonComponents.values.forEach { component -> component.remove() }
        buttonComponents.clear()
    }

    private fun handleButtonClick(profileId: String) {
        val activeProfileId = runningProfileId
        if (activeProfileId == profileId) {
            endActiveTask("配置任务已结束")
            return
        }
        if (activeProfileId != null) {
            Toast.makeText(context.applicationContext, "已有配置任务正在执行，请先停止当前任务", Toast.LENGTH_SHORT).show()
            return
        }

        val profile = profiles.firstOrNull { it.profileId == profileId }
        if (profile == null) {
            Toast.makeText(context.applicationContext, "配置已不存在，请刷新执行控件", Toast.LENGTH_SHORT).show()
            return
        }

        // 先登记 runningProfileId，因为调度器 start() 会同步回调 RUNNING 状态。
        runningProfileId = profile.profileId
        val result = MultiPointClickScheduler.start(
            request = profile.toClickTaskRequest(),
            targetPositionProvider = AutomationTargetPositionProvider { targetId ->
                targetCenterOnScreen(profile, targetId)
            },
            onStatusChanged = ::handleSchedulerStatusChanged,
        )
        if (result == MultiPointClickStartResult.STARTED) {
            refreshOverlay()
            return
        }

        runningProfileId = null
        taskStatus = MultiPointTaskStatus()
        refreshOverlay()
        showStartFailure(result)
    }

    private fun endActiveTask(message: String? = null) {
        val hadActiveTask = runningProfileId != null || taskStatus.taskRunState != TaskRunState.IDLE
        if (hadActiveTask) {
            MultiPointClickScheduler.end()
        }
        if (taskStatus.taskRunState != TaskRunState.IDLE || runningProfileId != null) {
            handleSchedulerStatusChanged(MultiPointTaskStatus())
        } else {
            runningProfileId = null
        }
        if (message != null && hadActiveTask) {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun handleSchedulerStatusChanged(status: MultiPointTaskStatus) {
        taskStatus = if (isShowing) status else MultiPointTaskStatus()
        if (taskStatus.taskRunState == TaskRunState.IDLE) {
            runningProfileId = null
        }
        if (isShowing && !refreshOverlay()) {
            hide()
        }
    }

    private fun showStartFailure(result: MultiPointClickStartResult) {
        val message = when (result) {
            MultiPointClickStartResult.NO_ENABLED_TARGETS -> "请至少启用 1 个点位后再执行"
            MultiPointClickStartResult.ACCESSIBILITY_SERVICE_UNAVAILABLE -> "无障碍服务未连接，无法执行配置任务"
            MultiPointClickStartResult.INVALID_TASK_STATE -> "已有多点任务正在执行，请先结束当前任务"
            MultiPointClickStartResult.STARTED -> return
        }
        Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
    }

    private fun targetCenterOnScreen(
        profile: LoadedMultiPointProfileState,
        targetId: String,
    ): AutomationTargetPosition? {
        val target = profile.targets.firstOrNull { it.id == targetId } ?: return null
        val position = overlay.coercePositionPx(
            OverlayPoint(target.x, target.y),
            widthPx = metrics.targetSizePx,
            heightPx = metrics.targetSizePx,
        )
        // profile 保存的是 Flutter 逻辑像素，dispatchGesture 需要真实屏幕像素。
        return AutomationTargetPosition(
            x = overlay.dp(position.x) + metrics.targetSizePx / 2f,
            y = overlay.dp(position.y) + metrics.targetSizePx / 2f,
        )
    }

    private fun coercedPositionFor(
        profile: LoadedMultiPointProfileState,
        index: Int,
    ): OverlayPoint {
        val fallback = defaultPosition(index)
        val currentPosition = buttonPositions[profile.profileId] ?: profile.buttonPosition ?: fallback
        return overlay.coercePositionPx(
            currentPosition,
            widthPx = executionButtonWidthPx(),
            heightPx = executionButtonHeightPx(),
        )
    }

    private fun defaultPosition(index: Int): OverlayPoint {
        return OverlayPoint(
            x = DEFAULT_START_X,
            y = DEFAULT_START_Y + index * DEFAULT_VERTICAL_GAP,
        )
    }

    private fun executionButtonWidthPx(): Int {
        return (metrics.actionButtonSizePx * 3.2f).toInt().coerceAtLeast(overlay.dp(112))
    }

    private fun executionButtonHeightPx(): Int {
        return metrics.actionButtonSizePx.coerceAtLeast(overlay.dp(42))
    }

    private fun launcherSizePx(): Int {
        return metrics.actionButtonSizePx.coerceAtLeast(overlay.dp(44))
    }

    private fun handleDisplayBoundsChanged() {
        mainHandler.removeCallbacks(displayBoundsRefreshRunnable)
        mainHandler.post(displayBoundsRefreshRunnable)
    }

    private fun ensureDisplayListener() {
        if (isDisplayListenerRegistered) {
            return
        }

        displayManager.registerDisplayListener(displayListener, mainHandler)
        isDisplayListenerRegistered = true
    }

    private fun removeDisplayListener() {
        if (!isDisplayListenerRegistered) {
            return
        }

        displayManager.unregisterDisplayListener(displayListener)
        isDisplayListenerRegistered = false
    }

    private fun normalizedProfiles(
        loadedProfiles: List<LoadedMultiPointProfileState>,
    ): List<LoadedMultiPointProfileState> {
        return loadedProfiles
            .filter { it.profileId.isNotBlank() && it.displayName.isNotBlank() }
            .distinctBy { it.profileId }
            .sortedWith(compareBy<LoadedMultiPointProfileState> { it.order }.thenBy { it.profileId })
            .mapIndexed { index, profile -> profile.copy(order = index + 1) }
    }

    private companion object {
        const val DEFAULT_START_X = 18
        const val DEFAULT_START_Y = 260
        const val DEFAULT_VERTICAL_GAP = 56
    }
}
