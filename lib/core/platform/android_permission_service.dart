import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/global_overlay_appearance_settings.dart';
import '../../features/clicker/clicker_settings.dart';

typedef SinglePointOverlayStateChanged =
    FutureOr<void> Function(SinglePointOverlaySnapshot snapshot);
typedef AndroidPermissionStateChanged =
    FutureOr<void> Function(AndroidPermissionSnapshot snapshot);

class AndroidPermissionSnapshot {
  const AndroidPermissionSnapshot({
    required this.accessibilityGranted,
    required this.accessibilityConnected,
    required this.overlayGranted,
  });

  final bool accessibilityGranted;
  final bool accessibilityConnected;
  final bool overlayGranted;

  factory AndroidPermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    // MethodChannel 传回的是动态 Map，这里集中转换成 Flutter 侧稳定的状态模型。
    return AndroidPermissionSnapshot(
      accessibilityGranted: map['accessibilityGranted'] == true,
      accessibilityConnected: map['accessibilityConnected'] == true,
      overlayGranted: map['overlayGranted'] == true,
    );
  }

  static const unsupported = AndroidPermissionSnapshot(
    accessibilityGranted: false,
    accessibilityConnected: false,
    overlayGranted: false,
  );
}

class SinglePointOverlaySnapshot {
  const SinglePointOverlaySnapshot({
    required this.isEnabled,
    required this.taskRunState,
    this.executedCount = 0,
    this.overlayUiSettings,
  });

  final bool isEnabled;
  final TaskRunState taskRunState;
  final int executedCount;
  final OverlayUiSettings? overlayUiSettings;

  bool get isRunning => taskRunState == TaskRunState.running;

  factory SinglePointOverlaySnapshot.fromMap(Map<Object?, Object?> map) {
    return SinglePointOverlaySnapshot(
      isEnabled: map['isEnabled'] == true,
      taskRunState: map['taskRunState'] is String
          ? TaskRunState.fromName(map['taskRunState'] as String?)
          : (map['isRunning'] == true
                ? TaskRunState.running
                : TaskRunState.idle),
      executedCount: (map['executedCount'] as num?)?.toInt() ?? 0,
      overlayUiSettings: _overlayUiSettingsFromMap(map),
    );
  }

  static const disabled = SinglePointOverlaySnapshot(
    isEnabled: false,
    taskRunState: TaskRunState.idle,
  );
}

OverlayUiSettings? _overlayUiSettingsFromMap(Map<Object?, Object?> map) {
  if (map['interactionMode'] is! String) {
    return null;
  }

  final defaults = OverlayUiSettings.defaults;
  return OverlayUiSettings(
    interactionMode: OverlayInteractionMode.fromName(
      map['interactionMode'] as String?,
    ),
    targetPositionX:
        (map['targetPositionX'] as num?)?.toInt() ?? defaults.targetPositionX,
    targetPositionY:
        (map['targetPositionY'] as num?)?.toInt() ?? defaults.targetPositionY,
    toolbarPositionX:
        (map['toolbarPositionX'] as num?)?.toInt() ?? defaults.toolbarPositionX,
    toolbarPositionY:
        (map['toolbarPositionY'] as num?)?.toInt() ?? defaults.toolbarPositionY,
    collapsedToolbarPositionX:
        (map['collapsedToolbarPositionX'] as num?)?.toInt() ??
        defaults.collapsedToolbarPositionX,
    collapsedToolbarPositionY:
        (map['collapsedToolbarPositionY'] as num?)?.toInt() ??
        defaults.collapsedToolbarPositionY,
    actionButtonPositionX:
        (map['actionButtonPositionX'] as num?)?.toInt() ??
        defaults.actionButtonPositionX,
    actionButtonPositionY:
        (map['actionButtonPositionY'] as num?)?.toInt() ??
        defaults.actionButtonPositionY,
    isToolbarCollapsed:
        (map['isToolbarCollapsed'] as bool?) ?? defaults.isToolbarCollapsed,
  );
}

