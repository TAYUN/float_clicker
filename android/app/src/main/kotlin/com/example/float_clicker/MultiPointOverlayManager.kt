package com.example.float_clicker

import android.content.Context
import android.view.WindowManager

internal class MultiPointOverlayManager(
    context: Context,
    private val onOverlayStateChanged: (MultiPointOverlaySnapshot) -> Unit = {},
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val overlay = OverlayWindowHelper(context, windowManager)
    private val targetComponent = MultiPointTargetOverlayComponent(
        context = context,
        overlayWindow = overlay,
    ) { targetId, point ->
        targets = targets.map { target ->
            if (target.id == targetId) {
                target.copy(x = point.x, y = point.y)
            } else {
                target
            }
        }
        notifyOverlayStateChanged()
    }

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
        val firstEnabledTarget = targets.firstOrNull { it.enabled }
        if (firstEnabledTarget == null) {
            // 允许所有点位禁用；此时多点模式开启，但悬浮层不显示目标点，执行前由 Flutter/调度器拒绝。
            targetComponent.remove()
            notifyOverlayStateChanged()
            return true
        }

        // P3.2 只验证单个编号点位组件；多个点位统一管理留到 P3.3。
        targetComponent.show(
            target = firstEnabledTarget,
            displayIndex = 1,
            metrics = metrics,
        )
        notifyOverlayStateChanged()
        return targetComponent.isShowing
    }

    fun hide() {
        isModeEnabled = false
        targetComponent.remove()
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
        notifyOverlayStateChanged()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        targetComponent.updateMetrics(metrics)
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
