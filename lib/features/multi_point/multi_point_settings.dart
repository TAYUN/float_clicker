import 'package:float_clicker/features/clicker/clicker_settings.dart';

/// 多点模式里的单个点击点。
///
/// 坐标保存的是悬浮点组件左上角，后续 Android 执行点击时再按组件尺寸换算中心点。
class MultiPointTarget {
  const MultiPointTarget({
    required this.id,
    required this.order,
    required this.label,
    required this.x,
    required this.y,
    required this.enabled,
  });

  final String id;
  // order 表示完整点位列表顺序；启用点位的悬浮显示序号后续由页面/原生侧连续生成。
  final int order;
  final String label;
  final double x;
  final double y;
  final bool enabled;

  // 首次进入多点模式时默认给 2 个启用点位，位置靠近单点默认点并上下错开。
  static const defaultFirstTarget = MultiPointTarget(
    id: 'p1',
    order: 1,
    label: '1',
    x: 280,
    y: 260,
    enabled: true,
  );

  static const defaultSecondTarget = MultiPointTarget(
    id: 'p2',
    order: 2,
    label: '2',
    x: 280,
    y: 340,
    enabled: true,
  );

  MultiPointTarget copyWith({
    String? id,
    int? order,
    String? label,
    double? x,
    double? y,
    bool? enabled,
  }) {
    return MultiPointTarget(
      id: id ?? this.id,
      order: order ?? this.order,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'order': order,
      'label': label,
      'x': x,
      'y': y,
      'enabled': enabled,
    };
  }

  static MultiPointTarget? tryFromJson(Object? value, {int? fallbackOrder}) {
    if (value is! Map) {
      return null;
    }

    final id = value['id'];
    final x = _readDouble(value['x']);
    final y = _readDouble(value['y']);
    // id 和坐标是点位恢复的最低要求；缺任何一个都丢弃该条坏数据。
    if (id is! String || id.trim().isEmpty || x == null || y == null) {
      return null;
    }

    return MultiPointTarget(
      id: id.trim(),
      order: _readInt(value['order']) ?? fallbackOrder ?? 1,
      label: (value['label'] as String?)?.trim() ?? '',
      x: x,
      y: y,
      enabled: value['enabled'] is bool ? value['enabled'] as bool : true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MultiPointTarget &&
        other.id == id &&
        other.order == order &&
        other.label == label &&
        other.x == x &&
        other.y == y &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return Object.hash(id, order, label, x, y, enabled);
  }
}

/// 多点点位列表的不可变包装，集中维护第一版的增删、排序和启禁约束。
class MultiPointTargets {
  MultiPointTargets(Iterable<MultiPointTarget> targets)
    : values = List.unmodifiable(_normalizeTargets(targets));

  factory MultiPointTargets.defaults() {
    return MultiPointTargets(const [
      MultiPointTarget.defaultFirstTarget,
      MultiPointTarget.defaultSecondTarget,
    ]);
  }

  factory MultiPointTargets.fromJsonList(Object? value) {
    if (value is! List) {
      return MultiPointTargets.defaults();
    }

    final parsed = <MultiPointTarget>[];
    for (var index = 0; index < value.length; index += 1) {
      final target = MultiPointTarget.tryFromJson(
        value[index],
        fallbackOrder: index + 1,
      );
      if (target != null) {
        parsed.add(target);
      }
    }

    // 点位对象不能被持久化成空列表；坏 JSON 或空列表都回到首启默认状态。
    if (parsed.isEmpty) {
      return MultiPointTargets.defaults();
    }

    return MultiPointTargets(_sortBySavedOrder(parsed).take(maxTargets));
  }

  static const maxTargets = 12;
  // 新增点位默认沿用最后一个点位的 x，并向下错开，后续原生侧负责校正到可见区域。
  static const addOffsetY = 80.0;
  static const noEnabledTargetsErrorCode = 'no_enabled_targets';

  final List<MultiPointTarget> values;

  int get length => values.length;
  bool get canAdd => values.length < maxTargets;
  bool get canRemove => values.length > 1;
  bool get hasEnabledTarget => values.any((target) => target.enabled);

  // 允许用户把点位全部禁用，但执行/继续前必须用这个校验拒绝启动。
  String? get executionValidationErrorCode {
    return hasEnabledTarget ? null : noEnabledTargetsErrorCode;
  }

