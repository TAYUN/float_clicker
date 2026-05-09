package com.example.float_clicker

/**
 * 通用自动化动作模型。
 *
 * P4.1 第一版只开放 tap，后续多点调度器会按启用点位顺序生成同类动作。
 * 坐标不直接固化在动作里，执行前通过 targetId 查询最新位置，保证拖动点位后下一次点击使用新坐标。
 */
internal sealed class AutomationAction {
    abstract val id: String

    data class Tap(
        override val id: String,
        val targetId: String,
        val durationMs: Long,
    ) : AutomationAction()
}

internal data class AutomationTargetPosition(
    val x: Float,
    val y: Float,
)

internal fun interface AutomationTargetPositionProvider {
    fun positionOf(targetId: String): AutomationTargetPosition?
}
