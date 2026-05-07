class ClickerSettings {
  const ClickerSettings({
    required this.intervalMs,
    required this.repeatCount,
    required this.infiniteLoop,
    required this.tapDurationMs,
  });

  final int intervalMs;
  final int repeatCount;
  final bool infiniteLoop;
  final int tapDurationMs;

  // 需求文档里的单点模式默认值。Flutter 页面、持久化和 Android 兜底值都应保持一致。
  static const defaults = ClickerSettings(
    intervalMs: 500,
    repeatCount: 10,
    infiniteLoop: false,
    tapDurationMs: 50,
  );

  ClickerSettings copyWith({
    int? intervalMs,
    int? repeatCount,
    bool? infiniteLoop,
    int? tapDurationMs,
  }) {
    return ClickerSettings(
      intervalMs: intervalMs ?? this.intervalMs,
      repeatCount: repeatCount ?? this.repeatCount,
      infiniteLoop: infiniteLoop ?? this.infiniteLoop,
      tapDurationMs: tapDurationMs ?? this.tapDurationMs,
    );
  }
}
