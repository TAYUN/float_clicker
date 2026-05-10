import 'package:flutter/material.dart';

import 'multi_point_settings.dart';

class MultiPointProfilePage extends StatefulWidget {
  const MultiPointProfilePage({super.key, required this.initialState});

  final MultiPointProfileState initialState;

  @override
  State<MultiPointProfilePage> createState() => _MultiPointProfilePageState();
}

class _MultiPointProfilePageState extends State<MultiPointProfilePage> {
  late List<MultiPointProfile> _profiles;
  late String _activeProfileId;
  late List<LoadedMultiPointProfile> _loadedProfiles;

  @override
  void initState() {
    super.initState();
    _profiles = widget.initialState.profiles.toList();
    _activeProfileId = widget.initialState.activeProfileId;
    _loadedProfiles = widget.initialState.loadedProfiles.toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = _profiles.firstWhere(
      (profile) => profile.id == _activeProfileId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('多点配置'),
        actions: [TextButton(onPressed: _finish, child: const Text('完成'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.playlist_add_check),
                title: Text('当前配置：${activeProfile.name}'),
                subtitle: Text(
                  '共 ${_profiles.length} 套配置，已加载 ${_loadedProfiles.length} 套',
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final profile in _profiles) ...[
              _ProfileTile(
                profile: profile,
                isActive: profile.id == _activeProfileId,
                isLoaded: _isProfileLoaded(profile.id),
                canDelete: _profiles.length > 1,
                canUnload: _loadedProfiles.length > 1,
                onSelect: () => _selectProfile(profile.id),
                onLoadedChanged: (loaded) =>
                    _setProfileLoaded(profile: profile, loaded: loaded),
                onRename: () => _renameProfile(profile),
                onCopy: () => _copyProfile(profile),
                onDelete: () => _deleteProfile(profile),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 88),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProfile,
        icon: const Icon(Icons.add),
        label: const Text('新建配置'),
      ),
    );
  }

  void _selectProfile(String profileId) {
    setState(() {
      _activeProfileId = profileId;
    });
  }

  void _addProfile() {
    final now = DateTime.now();
    final profile = MultiPointProfile.defaultProfile(
      now: now,
    ).copyWith(id: _nextProfileId(), name: _uniqueProfileName('新配置'));
    setState(() {
      _profiles = [..._profiles, profile];
      _activeProfileId = profile.id;
      _normalizeLoadedProfiles();
    });
  }

  void _copyProfile(MultiPointProfile profile) {
    final now = DateTime.now();
    final copy = profile.copyWith(
      id: _nextProfileId(),
      name: _uniqueProfileName('${profile.name} 副本'),
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _profiles = [..._profiles, copy];
      _activeProfileId = copy.id;
      _normalizeLoadedProfiles();
    });
  }

  void _setProfileLoaded({
    required MultiPointProfile profile,
    required bool loaded,
  }) {
    if (loaded && !profile.targets.hasEnabledTarget) {
      _showMessage('请至少启用 1 个点位后再加载到执行区。');
      return;
    }
    if (!loaded && _loadedProfiles.length <= 1) {
      _showMessage('至少需要保留 1 套已加载配置。');
      return;
    }

    setState(() {
      if (loaded) {
        if (!_isProfileLoaded(profile.id)) {
          _loadedProfiles = [
            ..._loadedProfiles,
            LoadedMultiPointProfile(
              profileId: profile.id,
              order: _loadedProfiles.length + 1,
              isVisible: true,
            ),
          ];
        }
      } else {
        _loadedProfiles = _loadedProfiles
            .where((loadedProfile) => loadedProfile.profileId != profile.id)
            .toList(growable: false);
      }
      _normalizeLoadedProfiles();
    });
  }

  Future<void> _renameProfile(MultiPointProfile profile) async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameProfileDialog(initialName: profile.name),
    );

