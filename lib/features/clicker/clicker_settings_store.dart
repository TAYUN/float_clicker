import 'package:shared_preferences/shared_preferences.dart';

import 'clicker_settings.dart';

class ClickerSettingsStore {
  const ClickerSettingsStore();

  static const _intervalMsKey = 'single_point.interval_ms';
  static const _repeatCountKey = 'single_point.repeat_count';
  static const _infiniteLoopKey = 'single_point.infinite_loop';
  static const _tapDurationMsKey = 'single_point.tap_duration_ms';

  Future<ClickerSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final defaults = ClickerSettings.defaults;

    // 每一项单独兜底，允许后续新增配置时老用户仍能读到完整设置对象。
    return ClickerSettings(
      intervalMs: preferences.getInt(_intervalMsKey) ?? defaults.intervalMs,
      repeatCount: preferences.getInt(_repeatCountKey) ?? defaults.repeatCount,
      infiniteLoop:
          preferences.getBool(_infiniteLoopKey) ?? defaults.infiniteLoop,
      tapDurationMs:
          preferences.getInt(_tapDurationMsKey) ?? defaults.tapDurationMs,
    );
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
}
