import 'package:flutter/material.dart';

import '../clicker/clicker_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const routeName = '/';

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
            const _PermissionCard(
              icon: Icons.accessibility_new,
              title: '无障碍权限',
              subtitle: '用于执行模拟点击，下一步接入系统权限检测',
              status: '未接入',
            ),
            const SizedBox(height: 12),
            const _PermissionCard(
              icon: Icons.layers,
              title: '悬浮窗口权限',
              subtitle: '用于显示工具条和点击点，下一步接入系统权限检测',
              status: '未接入',
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
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(status, style: Theme.of(context).textTheme.labelMedium),
          ],
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
