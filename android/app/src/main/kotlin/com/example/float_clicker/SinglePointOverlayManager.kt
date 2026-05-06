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

    private var targetView: View? = null
    private var targetParams: WindowManager.LayoutParams? = null
    private var toolbarView: LinearLayout? = null
    private var isRunning = false

    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var tapDurationMs = 50

    fun show(settings: SinglePointOverlaySettings = SinglePointOverlaySettings()) {
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)

        if (targetView != null || toolbarView != null) {
            return
        }

        val target = createTargetView()
        val toolbar = createToolbarView()
        val nextTargetParams = overlayParams(width = dp(38), height = dp(38), x = dp(280), y = dp(260))
        val toolbarParams = overlayParams(width = dp(52), height = WindowManager.LayoutParams.WRAP_CONTENT, x = dp(18), y = dp(180))

        bindDrag(target, nextTargetParams)
        bindDrag(toolbar.getChildAt(0), toolbarParams)

        windowManager.addView(target, nextTargetParams)
        windowManager.addView(toolbar, toolbarParams)

        targetView = target
        targetParams = nextTargetParams
        toolbarView = toolbar
        refreshToolbarState()
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
        val params = targetParams ?: return false
        val target = targetView ?: return false
        val centerX = (params.x + target.width / 2f)
        val centerY = (params.y + target.height / 2f)
        val started = SinglePointClickScheduler.start {
            SinglePointClickRequest(
                x = centerX,
                y = centerY,
                intervalMs = intervalMs,
                repeatCount = repeatCount,
                infiniteLoop = infiniteLoop,
                tapDurationMs = tapDurationMs,
            )
        }

        isRunning = started
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
        (toolbar.getChildAt(1) as? TextView)?.alpha = if (isRunning) 0.45f else 1f
        (toolbar.getChildAt(2) as? TextView)?.alpha = if (isRunning) 1f else 0.45f
    }

    private fun overlayParams(width: Int, height: Int, x: Int, y: Int): WindowManager.LayoutParams {
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
        params.flags = if (isTouchable) {
            params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        windowManager.updateViewLayout(target, params)
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
