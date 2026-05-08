package com.example.float_clicker

import kotlin.math.roundToInt

data class OverlayAppearanceSettings(
    val controlScale: Float = DEFAULT_SCALE,
) {
    val normalized: OverlayAppearanceSettings
        get() = copy(controlScale = normalizeScale(controlScale))

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
    private val scale = appearanceSettings.normalized.controlScale

    val targetSizePx = scaledDp(38f)
    val targetStrokePx = scaledDp(3f)
    val targetInnerDotSizePx = scaledDp(8f)

    val toolbarWidthPx = scaledDp(42f)
    val toolbarButtonWidthPx = scaledDp(34f)
    val toolbarButtonHeightPx = scaledDp(32f)
    val toolbarPaddingHorizontalPx = scaledDp(3f)
    val toolbarPaddingVerticalPx = scaledDp(4f)
    val toolbarCornerRadiusPx = scaledDp(15f)
    val toolbarButtonCornerRadiusPx = scaledDp(11f)
    val toolbarButtonStrokePx = scaledDp(1f)
    val toolbarElevationPx = scaledDp(8f)
    val toolbarDragTextSizeSp = scaledSp(20f)
    val toolbarTaskTextSizeSp = scaledSp(19f)
    val toolbarPauseTextSizeSp = scaledSp(16f)
    val toolbarEndTextSizeSp = scaledSp(15f)
    val toolbarCloseTextSizeSp = scaledSp(20f)

    val collapsedToolbarSizePx = scaledDp(44f)
    val collapsedToolbarTextSizeSp = scaledSp(24f)

    val actionButtonSizePx = scaledDp(42f)
    val actionButtonStrokePx = scaledDp(2f)
    val actionPlayIconWidthPx = scaledDp(11f)
    val actionPlayIconHeightPx = scaledDp(14f)
    val actionPauseBarWidthPx = scaledDp(3f)
    val actionPauseBarHeightPx = scaledDp(13f)
    val actionPauseGapPx = scaledDp(3f)
    val actionPauseCornerPx = scaledDp(1f)

    val toolbarEstimatedHeightPx: Int
        get() = toolbarPaddingVerticalPx * 2 + toolbarButtonHeightPx * TOOLBAR_BUTTON_COUNT

    private fun scaledDp(baseDp: Float): Int {
        return overlayWindow.dp(baseDp * scale).coerceAtLeast(1)
    }

    private fun scaledSp(baseSp: Float): Float {
        return ((baseSp * scale) * 10f).roundToInt() / 10f
    }

    private companion object {
        const val TOOLBAR_BUTTON_COUNT = 4
    }
}
