package com.example.float_clicker

import android.os.Handler
import android.os.Looper

internal object MultiPointClickScheduler {
    private val handler = Handler(Looper.getMainLooper())

    // P4.2 先实现独立调度内核，P4.3 再接入 OverlayManager 和 MethodChannel。
    private var taskRunState = TaskRunState.IDLE
    private var actions: List<AutomationAction.Tap> = emptyList()
    private var targetPositionProvider: AutomationTargetPositionProvider? = null
    private var onStatusChanged: ((MultiPointTaskStatus) -> Unit)? = null
    private var intervalMs = 500
    private var repeatCount = 10
    private var infiniteLoop = false
    private var completedRounds = 0
    private var executedActionCountInCurrentRound = 0
    private var currentActionIndex = 0
    private var currentTargetId: String? = null
    private var isGestureInFlight = false
    private var taskGeneration = 0

    val status: MultiPointTaskStatus
        get() = MultiPointTaskStatus(
            taskRunState = taskRunState,
            completedRounds = completedRounds,
            currentRound = currentRoundForStatus(),
            executedActionCountInCurrentRound = executedActionCountInCurrentRound,
            currentTargetId = if (taskRunState == TaskRunState.IDLE) null else currentTargetId,
        )

    fun start(
        request: MultiPointClickTaskRequest,
        targetPositionProvider: AutomationTargetPositionProvider,
        onStatusChanged: (MultiPointTaskStatus) -> Unit,
    ): MultiPointClickStartResult {
        if (taskRunState != TaskRunState.IDLE) {
            return MultiPointClickStartResult.INVALID_TASK_STATE
        }
        if (!AccessibilityGestureExecutor.isServiceAvailable) {
            return MultiPointClickStartResult.ACCESSIBILITY_SERVICE_UNAVAILABLE
        }

        val nextActions = request.enabledTargets()
            .mapIndexed { index, target ->
                AutomationAction.Tap(
                    id = "multi_point_tap_${target.id}_$index",
                    targetId = target.id,
                    durationMs = request.tapDurationMs.toLong(),
                )
            }
        if (nextActions.isEmpty()) {
            return MultiPointClickStartResult.NO_ENABLED_TARGETS
        }

        actions = nextActions
        this.targetPositionProvider = targetPositionProvider
        this.onStatusChanged = onStatusChanged
        intervalMs = request.intervalMs.coerceAtLeast(50)
        repeatCount = request.repeatCount.coerceAtLeast(1)
        infiniteLoop = request.infiniteLoop
        completedRounds = 0
        executedActionCountInCurrentRound = 0
        currentActionIndex = 0
        currentTargetId = actions.firstOrNull()?.targetId
        isGestureInFlight = false
        taskGeneration += 1
        setTaskRunState(TaskRunState.RUNNING)
        runNext(taskGeneration)
        return MultiPointClickStartResult.STARTED
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
        val wasActive = taskRunState != TaskRunState.IDLE ||
            completedRounds != 0 ||
            executedActionCountInCurrentRound != 0
        handler.removeCallbacksAndMessages(null)
        actions = emptyList()
        targetPositionProvider = null
        isGestureInFlight = false
        completedRounds = 0
        executedActionCountInCurrentRound = 0
        currentActionIndex = 0
        currentTargetId = null
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
        if (!infiniteLoop && completedRounds >= repeatCount) {
            end()
            return
        }

        val action = actions.getOrNull(currentActionIndex) ?: return end()
        val provider = targetPositionProvider ?: return end()
        currentTargetId = action.targetId
        notifyStatusChanged()
        isGestureInFlight = true

        AccessibilityGestureExecutor.execute(action, provider) { result ->
            if (generation != taskGeneration) {
                return@execute
            }

            isGestureInFlight = false
            if (taskRunState == TaskRunState.IDLE) {
                return@execute
            }
            if (result != AccessibilityGestureResult.COMPLETED) {
                // 取消、派发失败、服务断开或目标坐标不可用都不能继续排队，统一安全结束。
                end()
                return@execute
            }

            markCurrentActionCompleted()
            if (!infiniteLoop && completedRounds >= repeatCount) {
                end()
                return@execute
            }

            notifyStatusChanged()
            if (taskRunState == TaskRunState.PAUSED) {
                return@execute
            }

            handler.postDelayed(
                {
                    if (AccessibilityGestureExecutor.isServiceAvailable) {
                        runNext(generation)
                    } else {
                        end()
                    }
                },
                intervalMs.toLong(),
            )
        }
    }

    private fun markCurrentActionCompleted() {
        executedActionCountInCurrentRound += 1
        currentActionIndex += 1

        if (currentActionIndex >= actions.size) {
            completedRounds += 1
            executedActionCountInCurrentRound = 0
            currentActionIndex = 0
        }

        currentTargetId = actions.getOrNull(currentActionIndex)?.targetId
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

    private fun currentRoundForStatus(): Int {
        return if (taskRunState == TaskRunState.IDLE) {
            0
        } else {
            completedRounds + 1
        }
    }
}

internal data class MultiPointClickTaskRequest(
    val targets: List<MultiPointTargetState>,
    val intervalMs: Int,
    val repeatCount: Int,
    val infiniteLoop: Boolean,
    val tapDurationMs: Int,
) {
    fun enabledTargets(): List<MultiPointTargetState> {
        // 执行序列只取启用点位，并以完整列表 order 恢复用户配置的点击顺序。
        return targets
            .filter { it.enabled }
            .sortedWith(compareBy<MultiPointTargetState> { it.order }.thenBy { it.id })
    }
}

internal data class MultiPointTaskStatus(
    val taskRunState: TaskRunState = TaskRunState.IDLE,
    val completedRounds: Int = 0,
    val currentRound: Int = 0,
    val executedActionCountInCurrentRound: Int = 0,
    val currentTargetId: String? = null,
)

internal enum class MultiPointClickStartResult {
    STARTED,
    NO_ENABLED_TARGETS,
    ACCESSIBILITY_SERVICE_UNAVAILABLE,
    INVALID_TASK_STATE,
}
