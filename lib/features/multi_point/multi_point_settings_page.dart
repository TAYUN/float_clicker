import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'multi_point_settings.dart';

class MultiPointSettingsPage extends StatefulWidget {
  const MultiPointSettingsPage({super.key, required this.initialSettings});

  static const routeName = '/multi-point/settings';

  final MultiPointConfiguration initialSettings;

  @override
  State<MultiPointSettingsPage> createState() => _MultiPointSettingsPageState();
}

class _MultiPointSettingsPageState extends State<MultiPointSettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _repeatController;
  late final TextEditingController _tapDurationController;

  late bool _infiniteLoop;
  late OverlayInteractionMode _interactionMode;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(
      text: widget.initialSettings.settings.intervalMs.toString(),
    );
    _repeatController = TextEditingController(
      text: widget.initialSettings.settings.repeatCount.toString(),
    );
    _tapDurationController = TextEditingController(
      text: widget.initialSettings.settings.tapDurationMs.toString(),
    );
    _infiniteLoop = widget.initialSettings.settings.infiniteLoop;
    _interactionMode = widget.initialSettings.overlayUiSettings.interactionMode;
  }

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
      appBar: AppBar(title: const Text('多点设置')),
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
                      labelText: '循环次数',
                      suffixText: '轮',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('无限循环'),
                      subtitle: const Text('开启后会持续执行整组点位，直到手动停止'),
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

    // 设置页只修改多点的通用点击参数；点位增删和排序由多点模式页维护。
    Navigator.of(context).pop(
      MultiPointSettingsResult(
        configuration: MultiPointConfiguration(
          settings: MultiPointSettings(
            intervalMs: intervalMs,
            repeatCount: repeatCount,
            infiniteLoop: _infiniteLoop,
            tapDurationMs: tapDurationMs,
          ),
          overlayUiSettings: widget.initialSettings.overlayUiSettings.copyWith(
            interactionMode: _interactionMode,
          ),
          targets: widget.initialSettings.targets,
        ),
      ),
    );
  }
}

class MultiPointSettingsResult {
  const MultiPointSettingsResult({required this.configuration});

  final MultiPointConfiguration configuration;
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