  List<MultiPointTarget> get enabledTargets {
    return values.where((target) => target.enabled).toList(growable: false);
  }

  MultiPointTargets addTarget({String? id}) {
    if (!canAdd) {
      throw StateError(
        'Multi point mode supports at most $maxTargets targets.',
      );
    }

    final lastTarget = values.last;
    final order = values.length + 1;
    return MultiPointTargets([
      ...values,
      MultiPointTarget(
        id: id ?? _nextTargetId(values),
        order: order,
        label: '$order',
        x: lastTarget.x,
        y: lastTarget.y + addOffsetY,
        enabled: true,
      ),
    ]);
  }

  MultiPointTargets removeTarget(String id) {
    if (!canRemove) {
      throw StateError('Multi point mode must keep at least one target.');
    }

    final nextTargets = values.where((target) => target.id != id).toList();
    if (nextTargets.isEmpty) {
      throw StateError('Multi point mode must keep at least one target.');
    }
    return MultiPointTargets(nextTargets);
  }

  MultiPointTargets reorderTarget({
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= values.length) {
      throw RangeError.index(oldIndex, values, 'oldIndex');
    }
    if (newIndex < 0 || newIndex > values.length) {
      throw RangeError.index(newIndex, values, 'newIndex');
    }

    final nextTargets = values.toList();
    final target = nextTargets.removeAt(oldIndex);
    final insertIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    nextTargets.insert(insertIndex, target);
    return MultiPointTargets(nextTargets);
  }

  MultiPointTargets updateTarget(MultiPointTarget updatedTarget) {
    return MultiPointTargets([
      for (final target in values)
        target.id == updatedTarget.id ? updatedTarget : target,
    ]);
  }

  MultiPointTargets setTargetEnabled(String id, bool enabled) {
    return MultiPointTargets([
      for (final target in values)
        target.id == id ? target.copyWith(enabled: enabled) : target,
    ]);
  }

  List<Map<String, Object?>> toJsonList() {
    return [for (final target in values) target.toJson()];
  }

