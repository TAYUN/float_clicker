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

class SinglePointOverlayManager(
    private val context: Context,
    private val onOverlayStateChanged: (SinglePointOverlaySnapshot) -> Unit = {},
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    // targetView 是用户拖动的点击点；toolbarView 是运行/关闭工具条。
    // params 必须保留下来，因为拖拽时要不断更新 WindowManager 里的 x/y。
    private var targetView: View? = null
    private var targetParams: WindowManager.LayoutParams? = null
    private var toolbarView: LinearLayout? = null
    private var toolbarParams: WindowManager.LayoutParams? = null
    private var collapsedToolbarView: TextView? = null
    private var collapsedToolbarParams: WindowManager.LayoutParams? = null
    private var actionButtonView: TextView? = null
    private var actionButtonParams: WindowManager.LayoutParams? = null
    private var taskStatus = SinglePointTaskStatus()
    private var interactionState = OverlayInteractionState()

    // 当前配置保存在 overlay 管理器中。真正开始点击时会打包成 SinglePointClickRequest。
    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var tapDurationMs = 50
    val isShowing: Boolean
        get() = targetView != null && toolbarView != null
    val snapshot: SinglePointOverlaySnapshot
        get() = SinglePointOverlaySnapshot(
            isEnabled = isShowing,
            taskRunState = if (isShowing) taskStatus.taskRunState else TaskRunState.IDLE,
            executedCount = if (isShowing) taskStatus.executedCount else 0,
        )

    fun show(settings: SinglePointOverlaySettings = SinglePointOverlaySettings()) {
        updateSettings(settings)

        if (targetView != null) {
            // 已经显示时不重复 addView，避免 WindowManager 报 view already has parent。
            refreshInteractionViews()
            return
        }

        val target = createTargetView()
        val nextTargetParams = overlayParams(
            width = dp(38),
            height = dp(38),
            x = dpPosition(interactionState.targetPosition.x),
            y = dpPosition(interactionState.targetPosition.y),
        )

        bindDrag(target, nextTargetParams) { point ->
            interactionState = interactionState.copy(targetPosition = point)
        }

        windowManager.addView(target, nextTargetParams)

        targetView = target
        targetParams = nextTargetParams
        refreshInteractionViews()
        notifyOverlayStateChanged()
    }

    fun updateSettings(settings: SinglePointOverlaySettings) {
        // 原生侧做最后一道安全裁剪，防止过小间隔或非法次数把调度器拖进异常状态。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
        interactionState = settings.interactionState
        refreshInteractionViews()
    }

    fun updateClickSettings(settings: SinglePointOverlaySettings) {
        // 设置页可能只更新点击参数；交互位置和当前模式不能因此回到默认值。
        intervalMs = settings.intervalMs.coerceAtLeast(50)
        repeatCount = settings.repeatCount.coerceAtLeast(1)
        infiniteLoop = settings.infiniteLoop
        tapDurationMs = settings.tapDurationMs.coerceAtLeast(1)
    }

    fun updateInteractionState(state: OverlayInteractionState) {
        interactionState = state
        refreshInteractionViews()
    }

    fun hide() {
        end()
        removeView(targetView)
        removeView(toolbarView)
        removeView(collapsedToolbarView)
        removeView(actionButtonView)
        targetView = null
        targetParams = null
        toolbarView = null
        toolbarParams = null
        collapsedToolbarView = null
        collapsedToolbarParams = null
        actionButtonView = null
        actionButtonParams = null
        notifyOverlayStateChanged()
    }

    fun start(): Boolean {
        if (taskStatus.taskRunState != TaskRunState.IDLE) {
            return false
        }

        val target = targetView ?: return false
        // provider 每次点击前都会重新读取目标点中心坐标。
        // 这样用户在点击过程中移动目标点，下一次点击会使用最新位置。
        val started = SinglePointClickScheduler.start(
            provider = {
                val center = targetCenterOnScreen(target)
                SinglePointClickRequest(
                    x = center.first,
                    y = center.second,
                    intervalMs = intervalMs,
                    repeatCount = repeatCount,
                    infiniteLoop = infiniteLoop,
                    tapDurationMs = tapDurationMs,
                )
            },
            onStatusChanged = ::handleSchedulerStatusChanged,
        )

        // 运行时让目标点不拦截触摸，减少它挡住被点击 App 控件的概率。
        return started
    }

    fun pause(): Boolean {
        return SinglePointClickScheduler.pause()
    }

    fun resume(): Boolean {
        return SinglePointClickScheduler.resume()
    }

    fun end() {
        SinglePointClickScheduler.end()
        if (taskStatus.taskRunState != TaskRunState.IDLE || taskStatus.executedCount != 0) {
            handleSchedulerStatusChanged(SinglePointTaskStatus())
        }
    }

    fun stop() {
        end()
    }

    private fun handleSchedulerStatusChanged(status: SinglePointTaskStatus) {
        taskStatus = if (isShowing) status else SinglePointTaskStatus()
        setTargetTouchable(taskStatus.taskRunState != TaskRunState.RUNNING)
        refreshToolbarState()
        notifyOverlayStateChanged()
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

            // 只有第一个按钮负责拖拽，避免运行/关闭按钮拦截整条工具条的移动手势。
            addView(toolbarButton("✥", textSize = 24f, onClick = null))
            addView(toolbarButton("▶", textSize = 24f) { toggleTaskRunState() })
            addView(toolbarButton("×", textSize = 24f) { hide() })
        }
    }

    private fun createCollapsedToolbarView(): TextView {
        return floatingButton("≡", textSize = 24f) {
            interactionState = interactionState.copy(isToolbarCollapsed = false)
            refreshInteractionViews()
        }
    }

    private fun createActionButtonView(): TextView {
        return floatingButton("▶", textSize = 24f) { toggleTaskRunState() }
    }

    private fun floatingButton(text: String, textSize: Float, onClick: () -> Unit): TextView {
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
        (toolbar.getChildAt(1) as? TextView)?.apply {
            text = when (taskStatus.taskRunState) {
                TaskRunState.IDLE -> "▶"
                TaskRunState.RUNNING -> "Ⅱ"
                TaskRunState.PAUSED -> "▶"
            }
            textSize = when (taskStatus.taskRunState) {
                TaskRunState.IDLE,
                TaskRunState.PAUSED -> 24f
                TaskRunState.RUNNING -> 20f
            }
            contentDescription = when (taskStatus.taskRunState) {
                TaskRunState.IDLE -> "开始点击"
                TaskRunState.RUNNING -> "暂停点击"
                TaskRunState.PAUSED -> "继续点击"
            }
        }
        refreshActionButtonState()
    }

    private fun refreshActionButtonState() {
        actionButtonView?.apply {
            text = when (taskStatus.taskRunState) {
                TaskRunState.IDLE -> "▶"
                TaskRunState.RUNNING -> "Ⅱ"
                TaskRunState.PAUSED -> "▶"
            }
            contentDescription = when (taskStatus.taskRunState) {
                TaskRunState.IDLE -> "开始点击"
                TaskRunState.RUNNING -> "暂停点击"
                TaskRunState.PAUSED -> "继续点击"
            }
        }
    }

    private fun toggleTaskRunState() {
        when (taskStatus.taskRunState) {
            TaskRunState.IDLE -> start()
            TaskRunState.RUNNING -> pause()
            TaskRunState.PAUSED -> resume()
        }
    }

    private fun notifyOverlayStateChanged() {
        onOverlayStateChanged(snapshot)
    }

    private fun refreshInteractionViews() {
        val target = targetView ?: return
        if (target.parent == null) {
            return
        }

        syncTargetPosition()
        syncToolbarVisibility()
        syncCollapsedToolbarVisibility()
        syncActionButtonVisibility()
        refreshToolbarState()
        refreshActionButtonState()
        notifyOverlayStateChanged()
    }

    private fun syncTargetPosition() {
        val params = targetParams ?: return
        params.x = dpPosition(interactionState.targetPosition.x)
        params.y = dpPosition(interactionState.targetPosition.y)
        targetView?.let { windowManager.updateViewLayout(it, params) }
    }

    private fun syncToolbarVisibility() {
        if (interactionState.shouldShowToolbar()) {
            ensureToolbarView()
            moveToolbarToConfiguredPosition()
        } else {
            removeView(toolbarView)
            toolbarView = null
            toolbarParams = null
        }
    }

    private fun ensureToolbarView() {
        if (toolbarView != null) {
            return
        }

        val toolbar = createToolbarView()
        val params = overlayParams(
            width = dp(52),
            height = WindowManager.LayoutParams.WRAP_CONTENT,
            x = dpPosition(interactionState.toolbarPosition.x),
            y = dpPosition(interactionState.toolbarPosition.y),
        )
        // 工具条只让第一个“移动”按钮负责拖动，避免运行/关闭按钮拦截整条工具条的移动手势。
        bindDrag(toolbar.getChildAt(0), params) { point ->
            interactionState = interactionState.copy(toolbarPosition = point)
        }
        windowManager.addView(toolbar, params)
        toolbarView = toolbar
        toolbarParams = params
    }

    private fun syncCollapsedToolbarVisibility() {
        if (interactionState.shouldShowCollapsedToolbar()) {
            ensureCollapsedToolbarView()
            moveCollapsedToolbarToConfiguredPosition()
        } else {
            removeView(collapsedToolbarView)
            collapsedToolbarView = null
            collapsedToolbarParams = null
        }
    }

    private fun ensureCollapsedToolbarView() {
        if (collapsedToolbarView != null) {
            return
        }

        val collapsed = createCollapsedToolbarView()
        val params = overlayParams(
            width = dp(44),
            height = dp(44),
            x = dpPosition(interactionState.collapsedToolbarPosition.x),
            y = dpPosition(interactionState.collapsedToolbarPosition.y),
        )
        bindDrag(collapsed, params) { point ->
            interactionState = interactionState.copy(collapsedToolbarPosition = point)
        }
        windowManager.addView(collapsed, params)
        collapsedToolbarView = collapsed
        collapsedToolbarParams = params
    }

    private fun syncActionButtonVisibility() {
        if (interactionState.shouldShowActionButton()) {
            ensureActionButtonView()
            moveActionButtonToConfiguredPosition()
        } else {
            removeView(actionButtonView)
            actionButtonView = null
            actionButtonParams = null
        }
    }

    private fun ensureActionButtonView() {
        if (actionButtonView != null) {
            return
        }

        val actionButton = createActionButtonView()
        val params = overlayParams(
            width = dp(52),
            height = dp(52),
            x = dpPosition(interactionState.actionButtonPosition.x),
            y = dpPosition(interactionState.actionButtonPosition.y),
        )
        bindDrag(actionButton, params) { point ->
            interactionState = interactionState.copy(actionButtonPosition = point)
        }
        windowManager.addView(actionButton, params)
        actionButtonView = actionButton
        actionButtonParams = params
    }

    private fun moveToolbarToConfiguredPosition() {
        val view = toolbarView ?: return
        val params = toolbarParams ?: return
        params.x = dpPosition(interactionState.toolbarPosition.x)
        params.y = dpPosition(interactionState.toolbarPosition.y)
        windowManager.updateViewLayout(view, params)
    }

    private fun moveCollapsedToolbarToConfiguredPosition() {
        val view = collapsedToolbarView ?: return
        val params = collapsedToolbarParams ?: return
        params.x = dpPosition(interactionState.collapsedToolbarPosition.x)
        params.y = dpPosition(interactionState.collapsedToolbarPosition.y)
        windowManager.updateViewLayout(view, params)
    }

    private fun moveActionButtonToConfiguredPosition() {
        val view = actionButtonView ?: return
        val params = actionButtonParams ?: return
        params.x = dpPosition(interactionState.actionButtonPosition.x)
        params.y = dpPosition(interactionState.actionButtonPosition.y)
        windowManager.updateViewLayout(view, params)
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

    private fun bindDrag(
        view: View,
        params: WindowManager.LayoutParams,
        onPositionChanged: (OverlayPoint) -> Unit = {},
    ) {
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
                    } else {
                        onPositionChanged(OverlayPoint(x = logicalPosition(params.x), y = logicalPosition(params.y)))
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

    private fun dpPosition(value: Int): Int {
        // Flutter 持久化的是逻辑像素；WindowManager 需要真实屏幕像素。
        // 先在原生边界统一转换，后续位置回传时也应在同一处做反向转换。
        return dp(value)
    }

    private fun logicalPosition(value: Int): Int {
        val density = context.resources.displayMetrics.density
        return (value / density).roundToInt()
    }
}

data class SinglePointOverlaySettings(
    val intervalMs: Int = 500,
    val repeatCount: Int = 10,
    val infiniteLoop: Boolean = false,
    val tapDurationMs: Int = 50,
    val interactionState: OverlayInteractionState = OverlayInteractionState(),
)
