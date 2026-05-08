package com.example.float_clicker

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

internal class MultiPointTargetOverlayComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (String, OverlayPoint) -> Unit,
) {
    private var view: FrameLayout? = null
    private var labelView: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var targetId: String? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun show(
        target: MultiPointTargetState,
        displayIndex: Int,
        metrics: OverlayComponentMetrics,
    ) {
        this.metrics = metrics
        targetId = target.id
        if (view != null) {
            updateLabel(displayIndex)
            updateMetrics(metrics)
            moveTo(OverlayPoint(target.x, target.y))
            return
        }

        val targetView = createView(displayIndex)
        val nextParams = overlayWindow.overlayParams(
            width = metrics.targetSizePx,
            height = metrics.targetSizePx,
            position = OverlayPoint(target.x, target.y),
        )
        overlayWindow.bindDrag(
            view = targetView,
            params = nextParams,
            onPositionChanged = { point ->
                // 回传稳定 id，Flutter 才能在排序后仍更新正确点位。
                targetId?.let { id -> onPositionChanged(id, point) }
            },
        )
        if (!overlayWindow.addView(targetView, nextParams)) {
            return
        }
        view = targetView
        params = nextParams
    }

    fun moveTo(position: OverlayPoint) {
        overlayWindow.moveTo(view, params, position)
    }

    fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val targetView = view ?: return
        targetView.background = outerBackground()
        labelView?.textSize = labelTextSizeSp()
        updateLayoutSize(metrics.targetSizePx, metrics.targetSizePx)
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        labelView = null
        params = null
        targetId = null
    }

    private fun createView(displayIndex: Int): FrameLayout {
        return FrameLayout(context).apply {
            background = outerBackground()
            alpha = 0.94f
            addView(
                TextView(context).also { label ->
                    labelView = label
                    label.text = displayIndex.toString()
                    label.textSize = labelTextSizeSp()
                    label.typeface = Typeface.DEFAULT_BOLD
                    label.setTextColor(OverlayColors.TEXT_PRIMARY)
                    label.gravity = Gravity.CENTER
                    label.includeFontPadding = false
                },
                FrameLayout.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER,
                ),
            )
        }
    }

    private fun updateLabel(displayIndex: Int) {
        labelView?.text = displayIndex.toString()
    }

    private fun outerBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(OverlayColors.ACCENT_SOFT)
            setStroke(metrics.targetStrokePx, OverlayColors.ACCENT)
        }
    }

    private fun labelTextSizeSp(): Float {
        return (metrics.targetSizePx / context.resources.displayMetrics.density * 0.42f)
            .coerceAtLeast(12f)
    }

    private fun updateLayoutSize(width: Int, height: Int) {
        val targetView = view ?: return
        val targetParams = params ?: return
        targetParams.width = width
        targetParams.height = height
        overlayWindow.updateViewLayout(targetView, targetParams)
    }
}
