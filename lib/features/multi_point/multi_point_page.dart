import 'package:flutter/material.dart';

import 'package:float_clicker/features/clicker/clicker_settings.dart';
import 'multi_point_settings.dart';
import 'multi_point_settings_page.dart';
import 'multi_point_settings_store.dart';

class MultiPointPage extends StatefulWidget {
  const MultiPointPage({super.key});

  static const routeName = '/multi-point';

  @override
  State<MultiPointPage> createState() => _MultiPointPageState();
}

class _MultiPointPageState extends State<MultiPointPage> {
  final MultiPointSettingsStore _settingsStore =
      const MultiPointSettingsStore();

  MultiPointConfiguration _configuration = MultiPointConfiguration(
    settings: MultiPointSettings.defaults,
    overlayUiSettings: MultiPointOverlayUiSettings.defaults,
    targets: MultiPointTargets.defaults(),
  );
  TaskRunState _taskRunState = TaskRunState.idle;
  bool _isLoadingSettings = true;
  bool _isModeEnabled = false;

  bool get _canEditStructure => _taskRunState != TaskRunState.running;

  @override
  void initState() {
    super.initState();
    _loadSavedConfiguration();
  }

  Future<void> _loadSavedConfiguration() async {
    final configuration = await _settingsStore.loadConfiguration();
    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = configuration;
      _isLoadingSettings = false;
    });
  }

  Future<void> _saveConfiguration(MultiPointConfiguration configuration) async {
    await _settingsStore.saveConfiguration(configuration);
    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = configuration;
    });
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
    await _saveConfiguration(
      MultiPointConfiguration(
        settings: _configuration.settings,
        overlayUiSettings: _configuration.overlayUiSettings,
        targets: targets,
      ),
    );
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

    await _saveConfiguration(result.configuration);
  }

  void _toggleModeEnabled() {
    setState(() {
      _isModeEnabled = !_isModeEnabled;
      if (!_isModeEnabled) {
        _taskRunState = TaskRunState.idle;
      }
    });

    // P2 只开放 Flutter 编辑页面，真正的多点悬浮窗会在 Android Overlay 阶段接入。
    _showMessage(
      _isModeEnabled ? '多点页面已进入编辑状态，Android 多点悬浮层将在后续阶段接入。' : '多点编辑状态已关闭。',
    );
  }

  void _startTask() {
    final errorCode = _configuration.targets.executionValidationErrorCode;
    if (errorCode == MultiPointTargets.noEnabledTargetsErrorCode) {
      _showMessage('请至少启用 1 个点位后再执行。');
      return;
    }

    _showMessage('Android 多点顺序点击尚未接入，当前阶段只支持编辑和保存点位。');
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
                    isModeEnabled: _isModeEnabled,
                    taskRunState: _taskRunState,
                    totalCount: targets.length,
                    enabledCount: enabledCount,
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
                    label: Text(_isModeEnabled ? '关闭多点编辑' : '开启多点编辑'),
                  ),
                  if (_isModeEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _startTask,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('执行任务'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.isModeEnabled,
    required this.taskRunState,
    required this.totalCount,
    required this.enabledCount,
    required this.settings,
  });

  final bool isModeEnabled;
  final TaskRunState taskRunState;
  final int totalCount;
  final int enabledCount;
  final MultiPointSettings settings;

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
        child: Row(
          children: [
            Icon(
              isModeEnabled
                  ? Icons.control_point_duplicate
                  : Icons.pause_circle_outline,
              color: isModeEnabled ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
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
