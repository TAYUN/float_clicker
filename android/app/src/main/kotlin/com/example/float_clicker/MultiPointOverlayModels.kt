package com.example.float_clicker

data class MultiPointTargetState(
    val id: String,
    val order: Int,
    val label: String,
    val x: Int,
    val y: Int,
    val enabled: Boolean,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "id" to id,
            "order" to order,
            "label" to label,
            "x" to x,
            "y" to y,
            "enabled" to enabled,
        )
    }

    companion object {
        fun fromMap(value: Any?, fallbackOrder: Int): MultiPointTargetState? {
            val map = value as? Map<*, *> ?: return null
            val id = (map["id"] as? String)?.trim()
            val x = (map["x"] as? Number)?.toInt()
            val y = (map["y"] as? Number)?.toInt()
            if (id.isNullOrEmpty() || x == null || y == null) {
                return null
            }

            // order 用于恢复完整点位顺序；悬浮层显示序号后续按启用点位重新连续生成。
            val order = (map["order"] as? Number)?.toInt() ?: fallbackOrder
            val label = (map["label"] as? String)?.trim().orEmpty().ifEmpty { order.toString() }
            return MultiPointTargetState(
                id = id,
                order = order,
                label = label,
                x = x,
                y = y,
                enabled = map["enabled"] as? Boolean ?: true,
            )
        }
    }
}

data class MultiPointOverlayUiState(
    val interactionMode: OverlayInteractionMode = OverlayInteractionMode.NORMAL,
    val toolbarPosition: OverlayPoint = OverlayPoint(x = 18, y = 180),
    val collapsedToolbarPosition: OverlayPoint = OverlayPoint(x = 18, y = 180),
    val actionButtonPosition: OverlayPoint = OverlayPoint(x = 18, y = 260),
    val isToolbarCollapsed: Boolean = false,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "interactionMode" to interactionMode.wireName,
            "toolbarPositionX" to toolbarPosition.x,
            "toolbarPositionY" to toolbarPosition.y,
            "collapsedToolbarPositionX" to collapsedToolbarPosition.x,
            "collapsedToolbarPositionY" to collapsedToolbarPosition.y,
            "actionButtonPositionX" to actionButtonPosition.x,
            "actionButtonPositionY" to actionButtonPosition.y,
            "isToolbarCollapsed" to isToolbarCollapsed,
        )
    }
}

data class MultiPointOverlaySettings(
    val intervalMs: Int = 500,
    val repeatCount: Int = 10,
    val infiniteLoop: Boolean = false,
    val tapDurationMs: Int = 50,
    val targets: List<MultiPointTargetState> = defaultMultiPointTargets(),
    val overlayUiState: MultiPointOverlayUiState = MultiPointOverlayUiState(),
    val appearanceSettings: OverlayAppearanceSettings = OverlayAppearanceSettings(),
)

data class MultiPointOverlaySnapshot(
    val modeEnabled: Boolean,
    val taskRunState: TaskRunState = TaskRunState.IDLE,
    val completedRounds: Int = 0,
    val currentRound: Int = 0,
    val executedActionCountInCurrentRound: Int = 0,
    val currentTargetId: String? = null,
    val targets: List<MultiPointTargetState> = emptyList(),
    val overlayUiState: MultiPointOverlayUiState? = null,
    val errorCode: String? = null,
) {
    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "modeEnabled" to modeEnabled,
            "taskRunState" to taskRunState.wireName,
            "completedRounds" to completedRounds,
            "currentRound" to currentRound,
            "executedActionCountInCurrentRound" to executedActionCountInCurrentRound,
            "targets" to targets.map { it.toMap() },
        )
        currentTargetId?.let { map["currentTargetId"] = it }
        errorCode?.let { map["errorCode"] = it }
        overlayUiState?.let { map.putAll(it.toMap()) }
        return map
    }
}

fun defaultMultiPointTargets(): List<MultiPointTargetState> {
    return listOf(
        MultiPointTargetState(
            id = "p1",
            order = 1,
            label = "1",
            x = 280,
            y = 260,
            enabled = true,
        ),
        MultiPointTargetState(
            id = "p2",
            order = 2,
            label = "2",
            x = 280,
            y = 340,
            enabled = true,
        ),
    )
}
