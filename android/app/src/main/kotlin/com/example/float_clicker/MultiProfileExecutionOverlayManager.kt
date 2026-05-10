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

        if (!refreshButtons()) {
            hide()
        }
    }
    private val buttonComponents = mutableMapOf<String, MultiProfileExecutionButtonComponent>()
    private val buttonPositions = mutableMapOf<String, OverlayPoint>()
    private var profiles = emptyList<LoadedMultiPointProfileState>()
    private var appearanceSettings = OverlayAppearanceSettings()
    private var metrics = OverlayComponentMetrics(overlay, appearanceSettings)
    private var isDisplayListenerRegistered = false

    var isShowing: Boolean = false
        private set

    fun show(
        loadedProfiles: List<LoadedMultiPointProfileState>,
        appearanceSettings: OverlayAppearanceSettings,
    ): Boolean {
        profiles = normalizedProfiles(loadedProfiles)
        if (profiles.isEmpty()) {
            return false
        }
        this.appearanceSettings = appearanceSettings.normalized
        metrics = OverlayComponentMetrics(overlay, this.appearanceSettings)
        isShowing = true
        if (!refreshButtons()) {
            hide()
            return false
        }
        ensureDisplayListener()
        return true
    }

    fun update(
        loadedProfiles: List<LoadedMultiPointProfileState>,
        appearanceSettings: OverlayAppearanceSettings = this.appearanceSettings,
    ): Boolean {
        profiles = normalizedProfiles(loadedProfiles)
        this.appearanceSettings = appearanceSettings.normalized
        metrics = OverlayComponentMetrics(overlay, this.appearanceSettings)

        if (!isShowing) {
            return true
        }
        if (profiles.isEmpty()) {
            hide()
            return true
        }
        return refreshButtons()
    }

    fun hide() {
        isShowing = false
        mainHandler.removeCallbacks(displayBoundsRefreshRunnable)
        buttonComponents.values.forEach { component -> component.remove() }
        buttonComponents.clear()
        removeDisplayListener()
    }

    fun updateAppearanceSettings(settings: OverlayAppearanceSettings) {
        appearanceSettings = settings.normalized
        metrics = OverlayComponentMetrics(overlay, appearanceSettings)
        if (isShowing && !refreshButtons()) {
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

    private fun refreshButtons(): Boolean {
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
                    onPositionChanged = { point -> buttonPositions[profile.profileId] = point },
                    onClick = {
                        // P7.2.1 只验证多控件悬浮展示；真实绑定 profile 执行留到 P7.2.2。
                        Toast.makeText(context.applicationContext, "执行功能将在下一阶段接入", Toast.LENGTH_SHORT).show()
                    },
                )
            }
            component.show(profile = profile, position = position, metrics = metrics)
            if (!component.isShowing) {
                return false
            }
        }
        return true
    }

    private fun coercedPositionFor(
        profile: LoadedMultiPointProfileState,
        index: Int,
    ): OverlayPoint {
        val fallback = defaultPosition(index)
        val currentPosition = buttonPositions[profile.profileId] ?: fallback
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
