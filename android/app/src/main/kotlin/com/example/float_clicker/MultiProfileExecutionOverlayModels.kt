package com.example.float_clicker

internal data class LoadedMultiPointProfileState(
    val profileId: String,
    val displayName: String,
    val order: Int,
    val targets: List<MultiPointTargetState>,
    val intervalMs: Int,
    val repeatCount: Int,
    val infiniteLoop: Boolean,
    val tapDurationMs: Int,
    val buttonPosition: OverlayPoint?,
) {
    fun toClickTaskRequest(): MultiPointClickTaskRequest {
        return MultiPointClickTaskRequest(
            targets = targets,
            intervalMs = intervalMs,
            repeatCount = repeatCount,
            infiniteLoop = infiniteLoop,
            tapDurationMs = tapDurationMs,
        )
    }

    companion object {
        fun fromMap(value: Any?, fallbackOrder: Int): LoadedMultiPointProfileState? {
            val map = value as? Map<*, *> ?: return null
            val profileId = (map["profileId"] as? String)?.trim()
            val displayName = (map["displayName"] as? String)?.trim()
            if (profileId.isNullOrEmpty() || displayName.isNullOrEmpty()) {
                return null
            }
            val targets = (map["targets"] as? List<*>)
                ?.mapIndexedNotNull { index, target ->
                    MultiPointTargetState.fromMap(target, fallbackOrder = index + 1)
                }
                .orEmpty()
                .sortedWith(compareBy<MultiPointTargetState> { it.order }.thenBy { it.id })
                .mapIndexed { index, target -> target.copy(order = index + 1) }
            if (targets.none { it.enabled }) {
                return null
            }
            val settings = map["settings"] as? Map<*, *> ?: emptyMap<Any?, Any?>()

            return LoadedMultiPointProfileState(
                profileId = profileId,
                displayName = displayName,
                order = (map["order"] as? Number)?.toInt() ?: fallbackOrder,
                targets = targets,
                intervalMs = (settings["intervalMs"] as? Number)?.toInt() ?: 500,
                repeatCount = (settings["repeatCount"] as? Number)?.toInt() ?: 10,
                infiniteLoop = settings["infiniteLoop"] as? Boolean ?: false,
                tapDurationMs = (settings["tapDurationMs"] as? Number)?.toInt() ?: 50,
                buttonPosition = buttonPositionFrom(map),
            )
        }

        private fun buttonPositionFrom(map: Map<*, *>): OverlayPoint? {
            val x = (map["buttonPositionX"] as? Number)?.toInt()
            val y = (map["buttonPositionY"] as? Number)?.toInt()
            if (x == null || y == null) {
                return null
            }
            return OverlayPoint(x = x, y = y)
        }
    }
}

internal fun loadedMultiPointProfilesFrom(arguments: Any?): List<LoadedMultiPointProfileState> {
    val map = arguments as? Map<*, *> ?: return emptyList()
    val rawProfiles = map["loadedProfiles"] as? List<*> ?: return emptyList()
    return rawProfiles
        .mapIndexedNotNull { index, value ->
            LoadedMultiPointProfileState.fromMap(value, fallbackOrder = index + 1)
        }
        .distinctBy { it.profileId }
        .sortedWith(compareBy<LoadedMultiPointProfileState> { it.order }.thenBy { it.profileId })
        .mapIndexed { index, profile -> profile.copy(order = index + 1) }
}
