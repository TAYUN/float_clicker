package com.example.float_clicker

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

internal class MultiProfileExecutionSidebarComponent(
    private val context: Context,
    private val overlayWindow: OverlayWindowHelper,
    private val onCollapse: () -> Unit,
    private val onStopCurrentTask: () -> Unit,
) {
    private var view: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun preferredWidthPx(): Int = sidebarWidthPx()

    fun preferredHeightPx(state: MultiProfileExecutionSidebarState): Int {
        val baseHeight = overlayWindow.dp(112)
        return if (state.isRunning) baseHeight + overlayWindow.dp(40) else baseHeight
    }

    fun show(
        state: MultiProfileExecutionSidebarState,
        position: OverlayPoint,
        metrics: OverlayComponentMetrics,
    ): Boolean {
        this.metrics = metrics
        if (view == null) {
            val panel = createView()
            val nextParams = overlayWindow.overlayParams(
                width = sidebarWidthPx(),
                height = WindowManager.LayoutParams.WRAP_CONTENT,
                position = position,
            )
            if (!overlayWindow.addView(panel, nextParams)) {
                return false
            }
            view = panel
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        updateState(state)
        overlayWindow.moveTo(view, params, position)
        return true
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    private fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val panel = view ?: return
        val panelParams = params ?: return
        panelParams.width = sidebarWidthPx()
        panel.background = panelBackground()
        panel.setPadding(panelPaddingPx(), panelPaddingPx(), panelPaddingPx(), panelPaddingPx())
        overlayWindow.updateViewLayout(panel, panelParams)
    }

    private fun createView(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(panelPaddingPx(), panelPaddingPx(), panelPaddingPx(), panelPaddingPx())
            background = panelBackground()
            elevation = overlayWindow.dp(10).toFloat()
        }
    }

    private fun updateState(state: MultiProfileExecutionSidebarState) {
        val panel = view ?: return
        panel.removeAllViews()
        panel.addView(textRow("多配置执行区", titleTextSizeSp(), Typeface.DEFAULT_BOLD))
        panel.addView(textRow(state.statusText, bodyTextSizeSp(), Typeface.DEFAULT_BOLD))
        state.currentProfileName?.let { profileName ->
            panel.addView(textRow("当前配置：$profileName", smallTextSizeSp()))
        } ?: panel.addView(textRow("已加载 ${state.loadedProfileCount} 个配置", smallTextSizeSp()))
        panel.addView(separator())
        panel.addView(textRow(state.description, smallTextSizeSp()))
        panel.addView(separator())
        if (state.isRunning) {
            panel.addView(actionButton("停止当前任务", OverlayColors.DANGER_SOFT) {
                onStopCurrentTask()
            })
        }
        panel.addView(actionButton("收起", OverlayColors.ACCENT_SOFT) {
            onCollapse()
        })
        panel.contentDescription = if (state.isRunning) {
            "多配置执行区，运行中，当前配置 ${state.currentProfileName.orEmpty()}"
        } else {
            "多配置执行区，空闲中，已加载 ${state.loadedProfileCount} 个配置"
        }
    }

    private fun textRow(
        text: String,
        textSize: Float,
        typeface: Typeface = Typeface.DEFAULT,
    ): TextView {
        return TextView(context).apply {
            this.text = text
            this.textSize = textSize
            this.typeface = typeface
            setTextColor(OverlayColors.TEXT_PRIMARY)
            gravity = Gravity.CENTER
            includeFontPadding = true
            maxLines = 2
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
    }

    private fun actionButton(
        text: String,
        backgroundColor: Int,
        onClick: () -> Unit,
    ): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = bodyTextSizeSp()
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(OverlayColors.TEXT_PRIMARY)
            gravity = Gravity.CENTER
            includeFontPadding = false
            background = roundedBackground(backgroundColor, overlayWindow.dp(12))
            isClickable = true
            setOnClickListener {
                performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                onClick()
            }
            val verticalMargin = overlayWindow.dp(3)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                actionButtonHeightPx(),
            ).apply {
                topMargin = verticalMargin
                bottomMargin = verticalMargin
            }
        }
    }

    private fun separator(): TextView {
        return TextView(context).apply {
            text = ""
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                overlayWindow.dp(8),
            )
        }
    }

    private fun panelBackground(): GradientDrawable {
        return roundedBackground(OverlayColors.PANEL, overlayWindow.dp(18)).apply {
            setStroke(overlayWindow.dp(1), OverlayColors.ACCENT)
        }
    }

    private fun roundedBackground(color: Int, radiusPx: Int): GradientDrawable {
        return GradientDrawable().apply {
            cornerRadius = radiusPx.toFloat()
            setColor(color)
        }
    }

    private fun sidebarWidthPx(): Int {
        return overlayWindow.dp(168)
    }

    private fun panelPaddingPx(): Int {
        return overlayWindow.dp(10)
    }

    private fun actionButtonHeightPx(): Int {
        return overlayWindow.dp(34)
    }

    private fun titleTextSizeSp(): Float = 13f

    private fun bodyTextSizeSp(): Float = 12f

    private fun smallTextSizeSp(): Float = 10.5f
}

internal data class MultiProfileExecutionSidebarState(
    val loadedProfileCount: Int,
    val isRunning: Boolean,
    val currentProfileName: String?,
) {
    val statusText: String
        get() = if (isRunning) "运行中" else "空闲中"

    val description: String
        get() = if (isRunning) {
            "当前仅支持停止任务"
        } else {
            // 侧边栏第一轮只做全局控制壳，profile 的真实启动入口仍保留在外部圆形按钮。
            "点击外部圆形执行控件可启动对应配置任务"
        }
}
