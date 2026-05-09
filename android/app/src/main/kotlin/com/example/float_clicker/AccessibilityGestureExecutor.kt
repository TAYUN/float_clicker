package com.example.float_clicker

import android.accessibilityservice.GestureDescription
import android.graphics.Path

internal enum class AccessibilityGestureResult {
    COMPLETED,
    CANCELLED,
    DISPATCH_FAILED,
    SERVICE_DISCONNECTED,
    TARGET_UNAVAILABLE,
}

/**
 * 无障碍手势执行器，只负责把 AutomationAction 转成 dispatchGesture 调用并归一结果。
 *
 * 调度器不再直接拼 GestureDescription，后续多点和高级动作可以复用这里的失败、取消和服务断开收尾语义。
 */
internal object AccessibilityGestureExecutor {
    val isServiceAvailable: Boolean
        get() = FloatClickerAccessibilityService.instance != null

    fun execute(
        action: AutomationAction,
        targetPositionProvider: AutomationTargetPositionProvider,
        onResult: (AccessibilityGestureResult) -> Unit,
    ) {
        when (action) {
            is AutomationAction.Tap -> dispatchTap(action, targetPositionProvider, onResult)
        }
    }

    private fun dispatchTap(
        action: AutomationAction.Tap,
        targetPositionProvider: AutomationTargetPositionProvider,
        onResult: (AccessibilityGestureResult) -> Unit,
    ) {
        val service = FloatClickerAccessibilityService.instance
        if (service == null) {
            onResult(AccessibilityGestureResult.SERVICE_DISCONNECTED)
            return
        }

        val position = targetPositionProvider.positionOf(action.targetId)
        if (position == null) {
            onResult(AccessibilityGestureResult.TARGET_UNAVAILABLE)
            return
        }

        // Tap 用零位移路径表达：按下目标坐标，持续 durationMs 后抬起。
        val path = Path().apply {
            moveTo(position.x, position.y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, action.durationMs.coerceAtLeast(1L)))
            .build()

        var hasDeliveredResult = false
        fun deliver(result: AccessibilityGestureResult) {
            if (hasDeliveredResult) {
                return
            }
            hasDeliveredResult = true
            onResult(result)
        }

        val accepted = service.dispatchGesture(
            gesture,
            object : android.accessibilityservice.AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    super.onCompleted(gestureDescription)
                    deliver(AccessibilityGestureResult.COMPLETED)
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    super.onCancelled(gestureDescription)
                    deliver(AccessibilityGestureResult.CANCELLED)
                }
            },
            null,
        )

        if (!accepted) {
            // dispatchGesture 返回 false 时系统不会再触发回调，必须立即把失败交还调度器收尾。
            deliver(AccessibilityGestureResult.DISPATCH_FAILED)
        }
    }
}
