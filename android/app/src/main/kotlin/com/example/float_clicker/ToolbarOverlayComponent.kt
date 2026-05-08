package com.example.float_clicker

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

internal class ToolbarOverlayComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
    private val onTaskAction: () -> Unit,
    private val onEndTask: () -> Unit,
    private val onClose: () -> Unit,
    private val onCollapse: () -> Unit,
    private val closeContentDescription: String = "关闭单点模式",
) {
    private var view: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var canCollapse = false
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    fun show(
        position: OverlayPoint,
        taskRunState: TaskRunState,
        canCollapse: Boolean,
        metrics: OverlayComponentMetrics,
    ) {
        this.canCollapse = canCollapse
        this.metrics = metrics
        if (view == null) {
            val toolbar = createView()
            val nextParams = overlayWindow.overlayParams(
                width = metrics.toolbarWidthPx,
                height = WindowManager.LayoutParams.WRAP_CONTENT,
                position = position,
            )
            // 工具条只让第一个“移动”按钮负责拖动，避免运行/关闭按钮拦截整条工具条的移动手势。
            overlayWindow.bindDrag(
                view = toolbar.getChildAt(0),
                params = nextParams,
                onPositionChanged = { point -> onPositionChanged(point) },
                onClick = ::handleDragButtonClick,
            )
            if (!overlayWindow.addView(toolbar, nextParams)) {
                return
            }
            view = toolbar
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        moveTo(position)
        updateTaskRunState(taskRunState)
    }

    fun moveTo(position: OverlayPoint) {
        overlayWindow.moveTo(view, params, position)
    }

    fun updateTaskRunState(taskRunState: TaskRunState) {
        val toolbar = view ?: return
        (toolbar.getChildAt(1) as? TextView)?.apply {
            text = taskActionText(taskRunState)
            textSize = taskActionTextSize(taskRunState, metrics)
            contentDescription = taskActionContentDescription(taskRunState)
            setButtonBackground(this, taskActionBackgroundColor(taskRunState))
            layoutParams = LinearLayout.LayoutParams(metrics.toolbarButtonWidthPx, metrics.toolbarButtonHeightPx)
        }
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val toolbar = view ?: return
        val toolbarParams = params ?: return
        toolbarParams.width = metrics.toolbarWidthPx
        toolbar.background = toolbarBackground()
        toolbar.setPadding(
            metrics.toolbarPaddingHorizontalPx,
            metrics.toolbarPaddingVerticalPx,
            metrics.toolbarPaddingHorizontalPx,
            metrics.toolbarPaddingVerticalPx,
        )
        toolbar.elevation = metrics.toolbarElevationPx.toFloat()
        updateStaticButtonStyle(toolbar)
        overlayWindow.updateViewLayout(toolbar, toolbarParams)
    }

    private fun createView(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(
                metrics.toolbarPaddingHorizontalPx,
                metrics.toolbarPaddingVerticalPx,
                metrics.toolbarPaddingHorizontalPx,
                metrics.toolbarPaddingVerticalPx,
            )
            this.background = toolbarBackground()
            elevation = metrics.toolbarElevationPx.toFloat()

            addView(toolbarButton("✥", textSize = metrics.toolbarDragTextSizeSp, contentDescription = "移动控制条", onClick = null))
            addView(toolbarButton("▶", textSize = metrics.toolbarTaskTextSizeSp, contentDescription = "开始点击") { onTaskAction() })
            addView(
                toolbarButton(
                    "■",
                    textSize = metrics.toolbarEndTextSizeSp,
                    contentDescription = "结束任务",
                    textColor = OverlayColors.DANGER,
                ) { onEndTask() },
            )
            addView(toolbarButton("×", textSize = metrics.toolbarCloseTextSizeSp, contentDescription = closeContentDescription) { onClose() })
        }
    }

    private fun toolbarButton(
        text: String,
        textSize: Float,
        contentDescription: String,
        backgroundColor: Int? = null,
        textColor: Int = OverlayColors.TEXT_PRIMARY,
        onClick: (() -> Unit)?,
    ): TextView {
        return TextView(context).apply {
            this.text = text
            this.textSize = textSize
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(textColor)
            gravity = Gravity.CENTER
            includeFontPadding = false
            this.contentDescription = contentDescription
            backgroundColor?.let { setButtonBackground(this, it) }
            isClickable = onClick != null
            if (onClick != null) {
                setOnClickListener {
                    performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                    onClick()
                }
            }
            layoutParams = LinearLayout.LayoutParams(metrics.toolbarButtonWidthPx, metrics.toolbarButtonHeightPx)
        }
    }

    private fun handleDragButtonClick() {
        if (canCollapse) {
            onCollapse()
        }
    }

    private fun setButtonBackground(button: TextView, color: Int) {
        button.background = GradientDrawable().apply {
            cornerRadius = metrics.toolbarButtonCornerRadiusPx.toFloat()
            setColor(color)
            setStroke(metrics.toolbarButtonStrokePx, OverlayColors.ACCENT)
        }
    }

    private fun toolbarBackground(): GradientDrawable {
        return GradientDrawable().apply {
            cornerRadius = metrics.toolbarCornerRadiusPx.toFloat()
            setColor(OverlayColors.PANEL)
        }
    }

    private fun updateStaticButtonStyle(toolbar: LinearLayout) {
        (toolbar.getChildAt(0) as? TextView)?.apply {
            textSize = metrics.toolbarDragTextSizeSp
            layoutParams = LinearLayout.LayoutParams(metrics.toolbarButtonWidthPx, metrics.toolbarButtonHeightPx)
        }
        (toolbar.getChildAt(2) as? TextView)?.apply {
            textSize = metrics.toolbarEndTextSizeSp
            layoutParams = LinearLayout.LayoutParams(metrics.toolbarButtonWidthPx, metrics.toolbarButtonHeightPx)
        }
        (toolbar.getChildAt(3) as? TextView)?.apply {
            textSize = metrics.toolbarCloseTextSizeSp
            layoutParams = LinearLayout.LayoutParams(metrics.toolbarButtonWidthPx, metrics.toolbarButtonHeightPx)
        }
    }
}

internal fun taskActionText(taskRunState: TaskRunState): String {
    return when (taskRunState) {
        TaskRunState.IDLE -> "▶"
        TaskRunState.RUNNING -> "Ⅱ"
        TaskRunState.PAUSED -> "▶"
    }
}

internal fun taskActionTextSize(
    taskRunState: TaskRunState,
    metrics: OverlayComponentMetrics,
): Float {
    return when (taskRunState) {
        TaskRunState.IDLE,
        TaskRunState.PAUSED -> metrics.toolbarTaskTextSizeSp
        TaskRunState.RUNNING -> metrics.toolbarPauseTextSizeSp
    }
}

internal fun taskActionContentDescription(taskRunState: TaskRunState): String {
    return when (taskRunState) {
        TaskRunState.IDLE -> "开始点击"
        TaskRunState.RUNNING -> "暂停点击"
        TaskRunState.PAUSED -> "继续点击"
    }
}

internal fun taskActionBackgroundColor(taskRunState: TaskRunState): Int {
    return when (taskRunState) {
        TaskRunState.IDLE,
        TaskRunState.RUNNING,
        TaskRunState.PAUSED -> OverlayColors.ACCENT_SOFT
    }
}
