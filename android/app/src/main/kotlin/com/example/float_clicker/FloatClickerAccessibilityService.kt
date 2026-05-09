package com.example.float_clicker

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class FloatClickerAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        // Android 系统真正绑定服务后才会回调这里；调度器通过 instance 判断服务是否可用。
        instance = this
        AccessibilityServiceStateBus.notifyConnected(true)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 单点点击阶段不需要读取界面内容；服务只作为 dispatchGesture 的执行入口。
    }

    override fun onInterrupt() {
        // 系统中断无障碍服务时，正在进行的点击任务必须停止。
        SinglePointClickScheduler.end()
        MultiPointClickScheduler.end()
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        SinglePointClickScheduler.end()
        MultiPointClickScheduler.end()
        AccessibilityServiceStateBus.notifyConnected(false)
        super.onDestroy()
    }

    companion object {
        var instance: FloatClickerAccessibilityService? = null
            private set
    }
}
