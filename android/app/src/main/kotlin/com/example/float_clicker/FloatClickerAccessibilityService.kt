package com.example.float_clicker

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class FloatClickerAccessibilityService : AccessibilityService() {
    override fun onCreate() {
        super.onCreate()
        // 部分系统在包更新或重新绑定后，Activity 可能先读到系统 Bound，再等不到新的 onServiceConnected。
        // 服务对象创建后先注册为可用入口，onServiceConnected 再做一次幂等确认。
        registerServiceInstance()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        registerServiceInstance()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 单点点击阶段不需要读取界面内容；服务只作为 dispatchGesture 的执行入口。
    }

    override fun onInterrupt() {
        // 系统中断无障碍服务时，正在进行的点击任务必须停止。
        SinglePointClickScheduler.end()
        MultiPointClickScheduler.end()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        unregisterServiceInstance()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        unregisterServiceInstance()
        super.onDestroy()
    }

    private fun registerServiceInstance() {
        if (AccessibilityServiceStateHelper.attachService(this)) {
            AccessibilityServiceStateBus.notifyConnected(true)
        }
    }

    private fun unregisterServiceInstance() {
        if (AccessibilityServiceStateHelper.detachService(this)) {
            SinglePointClickScheduler.end()
            MultiPointClickScheduler.end()
            AccessibilityServiceStateBus.notifyConnected(false)
        }
    }

    companion object {
        val instance: FloatClickerAccessibilityService?
            get() = AccessibilityServiceStateHelper.currentService()
    }
}
