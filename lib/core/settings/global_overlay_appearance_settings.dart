class GlobalOverlayAppearanceSettings {
  const GlobalOverlayAppearanceSettings({
    required this.targetPointScale,
    required this.toolbarScale,
    required this.actionButtonScale,
  });

  final double targetPointScale;
  final double toolbarScale;
  final double actionButtonScale;

  static const minScale = 0.8;
  static const maxScale = 1.3;
  static const step = 0.05;

  static const defaults = GlobalOverlayAppearanceSettings(
    targetPointScale: 1.0,
    toolbarScale: 1.0,
    actionButtonScale: 1.0,
  );

  /// Android 仍处在单比例协议阶段，第一阶段先用三个配置的平均值兼容旧通道。
  double get overlayControlScale {
    return normalizeScale(
      (targetPointScale + toolbarScale + actionButtonScale) / 3,
    );
  }

  int get overlayControlScalePercent => (overlayControlScale * 100).round();
  int get targetPointScalePercent => (targetPointScale * 100).round();
  int get toolbarScalePercent => (toolbarScale * 100).round();
  int get actionButtonScalePercent => (actionButtonScale * 100).round();

  GlobalOverlayAppearanceSettings copyWith({
    double? targetPointScale,
    double? toolbarScale,
    double? actionButtonScale,
  }) {
    return GlobalOverlayAppearanceSettings(
      targetPointScale: normalizeScale(
        targetPointScale ?? this.targetPointScale,
      ),
      toolbarScale: normalizeScale(toolbarScale ?? this.toolbarScale),
      actionButtonScale: normalizeScale(
        actionButtonScale ?? this.actionButtonScale,
      ),
    );
  }

  factory GlobalOverlayAppearanceSettings.uniform(double scale) {
    final normalizedScale = normalizeScale(scale);
    return GlobalOverlayAppearanceSettings(
      targetPointScale: normalizedScale,
      toolbarScale: normalizedScale,
      actionButtonScale: normalizedScale,
    );
  }

  static double normalizeScale(double value) {
    final stepped = (value / step).round() * step;
    return _clampScale(stepped);
  }

  static double _clampScale(double value) {
    return value.clamp(minScale, maxScale).toDouble();
  }

  @override
  bool operator ==(Object other) {
    return other is GlobalOverlayAppearanceSettings &&
        other.targetPointScale == targetPointScale &&
        other.toolbarScale == toolbarScale &&
        other.actionButtonScale == actionButtonScale;
  }

  @override
  int get hashCode =>
      Object.hash(targetPointScale, toolbarScale, actionButtonScale);
}
