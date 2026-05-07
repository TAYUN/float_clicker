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
    val interactionState: OverlayInteractionState? = null,
) {
    fun toMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "isEnabled" to isEnabled,
            "isRunning" to taskRunState.isRunningCompat,
            "taskRunState" to taskRunState.wireName,
            "executedCount" to executedCount,
        )
        val state = interactionState ?: return map
        map["interactionMode"] = state.interactionMode.wireName
        map["targetPositionX"] = state.targetPosition.x
        map["targetPositionY"] = state.targetPosition.y
        map["toolbarPositionX"] = state.toolbarPosition.x
        map["toolbarPositionY"] = state.toolbarPosition.y
        map["collapsedToolbarPositionX"] = state.collapsedToolbarPosition.x
        map["collapsedToolbarPositionY"] = state.collapsedToolbarPosition.y
        map["actionButtonPositionX"] = state.actionButtonPosition.x
        map["actionButtonPositionY"] = state.actionButtonPosition.y
        map["isToolbarCollapsed"] = state.isToolbarCollapsed
        return map
    }
}

private val TaskRunState.isRunningCompat: Boolean
    get() = this == TaskRunState.RUNNING
