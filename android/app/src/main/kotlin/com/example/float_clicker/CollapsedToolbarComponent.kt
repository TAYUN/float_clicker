package com.example.float_clicker

import android.view.WindowManager
import android.widget.TextView

internal class CollapsedToolbarComponent(
    private val overlayWindow: OverlayWindowHelper,
    private val onPositionChanged: (OverlayPoint) -> Unit,
    private val onExpand: () -> Unit,
) {
    private var view: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var metrics = OverlayComponentMetrics(
        overlayWindow,
        OverlayAppearanceSettings(),
    )

    val isShowing: Boolean
        get() = view != null

    fun show(position: OverlayPoint, metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        if (view == null) {
            val collapsed = createView()
            val nextParams = overlayWindow.overlayParams(
                width = metrics.collapsedToolbarSizePx,
                height = metrics.collapsedToolbarSizePx,
                position = position,
            )
            overlayWindow.bindDrag(
                view = collapsed,
                params = nextParams,
                onPositionChanged = { point -> onPositionChanged(point) },
                onClick = onExpand,
            )
            if (!overlayWindow.addView(collapsed, nextParams)) {
                return
            }
            view = collapsed
            params = nextParams
        } else {
            updateMetrics(metrics)
        }

        moveTo(position)
    }

    fun moveTo(position: OverlayPoint) {
        overlayWindow.moveTo(view, params, position)
    }

    fun remove() {
        overlayWindow.removeView(view)
        view = null
        params = null
    }

    fun updateMetrics(metrics: OverlayComponentMetrics) {
        this.metrics = metrics
        val collapsed = view ?: return
        val collapsedParams = params ?: return
        collapsedParams.width = metrics.collapsedToolbarSizePx
        collapsedParams.height = metrics.collapsedToolbarSizePx
        collapsed.textSize = metrics.collapsedToolbarTextSizeSp
        overlayWindow.updateViewLayout(collapsed, collapsedParams)
    }

    private fun createView(): TextView {
        return overlayWindow.floatingButton("≡", textSize = metrics.collapsedToolbarTextSizeSp) { onExpand() }
    }
}
