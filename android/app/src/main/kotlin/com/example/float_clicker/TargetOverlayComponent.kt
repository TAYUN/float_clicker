package com.example.float_clicker

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout

internal class TargetOverlayComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
) {
    private var view: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun show(position: OverlayPoint, metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        if (view != null) {
            updateLayoutSize(metrics.targetSizePx, metrics.targetSizePx)
            moveTo(position)
            return
        }

        val target = createView()
        val nextParams = overlayWindow.overlayParams(
            width = metrics.targetSizePx,
            height = metrics.targetSizePx,
            position = position,
        )
        overlayWindow.bindDrag(
            view = target,
            params = nextParams,
            onPositionChanged = { point -> onPositionChanged(point) },
        )
        overlayWindow.addView(target, nextParams)
        view = target
        params = nextParams
    }

    fun moveTo(position: OverlayPoint) {
        overlayWindow.moveTo(view, params, position)
    }

    fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val target = view ?: return
        target.background = outerBackground()
        val inner = (target as? LinearLayout)?.getChildAt(0) ?: return
        inner.layoutParams = LinearLayout.LayoutParams(
            metrics.targetInnerDotSizePx,
            metrics.targetInnerDotSizePx,
        )
        updateLayoutSize(metrics.targetSizePx, metrics.targetSizePx)
    }

    fun setTouchable(isTouchable: Boolean) {
        val target = view ?: return
        val targetParams = params ?: return
        // FLAG_NOT_TOUCHABLE 是位标记：开启时点击点透传触摸，关闭时用户可以拖动它。
        targetParams.flags = if (isTouchable) {
            targetParams.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            targetParams.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        overlayWindow.updateViewLayout(target, targetParams)
    }

    fun centerOnScreen(): Pair<Float, Float>? {
        val target = view ?: return null
        val location = IntArray(2)
        // 无障碍手势使用的是屏幕坐标；用 View 的真实屏幕位置可以避开状态栏和 overlay 坐标偏移。
        target.getLocationOnScreen(location)
        return Pair(
            location[0] + target.width / 2f,
            location[1] + target.height / 2f,
        )
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun createView(): View {
        val inner = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(OverlayColors.ACCENT)
        }

        return LinearLayout(context).apply {
            gravity = Gravity.CENTER
            background = outerBackground()
            alpha = 0.94f
            addView(
                View(context).apply { background = inner },
                LinearLayout.LayoutParams(metrics.targetInnerDotSizePx, metrics.targetInnerDotSizePx),
            )
        }
    }

    private fun outerBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(OverlayColors.ACCENT_SOFT)
            setStroke(metrics.targetStrokePx, OverlayColors.ACCENT)
        }
    }

    private fun updateLayoutSize(width: Int, height: Int) {
        val target = view ?: return
        val targetParams = params ?: return
        targetParams.width = width
        targetParams.height = height
        overlayWindow.updateViewLayout(target, targetParams)
    }
}
