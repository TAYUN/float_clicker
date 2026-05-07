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
    _permissionService.setSinglePointOverlayStateChanged(
      _handleSinglePointOverlayStateChanged,
    );
    _loadSavedSettings();
  }

  @override
  void dispose() {
    // 页面离开时只解绑回调；悬浮窗由用户通过控制条或“关闭单点模式”按钮主动关闭。
    _permissionService.setSinglePointOverlayStateChanged(null);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleSinglePointMode() async {
    try {
      final shouldEnable = !_controller.isSinglePointModeEnabled;
      if (shouldEnable) {
        final settings = _controller.settings;
        // 开启模式的核心动作在 Android 侧：
        // Flutter 只把当前配置传过去，Android 负责检查悬浮窗权限并创建目标点/工具条。
        await _permissionService.showSinglePointOverlay(
          intervalMs: settings.intervalMs,
          repeatCount: settings.repeatCount,
          infiniteLoop: settings.infiniteLoop,
          tapDurationMs: settings.tapDurationMs,
          overlayUiSettings: _controller.overlayUiSettings,
        );
      } else {
        await _permissionService.hideSinglePointOverlay();
      }
      // 只有 MethodChannel 调用成功后才更新 Flutter 状态，避免原生失败时 UI 误显示已开启。
      _controller.setSinglePointModeState(isEnabled: shouldEnable);
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
    final settings = await _settingsStore.loadSinglePointSettings();
    final overlaySnapshot = await _permissionService
        .getSinglePointOverlaySnapshot();
    if (!mounted) {
      return;
    }

    _controller.updateSinglePointSettings(settings);
    _controller.setSinglePointModeState(
      isEnabled: overlaySnapshot.isEnabled,
      taskRunState: overlaySnapshot.taskRunState,
      executedCount: overlaySnapshot.executedCount,
    );
    setState(() {
      _isLoadingSettings = false;
    });
  }

  Future<void> _startClicking() async {
    try {
      // 原生侧会从当前点击点位置读取屏幕坐标，并通过无障碍服务执行 dispatchGesture。
      await _permissionService.startSinglePointClicking();
      // 和开启模式一样，点击运行态也等原生调用成功后再更新；
      // 原生工具条也会回传状态事件，这里显式设置可以避免事件先到时被再次翻转。
      _controller.setTaskRunState(TaskRunState.running);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法执行点击')));
    }
  }

  Future<void> _pauseClicking() async {
    try {
      await _permissionService.pauseSinglePointClicking();
      _controller.setTaskRunState(TaskRunState.paused);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法暂停点击')));
    }
  }

  Future<void> _resumeClicking() async {
    try {
      await _permissionService.resumeSinglePointClicking();
      _controller.setTaskRunState(TaskRunState.running);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法继续点击')));
    }
  }

  Future<void> _endClicking() async {
    try {
      await _permissionService.endSinglePointClicking();
      _controller.setTaskRunState(TaskRunState.idle);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法结束任务')));
    }
  }

  void _handleSinglePointOverlayStateChanged(
    SinglePointOverlaySnapshot snapshot,
  ) {
    if (!mounted) {
      return;
    }

    _controller.setSinglePointModeState(
      isEnabled: snapshot.isEnabled,
      taskRunState: snapshot.taskRunState,
      executedCount: snapshot.executedCount,
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SinglePointSettings>(
      MaterialPageRoute(
        builder: (_) => ClickerSettingsPage(
          initialSettings: SinglePointSettings(
            clickerSettings: _controller.settings,
            overlayUiSettings: _controller.overlayUiSettings,
          ),
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _settingsStore.saveSinglePointSettings(result);
    _controller.updateSinglePointSettings(result);
    if (_controller.isSinglePointModeEnabled) {
      // 悬浮窗已经创建时，保存新配置后需要同步给 Android，
      // 否则工具条播放按钮仍会按旧间隔/次数执行。
      await _syncSinglePointSettings(result.clickerSettings);
      await _permissionService.updateSinglePointOverlayUiSettings(
        result.overlayUiSettings,
      );
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
        final overlayUiSettings = _controller.overlayUiSettings;

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
                        taskRunState: _controller.taskRunState,
                        executedCount: _controller.executedCount,
                        settings: settings,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.settings),
                              title: const Text('设置'),
                              subtitle: Text(
                                '间隔 ${settings.intervalMs} ms，次数 ${settings.infiniteLoop ? '无限循环' : settings.repeatCount}，${overlayUiSettings.interactionMode.label}',
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
                        _TaskControls(
                          taskRunState: _controller.taskRunState,
                          onStart: _startClicking,
                          onPause: _pauseClicking,
                          onResume: _resumeClicking,
                          onEnd: _endClicking,
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
  const _StatusPanel({
    required this.isEnabled,
    required this.taskRunState,
    required this.executedCount,
    required this.settings,
  });

  final bool isEnabled;
  final TaskRunState taskRunState;
  final int executedCount;
  final ClickerSettings settings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = switch ((isEnabled, taskRunState)) {
      (false, _) => '未启动',
      (true, TaskRunState.running) => '正在点击',
      (true, TaskRunState.paused) => '已暂停',
      (true, TaskRunState.idle) => '单点模式已开启',
    };
    final subtitle = switch ((isEnabled, taskRunState)) {
      (false, _) => '开启后将显示悬浮组件和一个可拖动点击点',
      (true, TaskRunState.running) => '任务正在执行，点击点移动后下一次点击会使用新位置',
      (true, TaskRunState.paused) => '任务已暂停，继续后会从当前进度执行',
      (true, TaskRunState.idle) => '悬浮组件已显示，可以开始点击任务',
    };
    final progressLabel = isEnabled && taskRunState != TaskRunState.idle
        ? _progressLabel(settings, executedCount)
        : null;

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
                  if (progressLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      progressLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _progressLabel(ClickerSettings settings, int executedCount) {
    if (settings.infiniteLoop) {
      return '已执行 $executedCount 次';
    }

    return '已执行 $executedCount / ${settings.repeatCount} 次';
  }
}

class _TaskControls extends StatelessWidget {
  const _TaskControls({
    required this.taskRunState,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final TaskRunState taskRunState;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (taskRunState == TaskRunState.idle)
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('执行任务'),
          ),
        if (taskRunState == TaskRunState.running)
          OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            label: const Text('暂停任务'),
          ),
        if (taskRunState == TaskRunState.paused)
          OutlinedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('继续任务'),
          ),
        if (taskRunState != TaskRunState.idle) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onEnd,
            icon: const Icon(Icons.stop),
            label: const Text('结束任务'),
          ),
        ],
      ],
    );
  }
}
