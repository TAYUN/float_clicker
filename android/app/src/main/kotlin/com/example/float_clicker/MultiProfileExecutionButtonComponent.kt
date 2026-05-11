package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
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
                width = executionButtonSizePx(),
                height = executionButtonSizePx(),
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
        buttonParams.width = executionButtonSizePx()
        buttonParams.height = executionButtonSizePx()
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
            // 多个执行控件会长期停留在屏幕侧边；这里只保留短标签，优先换取更小遮挡面积。
            text = buttonLabel(profile, isRunning)
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
            setPadding(0, 0, 0, 0)
            background = buttonBackground(isRunning = false)
            elevation = overlayWindow.dp(8).toFloat()
            isClickable = true
        }
    }

    private fun buttonBackground(isRunning: Boolean = false): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (isRunning) OverlayColors.DANGER_SOFT else OverlayColors.PANEL)
            setStroke(
                metrics.actionButtonStrokePx,
                if (isRunning) OverlayColors.DANGER else OverlayColors.ACCENT,
            )
        }
    }

    private fun buttonLabel(profile: LoadedMultiPointProfileState, isRunning: Boolean): String {
        return if (isRunning) {
            "停止"
        } else {
            compactLabel(profile.displayName)
        }
    }

    private fun compactLabel(displayName: String): String {
        val trimmed = displayName.trim()
        if (trimmed.isEmpty()) {
            return "配置"
        }

        val tokenizedInitials = trimmed
            .split(Regex("[\\s_-]+"))
            .mapNotNull { token -> token.firstOrNull()?.takeIf { !it.isWhitespace() } }
            .take(2)
            .joinToString("")
        if (tokenizedInitials.length >= 2) {
            return tokenizedInitials.uppercase()
        }

        val condensed = trimmed.filterNot(Char::isWhitespace)
        if (condensed.length <= 2) {
            return condensed.uppercase()
        }

        val asciiOnly = condensed.all { it.code <= 0x7F }
        return if (asciiOnly) {
            condensed.take(2).uppercase()
        } else {
            condensed.take(2)
        }
    }

    private fun executionButtonSizePx(): Int {
        return metrics.actionButtonSizePx.coerceAtLeast(overlayWindow.dp(46))
    }

    private fun executionButtonTextSizeSp(): Float {
        return 10.5f
    }
}
