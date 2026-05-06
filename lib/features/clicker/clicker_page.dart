import 'package:flutter/material.dart';

import 'clicker_controller.dart';
import 'clicker_guide_page.dart';
import 'clicker_settings_page.dart';

class ClickerPage extends StatefulWidget {
  const ClickerPage({super.key});

  static const routeName = '/single-point';

  @override
  State<ClickerPage> createState() => _ClickerPageState();
}

class _ClickerPageState extends State<ClickerPage> {
  late final ClickerController _controller;

  @override
  void initState() {
    super.initState();
    // 控制器暂时只管理 Flutter 侧演示状态；后续会把开启/关闭动作接到 Android 悬浮窗。
    _controller = ClickerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final settings = _controller.settings;

        return Scaffold(
          appBar: AppBar(title: const Text('单点模式')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusPanel(
                  isEnabled: _controller.isSinglePointModeEnabled,
                  isRunning: _controller.isRunning,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('设置'),
                        subtitle: Text(
                          '间隔 ${settings.intervalMs} ms，次数 ${settings.infiniteLoop ? '无限循环' : settings.repeatCount}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(ClickerSettingsPage.routeName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('介绍向导'),
                        subtitle: const Text('查看点位和工具条的使用方式'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(ClickerGuidePage.routeName),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _controller.toggleSinglePointMode,
                  icon: Icon(
                    _controller.isSinglePointModeEnabled
                        ? Icons.close
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    _controller.isSinglePointModeEnabled ? '关闭单点模式' : '开启单点模式',
                  ),
                ),
                if (_controller.isSinglePointModeEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _controller.toggleRunning,
                    icon: Icon(
                      _controller.isRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(_controller.isRunning ? '停止点击' : '开始点击'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.isEnabled, required this.isRunning});

  final bool isEnabled;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = isRunning ? '正在点击' : (isEnabled ? '单点模式已开启' : '未启动');
    final subtitle = isEnabled ? '后续会创建悬浮工具条和点击点' : '开启后将显示悬浮工具条和一个可拖动点击点';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.touch_app : Icons.pause_circle_outline,
              color: isEnabled ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
