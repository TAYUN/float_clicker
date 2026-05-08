package com.example.float_clicker

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import android.widget.Toast

class SinglePointOverlayManager(
    private val context: Context,
    private val onOverlayStateChanged: (SinglePointOverlaySnapshot) -> Unit = {},
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

    private var taskStatus = SinglePointTaskStatus()
    private var interactionState = OverlayInteractionState()
    private var appearanceSettings = OverlayAppearanceSettings()
    private var metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    private var isDisplayListenerRegistered = false

    // 当前配置保存在 overlay 管理器中。真正开始点击时会打包成 SinglePointClickRequest。
    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var tapDurationMs = 50

    private val targetComponent = TargetOverlayComponent(
        context = context,
        overlayWindow = overlay,
    ) { point ->
        interactionState = interactionState.copy(targetPosition = point)
        notifyOverlayStateChanged()
    }

    private val toolbarComponent = ToolbarOverlayComponent(
        context = context,
        overlayWindow = overlay,
        onPositionChanged = { point ->
            interactionState = interactionState.copy(toolbarPosition = point)
            notifyOverlayStateChanged()
        },
        onTaskAction = ::toggleTaskRunState,
        onEndTask = ::endFromToolbar,
        onClose = ::hide,
        onCollapse = ::collapseToolbar,
    )

    private val collapsedToolbarComponent = CollapsedToolbarComponent(
        overlayWindow = overlay,
        onPositionChanged = { point ->
            interactionState = interactionState.copy(collapsedToolbarPosition = point)
            notifyOverlayStateChanged()
        },
        onExpand = {
            interactionState = interactionState.copy(isToolbarCollapsed = false)
            Toast.makeText(context.applicationContext, "控制条已展开", Toast.LENGTH_SHORT).show()
            refreshInteractionViews()
        },
    )

    private val actionButtonComponent = ActionButtonOverlayComponent(
        context = context,
        overlayWindow = overlay,
        onPositionChanged = { point ->
            interactionState = interactionState.copy(actionButtonPosition = point)
            notifyOverlayStateChanged()
        },
        onTaskAction = ::toggleTaskRunState,
        onEndTask = ::endFromActionButton,
    )

    val isShowing: Boolean
        get() = targetComponent.isShowing

    val snapshot: SinglePointOverlaySnapshot
        get() = SinglePointOverlaySnapshot(
            isEnabled = isShowing,
            taskRunState = if (isShowing) taskStatus.taskRunState else TaskRunState.IDLE,
            executedCount = if (isShowing) taskStatus.executedCount else 0,
            interactionState = if (isShowing) interactionState else null,
        )

    fun show(settings: SinglePointOverlaySettings = SinglePointOverlaySettings()): Boolean {
        applySettings(settings)
        coerceInteractionStateToScreen()
        targetComponent.show(interactionState.targetPosition, metrics)
        if (!targetComponent.isShowing) {
            return false
        }
        ensureDisplayListener()
        refreshInteractionViews()
        return true
    }

    fun updateSettings(settings: SinglePointOverlaySettings) {
        applySettings(settings)
        coerceInteractionStateToScreen()
        refreshInteractionViews()
    }

    fun updateClickSettings(settings: SinglePointOverlaySettings) {
        // 设置页可能只更新点击参数；交互位置和当前模式不能因此回到默认值。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
    }

    fun updateInteractionState(state: OverlayInteractionState) {
        interactionState = state
        coerceInteractionStateToScreen()
        refreshInteractionViews()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        // 外观缩放只改变 view 尺寸和内部图标，不改变任务进度，也不重写用户保存的逻辑坐标。
        refreshInteractionViews()
    }

    fun handleConfigurationChanged() {
        if (!isShowing) {
            return
        }

        // Activity 声明了 configChanges，横竖屏切换不会重建；这里主动按新屏幕尺寸刷新 overlay。
        handleDisplayBoundsChanged()
    }

    fun hide() {
        end()
        targetComponent.remove()
        toolbarComponent.remove()
        collapsedToolbarComponent.remove()
        actionButtonComponent.remove()
        removeDisplayListener()
        notifyOverlayStateChanged()
    }

    fun start(): Boolean {
        if (taskStatus.taskRunState != TaskRunState.IDLE) {
            return false
        }

        val initialCenter = targetComponent.centerOnScreen() ?: return false
        // provider 每次点击前都会重新读取目标点中心坐标。
        // 这样用户在点击过程中移动目标点，下一次点击会使用最新位置。
        val started = SinglePointClickScheduler.start(
            provider = {
                val center = targetComponent.centerOnScreen() ?: initialCenter
                SinglePointClickRequest(
                    x = center.first,
                    y = center.second,
                    intervalMs = intervalMs,
                    repeatCount = repeatCount,
                    infiniteLoop = infiniteLoop,
                    tapDurationMs = tapDurationMs,
                )
            },
            onStatusChanged = ::handleSchedulerStatusChanged,
        )

        return started
    }

    fun pause(): Boolean {
        return SinglePointClickScheduler.pause()
    }

    fun resume(): Boolean {
        return SinglePointClickScheduler.resume()
    }

    fun end() {
        SinglePointClickScheduler.end()
        if (taskStatus.taskRunState != TaskRunState.IDLE || taskStatus.executedCount != 0) {
            handleSchedulerStatusChanged(SinglePointTaskStatus())
        }
    }

    fun stop() {
        end()
    }

    fun handleAccessibilityServiceDisconnected() {
        if (taskStatus.taskRunState == TaskRunState.IDLE && taskStatus.executedCount == 0) {
            return
        }

        end()
        Toast.makeText(context.applicationContext, "无障碍服务已断开，点击任务已结束", Toast.LENGTH_SHORT).show()
    }

    fun handleOverlayPermissionRevoked() {
        if (!isShowing) {
            return
        }

        hide()
        Toast.makeText(context.applicationContext, "悬浮窗权限已关闭，单点模式已退出", Toast.LENGTH_SHORT).show()
    }

    private fun applySettings(settings: SinglePointOverlaySettings) {
        // 原生侧做最后一道安全裁剪，防止过小间隔或非法次数把调度器拖进异常状态。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
        interactionState = settings.interactionState
        appearanceSettings = settings.appearanceSettings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    }

    private fun handleSchedulerStatusChanged(status: SinglePointTaskStatus) {
        taskStatus = if (isShowing) status else SinglePointTaskStatus()
        targetComponent.setTouchable(taskStatus.taskRunState != TaskRunState.RUNNING)
        refreshTaskActionState()
        notifyOverlayStateChanged()
    }

    private fun refreshInteractionViews() {
        if (!isShowing) {
            return
        }

        coerceInteractionStateToScreen()
        targetComponent.updateMetrics(metrics)
        targetComponent.moveTo(interactionState.targetPosition)

        if (interactionState.shouldShowToolbar()) {
            toolbarComponent.show(
                position = interactionState.toolbarPosition,
                taskRunState = taskStatus.taskRunState,
                canCollapse = interactionState.interactionMode == OverlayInteractionMode.COMPACT,
                metrics = metrics,
            )
        } else {
            toolbarComponent.remove()
        }

        if (interactionState.shouldShowCollapsedToolbar()) {
            collapsedToolbarComponent.show(interactionState.collapsedToolbarPosition, metrics)
        } else {
            collapsedToolbarComponent.remove()
        }

        if (interactionState.shouldShowActionButton()) {
            actionButtonComponent.show(interactionState.actionButtonPosition, taskStatus.taskRunState, metrics)
        } else {
            actionButtonComponent.remove()
        }

        refreshTaskActionState()
        notifyOverlayStateChanged()
    }

    private fun refreshTaskActionState() {
        toolbarComponent.updateTaskRunState(taskStatus.taskRunState)
        actionButtonComponent.updateTaskRunState(taskStatus.taskRunState)
    }

    private fun handleDisplayBoundsChanged() {
        mainHandler.post {
            if (isShowing) {
                refreshInteractionViews()
            }
        }
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

    private fun coerceInteractionStateToScreen() {
        val coercedState = interactionState.copy(
            targetPosition = overlay.coercePositionPx(
                interactionState.targetPosition,
                widthPx = metrics.targetSizePx,
                heightPx = metrics.targetSizePx,
            ),
            toolbarPosition = overlay.coercePositionPx(
                interactionState.toolbarPosition,
                widthPx = metrics.toolbarWidthPx,
                heightPx = metrics.toolbarEstimatedHeightPx,
            ),
            collapsedToolbarPosition = overlay.coercePositionPx(
                interactionState.collapsedToolbarPosition,
                widthPx = metrics.collapsedToolbarSizePx,
                heightPx = metrics.collapsedToolbarSizePx,
            ),
            actionButtonPosition = overlay.coercePositionPx(
                interactionState.actionButtonPosition,
                widthPx = metrics.actionButtonSizePx,
                heightPx = metrics.actionButtonSizePx,
            ),
        )

        if (coercedState != interactionState) {
            // 横竖屏切换或历史配置越界时，原生侧先校正，再通过 snapshot 回传给 Flutter 持久化。
            interactionState = coercedState
        }
    }

    private fun toggleTaskRunState() {
        val handled = when (taskStatus.taskRunState) {
            TaskRunState.IDLE -> start()
            TaskRunState.RUNNING -> pause()
            TaskRunState.PAUSED -> resume()
        }

        if (!handled) {
            showTaskActionFailure()
        }
    }

    private fun collapseToolbar() {
        if (interactionState.interactionMode != OverlayInteractionMode.COMPACT) {
            return
        }

        interactionState = interactionState.copy(isToolbarCollapsed = true)
        Toast.makeText(context.applicationContext, "控制条已收起", Toast.LENGTH_SHORT).show()
        refreshInteractionViews()
    }

    private fun endFromToolbar() {
        end()
        Toast.makeText(context.applicationContext, "点击任务已结束", Toast.LENGTH_SHORT).show()
    }

    private fun endFromActionButton() {
        if (taskStatus.taskRunState == TaskRunState.IDLE) {
            Toast.makeText(context.applicationContext, "当前没有正在执行的任务", Toast.LENGTH_SHORT).show()
            return
        }

        end()
        Toast.makeText(context.applicationContext, "点击任务已结束", Toast.LENGTH_SHORT).show()
    }

    private fun showTaskActionFailure() {
        val message = when (taskStatus.taskRunState) {
            TaskRunState.IDLE -> "无障碍服务未连接，无法执行点击"
            TaskRunState.RUNNING -> "当前任务状态已变化，无法暂停"
            TaskRunState.PAUSED -> "无障碍服务未连接，无法继续点击"
        }
        // 悬浮控件不依赖 Flutter 页面存在，失败原因直接用系统 Toast 告知用户。
        Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
    }

    private fun notifyOverlayStateChanged() {
        onOverlayStateChanged(snapshot)
    }
}

data class SinglePointOverlaySettings(
    val intervalMs: Int = 500,
    val repeatCount: Int = 10,
    val infiniteLoop: Boolean = false,
    val tapDurationMs: Int = 50,
    val interactionState: OverlayInteractionState = OverlayInteractionState(),
    val appearanceSettings: OverlayAppearanceSettings = OverlayAppearanceSettings(),
)