    final trimmedName = nextName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    setState(() {
      _profiles = [
        for (final item in _profiles)
          item.id == profile.id
              ? item.copyWith(name: trimmedName, updatedAt: DateTime.now())
              : item,
      ];
    });
  }

  Future<void> _deleteProfile(MultiPointProfile profile) async {
    if (_profiles.length <= 1) {
      _showMessage('至少需要保留 1 套配置。');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除配置'),
          content: Text('删除“${profile.name}”后不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    final nextProfiles = _profiles
        .where((item) => item.id != profile.id)
        .toList(growable: false);
    final nextActiveProfileId =
        nextProfiles.any((item) => item.id == _activeProfileId)
        ? _activeProfileId
        : nextProfiles.first.id;
    setState(() {
      _profiles = nextProfiles;
      _activeProfileId = nextActiveProfileId;
      _loadedProfiles = _loadedProfiles
          .where((loadedProfile) => loadedProfile.profileId != profile.id)
          .toList(growable: false);
      _normalizeLoadedProfiles();
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      MultiPointProfileManagementResult(
        state: MultiPointProfileState(
          profiles: _profiles,
          activeProfileId: _activeProfileId,
          loadedProfiles: _loadedProfiles,
        ),
      ),
    );
  }

  bool _isProfileLoaded(String profileId) {
    return _loadedProfiles.any(
      (loadedProfile) => loadedProfile.profileId == profileId,
    );
  }

  void _normalizeLoadedProfiles() {
    final state = MultiPointProfileState(
      profiles: _profiles,
      activeProfileId: _activeProfileId,
      loadedProfiles: _loadedProfiles,
    );
    _activeProfileId = state.activeProfileId;
    _loadedProfiles = state.loadedProfiles.toList();
  }

  String _nextProfileId() {
    final existingIds = _profiles.map((profile) => profile.id).toSet();
    var candidate = 'profile_${DateTime.now().microsecondsSinceEpoch}';
    var suffix = 1;
    while (existingIds.contains(candidate)) {
      candidate = 'profile_${DateTime.now().microsecondsSinceEpoch}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _uniqueProfileName(String baseName) {
    final existingNames = _profiles.map((profile) => profile.name).toSet();
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    var suffix = 2;
    while (existingNames.contains('$baseName $suffix')) {
      suffix += 1;
    }
    return '$baseName $suffix';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class MultiPointProfileManagementResult {
  const MultiPointProfileManagementResult({required this.state});

  final MultiPointProfileState state;
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.isLoaded,
    required this.canDelete,
    required this.canUnload,
    required this.onSelect,
    required this.onLoadedChanged,
    required this.onRename,
    required this.onCopy,
    required this.onDelete,
  });

  final MultiPointProfile profile;
  final bool isActive;
  final bool isLoaded;
  final bool canDelete;
  final bool canUnload;
  final VoidCallback onSelect;
  final ValueChanged<bool> onLoadedChanged;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? colorScheme.primary : colorScheme.outline,
        ),
        title: Text(profile.name),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '点位 ${profile.targets.length} 个，启用 ${profile.targets.enabledTargets.length} 个',
              ),
              TextSpan(text: isLoaded ? ' · 已加载' : ' · 未加载'),
            ],
          ),
        ),
        onTap: onSelect,
        trailing: PopupMenuButton<_ProfileAction>(
          tooltip: '配置操作',
          onSelected: (action) {
            // 等待菜单路由完成本帧收尾后再打开弹窗或刷新列表，避免和 Overlay 构建作用域打架。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (action) {
                case _ProfileAction.select:
                  onSelect();
                  break;
                case _ProfileAction.load:
                  onLoadedChanged(true);
                  break;
                case _ProfileAction.unload:
                  onLoadedChanged(false);
                  break;
                case _ProfileAction.copy:
                  onCopy();
                  break;
                case _ProfileAction.rename:
                  onRename();
                  break;
                case _ProfileAction.delete:
                  onDelete();
                  break;
              }
            });
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: _ProfileAction.select,
                enabled: !isActive,
                child: const ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('选用'),
                ),
              ),
              PopupMenuItem(
                value: _ProfileAction.load,
                enabled: !isLoaded,
                child: const ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('加载到执行区'),
                ),
              ),
              PopupMenuItem(
                value: _ProfileAction.unload,
                enabled: isLoaded && canUnload,
                child: const ListTile(
                  leading: Icon(Icons.playlist_remove),
                  title: Text('从执行区卸载'),
                ),
              ),
              const PopupMenuItem(
                value: _ProfileAction.copy,
                child: ListTile(leading: Icon(Icons.copy), title: Text('复制')),
              ),
              const PopupMenuItem(
                value: _ProfileAction.rename,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('重命名'),
                ),
              ),
              PopupMenuItem(
                value: _ProfileAction.delete,
                enabled: canDelete,
                child: const ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('删除'),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

enum _ProfileAction { select, load, unload, copy, rename, delete }

class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名配置'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(labelText: '配置名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            // 保存前先收起输入法，减少弹窗退出动画和视口变化同帧触发的构建抖动。
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop(_controller.text);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
