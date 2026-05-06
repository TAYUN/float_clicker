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
