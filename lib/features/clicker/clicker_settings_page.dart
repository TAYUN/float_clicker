import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/global_overlay_appearance_settings.dart';
import 'clicker_settings.dart';

class ClickerSettingsPage extends StatefulWidget {
  const ClickerSettingsPage({
    super.key,
    required this.initialSettings,
    required this.initialAppearanceSettings,
  });

  static const routeName = '/single-point/settings';

  final SinglePointSettings initialSettings;
  final GlobalOverlayAppearanceSettings initialAppearanceSettings;

  @override
  State<ClickerSettingsPage> createState() => _ClickerSettingsPageState();
}

class _ClickerSettingsPageState extends State<ClickerSettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _repeatController;
  late final TextEditingController _tapDurationController;

  late bool _infiniteLoop;
  late double _overlayControlScale;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(
      text: widget.initialSettings.clickerSettings.intervalMs.toString(),
    );
    _repeatController = TextEditingController(
      text: widget.initialSettings.clickerSettings.repeatCount.toString(),
    );
    _tapDurationController = TextEditingController(
      text: widget.initialSettings.clickerSettings.tapDurationMs.toString(),
    );
    _infiniteLoop = widget.initialSettings.clickerSettings.infiniteLoop;
    _interactionMode = widget.initialSettings.overlayUiSettings.interactionMode;
    _overlayControlScale = widget.initialAppearanceSettings.overlayControlScale;
  }

  late OverlayInteractionMode _interactionMode;

  @override
  void dispose() {
    _intervalController.dispose();
    _repeatController.dispose();
    _tapDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单点设置')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('保存'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '点击参数',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _NumberField(
                      controller: _intervalController,
                      labelText: '点击间隔',
                      suffixText: '毫秒',
                    ),
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _tapDurationController,
                      labelText: '点击持续时间',
                      suffixText: '毫秒',
                    ),
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _repeatController,
                      enabled: !_infiniteLoop,
                      labelText: '点击次数',
                      suffixText: '次',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('无限循环'),
                      subtitle: const Text('开启后点击会持续执行，直到手动停止'),
                      value: _infiniteLoop,
                      onChanged: (value) {
                        setState(() {
                          _infiniteLoop = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '悬浮交互',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<OverlayInteractionMode>(
                      groupValue: _interactionMode,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _interactionMode = value;
                        });
                      },
                      child: Column(
                        children: [
                          for (final mode in OverlayInteractionMode.values)
                            RadioListTile<OverlayInteractionMode>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(mode.label),
                              subtitle: Text(mode.description),
                              value: mode,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                            '全局悬浮外观',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _resetOverlayControlScale,
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
                    Row(
                      children: [
                        const Expanded(child: Text('悬浮控件大小')),
                        Text(
                          _overlayControlScaleLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    Slider(
                      value: _overlayControlScale,
                      min: GlobalOverlayAppearanceSettings.minScale,
                      max: GlobalOverlayAppearanceSettings.maxScale,
                      divisions:
                          ((GlobalOverlayAppearanceSettings.maxScale -
                                      GlobalOverlayAppearanceSettings
                                          .minScale) /
                                  GlobalOverlayAppearanceSettings.step)
                              .round(),
                      label: _overlayControlScaleLabel,
                      onChanged: (value) {
                        setState(() {
                          _overlayControlScale =
                              GlobalOverlayAppearanceSettings.normalizeScale(
                                value,
                              );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _save() {
    final intervalMs = int.tryParse(_intervalController.text);
    final repeatCount = int.tryParse(_repeatController.text);
    final tapDurationMs = int.tryParse(_tapDurationController.text);

    if (intervalMs == null ||
        intervalMs <= 0 ||
        repeatCount == null ||
        repeatCount <= 0 ||
        tapDurationMs == null ||
        tapDurationMs <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入大于 0 的参数')));
      return;
    }

    // 设置页只负责收集配置，真正应用配置由单点模式页的控制器完成。
    Navigator.of(context).pop(
      ClickerSettingsResult(
        singlePointSettings: SinglePointSettings(
          clickerSettings: ClickerSettings(
            intervalMs: intervalMs,
            repeatCount: repeatCount,
            infiniteLoop: _infiniteLoop,
            tapDurationMs: tapDurationMs,
          ),
          overlayUiSettings: widget.initialSettings.overlayUiSettings.copyWith(
            interactionMode: _interactionMode,
          ),
        ),
        appearanceSettings: GlobalOverlayAppearanceSettings(
          overlayControlScale: GlobalOverlayAppearanceSettings.normalizeScale(
            _overlayControlScale,
          ),
        ),
      ),
    );
  }

  String get _overlayControlScaleLabel {
    return '${(_overlayControlScale * 100).round()}%';
  }

  void _resetOverlayControlScale() {
    setState(() {
      _overlayControlScale =
          GlobalOverlayAppearanceSettings.defaults.overlayControlScale;
    });
  }
}

class ClickerSettingsResult {
  const ClickerSettingsResult({
    required this.singlePointSettings,
    required this.appearanceSettings,
  });

  final SinglePointSettings singlePointSettings;
  final GlobalOverlayAppearanceSettings appearanceSettings;
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.labelText,
    required this.suffixText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String labelText;
  final String suffixText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: labelText, suffixText: suffixText),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }
}
