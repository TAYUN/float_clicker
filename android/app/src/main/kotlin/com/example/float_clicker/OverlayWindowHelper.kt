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
import android.view.Surface
import android.view.View
import android.view.WindowInsets
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
    private val metricsWindowManager: WindowManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context
                .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
                .getSystemService(WindowManager::class.java)
        } else {
            windowManager
        }

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
                    val dragBoundsMode = dragBoundsModeFor(event.rawX)
                    coerceParamsToVisibleBounds(
                        view = touchedView.rootView,
                        params = params,
                        relaxRight = dragBoundsMode.relaxRight,
                        forceLandscapeVerticalBounds = dragBoundsMode.forceLandscapeVerticalBounds,
                    )
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

    private fun coerceParamsToVisibleBounds(
        view: View,
        params: WindowManager.LayoutParams,
        relaxRight: Boolean = false,
        forceLandscapeVerticalBounds: Boolean = false,
    ) {
        val bounds = overlayBoundsPx(
            view = view,
            relaxRight = relaxRight,
            forceLandscapeVerticalBounds = forceLandscapeVerticalBounds,
        )
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

    private fun overlayBoundsPx(
        view: View?,
        relaxRight: Boolean = false,
        forceLandscapeVerticalBounds: Boolean = false,
    ): OverlayBoundsPx {
        val screenSize = realScreenSizePx()
        val isPortrait = screenSize.second >= screenSize.first
        val treatAsLandscape = forceLandscapeVerticalBounds || !isPortrait
        val topInset = if (treatAsLandscape) 0 else statusBarHeightPx()
        // 跨应用横屏时系统可能持续返回竖屏宽度；拖动 rawX 超出旧宽度后只放宽右边界。
        // 竖屏仍保持严格右边界，避免点位跑出屏幕右侧。
        val right = if (relaxRight || treatAsLandscape) {
            maxOf(screenSize.first, screenSize.second)
        } else {
            screenSize.first
        }
        val bottom = if (treatAsLandscape) {
            minOf(screenSize.first, screenSize.second)
        } else {
            maxOf(screenSize.first, screenSize.second)
        }
        return OverlayBoundsPx(
            left = 0,
            top = topInset,
            right = right,
            bottom = bottom,
        )
    }

    private fun viewSizeOrParamSize(viewSize: Int, paramSize: Int): Int {
        if (viewSize > 0) {
            return viewSize
        }

        return if (paramSize > 0) paramSize else 0
    }

    private fun statusBarHeightPx(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val topInset = metricsWindowManager.maximumWindowMetrics.windowInsets
                .getInsetsIgnoringVisibility(WindowInsets.Type.statusBars())
                .top
            if (topInset > 0) {
                return topInset
            }
        }

        return legacyStatusBarHeightPx()
    }

    @Suppress("DiscouragedApi", "InternalInsetResource")
    private fun legacyStatusBarHeightPx(): Int {
        val resourceId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId <= 0) {
            return dp(24)
        }

        return context.resources.getDimensionPixelSize(resourceId)
    }

    private fun realScreenSizePx(): Pair<Int, Int> {
        windowMetricsScreenSizePx()?.let { return it }

        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val size = Point()
        if (display != null) {
            @Suppress("DEPRECATION")
            display.getRealSize(size)
            if (size.x > 0 && size.y > 0) {
                return rotatedScreenSizePx(display, size)
            }
        }

        val metrics = context.resources.displayMetrics
        return Pair(metrics.widthPixels, metrics.heightPixels)
    }

    private fun windowMetricsScreenSizePx(): Pair<Int, Int>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }

        val bounds = metricsWindowManager.maximumWindowMetrics.bounds
        if (bounds.width() <= 0 || bounds.height() <= 0) {
            return null
        }

        // TYPE_APPLICATION_OVERLAY 的 WindowContext 比 Activity context 更接近悬浮窗实际所在显示区域。
        return Pair(bounds.width(), bounds.height())
    }

    private fun dragBoundsModeFor(rawX: Float): DragBoundsMode {
        val screenSize = realScreenSizePx()
        val strictWidth = minOf(screenSize.first, screenSize.second)
        val crossesOldPortraitWidth = rawX.roundToInt() > strictWidth
        return DragBoundsMode(
            relaxRight = crossesOldPortraitWidth,
            forceLandscapeVerticalBounds = crossesOldPortraitWidth,
        )
    }

    private fun rotatedScreenSizePx(display: Display, size: Point): Pair<Int, Int> {
        val longSide = maxOf(size.x, size.y)
        val shortSide = minOf(size.x, size.y)

        return when (display.rotation) {
            Surface.ROTATION_90,
            Surface.ROTATION_270,
            -> {
                // 跨应用横屏时部分设备仍会把 realSize 报成竖屏宽高；用 rotation 纠正边界方向。
                Pair(longSide, shortSide)
            }
            else -> Pair(shortSide, longSide)
        }
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

private data class DragBoundsMode(
    val relaxRight: Boolean,
    val forceLandscapeVerticalBounds: Boolean,
)
