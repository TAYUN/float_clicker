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

    fun show(position: OverlayPoint) {
        if (view == null) {
            val collapsed = createView()
            val nextParams = overlayWindow.overlayParams(
                width = overlayWindow.dp(44),
                height = overlayWindow.dp(44),
                position = position,
            )
            overlayWindow.bindDrag(
                view = collapsed,
                params = nextParams,
                onPositionChanged = { point -> onPositionChanged(point) },
                onClick = onExpand,
            )
            overlayWindow.addView(collapsed, nextParams)
            view = collapsed
            params = nextParams
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

    private fun createView(): TextView {
        return overlayWindow.floatingButton("≡", textSize = 24f) { onExpand() }
    }
}
