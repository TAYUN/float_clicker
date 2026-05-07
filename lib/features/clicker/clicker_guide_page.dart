import 'package:flutter/material.dart';

class ClickerGuidePage extends StatelessWidget {
  const ClickerGuidePage({super.key});

  static const routeName = '/single-point/guide';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('介绍向导')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _GuideStep(number: '1', text: '开启单点模式', visual: _ModePreview()),
            _GuideStep(
              number: '2',
              text: '选择适合当前页面的悬浮交互模式',
              visual: _InteractionModePreview(),
            ),
            _GuideStep(
              number: '3',
              text: '拖动点击点到需要点击的位置',
              visual: _TargetPointPreview(),
            ),
            _GuideStep(
              number: '4',
              text: '通过控制条或独立执行控件开始点击',
              visual: Icon(Icons.play_arrow_rounded, size: 80),
            ),
            _GuideStep(
              number: '5',
              text: '点击可暂停或继续任务，长按独立执行控件可结束任务',
              visual: Icon(Icons.pause_circle, size: 72),
            ),
            _GuideStep(
              number: '6',
              text: '需要完全退出时，关闭单点模式并移除悬浮组件',
              visual: Icon(Icons.close_rounded, size: 72),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionModePreview extends StatelessWidget {
  const _InteractionModePreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: const [
              _ModeChip(icon: Icons.view_week, text: '普通'),
              _ModeChip(icon: Icons.compress, text: '简洁'),
              _ModeChip(icon: Icons.radio_button_checked, text: '极简'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.text,
    required this.visual,
  });

  final String number;
  final String text;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $text',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: visual),
        ],
      ),
    );
  }
}

class _ModePreview extends StatelessWidget {
  const _ModePreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('单点模式', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 12),
                  Text('设置'),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [Icon(Icons.info), SizedBox(width: 12), Text('介绍向导')],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: null, child: Text('开启')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetPointPreview extends StatelessWidget {
  const _TargetPointPreview();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.primary, width: 4),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
