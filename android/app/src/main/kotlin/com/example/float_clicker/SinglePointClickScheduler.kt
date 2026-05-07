package com.example.float_clicker

import android.os.Handler
import android.os.Looper

object SinglePointClickScheduler {
    private val handler = Handler(Looper.getMainLooper())

    // 调度器是全局单例，保证同一时间只有一个单点点击任务在跑。
    private var isRunning = false
    private var clickProvider: (() -> SinglePointClickRequest)? = null
    private var onStopped: (() -> Unit)? = null
    private var completedCount = 0

    fun start(provider: () -> SinglePointClickRequest, onStopped: () -> Unit): Boolean {
        // 无障碍服务未连接时不能 dispatchGesture，直接拒绝启动并让 Flutter 提示。
        val service = FloatClickerAccessibilityService.instance ?: return false
        stop(notify = false)
        clickProvider = provider
        this.onStopped = onStopped
        completedCount = 0
        isRunning = true
        runNext(service)
        return true
    }

    fun stop() {
        stop(notify = true)
    }

    private fun stop(notify: Boolean) {
        val callback = onStopped
        val shouldNotify = notify && isRunning
        isRunning = false
        clickProvider = null
        onStopped = null
        handler.removeCallbacksAndMessages(null)
        if (shouldNotify) {
            callback?.invoke()
        }
    }

    private fun runNext(service: FloatClickerAccessibilityService) {
        if (!isRunning) {
            return
        }

        // 每轮都重新向 overlay manager 要一次请求，用来拿最新坐标和最新配置。
        val request = clickProvider?.invoke() ?: return stop()
        if (!request.infiniteLoop && completedCount >= request.repeatCount) {
            stop()
            return
        }

        // dispatchGesture 是异步的，必须等回调完成后再安排下一次点击。
        service.performTap(request.x, request.y, request.tapDurationMs.toLong()) {
            completedCount += 1
            if (!isRunning) {
                return@performTap
            }
            if (!request.infiniteLoop && completedCount >= request.repeatCount) {
                stop()
                return@performTap
            }
            // 间隔从“本次点击完成后”开始计算，避免手势持续时间和间隔互相重叠。
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
