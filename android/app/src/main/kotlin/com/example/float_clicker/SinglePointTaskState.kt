package com.example.float_clicker

enum class TaskRunState(val wireName: String) {
    IDLE("idle"),
    RUNNING("running"),
    PAUSED("paused"),
}

data class SinglePointTaskStatus(
    val taskRunState: TaskRunState = TaskRunState.IDLE,
    val executedCount: Int = 0,
) {
    val isRunning: Boolean
        get() = taskRunState == TaskRunState.RUNNING
}

data class SinglePointOverlaySnapshot(
    val isEnabled: Boolean,
    val taskRunState: TaskRunState = TaskRunState.IDLE,
    val executedCount: Int = 0,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "isEnabled" to isEnabled,
            "isRunning" to taskRunState.isRunningCompat,
            "taskRunState" to taskRunState.wireName,
            "executedCount" to executedCount,
        )
    }
}

private val TaskRunState.isRunningCompat: Boolean
    get() = this == TaskRunState.RUNNING
