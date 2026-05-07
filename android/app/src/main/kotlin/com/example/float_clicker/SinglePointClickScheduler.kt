package com.example.float_clicker

import android.os.Handler
import android.os.Looper

object SinglePointClickScheduler {
    private val handler = Handler(Looper.getMainLooper())

    // 调度器是全局单例，保证同一时间只有一个单点点击任务在跑。
    private var taskRunState = TaskRunState.IDLE
    private var clickProvider: (() -> SinglePointClickRequest)? = null
    private var onStatusChanged: ((SinglePointTaskStatus) -> Unit)? = null
    private var completedCount = 0
    private var isGestureInFlight = false
    private var taskGeneration = 0

    val status: SinglePointTaskStatus
        get() = SinglePointTaskStatus(taskRunState, completedCount)

    fun start(
        provider: () -> SinglePointClickRequest,
        onStatusChanged: (SinglePointTaskStatus) -> Unit,
    ): Boolean {
        // 无障碍服务未连接时不能 dispatchGesture，直接拒绝启动并让 Flutter 提示。
        val service = FloatClickerAccessibilityService.instance ?: return false
        end(notify = false)
        clickProvider = provider
        this.onStatusChanged = onStatusChanged
        completedCount = 0
        isGestureInFlight = false
        taskGeneration += 1
        setTaskRunState(TaskRunState.RUNNING)
        runNext(service, taskGeneration)
        return true
    }

    fun pause(): Boolean {
        if (taskRunState != TaskRunState.RUNNING) {
            return false
        }

        handler.removeCallbacksAndMessages(null)
        setTaskRunState(TaskRunState.PAUSED)
        return true
    }

    fun resume(): Boolean {
        if (taskRunState != TaskRunState.PAUSED) {
            return false
        }

        val service = FloatClickerAccessibilityService.instance ?: return false
        setTaskRunState(TaskRunState.RUNNING)
        if (!isGestureInFlight) {
            runNext(service, taskGeneration)
        }
        return true
    }

    fun end() {
        end(notify = true)
    }

    private fun end(notify: Boolean) {
        val wasActive = taskRunState != TaskRunState.IDLE || completedCount != 0
        handler.removeCallbacksAndMessages(null)
        clickProvider = null
        isGestureInFlight = false
        completedCount = 0
        taskGeneration += 1
        taskRunState = TaskRunState.IDLE
        val callback = onStatusChanged
        onStatusChanged = null
        if (notify && wasActive) {
            callback?.invoke(status)
        }
    }

    private fun runNext(service: FloatClickerAccessibilityService, generation: Int) {
        if (generation != taskGeneration) {
            return
        }

        if (taskRunState != TaskRunState.RUNNING || isGestureInFlight) {
            return
        }

        // 每轮都重新向 overlay manager 要一次请求，用来拿最新坐标和最新配置。
        val request = clickProvider?.invoke() ?: return end()
        if (!request.infiniteLoop && completedCount >= request.repeatCount) {
            end()
            return
        }

        isGestureInFlight = true
        service.performTap(request.x, request.y, request.tapDurationMs.toLong()) {
            if (generation != taskGeneration) {
                return@performTap
            }

            isGestureInFlight = false

            if (taskRunState == TaskRunState.IDLE) {
                return@performTap
            }

            completedCount += 1
            notifyStatusChanged()

            if (taskRunState == TaskRunState.PAUSED) {
                return@performTap
            }

            if (!request.infiniteLoop && completedCount >= request.repeatCount) {
                end()
                return@performTap
            }

            // 间隔从“本次点击完成后”开始计算，避免手势持续时间和间隔互相重叠。
            handler.postDelayed(
                {
                    FloatClickerAccessibilityService.instance?.let {
                        runNext(it, generation)
                    } ?: end()
                },
                request.intervalMs.toLong(),
            )
        }
    }

    private fun setTaskRunState(value: TaskRunState) {
        if (taskRunState == value) {
            notifyStatusChanged()
            return
        }

        taskRunState = value
        notifyStatusChanged()
    }

    private fun notifyStatusChanged() {
        onStatusChanged?.invoke(status)
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
