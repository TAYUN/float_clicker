package com.example.float_clicker

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

/**
 * 统一提供无障碍服务的“已授权 / 已连接”状态，避免 Activity、状态总线和执行器各自读不同来源。
 *
 * accessibilityGranted 表示系统设置里已经开启服务；
 * accessibilityConnected 表示当前进程里已有可直接 dispatchGesture 的服务实例。
 */
internal object AccessibilityServiceStateHelper {
    @Volatile
    private var connectedService: FloatClickerAccessibilityService? = null

    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedService = ComponentName(context, FloatClickerAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        // 系统保存的是冒号分隔的组件名列表，先解析成 ComponentName 再比对，兼容完整类名和短类名写法。
        return enabledServices.split(':').any { serviceName ->
            val enabledService = ComponentName.unflattenFromString(serviceName.trim()) ?: return@any false
            enabledService.packageName.equals(expectedService.packageName, ignoreCase = true) &&
                enabledService.className.equals(expectedService.className, ignoreCase = true)
        }
    }

    fun currentService(): FloatClickerAccessibilityService? {
        return connectedService
    }

    fun isAccessibilityServiceConnected(): Boolean {
        return connectedService != null
    }

    fun attachService(service: FloatClickerAccessibilityService): Boolean {
        val wasConnected = connectedService != null
        connectedService = service
        return !wasConnected
    }

    fun detachService(service: FloatClickerAccessibilityService): Boolean {
        if (connectedService !== service) {
            return false
        }

        connectedService = null
        return true
    }
}
