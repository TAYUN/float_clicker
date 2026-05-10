import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'multi_point_settings.dart';

/// 多点模式 P1 的本地持久化入口。
///
/// 配置参数沿用单点的散 key 风格，点位列表使用 JSON，方便后续增加点位字段。
class MultiPointSettingsStore {
  const MultiPointSettingsStore();

  static const profilesJsonKey = 'multi_point.profiles_json';
  static const activeProfileIdKey = 'multi_point.active_profile_id';
  static const loadedProfileIdsJsonKey = 'multi_point.loaded_profile_ids_json';
  static const intervalMsKey = 'multi_point.interval_ms';
  static const repeatCountKey = 'multi_point.repeat_count';
  static const infiniteLoopKey = 'multi_point.infinite_loop';
  static const tapDurationMsKey = 'multi_point.tap_duration_ms';
  static const targetsJsonKey = 'multi_point.targets_json';
  static const overlayInteractionModeKey =
      'multi_point.overlay_interaction_mode';
  static const toolbarPositionXKey = 'multi_point.toolbar_position_x';
  static const toolbarPositionYKey = 'multi_point.toolbar_position_y';
  static const collapsedToolbarPositionXKey =
      'multi_point.collapsed_toolbar_position_x';
  static const collapsedToolbarPositionYKey =
      'multi_point.collapsed_toolbar_position_y';
  static const actionButtonPositionXKey =
      'multi_point.action_button_position_x';
  static const actionButtonPositionYKey =
      'multi_point.action_button_position_y';
  static const isToolbarCollapsedKey = 'multi_point.is_toolbar_collapsed';
  static const executionLauncherPositionXKey =
      'multi_point.execution_launcher_position_x';
  static const executionLauncherPositionYKey =
      'multi_point.execution_launcher_position_y';

  Future<MultiPointConfiguration> loadConfiguration() async {
    return (await loadProfileState()).activeProfile.configuration;
  }

