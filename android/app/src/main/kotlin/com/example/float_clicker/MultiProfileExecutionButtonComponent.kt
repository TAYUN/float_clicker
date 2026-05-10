package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView

internal class MultiProfileExecutionButtonComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
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

    fun show(
        profile: LoadedMultiPointProfileState,
        position: OverlayPoint,
        metrics: OverlayComponentMetrics,
        isRunning: Boolean,
        isBlocked: Boolean,
    ) {
        this.metrics = metrics
        if (view == null) {
            val button = createView()
            val nextParams = overlayWindow.overlayParams(
                width = executionButtonWidthPx(),
                height = executionButtonHeightPx(),
                position = position,
            )
            overlayWindow.bindDrag(
                view = button,
                params = nextParams,
                onPositionChanged = { point -> onPositionChanged(point) },
                onClick = onClick,
            )
            if (!overlayWindow.addView(button, nextParams)) {
                return
            }
            view = button
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        updateProfile(profile, isRunning, isBlocked)
        overlayWindow.moveTo(view, params, position)
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val button = view ?: return
        val buttonParams = params ?: return
        buttonParams.width = executionButtonWidthPx()
        buttonParams.height = executionButtonHeightPx()
        button.textSize = executionButtonTextSizeSp()
        button.background = buttonBackground()
        overlayWindow.updateViewLayout(button, buttonParams)
    }

    private fun updateProfile(
        profile: LoadedMultiPointProfileState,
        isRunning: Boolean,
        isBlocked: Boolean,
    ) {
        view?.apply {
            text = if (isRunning) "停止 ${profile.displayName}" else profile.displayName
            alpha = if (isBlocked) 0.62f else 1f
            background = buttonBackground(isRunning)
            contentDescription = if (isRunning) {
                "停止配置任务：${profile.displayName}"
            } else {
                "执行配置任务：${profile.displayName}"
            }
        }
    }

    private fun createView(): TextView {
        return TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = executionButtonTextSizeSp()
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(
                overlayWindow.dp(12),
                0,
                overlayWindow.dp(12),
                0,
            )
            background = buttonBackground(isRunning = false)
            elevation = overlayWindow.dp(8).toFloat()
            isClickable = true
        }
    }

    private fun buttonBackground(isRunning: Boolean = false): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = overlayWindow.dp(16).toFloat()
            setColor(if (isRunning) OverlayColors.DANGER_SOFT else OverlayColors.PANEL)
            setStroke(
                metrics.actionButtonStrokePx,
                if (isRunning) OverlayColors.DANGER else OverlayColors.ACCENT,
            )
        }
    }

    private fun executionButtonWidthPx(): Int {
        return (metrics.actionButtonSizePx * 3.2f).toInt().coerceAtLeast(overlayWindow.dp(112))
    }

    private fun executionButtonHeightPx(): Int {
        return metrics.actionButtonSizePx.coerceAtLeast(overlayWindow.dp(42))
    }

    private fun executionButtonTextSizeSp(): Float {
        return 13f
    }
}
