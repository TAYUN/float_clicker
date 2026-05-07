package com.example.float_clicker

enum class OverlayInteractionMode(val wireName: String) {
    NORMAL("normal"),
    COMPACT("compact"),
    MINIMAL("minimal"),
    ;

    companion object {
        fun fromWireName(value: String?): OverlayInteractionMode {
            return when (value) {
                COMPACT.wireName -> COMPACT
                MINIMAL.wireName -> MINIMAL
                else -> NORMAL
            }
        }
    }
}

data class OverlayPoint(
    val x: Int,
    val y: Int,
)

data class OverlayInteractionState(
    val interactionMode: OverlayInteractionMode = OverlayInteractionMode.NORMAL,
    val targetPosition: OverlayPoint = OverlayPoint(x = 280, y = 260),
    val toolbarPosition: OverlayPoint = OverlayPoint(x = 18, y = 180),
    val collapsedToolbarPosition: OverlayPoint = OverlayPoint(x = 18, y = 180),
    val actionButtonPosition: OverlayPoint = OverlayPoint(x = 18, y = 260),
    val isToolbarCollapsed: Boolean = false,
) {
    fun shouldShowToolbar(): Boolean {
        return when (interactionMode) {
            OverlayInteractionMode.NORMAL -> true
            OverlayInteractionMode.COMPACT -> !isToolbarCollapsed
            OverlayInteractionMode.MINIMAL -> false
        }
    }

    fun shouldShowCollapsedToolbar(): Boolean {
        return interactionMode == OverlayInteractionMode.COMPACT && isToolbarCollapsed
    }

    fun shouldShowActionButton(): Boolean {
        return interactionMode == OverlayInteractionMode.MINIMAL ||
            (interactionMode == OverlayInteractionMode.COMPACT && isToolbarCollapsed)
    }
}
