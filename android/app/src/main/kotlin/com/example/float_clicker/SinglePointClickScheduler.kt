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
        if (!AccessibilityGestureExecutor.isServiceAvailable) {
            return false
        }
        end(notify = false)
        clickProvider = provider
        this.onStatusChanged = onStatusChanged
        completedCount = 0
        isGestureInFlight = false
        taskGeneration += 1
        setTaskRunState(TaskRunState.RUNNING)
        runNext(taskGeneration)
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

        if (!AccessibilityGestureExecutor.isServiceAvailable) {
            return false
        }
        setTaskRunState(TaskRunState.RUNNING)
        if (!isGestureInFlight) {
            runNext(taskGeneration)
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

    private fun runNext(generation: Int) {
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
        val action = AutomationAction.Tap(
            id = "single_point_tap_${generation}_$completedCount",
            targetId = SinglePointClickRequest.TARGET_ID,
            durationMs = request.tapDurationMs.toLong(),
        )
        val currentPosition = AutomationTargetPosition(request.x, request.y)
        AccessibilityGestureExecutor.execute(
            action = action,
            targetPositionProvider = AutomationTargetPositionProvider { targetId ->
                if (targetId == SinglePointClickRequest.TARGET_ID) currentPosition else null
            },
        ) { result ->
            if (generation != taskGeneration) {
                return@execute
            }

            isGestureInFlight = false

            if (taskRunState == TaskRunState.IDLE) {
                return@execute
            }

            if (result != AccessibilityGestureResult.COMPLETED) {
                // 系统拒绝、取消手势或服务断开时，结束任务比继续排队更安全，也避免卡在 running。
                end()
                return@execute
            }

            completedCount += 1
            notifyStatusChanged()

            if (taskRunState == TaskRunState.PAUSED) {
                return@execute
            }

            if (!request.infiniteLoop && completedCount >= request.repeatCount) {
                end()
                return@execute
            }

            // 间隔从“本次点击完成后”开始计算，避免手势持续时间和间隔互相重叠。
            handler.postDelayed(
                {
                    if (AccessibilityGestureExecutor.isServiceAvailable) {
                        runNext(generation)
                    } else {
                        end()
                    }
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
) {
    companion object {
        const val TARGET_ID = "single_point_target"
    }
}
