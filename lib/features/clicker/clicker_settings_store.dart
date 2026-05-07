import 'package:shared_preferences/shared_preferences.dart';

import 'clicker_settings.dart';

class ClickerSettingsStore {
  const ClickerSettingsStore();

  static const _intervalMsKey = 'single_point.interval_ms';
  static const _repeatCountKey = 'single_point.repeat_count';
  static const _infiniteLoopKey = 'single_point.infinite_loop';
  static const _tapDurationMsKey = 'single_point.tap_duration_ms';
  static const _overlayInteractionModeKey =
      'single_point.overlay_interaction_mode';
  static const _targetPositionXKey = 'single_point.target_position_x';
  static const _targetPositionYKey = 'single_point.target_position_y';
  static const _toolbarPositionXKey = 'single_point.toolbar_position_x';
  static const _toolbarPositionYKey = 'single_point.toolbar_position_y';
  static const _collapsedToolbarPositionXKey =
      'single_point.collapsed_toolbar_position_x';
  static const _collapsedToolbarPositionYKey =
      'single_point.collapsed_toolbar_position_y';
  static const _actionButtonPositionXKey =
      'single_point.action_button_position_x';
  static const _actionButtonPositionYKey =
      'single_point.action_button_position_y';
  static const _isToolbarCollapsedKey = 'single_point.is_toolbar_collapsed';

  Future<ClickerSettings> load() async {
    return (await loadSinglePointSettings()).clickerSettings;
  }

  Future<SinglePointSettings> loadSinglePointSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final clickerDefaults = ClickerSettings.defaults;
    final overlayDefaults = OverlayUiSettings.defaults;

    // 每一项单独兜底，允许后续新增配置时老用户仍能读到完整设置对象。
    return SinglePointSettings(
      clickerSettings: ClickerSettings(
        intervalMs:
            preferences.getInt(_intervalMsKey) ?? clickerDefaults.intervalMs,
        repeatCount:
            preferences.getInt(_repeatCountKey) ?? clickerDefaults.repeatCount,
        infiniteLoop:
            preferences.getBool(_infiniteLoopKey) ??
            clickerDefaults.infiniteLoop,
        tapDurationMs:
            preferences.getInt(_tapDurationMsKey) ??
            clickerDefaults.tapDurationMs,
      ),
      overlayUiSettings: OverlayUiSettings(
        interactionMode: OverlayInteractionMode.fromName(
          preferences.getString(_overlayInteractionModeKey),
        ),
        targetPositionX:
            preferences.getInt(_targetPositionXKey) ??
            overlayDefaults.targetPositionX,
        targetPositionY:
            preferences.getInt(_targetPositionYKey) ??
            overlayDefaults.targetPositionY,
        toolbarPositionX:
            preferences.getInt(_toolbarPositionXKey) ??
            overlayDefaults.toolbarPositionX,
        toolbarPositionY:
            preferences.getInt(_toolbarPositionYKey) ??
            overlayDefaults.toolbarPositionY,
        collapsedToolbarPositionX:
            preferences.getInt(_collapsedToolbarPositionXKey) ??
            overlayDefaults.collapsedToolbarPositionX,
        collapsedToolbarPositionY:
            preferences.getInt(_collapsedToolbarPositionYKey) ??
            overlayDefaults.collapsedToolbarPositionY,
        actionButtonPositionX:
            preferences.getInt(_actionButtonPositionXKey) ??
            overlayDefaults.actionButtonPositionX,
        actionButtonPositionY:
            preferences.getInt(_actionButtonPositionYKey) ??
            overlayDefaults.actionButtonPositionY,
        isToolbarCollapsed:
            preferences.getBool(_isToolbarCollapsedKey) ??
            overlayDefaults.isToolbarCollapsed,
      ),
    );
  }

  Future<void> saveSinglePointSettings(SinglePointSettings settings) async {
    await Future.wait([
      save(settings.clickerSettings),
      saveOverlayUiSettings(settings.overlayUiSettings),
    ]);
  }

  Future<void> save(ClickerSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    // 单点模式配置体积很小，逐项保存比引入 JSON 序列化更直观。
    await Future.wait([
      preferences.setInt(_intervalMsKey, settings.intervalMs),
      preferences.setInt(_repeatCountKey, settings.repeatCount),
      preferences.setBool(_infiniteLoopKey, settings.infiniteLoop),
      preferences.setInt(_tapDurationMsKey, settings.tapDurationMs),
    ]);
  }

  Future<void> saveOverlayUiSettings(OverlayUiSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait([
      preferences.setString(
        _overlayInteractionModeKey,
        settings.interactionMode.name,
      ),
      preferences.setInt(_targetPositionXKey, settings.targetPositionX),
      preferences.setInt(_targetPositionYKey, settings.targetPositionY),
      preferences.setInt(_toolbarPositionXKey, settings.toolbarPositionX),
      preferences.setInt(_toolbarPositionYKey, settings.toolbarPositionY),
      preferences.setInt(
        _collapsedToolbarPositionXKey,
        settings.collapsedToolbarPositionX,
      ),
      preferences.setInt(
        _collapsedToolbarPositionYKey,
        settings.collapsedToolbarPositionY,
      ),
      preferences.setInt(
        _actionButtonPositionXKey,
        settings.actionButtonPositionX,
      ),
      preferences.setInt(
        _actionButtonPositionYKey,
        settings.actionButtonPositionY,
      ),
      preferences.setBool(_isToolbarCollapsedKey, settings.isToolbarCollapsed),
    ]);
  }
}
