package com.example.float_clicker

import android.os.Handler
import android.os.Looper

object SinglePointClickScheduler {
    private val handler = Handler(Looper.getMainLooper())

    private var isRunning = false
    private var clickProvider: (() -> SinglePointClickRequest)? = null
    private var completedCount = 0

    fun start(provider: () -> SinglePointClickRequest): Boolean {
        val service = FloatClickerAccessibilityService.instance ?: return false
        clickProvider = provider
        completedCount = 0
        isRunning = true
        runNext(service)
        return true
    }

    fun stop() {
        isRunning = false
        clickProvider = null
        handler.removeCallbacksAndMessages(null)
    }

    private fun runNext(service: FloatClickerAccessibilityService) {
        if (!isRunning) {
            return
        }

        val request = clickProvider?.invoke() ?: return stop()
        if (!request.infiniteLoop && completedCount >= request.repeatCount) {
            stop()
            return
        }

        service.performTap(request.x, request.y, request.tapDurationMs.toLong()) {
            completedCount += 1
            if (!isRunning) {
                return@performTap
            }
            handler.postDelayed(
                { FloatClickerAccessibilityService.instance?.let(::runNext) ?: stop() },
                request.intervalMs.toLong(),
            )
        }
    }
}

data class SinglePointClickRequest(
    val x: Float,
    val y: Float,
    val intervalMs: Int,
    val repeatCount: Int,
    val infiniteLoop: Boolean,
    val tapDurationMs: Int,
)
