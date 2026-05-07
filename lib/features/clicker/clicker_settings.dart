enum TaskRunState {
  idle,
  running,
  paused;

  static TaskRunState fromName(String? value) {
    return switch (value) {
      'running' => TaskRunState.running,
      'paused' => TaskRunState.paused,
      _ => TaskRunState.idle,
    };
  }

  String get label {
    return switch (this) {
      TaskRunState.idle => '未执行',
      TaskRunState.running => '正在点击',
      TaskRunState.paused => '已暂停',
    };
  }
}

enum OverlayInteractionMode {
  normal,
  compact,
  minimal;

  static OverlayInteractionMode fromName(String? value) {
    return switch (value) {
      'compact' => OverlayInteractionMode.compact,
      'minimal' => OverlayInteractionMode.minimal,
      _ => OverlayInteractionMode.normal,
    };
  }

  String get label {
    return switch (this) {
      OverlayInteractionMode.normal => '普通模式',
      OverlayInteractionMode.compact => '简洁模式',
      OverlayInteractionMode.minimal => '极简模式',
    };
  }

  String get description {
    return switch (this) {
      OverlayInteractionMode.normal => '显示点击点和完整控制条',
      OverlayInteractionMode.compact => '控制条可收起，收起后显示独立执行控件',
      OverlayInteractionMode.minimal => '只显示点击点和独立执行控件',
    };
  }
}

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

class OverlayUiSettings {
  const OverlayUiSettings({
    required this.interactionMode,
    required this.targetPositionX,
    required this.targetPositionY,
    required this.toolbarPositionX,
    required this.toolbarPositionY,
    required this.collapsedToolbarPositionX,
    required this.collapsedToolbarPositionY,
    required this.actionButtonPositionX,
    required this.actionButtonPositionY,
    required this.isToolbarCollapsed,
  });

  final OverlayInteractionMode interactionMode;
  final int targetPositionX;
  final int targetPositionY;
  final int toolbarPositionX;
  final int toolbarPositionY;
  final int collapsedToolbarPositionX;
  final int collapsedToolbarPositionY;
  final int actionButtonPositionX;
  final int actionButtonPositionY;
  final bool isToolbarCollapsed;

  static const defaults = OverlayUiSettings(
    interactionMode: OverlayInteractionMode.normal,
    targetPositionX: 280,
    targetPositionY: 260,
    toolbarPositionX: 18,
    toolbarPositionY: 180,
    collapsedToolbarPositionX: 18,
    collapsedToolbarPositionY: 180,
    actionButtonPositionX: 18,
    actionButtonPositionY: 260,
    isToolbarCollapsed: false,
  );

  OverlayUiSettings copyWith({
    OverlayInteractionMode? interactionMode,
    int? targetPositionX,
    int? targetPositionY,
    int? toolbarPositionX,
    int? toolbarPositionY,
    int? collapsedToolbarPositionX,
    int? collapsedToolbarPositionY,
    int? actionButtonPositionX,
    int? actionButtonPositionY,
    bool? isToolbarCollapsed,
  }) {
    return OverlayUiSettings(
      interactionMode: interactionMode ?? this.interactionMode,
      targetPositionX: targetPositionX ?? this.targetPositionX,
      targetPositionY: targetPositionY ?? this.targetPositionY,
      toolbarPositionX: toolbarPositionX ?? this.toolbarPositionX,
      toolbarPositionY: toolbarPositionY ?? this.toolbarPositionY,
      collapsedToolbarPositionX:
          collapsedToolbarPositionX ?? this.collapsedToolbarPositionX,
      collapsedToolbarPositionY:
          collapsedToolbarPositionY ?? this.collapsedToolbarPositionY,
      actionButtonPositionX:
          actionButtonPositionX ?? this.actionButtonPositionX,
      actionButtonPositionY:
          actionButtonPositionY ?? this.actionButtonPositionY,
      isToolbarCollapsed: isToolbarCollapsed ?? this.isToolbarCollapsed,
    );
  }
}

class SinglePointSettings {
  const SinglePointSettings({
    required this.clickerSettings,
    required this.overlayUiSettings,
  });

  final ClickerSettings clickerSettings;
  final OverlayUiSettings overlayUiSettings;
}
