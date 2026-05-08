import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'multi_point_settings.dart';

/// 多点模式 P1 的本地持久化入口。
///
/// 配置参数沿用单点的散 key 风格，点位列表使用 JSON，方便后续增加点位字段。
class MultiPointSettingsStore {
  const MultiPointSettingsStore();

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

  Future<MultiPointConfiguration> loadConfiguration() async {
    final preferences = await SharedPreferences.getInstance();
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
      targets: _loadTargets(preferences),
    );
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
    await Future.wait([
      saveSettings(configuration.settings),
      saveOverlayUiSettings(configuration.overlayUiSettings),
      saveTargets(configuration.targets),
    ]);
  }

  Future<void> saveSettings(MultiPointSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    // 点击参数是固定字段，使用散 key 可直接对齐后续 MethodChannel 参数。
    await Future.wait([
      preferences.setInt(intervalMsKey, settings.intervalMs),
      preferences.setInt(repeatCountKey, settings.repeatCount),
      preferences.setBool(infiniteLoopKey, settings.infiniteLoop),
      preferences.setInt(tapDurationMsKey, settings.tapDurationMs),
    ]);
  }

  Future<void> saveOverlayUiSettings(
    MultiPointOverlayUiSettings settings,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    // 多点悬浮控制组件位置独立保存；点位坐标由 targets_json 负责。
    await Future.wait([
      preferences.setString(
        overlayInteractionModeKey,
        settings.interactionMode.name,
      ),
      preferences.setInt(toolbarPositionXKey, settings.toolbarPositionX),
      preferences.setInt(toolbarPositionYKey, settings.toolbarPositionY),
      preferences.setInt(
        collapsedToolbarPositionXKey,
        settings.collapsedToolbarPositionX,
      ),
      preferences.setInt(
        collapsedToolbarPositionYKey,
        settings.collapsedToolbarPositionY,
      ),
      preferences.setInt(
        actionButtonPositionXKey,
        settings.actionButtonPositionX,
      ),
      preferences.setInt(
        actionButtonPositionYKey,
        settings.actionButtonPositionY,
      ),
      preferences.setBool(isToolbarCollapsedKey, settings.isToolbarCollapsed),
    ]);
  }

  Future<void> saveTargets(MultiPointTargets targets) async {
    final preferences = await SharedPreferences.getInstance();

    // 点位列表使用单个 JSON key，便于后续加入字段时保持向后兼容。
    await preferences.setString(
      targetsJsonKey,
      jsonEncode(targets.toJsonList()),
    );
  }

  MultiPointTargets _loadTargets(SharedPreferences preferences) {
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
}
