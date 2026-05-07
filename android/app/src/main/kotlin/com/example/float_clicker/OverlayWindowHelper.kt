package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.roundToInt

internal class OverlayWindowHelper(
    private val context: Context,
    private val windowManager: WindowManager,
) {
    fun addView(view: View, params: WindowManager.LayoutParams) {
        windowManager.addView(view, params)
    }

    fun updateViewLayout(view: View, params: WindowManager.LayoutParams) {
        windowManager.updateViewLayout(view, params)
    }

    fun removeView(view: View?) {
        if (view == null) {
            return
        }

        runCatching {
            windowManager.removeView(view)
        }
    }

    fun overlayParams(
        width: Int,
        height: Int,
        position: OverlayPoint,
    ): WindowManager.LayoutParams {
        // Android O 之后必须使用 TYPE_APPLICATION_OVERLAY；老版本继续兼容 TYPE_PHONE。
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        return WindowManager.LayoutParams(
            width,
            height,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dpPosition(position.x)
            y = dpPosition(position.y)
        }
    }

    fun moveTo(view: View?, params: WindowManager.LayoutParams?, position: OverlayPoint) {
        if (view == null || params == null) {
            return
        }

        params.x = dpPosition(position.x)
        params.y = dpPosition(position.y)
        updateViewLayout(view, params)
    }

    fun coercePosition(position: OverlayPoint, widthDp: Int, heightDp: Int): OverlayPoint {
        val metrics = context.resources.displayMetrics
        val screenWidthDp = logicalPosition(metrics.widthPixels)
        val screenHeightDp = logicalPosition(metrics.heightPixels)
        val maxX = (screenWidthDp - widthDp).coerceAtLeast(0)
        val maxY = (screenHeightDp - heightDp).coerceAtLeast(0)

        return OverlayPoint(
            x = position.x.coerceIn(0, maxX),
            y = position.y.coerceIn(0, maxY),
        )
    }

    fun bindDrag(
        view: View,
        params: WindowManager.LayoutParams,
        onPositionChanged: (OverlayPoint) -> Unit = {},
        onClick: (() -> Unit)? = null,
        onLongClick: (() -> Unit)? = null,
        longPressDelayMs: Long = 700L,
    ) {
        var startRawX = 0f
        var startRawY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        var longPressed = false
        var longPressRunnable: Runnable? = null

        view.setOnTouchListener { touchedView, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    // rawX/rawY 是屏幕坐标；params.x/y 是 overlay 左上角坐标。
                    startRawX = event.rawX
                    startRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    longPressed = false
                    longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    if (onLongClick != null) {
                        longPressRunnable = Runnable {
                            longPressed = true
                            touchedView.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                            onLongClick()
                        }.also { touchedView.postDelayed(it, longPressDelayMs) }
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startRawX
                    val dy = event.rawY - startRawY
                    // 小于 3dp 的抖动仍当作点击，避免想点按钮时被误判为拖拽。
                    val hasMovedPastThreshold = abs(dx) > dp(3) || abs(dy) > dp(3)
                    moved = moved || hasMovedPastThreshold
                    if (hasMovedPastThreshold) {
                        longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    }
                    params.x = startX + dx.roundToInt()
                    params.y = startY + dy.roundToInt()
                    updateViewLayout(touchedView.rootView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    if (!moved) {
                        if (longPressed) {
                            // 长按已经消费本次手势，松手时不能再补一次单击。
                        } else if (onClick == null) {
                            touchedView.performClick()
                        } else {
                            onClick()
                        }
                    } else {
                        onPositionChanged(OverlayPoint(x = logicalPosition(params.x), y = logicalPosition(params.y)))
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    true
                }
                else -> false
            }
        }
    }

    fun floatingButton(text: String, textSize: Float, onClick: () -> Unit): TextView {
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.argb(236, 36, 39, 43))
        }

        return TextView(context).apply {
            this.text = text
            this.textSize = textSize
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            this.background = background
            elevation = dp(8).toFloat()
            isClickable = true
            setOnClickListener { onClick() }
        }
    }

    fun dp(value: Int): Int {
        return (value * context.resources.displayMetrics.density).roundToInt()
    }

    private fun dpPosition(value: Int): Int {
        // Flutter 持久化的是逻辑像素；WindowManager 需要真实屏幕像素。
        return dp(value)
    }

    private fun logicalPosition(value: Int): Int {
        val density = context.resources.displayMetrics.density
        return (value / density).roundToInt()
    }
}
