import 'package:flutter/material.dart';

import '../../core/platform/android_permission_service.dart';
import '../../core/settings/global_overlay_appearance_settings.dart';
import '../../core/settings/global_overlay_appearance_store.dart';

class GlobalSettingsPage extends StatefulWidget {
  const GlobalSettingsPage({super.key});

  static const routeName = '/settings';

  @override
  State<GlobalSettingsPage> createState() => _GlobalSettingsPageState();
}

class _GlobalSettingsPageState extends State<GlobalSettingsPage> {
  final GlobalOverlayAppearanceStore _appearanceStore =
      const GlobalOverlayAppearanceStore();
  final AndroidPermissionService _permissionService =
      AndroidPermissionService();

  GlobalOverlayAppearanceSettings _settings =
      GlobalOverlayAppearanceSettings.defaults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _appearanceStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _appearanceStore.save(_settings);
    await _permissionService.updateGlobalOverlayAppearanceSettings(_settings);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('全局设置已保存')));
  }

  void _resetAppearance() {
    setState(() {
      _settings = GlobalOverlayAppearanceSettings.defaults;
    });
  }

  void _updateAppearance({
    double? targetPointScale,
    double? toolbarScale,
    double? actionButtonScale,
  }) {
    setState(() {
      _settings = _settings.copyWith(
        targetPointScale: targetPointScale,
        toolbarScale: toolbarScale,
        actionButtonScale: actionButtonScale,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全局设置')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _isLoading ? null : _saveSettings,
          icon: const Icon(Icons.check),
          label: const Text('保存'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '悬浮外观',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: _resetAppearance,
                                child: const Text('恢复默认'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '对单点模式和后续多点模式生效',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _ScaleSlider(
                            title: '悬浮点位大小',
                            value: _settings.targetPointScale,
                            onChanged: (value) =>
                                _updateAppearance(targetPointScale: value),
                          ),
                          const SizedBox(height: 8),
                          _ScaleSlider(
                            title: '控制条大小',
                            value: _settings.toolbarScale,
                            onChanged: (value) =>
                                _updateAppearance(toolbarScale: value),
                          ),
                          const SizedBox(height: 8),
                          _ScaleSlider(
                            title: '独立控件大小',
                            value: _settings.actionButtonScale,
                            onChanged: (value) =>
                                _updateAppearance(actionButtonScale: value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  const _ScaleSlider({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = '${(value * 100).round()}%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value,
          min: GlobalOverlayAppearanceSettings.minScale,
          max: GlobalOverlayAppearanceSettings.maxScale,
          divisions:
              ((GlobalOverlayAppearanceSettings.maxScale -
                          GlobalOverlayAppearanceSettings.minScale) /
                      GlobalOverlayAppearanceSettings.step)
                  .round(),
          label: label,
          onChanged: (nextValue) {
            onChanged(
              GlobalOverlayAppearanceSettings.normalizeScale(nextValue),
            );
          },
        ),
      ],
    );
  }
}
