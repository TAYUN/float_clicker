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

    val isShowing: Boolean
        get() = view != null

    fun show(position: OverlayPoint) {
        if (view != null) {
            moveTo(position)
            return
        }

        val target = createView()
        val nextParams = overlayWindow.overlayParams(
            width = overlayWindow.dp(38),
            height = overlayWindow.dp(38),
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
        val outer = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(OverlayColors.ACCENT_SOFT)
            setStroke(overlayWindow.dp(3), OverlayColors.ACCENT)
        }
        val inner = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(OverlayColors.ACCENT)
        }

        return LinearLayout(context).apply {
            gravity = Gravity.CENTER
            background = outer
            alpha = 0.94f
            addView(
                View(context).apply { background = inner },
                LinearLayout.LayoutParams(overlayWindow.dp(8), overlayWindow.dp(8)),
            )
        }
    }
}
