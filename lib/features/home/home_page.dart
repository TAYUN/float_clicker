import 'package:flutter/material.dart';

import '../../core/platform/android_permission_service.dart';
import '../clicker/clicker_page.dart';

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
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 用户从系统设置页回到 App 后，权限状态可能已经改变。
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final snapshot = await _permissionService.getSnapshot();
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = snapshot;
      _isLoadingPermissions = false;
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
    return Scaffold(
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
              isLoading: _isLoadingPermissions,
              onTap: _openAccessibilitySettings,
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              icon: Icons.layers,
              title: '悬浮窗口权限',
              subtitle: '用于显示工具条和点击点，需要允许显示在其他应用上层',
              isGranted: _permissionSnapshot.overlayGranted,
              isLoading: _isLoadingPermissions,
              onTap: _openOverlaySettings,
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
            const _ModeTile(
              icon: Icons.control_point_duplicate,
              title: '多点模式',
              subtitle: '多个点击点按顺序执行，后续开发',
              trailing: _ComingSoonPill(),
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
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = isLoading ? '检测中' : (isGranted ? '已开启' : '去开启');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isGranted ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isGranted ? colorScheme.primary : colorScheme.outline,
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

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text('开发中'),
      ),
    );
  }
}
