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
) {
    private var view: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var canCollapse = false

    fun show(position: OverlayPoint, taskRunState: TaskRunState, canCollapse: Boolean) {
        this.canCollapse = canCollapse
        if (view == null) {
            val toolbar = createView()
            val nextParams = overlayWindow.overlayParams(
                width = overlayWindow.dp(42),
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
            overlayWindow.addView(toolbar, nextParams)
            view = toolbar
            params = nextParams
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
            textSize = taskActionTextSize(taskRunState)
            contentDescription = taskActionContentDescription(taskRunState)
            setButtonBackground(this, taskActionBackgroundColor(taskRunState))
        }
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun createView(): LinearLayout {
        val background = GradientDrawable().apply {
            cornerRadius = overlayWindow.dp(15).toFloat()
            setColor(OverlayColors.PANEL)
        }

        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(overlayWindow.dp(3), overlayWindow.dp(4), overlayWindow.dp(3), overlayWindow.dp(4))
            this.background = background
            elevation = overlayWindow.dp(8).toFloat()

            addView(toolbarButton("✥", textSize = 20f, contentDescription = "移动控制条", onClick = null))
            addView(toolbarButton("▶", textSize = 19f, contentDescription = "开始点击") { onTaskAction() })
            addView(
                toolbarButton(
                    "■",
                    textSize = 15f,
                    contentDescription = "结束任务",
                    textColor = OverlayColors.DANGER,
                ) { onEndTask() },
            )
            addView(toolbarButton("×", textSize = 20f, contentDescription = "关闭单点模式") { onClose() })
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
            layoutParams = LinearLayout.LayoutParams(overlayWindow.dp(34), overlayWindow.dp(32))
        }
    }

    private fun handleDragButtonClick() {
        if (canCollapse) {
            onCollapse()
        }
    }

    private fun setButtonBackground(button: TextView, color: Int) {
        button.background = GradientDrawable().apply {
            cornerRadius = overlayWindow.dp(11).toFloat()
            setColor(color)
            setStroke(overlayWindow.dp(1), OverlayColors.ACCENT)
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

internal fun taskActionTextSize(taskRunState: TaskRunState): Float {
    return when (taskRunState) {
        TaskRunState.IDLE,
        TaskRunState.PAUSED -> 19f
        TaskRunState.RUNNING -> 16f
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
