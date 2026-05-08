package com.example.float_clicker

import kotlin.math.roundToInt

data class OverlayAppearanceSettings(
    val targetPointScale: Float = DEFAULT_SCALE,
    val toolbarScale: Float = DEFAULT_SCALE,
    val actionButtonScale: Float = DEFAULT_SCALE,
) {
    val normalized: OverlayAppearanceSettings
        get() = copy(
            targetPointScale = normalizeScale(targetPointScale),
            toolbarScale = normalizeScale(toolbarScale),
            actionButtonScale = normalizeScale(actionButtonScale),
        )

    companion object {
        const val DEFAULT_SCALE = 1.0f
        const val MIN_SCALE = 0.8f
        const val MAX_SCALE = 1.3f

        fun normalizeScale(value: Float): Float {
            return value.coerceIn(MIN_SCALE, MAX_SCALE)
        }
    }
}

internal class OverlayComponentMetrics(
    private val overlayWindow: OverlayWindowHelper,
    appearanceSettings: OverlayAppearanceSettings,
) {
    private val normalizedSettings = appearanceSettings.normalized

    val targetSizePx = scaledDp(38f, normalizedSettings.targetPointScale)
    val targetStrokePx = scaledDp(3f, normalizedSettings.targetPointScale)
    val targetInnerDotSizePx = scaledDp(8f, normalizedSettings.targetPointScale)

    val toolbarWidthPx = scaledDp(42f, normalizedSettings.toolbarScale)
    val toolbarButtonWidthPx = scaledDp(34f, normalizedSettings.toolbarScale)
    val toolbarButtonHeightPx = scaledDp(32f, normalizedSettings.toolbarScale)
    val toolbarPaddingHorizontalPx = scaledDp(3f, normalizedSettings.toolbarScale)
    val toolbarPaddingVerticalPx = scaledDp(4f, normalizedSettings.toolbarScale)
    val toolbarCornerRadiusPx = scaledDp(15f, normalizedSettings.toolbarScale)
    val toolbarButtonCornerRadiusPx = scaledDp(11f, normalizedSettings.toolbarScale)
    val toolbarButtonStrokePx = scaledDp(1f, normalizedSettings.toolbarScale)
    val toolbarElevationPx = scaledDp(8f, normalizedSettings.toolbarScale)
    val toolbarDragTextSizeSp = scaledSp(20f, normalizedSettings.toolbarScale)
    val toolbarTaskTextSizeSp = scaledSp(19f, normalizedSettings.toolbarScale)
    val toolbarPauseTextSizeSp = scaledSp(16f, normalizedSettings.toolbarScale)
    val toolbarEndTextSizeSp = scaledSp(15f, normalizedSettings.toolbarScale)
    val toolbarCloseTextSizeSp = scaledSp(20f, normalizedSettings.toolbarScale)

    val collapsedToolbarSizePx = scaledDp(44f, normalizedSettings.toolbarScale)
    val collapsedToolbarTextSizeSp = scaledSp(24f, normalizedSettings.toolbarScale)

    val actionButtonSizePx = scaledDp(42f, normalizedSettings.actionButtonScale)
    val actionButtonStrokePx = scaledDp(2f, normalizedSettings.actionButtonScale)
    val actionPlayIconWidthPx = scaledDp(11f, normalizedSettings.actionButtonScale)
    val actionPlayIconHeightPx = scaledDp(14f, normalizedSettings.actionButtonScale)
    val actionPauseBarWidthPx = scaledDp(3f, normalizedSettings.actionButtonScale)
    val actionPauseBarHeightPx = scaledDp(13f, normalizedSettings.actionButtonScale)
    val actionPauseGapPx = scaledDp(3f, normalizedSettings.actionButtonScale)
    val actionPauseCornerPx = scaledDp(1f, normalizedSettings.actionButtonScale)

    val toolbarEstimatedHeightPx: Int
        get() = toolbarPaddingVerticalPx * 2 + toolbarButtonHeightPx * TOOLBAR_BUTTON_COUNT

    private fun scaledDp(baseDp: Float, scale: Float): Int {
        return overlayWindow.dp(baseDp * scale).coerceAtLeast(1)
    }

    private fun scaledSp(baseSp: Float, scale: Float): Float {
        return ((baseSp * scale) * 10f).roundToInt() / 10f
    }

    private companion object {
        const val TOOLBAR_BUTTON_COUNT = 4
    }
}
