import 'package:shared_preferences/shared_preferences.dart';

import 'global_overlay_appearance_settings.dart';

class GlobalOverlayAppearanceStore {
  const GlobalOverlayAppearanceStore();

  static const overlayControlScaleKey = 'global.overlay_control_scale';
  static const targetPointScaleKey = 'global.overlay.target_point_scale';
  static const toolbarScaleKey = 'global.overlay.toolbar_scale';
  static const actionButtonScaleKey = 'global.overlay.action_button_scale';

  Future<GlobalOverlayAppearanceSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final legacyScale = preferences.getDouble(overlayControlScaleKey);
    final fallbackSettings = legacyScale == null
        ? GlobalOverlayAppearanceSettings.defaults
        : GlobalOverlayAppearanceSettings.uniform(legacyScale);

    // 新版本拆成分组件比例；旧版本只保存一个全局比例，首次读取时用它作为三个新字段的迁移来源。
    return GlobalOverlayAppearanceSettings(
      targetPointScale: GlobalOverlayAppearanceSettings.normalizeScale(
        preferences.getDouble(targetPointScaleKey) ??
            fallbackSettings.targetPointScale,
      ),
      toolbarScale: GlobalOverlayAppearanceSettings.normalizeScale(
        preferences.getDouble(toolbarScaleKey) ?? fallbackSettings.toolbarScale,
      ),
      actionButtonScale: GlobalOverlayAppearanceSettings.normalizeScale(
        preferences.getDouble(actionButtonScaleKey) ??
            fallbackSettings.actionButtonScale,
      ),
    );
  }

  Future<void> save(GlobalOverlayAppearanceSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble(
        targetPointScaleKey,
        GlobalOverlayAppearanceSettings.normalizeScale(
          settings.targetPointScale,
        ),
      ),
      preferences.setDouble(
        toolbarScaleKey,
        GlobalOverlayAppearanceSettings.normalizeScale(settings.toolbarScale),
      ),
      preferences.setDouble(
        actionButtonScaleKey,
        GlobalOverlayAppearanceSettings.normalizeScale(
          settings.actionButtonScale,
        ),
      ),
    ]);
  }
}
