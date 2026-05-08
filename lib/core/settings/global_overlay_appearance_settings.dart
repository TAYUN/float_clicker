class GlobalOverlayAppearanceSettings {
  const GlobalOverlayAppearanceSettings({required this.overlayControlScale});

  final double overlayControlScale;

  static const minScale = 0.8;
  static const maxScale = 1.3;
  static const step = 0.05;

  static const defaults = GlobalOverlayAppearanceSettings(
    overlayControlScale: 1.0,
  );

  int get overlayControlScalePercent => (overlayControlScale * 100).round();

  GlobalOverlayAppearanceSettings copyWith({double? overlayControlScale}) {
    return GlobalOverlayAppearanceSettings(
      overlayControlScale: _clampScale(
        overlayControlScale ?? this.overlayControlScale,
      ),
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
        other.overlayControlScale == overlayControlScale;
  }

  @override
  int get hashCode => overlayControlScale.hashCode;
}
