package com.example.float_clicker

object AccessibilityServiceStateBus {
    private val listeners = mutableSetOf<(Boolean) -> Unit>()

    fun addListener(listener: (Boolean) -> Unit) {
        listeners.add(listener)
        listener(FloatClickerAccessibilityService.instance != null)
    }

    fun removeListener(listener: (Boolean) -> Unit) {
        listeners.remove(listener)
    }

    fun notifyConnected(isConnected: Boolean) {
        listeners.toList().forEach { listener ->
            listener(isConnected)
        }
    }
}