class AndroidPermissionService {
  AndroidPermissionService({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel {
    _ensureMethodCallHandler(_channel);
  }

  static const _channelName = 'float_clicker/android_permissions';
  static const _defaultChannel = MethodChannel(_channelName);

  final MethodChannel _channel;
  final Object _listenerKey = Object();

  Future<AndroidPermissionSnapshot> getSnapshot() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // 当前能力只存在于 Android。其他平台返回“未授权”快照，让 UI 走普通不可用状态。
      return AndroidPermissionSnapshot.unsupported;
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getPermissionSnapshot',
      );
      return AndroidPermissionSnapshot.fromMap(result ?? const {});
    } on MissingPluginException {
      // Widget 测试没有 Android 宿主环境，返回未授权快照即可。
      return AndroidPermissionSnapshot.unsupported;
    }
  }

  Future<void> openAccessibilitySettings() async {
    await _invokeAndroidOnly('openAccessibilitySettings');
  }

  Future<void> openOverlaySettings() async {
    await _invokeAndroidOnly('openOverlaySettings');
  }

  Future<void> showSinglePointOverlay({
    required int intervalMs,
    required int repeatCount,
    required bool infiniteLoop,
    required int tapDurationMs,
    OverlayUiSettings overlayUiSettings = OverlayUiSettings.defaults,
    GlobalOverlayAppearanceSettings appearanceSettings =
        GlobalOverlayAppearanceSettings.defaults,
  }) async {
    // 这些配置会被 Android 的 SinglePointOverlayManager 保存，
    // 点击时再交给 SinglePointClickScheduler 生成每次点击请求。
    await _invokeAndroidOnly(
      'showSinglePointOverlay',
      arguments: {
        'intervalMs': intervalMs,
        'repeatCount': repeatCount,
        'infiniteLoop': infiniteLoop,
        'tapDurationMs': tapDurationMs,
        ..._overlayUiSettingsArguments(overlayUiSettings),
        ..._globalOverlayAppearanceArguments(appearanceSettings),
      },
    );
  }

  Future<void> hideSinglePointOverlay() async {
    await _invokeAndroidOnly('hideSinglePointOverlay');
  }

  Future<SinglePointOverlaySnapshot> getSinglePointOverlaySnapshot() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return SinglePointOverlaySnapshot.disabled;
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getSinglePointOverlaySnapshot',
      );
      return SinglePointOverlaySnapshot.fromMap(result ?? const {});
    } on MissingPluginException {
      return SinglePointOverlaySnapshot.disabled;
    }
  }

  Future<void> updateSinglePointSettings({
    required int intervalMs,
    required int repeatCount,
    required bool infiniteLoop,
    required int tapDurationMs,
  }) async {
    await _invokeAndroidOnly(
      'updateSinglePointSettings',
      arguments: {
        'intervalMs': intervalMs,
        'repeatCount': repeatCount,
        'infiniteLoop': infiniteLoop,
        'tapDurationMs': tapDurationMs,
      },
    );
  }

  Future<void> updateSinglePointOverlayUiSettings(
    OverlayUiSettings settings,
  ) async {
    await _invokeAndroidOnly(
      'updateSinglePointOverlayUiSettings',
      arguments: _overlayUiSettingsArguments(settings),
      ignoreMissingPlugin: true,
    );
  }

  Future<void> updateGlobalOverlayAppearanceSettings(
    GlobalOverlayAppearanceSettings settings,
  ) async {
    await _invokeAndroidOnly(
      'updateGlobalOverlayAppearanceSettings',
      arguments: _globalOverlayAppearanceArguments(settings),
      ignoreMissingPlugin: true,
    );
  }

  Future<void> startSinglePointClicking() async {
    await _invokeAndroidOnly('startSinglePointClicking');
  }

  Future<void> pauseSinglePointClicking() async {
    await _invokeAndroidOnly('pauseSinglePointClicking');
  }

  Future<void> resumeSinglePointClicking() async {
    await _invokeAndroidOnly('resumeSinglePointClicking');
  }

  Future<void> endSinglePointClicking() async {
    await _invokeAndroidOnly('endSinglePointClicking');
  }

  Future<void> stopSinglePointClicking() async {
    await _invokeAndroidOnly('stopSinglePointClicking');
  }

  void setSinglePointOverlayStateChanged(
    SinglePointOverlayStateChanged? onChanged,
  ) {
    if (onChanged == null) {
      _singlePointOverlayListeners.remove(_listenerKey);
    } else {
      _singlePointOverlayListeners[_listenerKey] = onChanged;
    }
  }

  void setPermissionStateChanged(AndroidPermissionStateChanged? onChanged) {
    if (onChanged == null) {
      _permissionStateListeners.remove(_listenerKey);
    } else {
      _permissionStateListeners[_listenerKey] = onChanged;
    }
  }

  Future<void> _invokeAndroidOnly(
    String method, {
    Map<String, Object?>? arguments,
    bool ignoreMissingPlugin = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 个别第一阶段先行铺好的协议允许老 Android 端临时忽略；
      // 暂停/继续/结束这类会改变任务语义的方法必须显式暴露未实现状态。
      if (ignoreMissingPlugin) {
        return;
      }
      throw PlatformException(
        code: 'unimplemented_method',
        message: 'Android 尚未实现 $method。',
      );
    }
  }

  Map<String, Object?> _overlayUiSettingsArguments(OverlayUiSettings settings) {
    return {
      'interactionMode': settings.interactionMode.name,
      'targetPositionX': settings.targetPositionX,
      'targetPositionY': settings.targetPositionY,
      'toolbarPositionX': settings.toolbarPositionX,
      'toolbarPositionY': settings.toolbarPositionY,
      'collapsedToolbarPositionX': settings.collapsedToolbarPositionX,
      'collapsedToolbarPositionY': settings.collapsedToolbarPositionY,
      'actionButtonPositionX': settings.actionButtonPositionX,
      'actionButtonPositionY': settings.actionButtonPositionY,
      'isToolbarCollapsed': settings.isToolbarCollapsed,
    };
  }

  Map<String, Object?> _globalOverlayAppearanceArguments(
    GlobalOverlayAppearanceSettings settings,
  ) {
    return {
      'overlayControlScale': GlobalOverlayAppearanceSettings.normalizeScale(
        settings.overlayControlScale,
      ),
    };
  }

  static final Map<Object, SinglePointOverlayStateChanged>
  _singlePointOverlayListeners = {};
  static final Map<Object, AndroidPermissionStateChanged>
  _permissionStateListeners = {};

  static void _ensureMethodCallHandler(MethodChannel channel) {
    // MethodChannel 的 Flutter 侧 handler 是按 channel 名称全局生效的；
    // 这里集中分发，避免首页和单点页分别注册时互相覆盖。
    channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (arguments is! Map<Object?, Object?>) {
        return;
      }

      if (call.method == 'permissionSnapshotChanged') {
        final snapshot = AndroidPermissionSnapshot.fromMap(arguments);
        for (final listener in List<AndroidPermissionStateChanged>.of(
          _permissionStateListeners.values,
        )) {
          await listener(snapshot);
        }
        return;
      }

      if (call.method == 'singlePointOverlayStateChanged') {
        final snapshot = SinglePointOverlaySnapshot.fromMap(arguments);
        for (final listener in List<SinglePointOverlayStateChanged>.of(
          _singlePointOverlayListeners.values,
        )) {
          await listener(snapshot);
        }
        return;
      }

      if (call.method == 'singlePointClickingStateChanged') {
        final snapshot = SinglePointOverlaySnapshot(
          isEnabled: true,
          taskRunState: arguments['taskRunState'] is String
              ? TaskRunState.fromName(arguments['taskRunState'] as String?)
              : (arguments['isRunning'] == true
                    ? TaskRunState.running
                    : TaskRunState.idle),
          executedCount: (arguments['executedCount'] as num?)?.toInt() ?? 0,
          overlayUiSettings: _overlayUiSettingsFromMap(arguments),
        );
        for (final listener in List<SinglePointOverlayStateChanged>.of(
          _singlePointOverlayListeners.values,
        )) {
          await listener(snapshot);
        }
        return;
      }

      throw MissingPluginException();
    });
  }
}
