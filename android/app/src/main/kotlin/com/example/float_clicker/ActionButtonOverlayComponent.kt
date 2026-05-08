package com.example.float_clicker

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import android.view.WindowManager
import kotlin.math.min

internal class ActionButtonOverlayComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
    private val onTaskAction: () -> Unit,
    private val onEndTask: () -> Unit,
) {
    private var view: ActionButtonView? = null
    private var params: WindowManager.LayoutParams? = null

    fun show(position: OverlayPoint, taskRunState: TaskRunState) {
        if (view == null) {
            val actionButton = createView()
            val nextParams = overlayWindow.overlayParams(
                width = overlayWindow.dp(42),
                height = overlayWindow.dp(42),
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
        view?.setTaskRunState(taskRunState)
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun createView(): ActionButtonView {
        return ActionButtonView(context, overlayWindow)
    }
}

private class ActionButtonView(
    context: Context,
    private val overlayWindow: OverlayWindowHelper,
) : View(context) {
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = OverlayColors.ACCENT
        style = Paint.Style.STROKE
        strokeWidth = overlayWindow.dp(2).toFloat()
    }
    private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = OverlayColors.ACCENT
        style = Paint.Style.FILL
    }
    private val playPath = Path()
    private val pauseBar = RectF()
    private var taskRunState = TaskRunState.IDLE

    init {
        isClickable = true
        contentDescription = taskActionContentDescription(taskRunState)
    }

    fun setTaskRunState(value: TaskRunState) {
        if (taskRunState == value) {
            return
        }

        taskRunState = value
        contentDescription = taskActionContentDescription(value)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = min(width, height) / 2f

        fillPaint.color = if (isPressed) OverlayColors.ACCENT_SOFT else 0x00000000
        canvas.drawCircle(cx, cy, radius - strokePaint.strokeWidth / 2f, fillPaint)
        canvas.drawCircle(cx, cy, radius - strokePaint.strokeWidth / 2f, strokePaint)

        when (taskRunState) {
            TaskRunState.RUNNING -> drawPauseIcon(canvas, cx, cy)
            TaskRunState.IDLE,
            TaskRunState.PAUSED -> drawPlayIcon(canvas, cx, cy)
        }
    }

    private fun drawPlayIcon(canvas: Canvas, cx: Float, cy: Float) {
        val iconWidth = overlayWindow.dp(11).toFloat()
        val iconHeight = overlayWindow.dp(14).toFloat()
        // 三角形按字体绘制时容易显得偏左；这里用几何点位让视觉重心落在圆心附近。
        val left = cx - iconWidth * 0.34f
        val right = cx + iconWidth * 0.66f
        val top = cy - iconHeight / 2f
        val bottom = cy + iconHeight / 2f

        playPath.reset()
        playPath.moveTo(left, top)
        playPath.lineTo(left, bottom)
        playPath.lineTo(right, cy)
        playPath.close()
        canvas.drawPath(playPath, iconPaint)
    }

    private fun drawPauseIcon(canvas: Canvas, cx: Float, cy: Float) {
        val barWidth = overlayWindow.dp(3).toFloat()
        val barHeight = overlayWindow.dp(13).toFloat()
        val gap = overlayWindow.dp(3).toFloat()
        val corner = overlayWindow.dp(1).toFloat()
        val totalWidth = barWidth * 2 + gap
        val top = cy - barHeight / 2f
        val bottom = cy + barHeight / 2f
        val leftStart = cx - totalWidth / 2f

        pauseBar.set(leftStart, top, leftStart + barWidth, bottom)
        canvas.drawRoundRect(pauseBar, corner, corner, iconPaint)
        pauseBar.set(leftStart + barWidth + gap, top, leftStart + totalWidth, bottom)
        canvas.drawRoundRect(pauseBar, corner, corner, iconPaint)
    }

    override fun setPressed(pressed: Boolean) {
        if (isPressed == pressed) {
            return
        }

        super.setPressed(pressed)
        invalidate()
    }
}
