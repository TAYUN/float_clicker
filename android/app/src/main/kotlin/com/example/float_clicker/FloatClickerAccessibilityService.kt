package com.example.float_clicker

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class FloatClickerAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 单点点击阶段不需要读取界面内容；服务只作为 dispatchGesture 的执行入口。
    }

    override fun onInterrupt() {
        // 后续点击任务接入后，这里需要停止正在执行的点击循环。
    }
}
