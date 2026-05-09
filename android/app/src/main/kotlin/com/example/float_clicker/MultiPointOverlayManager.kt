package com.example.float_clicker

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import android.widget.Toast

internal class MultiPointOverlayManager(
    private val context: Context,
    private val onOverlayStateChanged: (MultiPointOverlaySnapshot) -> Unit = {},
    private val onTargetPositionChanged: (String, OverlayPoint) -> Unit = { _, _ -> },
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
        if (!isModeEnabled) {
            return@Runnable
        }

        if (!refreshTargetComponents() || !refreshInteractionViews()) {
            hide()
            return@Runnable
        }
        notifyOverlayStateChanged()
    }
    private val targetComponents = mutableMapOf<String, MultiPointTargetOverlayComponent>()
    private val toolbarComponent = ToolbarOverlayComponent(
        context = context,
        overlayWindow = overlay,
        onPositionChanged = { point ->
            overlayUiState = overlayUiState.copy(toolbarPosition = point)
            notifyOverlayStateChanged()
        },
        onTaskAction = ::toggleTaskRunState,
        onEndTask = ::endFromToolbar,
        onClose = ::hide,
        onCollapse = ::collapseToolbar,
        closeContentDescription = "关闭多点模式",
    )
    private val collapsedToolbarComponent = CollapsedToolbarComponent(
        overlayWindow = overlay,
        onPositionChanged = { point ->
            overlayUiState = overlayUiState.copy(collapsedToolbarPosition = point)
            notifyOverlayStateChanged()
        },
        onExpand = ::expandToolbar,
    )
    private val actionButtonComponent = ActionButtonOverlayComponent(
        context = context,
        overlayWindow = overlay,
        onPositionChanged = { point ->
            overlayUiState = overlayUiState.copy(actionButtonPosition = point)
            notifyOverlayStateChanged()
        },
        onTaskAction = ::toggleTaskRunState,
        onEndTask = ::endFromActionButton,
    )

    private var taskStatus = MultiPointTaskStatus()
    private var overlayUiState = MultiPointOverlayUiState()
    private var appearanceSettings = OverlayAppearanceSettings()
    private var metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    private var targets = defaultMultiPointTargets()
    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var tapDurationMs = 50
    private var isModeEnabled = false
    private var isDisplayListenerRegistered = false

    val isShowing: Boolean
        get() = isModeEnabled

    val snapshot: MultiPointOverlaySnapshot
        get() = MultiPointOverlaySnapshot(
            modeEnabled = isModeEnabled,
            taskRunState = if (isModeEnabled) taskStatus.taskRunState else TaskRunState.IDLE,
            completedRounds = if (isModeEnabled) taskStatus.completedRounds else 0,
            currentRound = if (isModeEnabled) taskStatus.currentRound else 0,
            executedActionCountInCurrentRound = if (isModeEnabled) {
                taskStatus.executedActionCountInCurrentRound
            } else {
                0
            },
            currentTargetId = if (isModeEnabled) taskStatus.currentTargetId else null,
            targets = targets,
            overlayUiState = if (isModeEnabled) overlayUiState else null,
        )

    fun show(settings: MultiPointOverlaySettings = MultiPointOverlaySettings()): Boolean {
        applySettings(settings)
        coerceOverlayStateToScreen()
        isModeEnabled = true
        val targetsReady = refreshTargetComponents()
        val interactionReady = refreshInteractionViews()
        if (!targetsReady || !interactionReady) {
            // 多点模式需要目标点和当前交互模式的控制组件同时创建成功；
            // 任一窗口失败都回滚，避免 Flutter 误以为模式已开启但悬浮层只显示一部分。
            hide()
            return false
        }
        ensureDisplayListener()
        notifyOverlayStateChanged()
        return true
    }

    fun hide() {
        end()
        isModeEnabled = false
        // 关闭模式后取消已排队的横竖屏刷新，避免窗口移除后又被延迟任务重新触发布局更新。
        mainHandler.removeCallbacks(displayBoundsRefreshRunnable)
        removeAllTargetComponents()
        removeInteractionComponents()
        removeDisplayListener()
        notifyOverlayStateChanged()
    }

    fun handleOverlayPermissionRevoked() {
        if (!isModeEnabled) {
            return
        }

        hide()
        Toast.makeText(context.applicationContext, "悬浮窗权限已关闭，多点模式已退出", Toast.LENGTH_SHORT).show()
    }

    fun updateTargets(nextTargets: List<MultiPointTargetState>) {
        targets = normalizedTargets(nextTargets)
        if (isModeEnabled) {
            if (!refreshTargetComponents()) {
                hide()
                return
            }
            updatePausedTask(resetCurrentRound = true)
            notifyOverlayStateChanged()
        } else {
            notifyOverlayStateChanged()
        }
    }

    fun updateClickSettings(settings: MultiPointOverlaySettings) {
        // 多点悬浮层已开启后，设置页保存的点击参数需要同步到原生侧，下一次执行才会使用新配置。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
        updatePausedTask(resetCurrentRound = false)
        notifyOverlayStateChanged()
    }

    fun updateOverlayUiState(state: MultiPointOverlayUiState) {
        overlayUiState = state
        coerceOverlayStateToScreen()
        if (isModeEnabled) {
            refreshInteractionViews()
        }
        notifyOverlayStateChanged()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        if (isModeEnabled) {
            coerceOverlayStateToScreen()
            if (!refreshTargetComponents() || !refreshInteractionViews()) {
                hide()
                return
            }
        }
        notifyOverlayStateChanged()
    }

    fun handleConfigurationChanged() {
        if (!isModeEnabled) {
            return
        }

        // Activity 横竖屏切换不重建时，按新屏幕边界延迟刷新，避免使用旧 display 尺寸。
        handleDisplayBoundsChanged()
    }

    fun start(): MultiPointClickStartResult {
        if (!isModeEnabled) {
            return MultiPointClickStartResult.INVALID_TASK_STATE
        }

        val result = MultiPointClickScheduler.start(
            request = MultiPointClickTaskRequest(
                targets = targets,
                intervalMs = intervalMs,
                repeatCount = repeatCount,
                infiniteLoop = infiniteLoop,
                tapDurationMs = tapDurationMs,
            ),
            targetPositionProvider = AutomationTargetPositionProvider(::targetCenterOnScreen),
            onStatusChanged = ::handleSchedulerStatusChanged,
        )
        if (result == MultiPointClickStartResult.STARTED) {
            refreshTaskActionState()
        }
        return result
    }

    fun pause(): Boolean {
        return MultiPointClickScheduler.pause()
    }

    fun resume(): MultiPointClickResumeResult {
        return MultiPointClickScheduler.resume()
    }

    fun end() {
        MultiPointClickScheduler.end()
        if (taskStatus.taskRunState != TaskRunState.IDLE || taskStatus.completedRounds != 0) {
            handleSchedulerStatusChanged(MultiPointTaskStatus())
        }
    }

    fun handleAccessibilityServiceDisconnected() {
        if (taskStatus.taskRunState == TaskRunState.IDLE) {
            return
        }

        end()
        Toast.makeText(context.applicationContext, "无障碍服务已断开，多点任务已结束", Toast.LENGTH_SHORT).show()
    }

    private fun applySettings(settings: MultiPointOverlaySettings) {
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
        overlayUiState = settings.overlayUiState
        appearanceSettings = settings.appearanceSettings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        targets = normalizedTargets(settings.targets)
    }

    private fun notifyOverlayStateChanged() {
        onOverlayStateChanged(snapshot)
    }

    private fun refreshTargetComponents(): Boolean {
        coerceOverlayStateToScreen()
        val enabledTargets = targets.filter { it.enabled }
        val enabledIds = enabledTargets.map { it.id }.toSet()
        val removedIds = targetComponents.keys - enabledIds

        for (removedId in removedIds) {
            targetComponents.remove(removedId)?.remove()
        }

        enabledTargets.forEachIndexed { index, target ->
            val component = targetComponents.getOrPut(target.id) {
                MultiPointTargetOverlayComponent(
                    context = context,
                    overlayWindow = overlay,
                    onPositionChanged = ::handleTargetPositionChanged,
                )
            }
            // 悬浮层编号按启用点位连续显示，不直接使用完整列表 order。
            component.show(
                target = target,
                displayIndex = index + 1,
                metrics = metrics,
            )
            if (!component.isShowing) {
                return false
            }
        }
        syncTargetTouchableState()
        return true
    }

    private fun removeAllTargetComponents() {
        targetComponents.values.forEach { component -> component.remove() }
        targetComponents.clear()
    }

    private fun refreshInteractionViews(): Boolean {
        if (!isModeEnabled) {
            removeInteractionComponents()
            return true
        }

        coerceOverlayStateToScreen()
        if (overlayUiState.shouldShowToolbar()) {
            toolbarComponent.show(
                position = overlayUiState.toolbarPosition,
                taskRunState = taskStatus.taskRunState,
                canCollapse = overlayUiState.interactionMode == OverlayInteractionMode.COMPACT,
                metrics = metrics,
            )
            if (!toolbarComponent.isShowing) {
                return false
            }
        } else {
            toolbarComponent.remove()
        }

        if (overlayUiState.shouldShowCollapsedToolbar()) {
            collapsedToolbarComponent.show(overlayUiState.collapsedToolbarPosition, metrics)
            if (!collapsedToolbarComponent.isShowing) {
                return false
            }
        } else {
            collapsedToolbarComponent.remove()
        }

        if (overlayUiState.shouldShowActionButton()) {
            actionButtonComponent.show(
                position = overlayUiState.actionButtonPosition,
                taskRunState = taskStatus.taskRunState,
                metrics = metrics,
            )
            if (!actionButtonComponent.isShowing) {
                return false
            }
        } else {
            actionButtonComponent.remove()
        }
        refreshTaskActionState()
        return true
    }

    private fun removeInteractionComponents() {
        toolbarComponent.remove()
        collapsedToolbarComponent.remove()
        actionButtonComponent.remove()
    }

    private fun collapseToolbar() {
        if (overlayUiState.interactionMode != OverlayInteractionMode.COMPACT) {
            return
        }

        overlayUiState = overlayUiState.copy(isToolbarCollapsed = true)
        refreshInteractionViews()
        notifyOverlayStateChanged()
    }

    private fun expandToolbar() {
        overlayUiState = overlayUiState.copy(isToolbarCollapsed = false)
        refreshInteractionViews()
        notifyOverlayStateChanged()
    }

    private fun handleTargetPositionChanged(targetId: String, point: OverlayPoint) {
        targets = targets.map { target ->
            if (target.id == targetId) {
                target.copy(x = point.x, y = point.y)
            } else {
                target
            }
        }
        // 点位拖动需要单独回传，Flutter 侧据此只更新对应点位并保存 targets_json。
        onTargetPositionChanged(targetId, point)
        notifyOverlayStateChanged()
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

    private fun coerceOverlayStateToScreen() {
        coerceTargetPositionsToScreen()
        coerceInteractionPositionsToScreen()
    }

    private fun coerceTargetPositionsToScreen() {
        val nextTargets = targets.map { target ->
            val coercedPoint = overlay.coercePositionPx(
                OverlayPoint(target.x, target.y),
                widthPx = metrics.targetSizePx,
                heightPx = metrics.targetSizePx,
            )
            if (coercedPoint.x == target.x && coercedPoint.y == target.y) {
                target
            } else {
                // 多点点位坐标保存在 targets_json；横竖屏裁剪后必须同步回 Flutter。
                onTargetPositionChanged(target.id, coercedPoint)
                target.copy(x = coercedPoint.x, y = coercedPoint.y)
            }
        }

        if (nextTargets != targets) {
            targets = nextTargets
        }
    }

    private fun handleSchedulerStatusChanged(status: MultiPointTaskStatus) {
        taskStatus = if (isModeEnabled) status else MultiPointTaskStatus()
        syncTargetTouchableState()
        refreshTaskActionState()
        notifyOverlayStateChanged()
    }

    private fun refreshTaskActionState() {
        toolbarComponent.updateTaskRunState(taskStatus.taskRunState)
        actionButtonComponent.updateTaskRunState(taskStatus.taskRunState)
    }

    private fun syncTargetTouchableState() {
        val canDragTargets = taskStatus.taskRunState != TaskRunState.RUNNING
        targetComponents.values.forEach { component ->
            component.setTouchable(canDragTargets)
        }
    }

    private fun toggleTaskRunState() {
        val handled = when (taskStatus.taskRunState) {
            TaskRunState.IDLE -> start() == MultiPointClickStartResult.STARTED
            TaskRunState.RUNNING -> pause()
            TaskRunState.PAUSED -> resume() == MultiPointClickResumeResult.RESUMED
        }

        if (!handled) {
            showTaskActionFailure()
        }
    }

    private fun endFromToolbar() {
        end()
        Toast.makeText(context.applicationContext, "多点任务已结束", Toast.LENGTH_SHORT).show()
    }

    private fun endFromActionButton() {
        if (taskStatus.taskRunState == TaskRunState.IDLE) {
            Toast.makeText(context.applicationContext, "当前没有正在执行的多点任务", Toast.LENGTH_SHORT).show()
            return
        }

        end()
        Toast.makeText(context.applicationContext, "多点任务已结束", Toast.LENGTH_SHORT).show()
    }

    private fun showTaskActionFailure() {
        val message = when (taskStatus.taskRunState) {
            TaskRunState.IDLE -> "无法开始多点任务，请检查无障碍服务和启用点位"
            TaskRunState.RUNNING -> "当前任务状态已变化，无法暂停"
            TaskRunState.PAUSED -> "无障碍服务未连接，无法继续多点任务"
        }
        Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
    }

    private fun targetCenterOnScreen(targetId: String): AutomationTargetPosition? {
        targetComponents[targetId]?.centerOnScreen()?.let { return it }
        val target = targets.firstOrNull { it.id == targetId } ?: return null
        // 正常执行时会从悬浮 View 读取真实屏幕中心；这里仅作为窗口短暂刷新期间的兜底。
        return AutomationTargetPosition(
            x = target.x + metrics.targetSizePx / 2f,
            y = target.y + metrics.targetSizePx / 2f,
        )
    }

    private fun updatePausedTask(resetCurrentRound: Boolean) {
        if (taskStatus.taskRunState != TaskRunState.PAUSED) {
            return
        }

        MultiPointClickScheduler.updatePausedTask(
            request = MultiPointClickTaskRequest(
                targets = targets,
                intervalMs = intervalMs,
                repeatCount = repeatCount,
                infiniteLoop = infiniteLoop,
                tapDurationMs = tapDurationMs,
            ),
            resetCurrentRound = resetCurrentRound,
        )
    }

    private fun coerceInteractionPositionsToScreen() {
        val coercedState = overlayUiState.copy(
            toolbarPosition = overlay.coercePositionPx(
                overlayUiState.toolbarPosition,
                widthPx = metrics.toolbarWidthPx,
                heightPx = metrics.toolbarEstimatedHeightPx,
            ),
            collapsedToolbarPosition = overlay.coercePositionPx(
                overlayUiState.collapsedToolbarPosition,
                widthPx = metrics.collapsedToolbarSizePx,
                heightPx = metrics.collapsedToolbarSizePx,
            ),
            actionButtonPosition = overlay.coercePositionPx(
                overlayUiState.actionButtonPosition,
                widthPx = metrics.actionButtonSizePx,
                heightPx = metrics.actionButtonSizePx,
            ),
        )

        if (coercedState != overlayUiState) {
            // 控制组件位置保存在多点 Overlay 快照中，更新 state 后由 snapshot 回传持久化。
            overlayUiState = coercedState
        }
    }

    private fun normalizedTargets(nextTargets: List<MultiPointTargetState>): List<MultiPointTargetState> {
        val source = nextTargets.ifEmpty { defaultMultiPointTargets() }
        return source
            .sortedWith(compareBy<MultiPointTargetState> { it.order }.thenBy { it.id })
            .mapIndexed { index, target -> target.copy(order = index + 1) }
            .take(MAX_TARGETS)
    }

    private companion object {
        const val MAX_TARGETS = 12
    }
}
