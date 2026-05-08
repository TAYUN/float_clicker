package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.Point
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.roundToInt

internal object OverlayColors {
    const val PANEL = 0xEC24272B.toInt()
    const val PANEL_PRESSED = 0xF0323740.toInt()
    const val ACCENT = 0xFF1976D2.toInt()
    const val ACCENT_SOFT = 0x331976D2
    const val DANGER = 0xFFFF8A80.toInt()
    const val DANGER_SOFT = 0x26FF5252
    const val TEXT_PRIMARY = 0xFFFFFFFF.toInt()
    const val TEXT_MUTED = 0xCCFFFFFF.toInt()
}

internal class OverlayWindowHelper(
    private val context: Context,
    private val windowManager: WindowManager,
) {
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

    fun addView(view: View, params: WindowManager.LayoutParams): Boolean {
        return runCatching {
            windowManager.addView(view, params)
        }.isSuccess
    }

    fun updateViewLayout(view: View, params: WindowManager.LayoutParams): Boolean {
        return runCatching {
            windowManager.updateViewLayout(view, params)
        }.isSuccess
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
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dpPosition(position.x)
            y = dpPosition(position.y)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    fun moveTo(view: View?, params: WindowManager.LayoutParams?, position: OverlayPoint) {
        if (view == null || params == null) {
            return
        }

        params.x = dpPosition(position.x)
        params.y = dpPosition(position.y)
        coerceParamsToVisibleBounds(view, params)
        updateViewLayout(view, params)
    }

    fun coercePositionPx(position: OverlayPoint, widthPx: Int, heightPx: Int): OverlayPoint {
        val bounds = overlayBoundsPx(view = null)
        val left = logicalPosition(bounds.left)
        val top = logicalPosition(bounds.top)
        val maxX = logicalPosition((bounds.right - widthPx).coerceAtLeast(bounds.left))
        val maxY = logicalPosition((bounds.bottom - heightPx).coerceAtLeast(bounds.top))

        return OverlayPoint(
            x = position.x.coerceIn(left, maxX),
            y = position.y.coerceIn(top, maxY),
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
                    // 横竖屏或系统栏显隐后 params 可能仍是旧边界下的值；按当前可拖动区域收回边界。
                    coerceParamsToVisibleBounds(touchedView.rootView, params)
                    touchedView.isPressed = true
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
                    coerceParamsToVisibleBounds(touchedView.rootView, params)
                    updateViewLayout(touchedView.rootView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    touchedView.isPressed = false
                    longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    if (!moved) {
                        if (longPressed) {
                            // 长按已经消费本次手势，松手时不能再补一次单击。
                        } else if (onClick == null) {
                            touchedView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            touchedView.performClick()
                        } else {
                            touchedView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            onClick()
                        }
                    } else {
                        touchedView.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        notifyPositionChanged(params, onPositionChanged)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    touchedView.isPressed = false
                    longPressRunnable?.let { touchedView.removeCallbacks(it) }
                    true
                }
                else -> false
            }
        }
    }

    fun floatingButton(
        text: String,
        textSize: Float,
        backgroundColor: Int = OverlayColors.PANEL,
        onClick: () -> Unit,
    ): TextView {
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(backgroundColor)
        }

        return TextView(context).apply {
            this.text = text
            this.textSize = textSize
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            includeFontPadding = false
            maxLines = 1
            this.background = background
            elevation = dp(8).toFloat()
            isClickable = true
            setOnClickListener { onClick() }
        }
    }

    fun dp(value: Int): Int {
        return (value * context.resources.displayMetrics.density).roundToInt()
    }

    fun dp(value: Float): Int {
        return (value * context.resources.displayMetrics.density).roundToInt()
    }

    private fun dpPosition(value: Int): Int {
        // Flutter 持久化的是逻辑像素；WindowManager 需要真实屏幕像素。
        return dp(value)
    }

    private fun notifyPositionChanged(
        params: WindowManager.LayoutParams,
        onPositionChanged: (OverlayPoint) -> Unit,
    ) {
        onPositionChanged(OverlayPoint(x = logicalPosition(params.x), y = logicalPosition(params.y)))
    }

    private fun coerceParamsToVisibleBounds(view: View, params: WindowManager.LayoutParams) {
        val bounds = overlayBoundsPx(view)
        val viewWidth = viewSizeOrParamSize(view.width, params.width)
        val viewHeight = viewSizeOrParamSize(view.height, params.height)
        val maxX = (bounds.right - viewWidth).coerceAtLeast(bounds.left)
        val maxY = (bounds.bottom - viewHeight).coerceAtLeast(bounds.top)
        val nextX = params.x.coerceIn(bounds.left, maxX)
        val nextY = params.y.coerceIn(bounds.top, maxY)

        if (nextX == params.x && nextY == params.y) {
            return
        }

        params.x = nextX
        params.y = nextY
        updateViewLayout(view, params)
    }

    private fun overlayBoundsPx(view: View?): OverlayBoundsPx {
        val screenSize = realScreenSizePx()
        val isPortrait = screenSize.second >= screenSize.first

        if (!isPortrait) {
            // 横屏下部分系统会把 overlay 的可用宽度报告成竖屏宽度，导致右侧过早卡住。
            // 这里放宽右/下边界，仅保留左/上非负，用户仍可拖回可见区域。
            val relaxedMax = Int.MAX_VALUE / 4
            return OverlayBoundsPx(left = 0, top = 0, right = relaxedMax, bottom = relaxedMax)
        }

        val topInset = statusBarHeightPx()
        return OverlayBoundsPx(
            left = 0,
            top = topInset,
            right = screenSize.first,
            bottom = screenSize.second,
        )
    }

    private fun viewSizeOrParamSize(viewSize: Int, paramSize: Int): Int {
        if (viewSize > 0) {
            return viewSize
        }

        return if (paramSize > 0) paramSize else 0
    }

    private fun statusBarHeightPx(): Int {
        val resourceId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId <= 0) {
            return dp(24)
        }

        return context.resources.getDimensionPixelSize(resourceId)
    }

    private fun realScreenSizePx(): Pair<Int, Int> {
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val size = Point()
        if (display != null) {
            @Suppress("DEPRECATION")
            display.getRealSize(size)
            if (size.x > 0 && size.y > 0) {
                return Pair(size.x, size.y)
            }
        }

        val metrics = context.resources.displayMetrics
        return Pair(metrics.widthPixels, metrics.heightPixels)
    }

    private fun logicalPosition(value: Int): Int {
        val density = context.resources.displayMetrics.density
        return (value / density).roundToInt()
    }
}

private data class OverlayBoundsPx(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
)
