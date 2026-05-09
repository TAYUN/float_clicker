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
    fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedService = ComponentName(context, FloatClickerAccessibilityService::class.java)
            .flattenToString()
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        // 系统保存的是冒号分隔的服务列表，逐项比较能避免包名局部匹配造成误判。
        return enabledServices.split(':').any { serviceName ->
            serviceName.equals(expectedService, ignoreCase = true)
        }
    }

    fun isAccessibilityServiceConnected(): Boolean {
        return FloatClickerAccessibilityService.instance != null
    }
}
