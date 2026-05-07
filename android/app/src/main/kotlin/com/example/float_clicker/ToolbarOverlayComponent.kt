package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
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
                width = overlayWindow.dp(52),
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
        }
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun createView(): LinearLayout {
        val background = GradientDrawable().apply {
            cornerRadius = overlayWindow.dp(18).toFloat()
            setColor(Color.argb(236, 36, 39, 43))
        }

        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(overlayWindow.dp(4), overlayWindow.dp(6), overlayWindow.dp(4), overlayWindow.dp(6))
            this.background = background
            elevation = overlayWindow.dp(8).toFloat()

            addView(toolbarButton("✥", textSize = 24f, onClick = null))
            addView(toolbarButton("▶", textSize = 24f) { onTaskAction() })
            addView(toolbarButton("■", textSize = 20f) { onEndTask() })
            addView(toolbarButton("×", textSize = 24f) { onClose() })
        }
    }

    private fun toolbarButton(text: String, textSize: Float, onClick: (() -> Unit)?): TextView {
        return TextView(context).apply {
            this.text = text
            this.textSize = textSize
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            isClickable = onClick != null
            if (onClick != null) {
                setOnClickListener { onClick() }
            }
            layoutParams = LinearLayout.LayoutParams(overlayWindow.dp(44), overlayWindow.dp(40))
        }
    }

    private fun handleDragButtonClick() {
        if (canCollapse) {
            onCollapse()
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
        TaskRunState.PAUSED -> 24f
        TaskRunState.RUNNING -> 20f
    }
}

internal fun taskActionContentDescription(taskRunState: TaskRunState): String {
    return when (taskRunState) {
        TaskRunState.IDLE -> "开始点击"
        TaskRunState.RUNNING -> "暂停点击"
        TaskRunState.PAUSED -> "继续点击"
    }
}
