package com.example.float_clicker

import android.content.Context
import android.view.WindowManager
import android.widget.TextView

internal class MultiProfileExecutionLauncherComponent(
    context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onClick: () -> Unit,
) {
    private var view: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun show(position: OverlayPoint, metrics: OverlayComponentMetrics): Boolean {
        this.metrics = metrics
        if (view == null) {
            val launcher = createView()
            val nextParams = overlayWindow.overlayParams(
                width = launcherSizePx(),
                height = launcherSizePx(),
                position = position,
            )
            if (!overlayWindow.addView(launcher, nextParams)) {
                return false
            }
            view = launcher
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        overlayWindow.moveTo(view, params, position)
        return true
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val launcher = view ?: return
        val launcherParams = params ?: return
        launcherParams.width = launcherSizePx()
        launcherParams.height = launcherSizePx()
        overlayWindow.updateViewLayout(launcher, launcherParams)
    }

    private fun createView(): TextView {
        return overlayWindow.floatingButton(
            text = "展",
            textSize = 15f,
            backgroundColor = OverlayColors.ACCENT,
            onClick = onClick,
        ).apply {
            contentDescription = "展开执行控件组"
        }
    }

    private fun launcherSizePx(): Int {
        return metrics.actionButtonSizePx.coerceAtLeast(overlayWindow.dp(44))
    }
}
