package com.example.float_clicker

import android.content.Context
import android.view.WindowManager
import android.widget.Toast

internal class MultiPointOverlayManager(
    private val context: Context,
    private val onOverlayStateChanged: (MultiPointOverlaySnapshot) -> Unit = {},
    private val onTargetPositionChanged: (String, OverlayPoint) -> Unit = { _, _ -> },
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val overlay = OverlayWindowHelper(context, windowManager)
    private val targetComponents = mutableMapOf<String, MultiPointTargetOverlayComponent>()
    private val toolbarComponent = ToolbarOverlayComponent(
        context = context,
        overlayWindow = overlay,
        onPositionChanged = { point ->
            overlayUiState = overlayUiState.copy(toolbarPosition = point)
            notifyOverlayStateChanged()
        },
        onTaskAction = ::showTaskUnavailableMessage,
        onEndTask = ::showTaskUnavailableMessage,
        onClose = ::hide,
        onCollapse = ::collapseToolbar,
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
        onTaskAction = ::showTaskUnavailableMessage,
        onEndTask = ::showTaskUnavailableMessage,
    )

    private var overlayUiState = MultiPointOverlayUiState()
    private var appearanceSettings = OverlayAppearanceSettings()
    private var metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    private var targets = defaultMultiPointTargets()
    private var isModeEnabled = false

    val isShowing: Boolean
        get() = isModeEnabled

    val snapshot: MultiPointOverlaySnapshot
        get() = MultiPointOverlaySnapshot(
            modeEnabled = isModeEnabled,
            taskRunState = TaskRunState.IDLE,
            targets = targets,
            overlayUiState = if (isModeEnabled) overlayUiState else null,
        )

    fun show(settings: MultiPointOverlaySettings = MultiPointOverlaySettings()): Boolean {
        applySettings(settings)
        isModeEnabled = true
        refreshTargetComponents()
        refreshInteractionViews()
        notifyOverlayStateChanged()
        return targets.none { it.enabled } || targetComponents.isNotEmpty()
    }

    fun hide() {
        isModeEnabled = false
        removeAllTargetComponents()
        removeInteractionComponents()
        notifyOverlayStateChanged()
    }

    fun updateTargets(nextTargets: List<MultiPointTargetState>) {
        targets = normalizedTargets(nextTargets)
        if (isModeEnabled) {
            show(
                MultiPointOverlaySettings(
                    targets = targets,
                    overlayUiState = overlayUiState,
                    appearanceSettings = appearanceSettings,
                ),
            )
        } else {
            notifyOverlayStateChanged()
        }
    }

    fun updateOverlayUiState(state: MultiPointOverlayUiState) {
        overlayUiState = state
        if (isModeEnabled) {
            refreshInteractionViews()
        }
        notifyOverlayStateChanged()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        if (isModeEnabled) {
            refreshTargetComponents()
            refreshInteractionViews()
        }
        notifyOverlayStateChanged()
    }

    private fun applySettings(settings: MultiPointOverlaySettings) {
        overlayUiState = settings.overlayUiState
        appearanceSettings = settings.appearanceSettings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        targets = normalizedTargets(settings.targets)
    }

    private fun notifyOverlayStateChanged() {
        onOverlayStateChanged(snapshot)
    }

    private fun refreshTargetComponents() {
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
        }
    }

    private fun removeAllTargetComponents() {
        targetComponents.values.forEach { component -> component.remove() }
        targetComponents.clear()
    }

    private fun refreshInteractionViews() {
        if (!isModeEnabled) {
            removeInteractionComponents()
            return
        }

        if (overlayUiState.shouldShowToolbar()) {
            toolbarComponent.show(
                position = overlayUiState.toolbarPosition,
                taskRunState = TaskRunState.IDLE,
                canCollapse = overlayUiState.interactionMode == OverlayInteractionMode.COMPACT,
                metrics = metrics,
            )
        } else {
            toolbarComponent.remove()
        }

        if (overlayUiState.shouldShowCollapsedToolbar()) {
            collapsedToolbarComponent.show(overlayUiState.collapsedToolbarPosition, metrics)
        } else {
            collapsedToolbarComponent.remove()
        }

        if (overlayUiState.shouldShowActionButton()) {
            actionButtonComponent.show(
                position = overlayUiState.actionButtonPosition,
                taskRunState = TaskRunState.IDLE,
                metrics = metrics,
            )
        } else {
            actionButtonComponent.remove()
        }
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

    private fun showTaskUnavailableMessage() {
        Toast.makeText(context.applicationContext, "多点点击调度尚未实现", Toast.LENGTH_SHORT).show()
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
