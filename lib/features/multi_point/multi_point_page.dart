import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:float_clicker/core/platform/android_permission_service.dart';
import 'package:float_clicker/core/settings/global_overlay_appearance_settings.dart';
import 'package:float_clicker/core/settings/global_overlay_appearance_store.dart';
import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'multi_point_profile_page.dart';
import 'multi_point_settings.dart';
import 'multi_point_settings_page.dart';
import 'multi_point_settings_store.dart';

class MultiPointPage extends StatefulWidget {
  const MultiPointPage({super.key});

  static const routeName = '/multi-point';

  @override
  State<MultiPointPage> createState() => _MultiPointPageState();
}

class _MultiPointPageState extends State<MultiPointPage>
    with WidgetsBindingObserver {
  final MultiPointSettingsStore _settingsStore =
      const MultiPointSettingsStore();
  final AndroidPermissionService _permissionService =
      AndroidPermissionService();
  final GlobalOverlayAppearanceStore _appearanceStore =
      const GlobalOverlayAppearanceStore();

  MultiPointConfiguration _configuration = MultiPointConfiguration(
    settings: MultiPointSettings.defaults,
    overlayUiSettings: MultiPointOverlayUiSettings.defaults,
    targets: MultiPointTargets.defaults(),
  );
  late MultiPointProfileState _profileState;
  GlobalOverlayAppearanceSettings _appearanceSettings =
      GlobalOverlayAppearanceSettings.defaults;
  TaskRunState _taskRunState = TaskRunState.idle;
  bool _isLoadingSettings = true;
  bool _isModeEnabled = false;
  bool _isExecutionPreviewEnabled = false;

  bool get _canEditStructure => _taskRunState != TaskRunState.running;

  @override
  void initState() {
    super.initState();
    _profileState = MultiPointProfileState(
      profiles: [
        MultiPointProfile.defaultProfile(configuration: _configuration),
      ],
      activeProfileId: MultiPointProfile.defaultProfileId,
    );
    WidgetsBinding.instance.addObserver(this);
    _permissionService.setMultiPointOverlayStateChanged(
      _handleMultiPointOverlayStateChanged,
    );
    _permissionService.setMultiPointTargetPositionChanged(
      _handleMultiPointTargetPositionChanged,
    );
    _loadSavedConfiguration();
  }

  @override
  void dispose() {
    _permissionService.setMultiPointOverlayStateChanged(null);
    _permissionService.setMultiPointTargetPositionChanged(null);
    if (_isExecutionPreviewEnabled) {
      unawaited(_permissionService.hideMultiProfileExecutionOverlay());
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 系统设置返回时，多点任务状态和服务连接态都可能已经变化，前台恢复时补一次短时收敛。
      _refreshNativeState();
    }
  }

  Future<void> _loadSavedConfiguration() async {
    final profileState = await _settingsStore.loadProfileState();
    final configuration = profileState.activeProfile.configuration;
    final appearanceSettings = await _appearanceStore.load();
    final refreshResult = await _permissionService
        .refreshMultiPointStateWithAccessibilityRetry();
    if (!mounted) {
      return;
    }

    final snapshotConfiguration = _configurationFromSnapshot(
      refreshResult.overlaySnapshot,
      fallback: configuration,
    );
    final snapshotProfileState = _profileStateWithConfiguration(
      profileState,
      snapshotConfiguration,
    );
    setState(() {
      _appearanceSettings = appearanceSettings;
      _configuration = snapshotConfiguration;
      _profileState = snapshotProfileState;
      _isModeEnabled = refreshResult.overlaySnapshot.modeEnabled;
      _taskRunState = refreshResult.overlaySnapshot.modeEnabled
          ? refreshResult.overlaySnapshot.taskRunState
          : TaskRunState.idle;
      _isLoadingSettings = false;
    });
  }

  Future<void> _refreshNativeState() async {
    final refreshResult = await _permissionService
        .refreshMultiPointStateWithAccessibilityRetry();
    if (!mounted) {
      return;
    }

    final snapshotConfiguration = _configurationFromSnapshot(
      refreshResult.overlaySnapshot,
      fallback: _configuration,
    );
    await _settingsStore.saveConfiguration(snapshotConfiguration);
    final snapshotProfileState = _profileStateWithConfiguration(
      _profileState,
      snapshotConfiguration,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = snapshotConfiguration;
      _profileState = snapshotProfileState;
      _isModeEnabled = refreshResult.overlaySnapshot.modeEnabled;
      _taskRunState = refreshResult.overlaySnapshot.modeEnabled
          ? refreshResult.overlaySnapshot.taskRunState
          : TaskRunState.idle;
    });
  }

  Future<MultiPointProfileState?> _saveConfiguration(
    MultiPointConfiguration configuration,
  ) async {
    await _settingsStore.saveConfiguration(configuration);
    if (!mounted) {
      return null;
    }

    final nextProfileState = _profileStateWithConfiguration(
      _profileState,
      configuration,
    );
    setState(() {
      _configuration = configuration;
      _profileState = nextProfileState;
    });
    return nextProfileState;
  }

  Future<void> _openProfileManager() async {
    if (!_canEditStructure) {
      _showMessage('任务运行中不能管理配置，请先暂停或结束任务。');
      return;
    }

    await _saveConfiguration(_configuration);
    final latestProfileState = await _settingsStore.loadProfileState();
    if (!mounted) {
      return;
    }

    final result = await Navigator.of(context)
        .push<MultiPointProfileManagementResult>(
          MaterialPageRoute(
            builder: (_) =>
                MultiPointProfilePage(initialState: latestProfileState),
          ),
        );
    if (result == null) {
      return;
    }

    final nextProfileState = await _settingsStore.saveProfileState(
      result.state,
    );
    final nextConfiguration = nextProfileState.activeProfile.configuration;
    if (!mounted) {
      return;
    }

    setState(() {
      _profileState = nextProfileState;
      _configuration = nextConfiguration;
    });

    if (_isModeEnabled) {
      try {
        await _permissionService.updateMultiPointSettings(
          nextConfiguration.settings,
        );
        await _permissionService.updateMultiPointOverlayUiSettings(
          nextConfiguration.overlayUiSettings,
        );
        await _permissionService.updateMultiPointTargets(
          nextConfiguration.targets,
        );
      } on PlatformException catch (error) {
        _showPlatformError(error, fallback: '无法切换多点配置');
      }
    }

    if (_isExecutionPreviewEnabled) {
      try {
        await _permissionService.updateMultiProfileExecutionOverlay(
          profileState: nextProfileState,
          appearanceSettings: _appearanceSettings,
        );
      } on PlatformException catch (error) {
        _showPlatformError(error, fallback: '无法刷新执行控件预览');
      }
    }
  }

  Future<void> _addTarget() async {
    if (!_canEditStructure) {
      _showMessage('任务运行中不能新增点位，请先暂停或结束任务。');
      return;
    }
    if (!_configuration.targets.canAdd) {
      _showMessage('第一版最多支持 ${MultiPointTargets.maxTargets} 个点位。');
      return;
    }

    await _updateTargets(_configuration.targets.addTarget());
  }

  Future<void> _removeTarget(MultiPointTarget target) async {
    if (!_canEditStructure) {
      _showMessage('任务运行中不能删除点位，请先暂停或结束任务。');
      return;
    }
    if (!_configuration.targets.canRemove) {
      _showMessage('至少需要保留 1 个点位对象。');
      return;
    }

    await _updateTargets(_configuration.targets.removeTarget(target.id));
  }

  Future<void> _setTargetEnabled(MultiPointTarget target, bool enabled) async {
    if (!_canEditStructure) {
      _showMessage('任务运行中不能启用或禁用点位，请先暂停或结束任务。');
      return;
    }

    await _updateTargets(
      _configuration.targets.setTargetEnabled(target.id, enabled),
    );
  }

  Future<void> _reorderTargets(int oldIndex, int newIndex) async {
    if (!_canEditStructure) {
      _showMessage('任务运行中不能调整顺序，请先暂停或结束任务。');
      return;
    }

    await _updateTargets(
      _configuration.targets.reorderTarget(
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
    );
  }

  Future<void> _updateTargets(MultiPointTargets targets) async {
    final nextConfiguration = MultiPointConfiguration(
      settings: _configuration.settings,
      overlayUiSettings: _configuration.overlayUiSettings,
      targets: targets,
    );
    final nextProfileState = await _saveConfiguration(nextConfiguration);
    if (_isModeEnabled) {
      await _permissionService.updateMultiPointTargets(targets);
    }
    if (nextProfileState != null) {
      await _refreshExecutionPreviewOverlay(nextProfileState);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<MultiPointSettingsResult>(
      MaterialPageRoute(
        builder: (_) => MultiPointSettingsPage(initialSettings: _configuration),
      ),
    );
    if (result == null) {
      return;
    }

    final nextProfileState = await _saveConfiguration(result.configuration);
    if (_isModeEnabled) {
      await _permissionService.updateMultiPointSettings(
        result.configuration.settings,
      );
      await _permissionService.updateMultiPointOverlayUiSettings(
        result.configuration.overlayUiSettings,
      );
    }
    if (nextProfileState != null) {
      await _refreshExecutionPreviewOverlay(nextProfileState);
    }
  }

  Future<void> _toggleModeEnabled() async {
    if (_isExecutionPreviewEnabled) {
      _showMessage('请先关闭执行控件预览，再开启多点悬浮层。');
      return;
    }

    try {
      if (_isModeEnabled) {
        await _permissionService.hideMultiPointOverlay();
        if (!mounted) {
          return;
        }
        setState(() {
          _isModeEnabled = false;
          _taskRunState = TaskRunState.idle;
        });
        return;
      }

      await _permissionService.showMultiPointOverlay(
        configuration: _configuration,
        appearanceSettings: _appearanceSettings,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isModeEnabled = true;
        _taskRunState = TaskRunState.idle;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法开启多点悬浮层');
    }
  }

  Future<void> _toggleExecutionPreview() async {
    if (_isModeEnabled) {
      _showMessage('请先关闭多点悬浮层，再开启执行控件预览。');
      return;
    }

    try {
      if (_isExecutionPreviewEnabled) {
        await _permissionService.hideMultiProfileExecutionOverlay();
        if (!mounted) {
          return;
        }
        setState(() {
          _isExecutionPreviewEnabled = false;
        });
        return;
      }

      final nextProfileState = await _saveConfiguration(_configuration);
      if (!mounted || nextProfileState == null) {
        return;
      }
      await _permissionService.showMultiProfileExecutionOverlay(
        profileState: nextProfileState,
        appearanceSettings: _appearanceSettings,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isExecutionPreviewEnabled = true;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法开启执行控件预览');
    }
  }

  Future<void> _refreshExecutionPreviewOverlay(
    MultiPointProfileState profileState,
  ) async {
    if (!_isExecutionPreviewEnabled) {
      return;
    }

    try {
      await _permissionService.updateMultiProfileExecutionOverlay(
        profileState: profileState,
        appearanceSettings: _appearanceSettings,
      );
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法刷新执行控件预览');
    }
  }

  Future<void> _setProfileExecutionControlVisible(
    MultiPointProfile profile,
    bool visible,
  ) async {
    if (_isModeEnabled) {
      _showMessage('请先关闭多点悬浮层，再管理执行控件。');
      return;
    }
    if (visible && !profile.targets.hasEnabledTarget) {
      _showMessage('请至少启用 1 个点位后再显示执行控件。');
      return;
    }

    final currentLoadedProfiles = _profileState.loadedProfiles;
    final isCurrentlyVisible = _profileState.isProfileLoaded(profile.id);
    if (visible == isCurrentlyVisible) {
      return;
    }
    if (!visible && currentLoadedProfiles.length <= 1) {
      _showMessage('至少需要保留 1 个执行控件。');
      return;
    }

    final nextLoadedProfiles = visible
        ? [
            ...currentLoadedProfiles,
            LoadedMultiPointProfile(
              profileId: profile.id,
              order: currentLoadedProfiles.length + 1,
              isVisible: true,
            ),
          ]
        : currentLoadedProfiles
              .where((loadedProfile) => loadedProfile.profileId != profile.id)
              .toList(growable: false);
    final nextProfileState = await _settingsStore.saveProfileState(
      _profileState.copyWith(loadedProfiles: nextLoadedProfiles),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _profileState = nextProfileState;
    });

    if (_isExecutionPreviewEnabled) {
      try {
        await _permissionService.updateMultiProfileExecutionOverlay(
          profileState: nextProfileState,
          appearanceSettings: _appearanceSettings,
        );
      } on PlatformException catch (error) {
        _showPlatformError(error, fallback: '无法刷新执行控件预览');
      }
    }
  }

  Future<void> _startTask() async {
    final errorCode = _configuration.targets.executionValidationErrorCode;
    if (errorCode == MultiPointTargets.noEnabledTargetsErrorCode) {
      _showMessage('请至少启用 1 个点位后再执行。');
      return;
    }

    try {
      await _permissionService.startMultiPointClicking();
      if (!mounted) {
        return;
      }
      setState(() {
        _taskRunState = TaskRunState.running;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法执行多点任务');
    }
  }

  Future<void> _pauseTask() async {
    try {
      await _permissionService.pauseMultiPointClicking();
      if (!mounted) {
        return;
      }
      setState(() {
        _taskRunState = TaskRunState.paused;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法暂停多点任务');
    }
  }

  Future<void> _resumeTask() async {
    try {
      await _permissionService.resumeMultiPointClicking();
      if (!mounted) {
        return;
      }
      final overlaySnapshot = await _permissionService
          .getMultiPointOverlaySnapshot();
      if (!mounted) {
        return;
      }
      final nextConfiguration = _configurationFromSnapshot(
        overlaySnapshot,
        fallback: _configuration,
      );
      setState(() {
        _configuration = nextConfiguration;
        _profileState = _profileStateWithConfiguration(
          _profileState,
          nextConfiguration,
        );
        _isModeEnabled = overlaySnapshot.modeEnabled;
        _taskRunState = overlaySnapshot.modeEnabled
            ? overlaySnapshot.taskRunState
            : TaskRunState.idle;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法继续多点任务');
    }
  }

  Future<void> _endTask() async {
    try {
      await _permissionService.endMultiPointClicking();
      if (!mounted) {
        return;
      }
      setState(() {
        _taskRunState = TaskRunState.idle;
      });
    } on PlatformException catch (error) {
      _showPlatformError(error, fallback: '无法结束多点任务');
    }
  }

  Future<void> _handleMultiPointOverlayStateChanged(
    MultiPointOverlaySnapshot snapshot,
  ) async {
    if (!mounted) {
      return;
    }

    final nextConfiguration = _configurationFromSnapshot(
      snapshot,
      fallback: _configuration,
    );
    await _settingsStore.saveConfiguration(nextConfiguration);
    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = nextConfiguration;
      _profileState = _profileStateWithConfiguration(
        _profileState,
        nextConfiguration,
      );
      _isModeEnabled = snapshot.modeEnabled;
      _taskRunState = snapshot.modeEnabled
          ? snapshot.taskRunState
          : TaskRunState.idle;
    });
  }

  Future<void> _handleMultiPointTargetPositionChanged(
    MultiPointTargetPositionChange change,
  ) async {
    if (!mounted) {
      return;
    }

    final currentTargets = _configuration.targets;
    final targetExists = currentTargets.values.any(
      (target) => target.id == change.id,
    );
    if (!targetExists) {
      return;
    }

    // 点位拖动只更新坐标，不重排、不改启禁，避免原生事件覆盖 Flutter 侧刚完成的结构编辑。
    final nextTargets = currentTargets.updateTarget(
      currentTargets.values
          .firstWhere((target) => target.id == change.id)
          .copyWith(x: change.x, y: change.y),
    );
    final nextConfiguration = MultiPointConfiguration(
      settings: _configuration.settings,
      overlayUiSettings: _configuration.overlayUiSettings,
      targets: nextTargets,
    );

    await _settingsStore.saveTargets(nextTargets);
    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = nextConfiguration;
      _profileState = _profileStateWithConfiguration(
        _profileState,
        nextConfiguration,
      );
    });
  }

  MultiPointConfiguration _configurationFromSnapshot(
    MultiPointOverlaySnapshot snapshot, {
    required MultiPointConfiguration fallback,
  }) {
    if (!snapshot.modeEnabled) {
      return fallback;
    }

    return MultiPointConfiguration(
      settings: fallback.settings,
      overlayUiSettings:
          snapshot.overlayUiSettings ?? fallback.overlayUiSettings,
      targets: snapshot.targets,
    );
  }

  MultiPointProfileState _profileStateWithConfiguration(
    MultiPointProfileState state,
    MultiPointConfiguration configuration,
  ) {
    return MultiPointProfileState(
      profiles: [
        for (final profile in state.profiles)
          profile.id == state.activeProfileId
              ? profile.withConfiguration(configuration)
              : profile,
      ],
      activeProfileId: state.activeProfileId,
      loadedProfiles: state.loadedProfiles,
    );
  }

  void _showPlatformError(PlatformException error, {required String fallback}) {
    final message = switch (error.code) {
      'mode_conflict' =>
        (error.message?.trim().isNotEmpty ?? false)
            ? error.message!.trim()
            : '单点模式已开启，请先关闭单点模式。',
      'no_enabled_targets' => '请至少启用 1 个点位后再执行。',
      'profile_empty' => '请至少加载 1 套配置后再开启执行控件预览。',
      'overlay_permission_denied' => '悬浮窗权限未开启，请先在系统设置中允许显示在其他应用上层。',
      'overlay_window_unavailable' => '多点悬浮窗创建失败，请确认悬浮窗权限仍然可用后重试。',
      'accessibility_service_unavailable' =>
        '无障碍服务未连接，请先在系统设置中开启 Float Clicker 无障碍服务。',
      'invalid_task_state' => '当前任务状态不支持该操作，请根据页面状态重新执行。',
      'unimplemented_method' => error.message ?? 'Android 多点点击调度尚未实现。',
      _ =>
        (error.message?.trim().isNotEmpty ?? false)
            ? error.message!.trim()
            : fallback,
    };
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = _configuration.settings;
    final targets = _configuration.targets;
    final enabledCount = targets.enabledTargets.length;

    return Scaffold(
      appBar: AppBar(title: const Text('多点模式')),
      body: SafeArea(
        child: _isLoadingSettings
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusPanel(
                    profileName: _profileState.activeProfile.name,
                    isModeEnabled: _isModeEnabled,
                    taskRunState: _taskRunState,
                    totalCount: targets.length,
                    enabledCount: enabledCount,
                    settings: settings,
                    onManageProfiles: _openProfileManager,
                    canManageProfiles: _canEditStructure,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('设置'),
                          subtitle: Text(
                            '间隔 ${settings.intervalMs} ms，${settings.infiniteLoop ? '无限循环' : '循环 ${settings.repeatCount} 轮'}，${_configuration.overlayUiSettings.interactionMode.label}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _canEditStructure
                              ? _openSettings
                              : () => _showMessage('任务运行中不能修改点击参数，请先暂停或结束任务。'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TargetsSection(
                    targets: targets,
                    canEditStructure: _canEditStructure,
                    onAddTarget: _addTarget,
                    onRemoveTarget: _removeTarget,
                    onEnabledChanged: _setTargetEnabled,
                    onReorder: _reorderTargets,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _toggleModeEnabled,
                    icon: Icon(_isModeEnabled ? Icons.close : Icons.layers),
                    label: Text(_isModeEnabled ? '关闭多点悬浮层' : '开启多点悬浮层'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _toggleExecutionPreview,
                    icon: Icon(
                      _isExecutionPreviewEnabled
                          ? Icons.close
                          : Icons.dashboard_customize_outlined,
                    ),
                    label: Text(
                      _isExecutionPreviewEnabled ? '关闭执行控件预览' : '开启执行控件预览',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ExecutionPreviewSection(
                    profileState: _profileState,
                    isPreviewEnabled: _isExecutionPreviewEnabled,
                    canManageControls: !_isModeEnabled,
                    onVisibilityChanged: _setProfileExecutionControlVisible,
                  ),
                  if (_isModeEnabled) ...[
                    const SizedBox(height: 12),
                    _TaskControls(
                      taskRunState: _taskRunState,
                      onStart: _startTask,
                      onPause: _pauseTask,
                      onResume: _resumeTask,
                      onEnd: _endTask,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ExecutionPreviewSection extends StatelessWidget {
  const _ExecutionPreviewSection({
    required this.profileState,
    required this.isPreviewEnabled,
    required this.canManageControls,
    required this.onVisibilityChanged,
  });

  final MultiPointProfileState profileState;
  final bool isPreviewEnabled;
  final bool canManageControls;
  final void Function(MultiPointProfile profile, bool visible)
  onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('执行控件'),
            subtitle: Text(
              '${isPreviewEnabled ? '预览中' : '未预览'} · 已显示 ${profileState.loadedProfiles.length} 个',
            ),
          ),
          const Divider(height: 1),
          for (final profile in profileState.profiles)
            SwitchListTile(
              key: ValueKey('execution-control-${profile.id}'),
              secondary: const Icon(Icons.play_circle_outline),
              title: Text('${profile.name} 控件'),
              subtitle: Text(
                profileState.isProfileLoaded(profile.id)
                    ? '显示该配置控件'
                    : '隐藏该配置控件',
              ),
              value: profileState.isProfileLoaded(profile.id),
              onChanged: canManageControls
                  ? (value) => onVisibilityChanged(profile, value)
                  : null,
            ),
        ],
      ),
    );
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.profileName,
    required this.isModeEnabled,
    required this.taskRunState,
    required this.totalCount,
    required this.enabledCount,
    required this.settings,
    required this.onManageProfiles,
    required this.canManageProfiles,
  });

  final String profileName;
  final bool isModeEnabled;
  final TaskRunState taskRunState;
  final int totalCount;
  final int enabledCount;
  final MultiPointSettings settings;
  final VoidCallback onManageProfiles;
  final bool canManageProfiles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = switch ((isModeEnabled, taskRunState)) {
      (false, _) => '未启动',
      (true, TaskRunState.running) => '正在点击',
      (true, TaskRunState.paused) => '已暂停',
      (true, TaskRunState.idle) => '多点编辑中',
    };
    final repeatLabel = settings.infiniteLoop
        ? '无限循环'
        : '循环 ${settings.repeatCount} 轮';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isModeEnabled
                      ? Icons.control_point_duplicate
                      : Icons.pause_circle_outline,
                  color: isModeEnabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点位 $totalCount 个，启用 $enabledCount 个，$repeatLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_copy_outlined),
              title: Text(profileName),
              subtitle: const Text('当前多点配置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: canManageProfiles ? onManageProfiles : onManageProfiles,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetsSection extends StatelessWidget {
  const _TargetsSection({
    required this.targets,
    required this.canEditStructure,
    required this.onAddTarget,
    required this.onRemoveTarget,
    required this.onEnabledChanged,
    required this.onReorder,
  });

  final MultiPointTargets targets;
  final bool canEditStructure;
  final VoidCallback onAddTarget;
  final ValueChanged<MultiPointTarget> onRemoveTarget;
  final void Function(MultiPointTarget target, bool enabled) onEnabledChanged;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.adjust),
              title: const Text('点位列表'),
              subtitle: Text('最多 ${MultiPointTargets.maxTargets} 个，按列表顺序执行'),
              trailing: IconButton(
                tooltip: '新增点位',
                onPressed: targets.canAdd && canEditStructure
                    ? onAddTarget
                    : null,
                icon: const Icon(Icons.add),
              ),
            ),
            const Divider(height: 1),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: targets.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final target = targets.values[index];
                return _TargetTile(
                  key: ValueKey(target.id),
                  target: target,
                  index: index,
                  canEditStructure: canEditStructure,
                  canRemove: targets.canRemove,
                  onRemove: () => onRemoveTarget(target),
                  onEnabledChanged: (value) => onEnabledChanged(target, value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    super.key,
    required this.target,
    required this.index,
    required this.canEditStructure,
    required this.canRemove,
    required this.onRemove,
    required this.onEnabledChanged,
  });

  final MultiPointTarget target;
  final int index;
  final bool canEditStructure;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text('点位 ${index + 1}'),
      subtitle: Text(
        '坐标 (${target.x.round()}, ${target.y.round()}) · ${target.enabled ? '启用' : '禁用'}',
      ),
      trailing: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Switch(
            value: target.enabled,
            onChanged: canEditStructure ? onEnabledChanged : null,
          ),
          IconButton(
            tooltip: '删除点位',
            onPressed: canEditStructure && canRemove ? onRemove : null,
            icon: const Icon(Icons.delete_outline),
          ),
          ReorderableDragStartListener(
            index: index,
            enabled: canEditStructure,
            child: Icon(
              Icons.drag_handle,
              color: canEditStructure
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
