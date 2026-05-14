package com.example.float_clicker

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView

internal class MultiProfileExecutionLauncherComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onClick: () -> Unit,
    private val onPositionChanged: (OverlayPoint) -> Unit = {},
) {
    private var view: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun show(position: OverlayPoint, metrics: OverlayComponentMetrics, isRunning: Boolean): Boolean {
        this.metrics = metrics
        if (view == null) {
            val launcher = createView()
            val nextParams = overlayWindow.overlayParams(
                width = launcherWidthPx(),
                height = launcherHeightPx(),
                position = position,
            )
            if (!overlayWindow.addView(launcher, nextParams)) {
                return false
            }
            overlayWindow.bindDrag(
                view = launcher,
                params = nextParams,
                onPositionChanged = onPositionChanged,
                onClick = onClick,
            )
            view = launcher
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        updateState(isRunning)
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
        launcherParams.width = launcherWidthPx()
        launcherParams.height = launcherHeightPx()
        launcher.textSize = launcherTextSizeSp()
        launcher.background = launcherBackground()
        overlayWindow.updateViewLayout(launcher, launcherParams)
    }

    private fun createView(): TextView {
        return TextView(context).apply {
            textSize = launcherTextSizeSp()
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(OverlayColors.TEXT_PRIMARY)
            gravity = Gravity.CENTER
            includeFontPadding = false
            maxLines = 2
            background = launcherBackground()
            elevation = overlayWindow.dp(8).toFloat()
            isClickable = true
            setOnClickListener { onClick() }
        }
    }

    private fun updateState(isRunning: Boolean) {
        view?.apply {
            text = if (isRunning) "执行区\n运行中" else "执行区"
            contentDescription = if (isRunning) {
                "打开多配置执行区，当前有任务运行中"
            } else {
                "打开多配置执行区"
            }
        }
    }

    private fun launcherBackground(): GradientDrawable {
        return GradientDrawable().apply {
            cornerRadius = overlayWindow.dp(16).toFloat()
            setColor(OverlayColors.ACCENT)
        }
    }

    private fun launcherWidthPx(): Int {
        return overlayWindow.dp(68)
    }

    private fun launcherHeightPx(): Int {
        return overlayWindow.dp(50)
    }

    private fun launcherTextSizeSp(): Float {
        return 11f
    }
}
