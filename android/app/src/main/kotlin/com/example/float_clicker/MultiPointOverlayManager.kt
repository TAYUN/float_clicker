package com.example.float_clicker

import android.content.Context
import android.view.WindowManager

internal class MultiPointOverlayManager(
    private val context: Context,
    private val onOverlayStateChanged: (MultiPointOverlaySnapshot) -> Unit = {},
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val overlay = OverlayWindowHelper(context, windowManager)
    private val targetComponents = mutableMapOf<String, MultiPointTargetOverlayComponent>()

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
        notifyOverlayStateChanged()
        return targets.none { it.enabled } || targetComponents.isNotEmpty()
    }

    fun hide() {
        isModeEnabled = false
        removeAllTargetComponents()
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
        if (isModeEnabled) {
            refreshTargetComponents()
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

    private fun handleTargetPositionChanged(targetId: String, point: OverlayPoint) {
        targets = targets.map { target ->
            if (target.id == targetId) {
                target.copy(x = point.x, y = point.y)
            } else {
                target
            }
        }
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
