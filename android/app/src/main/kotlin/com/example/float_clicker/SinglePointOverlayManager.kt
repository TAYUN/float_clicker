package com.example.float_clicker

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.roundToInt

class SinglePointOverlayManager(private val context: Context) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    // targetView 是用户拖动的点击点；toolbarView 是播放/停止/关闭工具条。
    // params 必须保留下来，因为拖拽时要不断更新 WindowManager 里的 x/y。
    private var targetView: View? = null
    private var targetParams: WindowManager.LayoutParams? = null
    private var toolbarView: LinearLayout? = null
    private var isRunning = false

    // 当前配置保存在 overlay 管理器中。真正开始点击时会打包成 SinglePointClickRequest。
    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var tapDurationMs = 50

    fun show(settings: SinglePointOverlaySettings = SinglePointOverlaySettings()) {
        updateSettings(settings)

        if (targetView != null || toolbarView != null) {
            // 已经显示时不重复 addView，避免 WindowManager 报 view already has parent。
            return
        }

        val target = createTargetView()
        val toolbar = createToolbarView()
        val nextTargetParams = overlayParams(width = dp(38), height = dp(38), x = dp(280), y = dp(260))
        val toolbarParams = overlayParams(width = dp(52), height = WindowManager.LayoutParams.WRAP_CONTENT, x = dp(18), y = dp(180))

        // 点击点整体可拖动；工具条只让第一个“移动”按钮负责拖动。
        bindDrag(target, nextTargetParams)
        bindDrag(toolbar.getChildAt(0), toolbarParams)

        windowManager.addView(target, nextTargetParams)
        windowManager.addView(toolbar, toolbarParams)

        targetView = target
        targetParams = nextTargetParams
        toolbarView = toolbar
        refreshToolbarState()
    }

    fun updateSettings(settings: SinglePointOverlaySettings) {
        // 原生侧做最后一道安全裁剪，防止过小间隔或非法次数把调度器拖进异常状态。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
    }

    fun hide() {
        stop()
        removeView(targetView)
        removeView(toolbarView)
        targetView = null
        targetParams = null
        toolbarView = null
    }

    fun start(): Boolean {
        val target = targetView ?: return false
        // provider 每次点击前都会重新读取目标点中心坐标。
        // 这样用户在点击过程中移动目标点，下一次点击会使用最新位置。
        val started = SinglePointClickScheduler.start {
            val center = targetCenterOnScreen(target)
            SinglePointClickRequest(
                x = center.first,
                y = center.second,
                intervalMs = intervalMs,
                repeatCount = repeatCount,
                infiniteLoop = infiniteLoop,
                tapDurationMs = tapDurationMs,
            )
        }

        isRunning = started
        // 运行时让目标点不拦截触摸，减少它挡住被点击 App 控件的概率。
        setTargetTouchable(!started)
        refreshToolbarState()
        return started
    }

    fun stop() {
        SinglePointClickScheduler.stop()
        isRunning = false
        setTargetTouchable(true)
        refreshToolbarState()
    }

    private fun createTargetView(): View {
        val outer = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.argb(28, 25, 118, 210))
            setStroke(dp(3), Color.rgb(25, 118, 210))
        }
        val inner = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.rgb(25, 118, 210))
        }

        return LinearLayout(context).apply {
            gravity = Gravity.CENTER
            background = outer
            alpha = 0.94f
            addView(
                View(context).apply { background = inner },
                LinearLayout.LayoutParams(dp(8), dp(8)),
            )
        }
    }

    private fun createToolbarView(): LinearLayout {
        val background = GradientDrawable().apply {
            cornerRadius = dp(18).toFloat()
            setColor(Color.argb(236, 36, 39, 43))
        }

        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(4), dp(6), dp(4), dp(6))
            this.background = background
            elevation = dp(8).toFloat()

            // 只有第一个按钮负责拖拽，避免播放/停止/关闭按钮拦截整条工具条的移动手势。
            addView(toolbarButton("✥", textSize = 24f, onClick = null))
            addView(toolbarButton("▶", textSize = 24f) { start() })
            addView(toolbarButton("■", textSize = 18f) { stop() })
            addView(toolbarButton("×", textSize = 24f) { hide() })
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
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(40))
        }
    }

    private fun refreshToolbarState() {
        val toolbar = toolbarView ?: return
        // 当前第一版没有替换图标，只用透明度提示播放/停止哪个按钮可用。
        (toolbar.getChildAt(1) as? TextView)?.alpha = if (isRunning) 0.45f else 1f
        (toolbar.getChildAt(2) as? TextView)?.alpha = if (isRunning) 1f else 0.45f
    }

    private fun overlayParams(width: Int, height: Int, x: Int, y: Int): WindowManager.LayoutParams {
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
            this.x = x
            this.y = y
        }
    }

    private fun setTargetTouchable(isTouchable: Boolean) {
        val target = targetView ?: return
        val params = targetParams ?: return
        // FLAG_NOT_TOUCHABLE 是位标记：开启时点击点透传触摸，关闭时用户可以拖动它。
        params.flags = if (isTouchable) {
            params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        windowManager.updateViewLayout(target, params)
    }

    private fun targetCenterOnScreen(target: View): Pair<Float, Float> {
        val location = IntArray(2)
        // 无障碍手势使用的是屏幕坐标；用 View 的真实屏幕位置可以避开状态栏和 overlay 坐标偏移。
        target.getLocationOnScreen(location)
        return Pair(
            location[0] + target.width / 2f,
            location[1] + target.height / 2f,
        )
    }

    private fun bindDrag(view: View, params: WindowManager.LayoutParams) {
        var startRawX = 0f
        var startRawY = 0f
        var startX = 0
        var startY = 0
        var moved = false

        view.setOnTouchListener { touchedView, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    // rawX/rawY 是屏幕坐标；params.x/y 是 overlay 左上角坐标。
                    // 记录两组起点后，MOVE 时用手指位移去更新悬浮窗位置。
                    startRawX = event.rawX
                    startRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startRawX
                    val dy = event.rawY - startRawY
                    // 小于 3dp 的抖动仍当作点击，避免想点按钮时被误判为拖拽。
                    moved = moved || abs(dx) > dp(3) || abs(dy) > dp(3)
                    params.x = startX + dx.roundToInt()
                    params.y = startY + dy.roundToInt()
                    windowManager.updateViewLayout(touchedView.rootView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        touchedView.performClick()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun removeView(view: View?) {
        if (view == null) {
            return
        }

        runCatching {
            windowManager.removeView(view)
        }
    }

    private fun dp(value: Int): Int {
        return (value * context.resources.displayMetrics.density).roundToInt()
    }
}

data class SinglePointOverlaySettings(
    val intervalMs: Int = 500,
    val repeatCount: Int = 10,
    val infiniteLoop: Boolean = false,
    val tapDurationMs: Int = 50,
)
