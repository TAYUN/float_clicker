package com.example.float_clicker

import android.accessibilityservice.GestureDescription
import android.accessibilityservice.AccessibilityService
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent

class FloatClickerAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        // Android 系统真正绑定服务后才会回调这里；调度器通过 instance 判断服务是否可用。
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 单点点击阶段不需要读取界面内容；服务只作为 dispatchGesture 的执行入口。
    }

    override fun onInterrupt() {
        // 系统中断无障碍服务时，正在进行的点击任务必须停止。
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
        // 单点点击用一条没有移动距离的 Stroke 表示：从目标坐标按下，持续 durationMs 后抬起。
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
                    // 取消也通知调度器继续收尾，否则任务可能卡在“等待本次点击完成”。
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
