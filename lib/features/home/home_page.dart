import 'package:flutter/material.dart';

import '../../core/platform/android_permission_service.dart';
import '../clicker/clicker_settings.dart';
import '../clicker/clicker_page.dart';
import '../multi_point/multi_point_page.dart';
import '../settings/global_settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final AndroidPermissionService _permissionService =
      AndroidPermissionService();

  AndroidPermissionSnapshot _permissionSnapshot =
      AndroidPermissionSnapshot.unsupported;
  SinglePointOverlaySnapshot _singlePointSnapshot =
      SinglePointOverlaySnapshot.disabled;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionService.setPermissionStateChanged(_handlePermissionChanged);
    _permissionService.setSinglePointOverlayStateChanged(
      _handleSinglePointOverlayChanged,
    );
    _refreshPermissions();
  }

  @override
  void dispose() {
    _permissionService.setPermissionStateChanged(null);
    _permissionService.setSinglePointOverlayStateChanged(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 用户从系统设置页回到 App 后，服务绑定可能晚于“已授权”状态，前台恢复时补一次短时收敛。
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final refreshResult = await _permissionService
        .refreshSinglePointStateWithAccessibilityRetry();
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = refreshResult.permissionSnapshot;
      _singlePointSnapshot = refreshResult.overlaySnapshot;
      _isLoadingPermissions = false;
    });
  }

  void _handlePermissionChanged(AndroidPermissionSnapshot snapshot) {
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = snapshot;
      _isLoadingPermissions = false;
    });
  }

  void _handleSinglePointOverlayChanged(SinglePointOverlaySnapshot snapshot) {
    if (!mounted) {
      return;
    }

    setState(() {
      _singlePointSnapshot = snapshot;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    await _permissionService.openAccessibilitySettings();
  }

  Future<void> _openOverlaySettings() async {
    await _permissionService.openOverlaySettings();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        _permissionService.sendAppToBackground();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Float Clicker')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('权限状态', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: Icons.accessibility_new,
                title: '无障碍权限',
                subtitle: '用于执行模拟点击，需要用户在系统设置中开启',
                isGranted: _permissionSnapshot.accessibilityGranted,
                isConnected: _permissionSnapshot.accessibilityConnected,
                connectedLabel: '已连接',
                disconnectedLabel: '服务未连接',
                isLoading: _isLoadingPermissions,
                onTap: _openAccessibilitySettings,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: Icons.layers,
                title: '悬浮窗口权限',
                subtitle: '用于显示工具条和点击点，需要允许显示在其他应用上层',
                isGranted: _permissionSnapshot.overlayGranted,
                isConnected: _permissionSnapshot.overlayGranted,
                connectedLabel: '已开启',
                disconnectedLabel: '去开启',
                isLoading: _isLoadingPermissions,
                onTap: _openOverlaySettings,
              ),
              const SizedBox(height: 24),
              Text('当前运行状态', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _RunStateCard(snapshot: _singlePointSnapshot),
              const SizedBox(height: 24),
              Text('全局配置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ModeTile(
                icon: Icons.tune,
                title: '全局设置',
                subtitle: '调整悬浮点位、控制条和独立控件大小',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(GlobalSettingsPage.routeName),
              ),
              const SizedBox(height: 24),
              Text('点击模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ModeTile(
                icon: Icons.touch_app,
                title: '单点模式',
                subtitle: '拖动一个点击点，在固定位置重复点击',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(ClickerPage.routeName),
              ),
              const SizedBox(height: 12),
              _ModeTile(
                icon: Icons.control_point_duplicate,
                title: '多点模式',
                subtitle: '编辑多个点击点，按顺序执行的基础配置',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(MultiPointPage.routeName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunStateCard extends StatelessWidget {
  const _RunStateCard({required this.snapshot});

  final SinglePointOverlaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = switch ((snapshot.isEnabled, snapshot.taskRunState)) {
      (false, _) => '未启动',
      (true, TaskRunState.running) => '单点任务执行中',
      (true, TaskRunState.paused) => '单点任务已暂停',
      (true, TaskRunState.idle) => '单点模式已开启',
    };
    final subtitle = switch ((snapshot.isEnabled, snapshot.taskRunState)) {
      (true, TaskRunState.running) ||
      (true, TaskRunState.paused) => '已执行 ${snapshot.executedCount} 次',
      _ => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              snapshot.isEnabled ? Icons.touch_app : Icons.do_not_disturb_on,
              color: snapshot.isEnabled
                  ? colorScheme.primary
                  : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.isConnected,
    required this.connectedLabel,
    required this.disconnectedLabel,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final bool isConnected;
  final String connectedLabel;
  final String disconnectedLabel;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = isLoading
        ? '检测中'
        : (!isGranted
              ? '去开启'
              : (isConnected ? connectedLabel : disconnectedLabel));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isGranted && isConnected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isGranted && isConnected
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(status, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