  @override
  bool operator ==(Object other) {
    if (other is! MultiPointTargets || other.values.length != values.length) {
      return false;
    }

    for (var index = 0; index < values.length; index += 1) {
      if (other.values[index] != values[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);

  static List<MultiPointTarget> _normalizeTargets(
    Iterable<MultiPointTarget> targets,
  ) {
    final ordered = targets.toList();

    return [
      for (var index = 0; index < ordered.length; index += 1)
        // 排序变化只重排执行顺序，稳定 id 和用户标签都保持不变。
        ordered[index].copyWith(order: index + 1),
    ];
  }

  static List<MultiPointTarget> _sortBySavedOrder(
    Iterable<MultiPointTarget> targets,
  ) {
    // 只有从持久化恢复时才按保存的 order 排序；运行时重排必须保留当前列表顺序。
    return targets.toList()..sort((a, b) {
      final orderCompare = a.order.compareTo(b.order);
      return orderCompare == 0 ? a.id.compareTo(b.id) : orderCompare;
    });
  }

  static String _nextTargetId(List<MultiPointTarget> targets) {
    // id 是稳定身份，不随排序重排；新增时只向后取下一个 pN，避免复用已删除 id。
    var maxNumericId = 0;
    for (final target in targets) {
      final match = RegExp(r'^p(\d+)$').firstMatch(target.id);
      if (match == null) {
        continue;
      }
      final numericId = int.tryParse(match.group(1)!);
      if (numericId != null && numericId > maxNumericId) {
        maxNumericId = numericId;
      }
    }
    return 'p${maxNumericId + 1}';
  }
}

/// 基础多点第一版的点击参数，语义保持和单点模式一致。
class MultiPointSettings {
  const MultiPointSettings({
    required this.intervalMs,
    required this.repeatCount,
    required this.infiniteLoop,
    required this.tapDurationMs,
  });

  final int intervalMs;
  final int repeatCount;
  final bool infiniteLoop;
  final int tapDurationMs;

  static const defaults = MultiPointSettings(
    intervalMs: 500,
    repeatCount: 10,
    infiniteLoop: false,
    tapDurationMs: 50,
  );

  MultiPointSettings copyWith({
    int? intervalMs,
    int? repeatCount,
    bool? infiniteLoop,
    int? tapDurationMs,
  }) {
    return MultiPointSettings(
      intervalMs: intervalMs ?? this.intervalMs,
      repeatCount: repeatCount ?? this.repeatCount,
      infiniteLoop: infiniteLoop ?? this.infiniteLoop,
      tapDurationMs: tapDurationMs ?? this.tapDurationMs,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MultiPointSettings &&
        other.intervalMs == intervalMs &&
        other.repeatCount == repeatCount &&
        other.infiniteLoop == infiniteLoop &&
        other.tapDurationMs == tapDurationMs;
  }

  @override
  int get hashCode {
    return Object.hash(intervalMs, repeatCount, infiniteLoop, tapDurationMs);
  }
}

/// 多点模式自己的悬浮控制组件位置。
///
/// 点位位置保存在 [MultiPointTarget]，这里不重复保存，避免两套坐标语义打架。
class MultiPointOverlayUiSettings {
  const MultiPointOverlayUiSettings({
    required this.interactionMode,
    required this.toolbarPositionX,
    required this.toolbarPositionY,
    required this.collapsedToolbarPositionX,
    required this.collapsedToolbarPositionY,
    required this.actionButtonPositionX,
    required this.actionButtonPositionY,
    required this.isToolbarCollapsed,
  });

  final OverlayInteractionMode interactionMode;
  final int toolbarPositionX;
  final int toolbarPositionY;
  final int collapsedToolbarPositionX;
  final int collapsedToolbarPositionY;
  final int actionButtonPositionX;
  final int actionButtonPositionY;
  final bool isToolbarCollapsed;

  static const defaults = MultiPointOverlayUiSettings(
    interactionMode: OverlayInteractionMode.normal,
    toolbarPositionX: 18,
    toolbarPositionY: 180,
    collapsedToolbarPositionX: 18,
    collapsedToolbarPositionY: 180,
    actionButtonPositionX: 18,
    actionButtonPositionY: 260,
    isToolbarCollapsed: false,
  );

  MultiPointOverlayUiSettings copyWith({
    OverlayInteractionMode? interactionMode,
    int? toolbarPositionX,
    int? toolbarPositionY,
    int? collapsedToolbarPositionX,
    int? collapsedToolbarPositionY,
    int? actionButtonPositionX,
    int? actionButtonPositionY,
    bool? isToolbarCollapsed,
  }) {
    return MultiPointOverlayUiSettings(
      interactionMode: interactionMode ?? this.interactionMode,
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

  @override
  bool operator ==(Object other) {
    return other is MultiPointOverlayUiSettings &&
        other.interactionMode == interactionMode &&
        other.toolbarPositionX == toolbarPositionX &&
        other.toolbarPositionY == toolbarPositionY &&
        other.collapsedToolbarPositionX == collapsedToolbarPositionX &&
        other.collapsedToolbarPositionY == collapsedToolbarPositionY &&
        other.actionButtonPositionX == actionButtonPositionX &&
        other.actionButtonPositionY == actionButtonPositionY &&
        other.isToolbarCollapsed == isToolbarCollapsed;
  }

  @override
  int get hashCode {
    return Object.hash(
      interactionMode,
      toolbarPositionX,
      toolbarPositionY,
      collapsedToolbarPositionX,
      collapsedToolbarPositionY,
      actionButtonPositionX,
      actionButtonPositionY,
      isToolbarCollapsed,
    );
  }
}

/// P1 阶段的完整多点本地配置快照，供后续页面和 MethodChannel 参数复用。
class MultiPointConfiguration {
  const MultiPointConfiguration({
    required this.settings,
    required this.overlayUiSettings,
    required this.targets,
  });

  final MultiPointSettings settings;
  final MultiPointOverlayUiSettings overlayUiSettings;
  final MultiPointTargets targets;
}

int? _readInt(Object? value) {
  return switch (value) {
    int() => value,
    double() => value.round(),
    String() => int.tryParse(value),
    _ => null,
  };
}

double? _readDouble(Object? value) {
  // SharedPreferences/JSON 历史数据可能出现 int、double 或字符串，这里统一宽松读取。
  return switch (value) {
    int() => value.toDouble(),
    double() => value,
    String() => double.tryParse(value),
    _ => null,
  };
}
