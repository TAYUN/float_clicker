import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/android_permission_service.dart';
import 'clicker_controller.dart';
import 'clicker_guide_page.dart';
import 'clicker_settings.dart';
import 'clicker_settings_page.dart';
import 'clicker_settings_store.dart';

class ClickerPage extends StatefulWidget {
  const ClickerPage({super.key});

  static const routeName = '/single-point';

  @override
  State<ClickerPage> createState() => _ClickerPageState();
}

class _ClickerPageState extends State<ClickerPage> {
  late final ClickerController _controller;
  final AndroidPermissionService _permissionService =
      AndroidPermissionService();
  final ClickerSettingsStore _settingsStore = const ClickerSettingsStore();
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _controller = ClickerController();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    // 离开单点模式页时主动移除悬浮窗，避免用户返回首页后还残留工具条。
    _permissionService.hideSinglePointOverlay();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleSinglePointMode() async {
    try {
      if (_controller.isSinglePointModeEnabled) {
        await _permissionService.hideSinglePointOverlay();
      } else {
        final settings = _controller.settings;
        // 开启模式的核心动作在 Android 侧：
        // Flutter 只把当前配置传过去，Android 负责检查悬浮窗权限并创建目标点/工具条。
        await _permissionService.showSinglePointOverlay(
          intervalMs: settings.intervalMs,
          repeatCount: settings.repeatCount,
          infiniteLoop: settings.infiniteLoop,
          tapDurationMs: settings.tapDurationMs,
        );
      }
      // 只有 MethodChannel 调用成功后才更新 Flutter 状态，避免原生失败时 UI 误显示已开启。
      _controller.toggleSinglePointMode();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      // 当前最常见失败原因是悬浮窗权限未开启，先用 SnackBar 明确提示用户。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法开启悬浮窗')));
    }
  }

  Future<void> _loadSavedSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }

    _controller.updateSettings(settings);
    setState(() {
      _isLoadingSettings = false;
    });
  }

  Future<void> _toggleRunning() async {
    try {
      if (_controller.isRunning) {
        await _permissionService.stopSinglePointClicking();
      } else {
        // 原生侧会从当前点击点位置读取屏幕坐标，并通过无障碍服务执行 dispatchGesture。
        await _permissionService.startSinglePointClicking();
      }
      // 和开启模式一样，点击运行态也等原生调用成功后再翻转。
      _controller.toggleRunning();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法执行点击')));
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<ClickerSettings>(
      MaterialPageRoute(
        builder: (_) =>
            ClickerSettingsPage(initialSettings: _controller.settings),
      ),
    );

    if (result == null) {
      return;
    }

    await _settingsStore.save(result);
    _controller.updateSettings(result);
    if (_controller.isSinglePointModeEnabled) {
      // 悬浮窗已经创建时，保存新配置后需要同步给 Android，
      // 否则工具条播放按钮仍会按旧间隔/次数执行。
      await _syncSinglePointSettings(result);
    }
  }

  Future<void> _syncSinglePointSettings(ClickerSettings settings) async {
    await _permissionService.updateSinglePointSettings(
      intervalMs: settings.intervalMs,
      repeatCount: settings.repeatCount,
      infiniteLoop: settings.infiniteLoop,
      tapDurationMs: settings.tapDurationMs,
    );
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
            child: _isLoadingSettings
                ? const Center(child: CircularProgressIndicator())
                : ListView(
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
                              onTap: _openSettings,
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
                        onPressed: _toggleSinglePointMode,
                        icon: Icon(
                          _controller.isSinglePointModeEnabled
                              ? Icons.close
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          _controller.isSinglePointModeEnabled
                              ? '关闭单点模式'
                              : '开启单点模式',
                        ),
                      ),
                      if (_controller.isSinglePointModeEnabled) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _toggleRunning,
                          icon: Icon(
                            _controller.isRunning
                                ? Icons.stop
                                : Icons.play_arrow,
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
