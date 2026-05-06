package com.example.float_clicker

import android.accessibilityservice.GestureDescription
import android.accessibilityservice.AccessibilityService
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent

class FloatClickerAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 单点点击阶段不需要读取界面内容；服务只作为 dispatchGesture 的执行入口。
    }

    override fun onInterrupt() {
        SinglePointClickScheduler.stop()
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        SinglePointClickScheduler.stop()
        super.onDestroy()
    }

    fun performTap(x: Float, y: Float, durationMs: Long, onComplete: () -> Unit) {
        val path = Path().apply {
            moveTo(x, y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
            .build()

        dispatchGesture(
            gesture,
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    super.onCompleted(gestureDescription)
                    onComplete()
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    super.onCancelled(gestureDescription)
                    onComplete()
                }
            },
            null,
        )
    }

    companion object {
        var instance: FloatClickerAccessibilityService? = null
            private set
    }
}
