import 'package:shared_preferences/shared_preferences.dart';

import 'global_overlay_appearance_settings.dart';

class GlobalOverlayAppearanceStore {
  const GlobalOverlayAppearanceStore();

  static const overlayControlScaleKey = 'global.overlay_control_scale';

  Future<GlobalOverlayAppearanceSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final scale = preferences.getDouble(overlayControlScaleKey);

    // 全局外观配置会被单点和后续多点复用；读取时统一做范围裁剪，避免旧版本异常值影响悬浮控件。
    return GlobalOverlayAppearanceSettings(
      overlayControlScale: GlobalOverlayAppearanceSettings.normalizeScale(
        scale ?? GlobalOverlayAppearanceSettings.defaults.overlayControlScale,
      ),
    );
  }

  Future<void> save(GlobalOverlayAppearanceSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(
      overlayControlScaleKey,
      GlobalOverlayAppearanceSettings.normalizeScale(
        settings.overlayControlScale,
      ),
    );
  }
}
