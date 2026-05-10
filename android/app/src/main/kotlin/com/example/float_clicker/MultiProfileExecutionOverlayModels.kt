package com.example.float_clicker

data class LoadedMultiPointProfileState(
    val profileId: String,
    val displayName: String,
    val order: Int,
) {
    companion object {
        fun fromMap(value: Any?, fallbackOrder: Int): LoadedMultiPointProfileState? {
            val map = value as? Map<*, *> ?: return null
            val profileId = (map["profileId"] as? String)?.trim()
            val displayName = (map["displayName"] as? String)?.trim()
            if (profileId.isNullOrEmpty() || displayName.isNullOrEmpty()) {
                return null
            }

            return LoadedMultiPointProfileState(
                profileId = profileId,
                displayName = displayName,
                order = (map["order"] as? Number)?.toInt() ?: fallbackOrder,
            )
        }
    }
}

fun loadedMultiPointProfilesFrom(arguments: Any?): List<LoadedMultiPointProfileState> {
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
