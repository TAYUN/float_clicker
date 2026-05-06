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
              number: '2.1',
              text: '拖动指示标志至您想点击的位置',
              visual: _TargetPointPreview(),
            ),
            _GuideStep(
              number: '2.2',
              text: '拖动移动图标来移动面板',
              visual: Icon(Icons.open_with, size: 64),
            ),
            _GuideStep(
              number: '3',
              text: '点击播放形状按钮以执行点击操作',
              visual: Icon(Icons.play_arrow_rounded, size: 80),
            ),
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
