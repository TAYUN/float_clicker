package com.example.float_clicker

import android.view.WindowManager
import android.widget.TextView

internal class ActionButtonOverlayComponent(
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
    private val onTaskAction: () -> Unit,
    private val onEndTask: () -> Unit,
) {
    private var view: TextView? = null
    private var params: WindowManager.LayoutParams? = null

    fun show(position: OverlayPoint, taskRunState: TaskRunState) {
        if (view == null) {
            val actionButton = createView()
            val nextParams = overlayWindow.overlayParams(
                width = overlayWindow.dp(52),
                height = overlayWindow.dp(52),
                position = position,
            )
            overlayWindow.bindDrag(
                view = actionButton,
                params = nextParams,
                onPositionChanged = { point -> onPositionChanged(point) },
                onClick = onTaskAction,
                onLongClick = onEndTask,
            )
            overlayWindow.addView(actionButton, nextParams)
            view = actionButton
            params = nextParams
        }

        moveTo(position)
        updateTaskRunState(taskRunState)
    }

    fun moveTo(position: OverlayPoint) {
        overlayWindow.moveTo(view, params, position)
    }

    fun updateTaskRunState(taskRunState: TaskRunState) {
        view?.apply {
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

    private fun createView(): TextView {
        return overlayWindow.floatingButton("▶", textSize = 24f) { onTaskAction() }
    }
}