  Future<MultiPointProfileState> loadProfileState() async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    await _saveProfileState(preferences, state);
    return state;
  }

  Future<MultiPointSettings> loadSettings() async {
    return (await loadConfiguration()).settings;
  }

  Future<MultiPointOverlayUiSettings> loadOverlayUiSettings() async {
    return (await loadConfiguration()).overlayUiSettings;
  }

  Future<MultiPointTargets> loadTargets() async {
    return (await loadConfiguration()).targets;
  }

  Future<void> saveConfiguration(MultiPointConfiguration configuration) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    final nextProfiles = [
      for (final profile in state.profiles)
        profile.id == state.activeProfileId
            ? profile.withConfiguration(configuration)
            : profile,
    ];
    await _saveProfileState(
      preferences,
      MultiPointProfileState(
        profiles: nextProfiles,
        activeProfileId: state.activeProfileId,
        loadedProfiles: state.loadedProfiles,
      ),
    );
  }

  Future<void> saveSettings(MultiPointSettings settings) async {
    final configuration = await loadConfiguration();
    await saveConfiguration(configuration.copyWith(settings: settings));
  }

  Future<void> saveOverlayUiSettings(
    MultiPointOverlayUiSettings settings,
  ) async {
    final configuration = await loadConfiguration();
    await saveConfiguration(
      configuration.copyWith(overlayUiSettings: settings),
    );
  }

  Future<void> saveTargets(MultiPointTargets targets) async {
    final configuration = await loadConfiguration();
    await saveConfiguration(configuration.copyWith(targets: targets));
  }

  Future<MultiPointProfileState> saveProfileState(
    MultiPointProfileState state,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _saveProfileState(preferences, state);
    return _readProfileState(preferences);
  }

  Future<MultiProfileExecutionLauncherPosition?>
  loadExecutionLauncherPosition() async {
    final preferences = await SharedPreferences.getInstance();
    final x = preferences.getInt(executionLauncherPositionXKey);
    final y = preferences.getInt(executionLauncherPositionYKey);
    if (x == null || y == null) {
      return null;
    }
    return MultiProfileExecutionLauncherPosition(x: x, y: y);
  }

  Future<void> saveExecutionLauncherPosition(
    MultiProfileExecutionLauncherPosition position,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setInt(executionLauncherPositionXKey, position.x),
      preferences.setInt(executionLauncherPositionYKey, position.y),
    ]);
  }

  Future<MultiPointProfileState> createProfile({String? name}) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    final now = DateTime.now();
    final profile = MultiPointProfile.defaultProfile(now: now).copyWith(
      id: _nextProfileId(state.profiles),
      name: _uniqueProfileName(
        state.profiles,
        _cleanProfileName(name) ?? '新配置',
      ),
    );
    final nextState = MultiPointProfileState(
      profiles: [...state.profiles, profile],
      activeProfileId: profile.id,
      loadedProfiles: state.loadedProfiles,
    );
    await _saveProfileState(preferences, nextState);
    return nextState;
  }

  Future<MultiPointProfileState> copyProfile(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    final source = state.profiles.firstWhere(
      (profile) => profile.id == profileId,
      orElse: () => state.activeProfile,
    );
    final now = DateTime.now();
    final copy = source.copyWith(
      id: _nextProfileId(state.profiles),
      name: _uniqueProfileName(state.profiles, '${source.name} 副本'),
      createdAt: now,
      updatedAt: now,
    );
    final nextState = MultiPointProfileState(
      profiles: [...state.profiles, copy],
      activeProfileId: copy.id,
      loadedProfiles: state.loadedProfiles,
    );
    await _saveProfileState(preferences, nextState);
    return nextState;
  }

  Future<MultiPointProfileState> renameProfile(
    String profileId,
    String name,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    final nextName = _cleanProfileName(name);
    if (nextName == null) {
      return state;
    }

    final nextProfiles = [
      for (final profile in state.profiles)
        profile.id == profileId
            ? profile.copyWith(name: nextName, updatedAt: DateTime.now())
            : profile,
    ];
    final nextState = MultiPointProfileState(
      profiles: nextProfiles,
      activeProfileId: state.activeProfileId,
      loadedProfiles: state.loadedProfiles,
    );
    await _saveProfileState(preferences, nextState);
    return nextState;
  }

  Future<MultiPointProfileState> deleteProfile(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    if (state.profiles.length <= 1) {
      return state;
    }

    final nextProfiles = state.profiles
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    final nextActiveProfileId =
        nextProfiles.any((profile) => profile.id == state.activeProfileId)
        ? state.activeProfileId
        : nextProfiles.first.id;
    final nextState = MultiPointProfileState(
      profiles: nextProfiles,
      activeProfileId: nextActiveProfileId,
      loadedProfiles: state.loadedProfiles,
    );
    await _saveProfileState(preferences, nextState);
    return nextState;
  }

  Future<MultiPointProfileState> setActiveProfile(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readProfileState(preferences);
    final nextState = MultiPointProfileState(
      profiles: state.profiles,
      activeProfileId: profileId,
      loadedProfiles: state.loadedProfiles,
    );
    await _saveProfileState(preferences, nextState);
    return nextState;
  }

  MultiPointProfileState _readProfileState(SharedPreferences preferences) {
    final profiles = _loadProfiles(preferences);
    if (profiles.isNotEmpty) {
      return MultiPointProfileState(
        profiles: profiles,
        activeProfileId: preferences.getString(activeProfileIdKey) ?? '',
        loadedProfiles: _loadLoadedProfiles(preferences),
      );
    }

    // 没有 profile 库或 profile JSON 损坏时，回到旧单配置 key，保证升级不丢点位。
    final defaultProfile = MultiPointProfile.defaultProfile(
      configuration: _loadLegacyConfiguration(preferences),
    );
    return MultiPointProfileState(
      profiles: [defaultProfile],
      activeProfileId: defaultProfile.id,
      loadedProfiles: [
        const LoadedMultiPointProfile(
          profileId: MultiPointProfile.defaultProfileId,
          order: 1,
          isVisible: true,
        ),
      ],
    );
  }

  List<MultiPointProfile> _loadProfiles(SharedPreferences preferences) {
    final profilesJson = preferences.getString(profilesJsonKey);
    if (profilesJson == null) {
      return const [];
    }

    try {
      final decoded = jsonDecode(profilesJson);
      if (decoded is! List) {
        return const [];
      }

      final profiles = <MultiPointProfile>[];
      final seenIds = <String>{};
      for (final item in decoded) {
        final profile = MultiPointProfile.tryFromJson(item);
        if (profile == null || seenIds.contains(profile.id)) {
          continue;
        }
        profiles.add(profile);
        seenIds.add(profile.id);
      }
      return profiles;
    } on FormatException {
      return const [];
    }
  }

  Future<void> _saveProfileState(
    SharedPreferences preferences,
    MultiPointProfileState state,
  ) async {
    final profiles = state.profiles.isEmpty
        ? [MultiPointProfile.defaultProfile()]
        : state.profiles;
    final normalizedState = MultiPointProfileState(
      profiles: profiles,
      activeProfileId: state.activeProfileId,
      loadedProfiles: state.loadedProfiles,
    );
    final activeConfiguration = normalizedState.activeProfile.configuration;

    await Future.wait([
      preferences.setString(
        profilesJsonKey,
        jsonEncode([
          for (final profile in normalizedState.profiles) profile.toJson(),
        ]),
      ),
      preferences.setString(
        activeProfileIdKey,
        normalizedState.activeProfileId,
      ),
      preferences.setString(
        loadedProfileIdsJsonKey,
        jsonEncode([
          for (final loadedProfile in normalizedState.loadedProfiles)
            loadedProfile.toJson(),
        ]),
      ),
      _saveLegacyConfiguration(preferences, activeConfiguration),
    ]);
  }

  List<LoadedMultiPointProfile> _loadLoadedProfiles(
    SharedPreferences preferences,
  ) {
    final loadedProfilesJson = preferences.getString(loadedProfileIdsJsonKey);
    if (loadedProfilesJson == null) {
      return const [];
    }

    try {
      final decoded = jsonDecode(loadedProfilesJson);
      if (decoded is! List) {
        return const [];
      }

      final loadedProfiles = <LoadedMultiPointProfile>[];
      for (var index = 0; index < decoded.length; index += 1) {
        final loadedProfile = LoadedMultiPointProfile.tryFromJson(
          decoded[index],
          fallbackOrder: index + 1,
        );
        if (loadedProfile != null) {
          loadedProfiles.add(loadedProfile);
        }
      }
      return loadedProfiles..sort((a, b) => a.order.compareTo(b.order));
    } on FormatException {
      return const [];
    }
  }

  Future<void> _saveLegacyConfiguration(
    SharedPreferences preferences,
    MultiPointConfiguration configuration,
  ) async {
    // P6 以 profiles_json 为主，但继续同步旧散 key，方便旧页面、测试和回滚读取。
    await Future.wait([
      preferences.setInt(intervalMsKey, configuration.settings.intervalMs),
      preferences.setInt(repeatCountKey, configuration.settings.repeatCount),
      preferences.setBool(infiniteLoopKey, configuration.settings.infiniteLoop),
      preferences.setInt(
        tapDurationMsKey,
        configuration.settings.tapDurationMs,
      ),
      preferences.setString(
        overlayInteractionModeKey,
        configuration.overlayUiSettings.interactionMode.name,
      ),
      preferences.setInt(
        toolbarPositionXKey,
        configuration.overlayUiSettings.toolbarPositionX,
      ),
      preferences.setInt(
        toolbarPositionYKey,
        configuration.overlayUiSettings.toolbarPositionY,
      ),
      preferences.setInt(
        collapsedToolbarPositionXKey,
        configuration.overlayUiSettings.collapsedToolbarPositionX,
      ),
      preferences.setInt(
        collapsedToolbarPositionYKey,
        configuration.overlayUiSettings.collapsedToolbarPositionY,
      ),
      preferences.setInt(
        actionButtonPositionXKey,
        configuration.overlayUiSettings.actionButtonPositionX,
      ),
      preferences.setInt(
        actionButtonPositionYKey,
        configuration.overlayUiSettings.actionButtonPositionY,
      ),
      preferences.setBool(
        isToolbarCollapsedKey,
        configuration.overlayUiSettings.isToolbarCollapsed,
      ),
      preferences.setString(
        targetsJsonKey,
        jsonEncode(configuration.targets.toJsonList()),
      ),
    ]);
  }

  MultiPointConfiguration _loadLegacyConfiguration(
    SharedPreferences preferences,
  ) {
    final settingsDefaults = MultiPointSettings.defaults;
    final overlayDefaults = MultiPointOverlayUiSettings.defaults;

    // 每一类配置都独立兜底，避免旧版本缺少某些 key 时整套配置读取失败。
    return MultiPointConfiguration(
      settings: MultiPointSettings(
        intervalMs:
            preferences.getInt(intervalMsKey) ?? settingsDefaults.intervalMs,
        repeatCount:
            preferences.getInt(repeatCountKey) ?? settingsDefaults.repeatCount,
        infiniteLoop:
            preferences.getBool(infiniteLoopKey) ??
            settingsDefaults.infiniteLoop,
        tapDurationMs:
            preferences.getInt(tapDurationMsKey) ??
            settingsDefaults.tapDurationMs,
      ),
      overlayUiSettings: MultiPointOverlayUiSettings(
        interactionMode: OverlayInteractionMode.fromName(
          preferences.getString(overlayInteractionModeKey),
        ),
        toolbarPositionX:
            preferences.getInt(toolbarPositionXKey) ??
            overlayDefaults.toolbarPositionX,
        toolbarPositionY:
            preferences.getInt(toolbarPositionYKey) ??
            overlayDefaults.toolbarPositionY,
        collapsedToolbarPositionX:
            preferences.getInt(collapsedToolbarPositionXKey) ??
            overlayDefaults.collapsedToolbarPositionX,
        collapsedToolbarPositionY:
            preferences.getInt(collapsedToolbarPositionYKey) ??
            overlayDefaults.collapsedToolbarPositionY,
        actionButtonPositionX:
            preferences.getInt(actionButtonPositionXKey) ??
            overlayDefaults.actionButtonPositionX,
        actionButtonPositionY:
            preferences.getInt(actionButtonPositionYKey) ??
            overlayDefaults.actionButtonPositionY,
        isToolbarCollapsed:
            preferences.getBool(isToolbarCollapsedKey) ??
            overlayDefaults.isToolbarCollapsed,
      ),
      targets: _loadLegacyTargets(preferences),
    );
  }

  MultiPointTargets _loadLegacyTargets(SharedPreferences preferences) {
    final targetsJson = preferences.getString(targetsJsonKey);
    if (targetsJson == null) {
      return MultiPointTargets.defaults();
    }

    try {
      return MultiPointTargets.fromJsonList(jsonDecode(targetsJson));
    } on FormatException {
      // 用户升级或本地数据损坏时，回到默认点位，保证页面仍可进入并重新保存。
      return MultiPointTargets.defaults();
    }
  }

  String _nextProfileId(List<MultiPointProfile> profiles) {
    final existingIds = profiles.map((profile) => profile.id).toSet();
    var candidate = 'profile_${DateTime.now().microsecondsSinceEpoch}';
    var suffix = 1;
    while (existingIds.contains(candidate)) {
      candidate = 'profile_${DateTime.now().microsecondsSinceEpoch}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _uniqueProfileName(List<MultiPointProfile> profiles, String baseName) {
    final existingNames = profiles.map((profile) => profile.name).toSet();
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    var suffix = 2;
    while (existingNames.contains('$baseName $suffix')) {
      suffix += 1;
    }
    return '$baseName $suffix';
  }

  String? _cleanProfileName(String? name) {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
