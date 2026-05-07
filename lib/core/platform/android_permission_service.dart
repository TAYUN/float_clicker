import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/clicker/clicker_settings.dart';

typedef SinglePointOverlayStateChanged =
    void Function(SinglePointOverlaySnapshot snapshot);

class AndroidPermissionSnapshot {
  const AndroidPermissionSnapshot({
    required this.accessibilityGranted,
    required this.overlayGranted,
  });

  final bool accessibilityGranted;
  final bool overlayGranted;

  factory AndroidPermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    // MethodChannel 传回的是动态 Map，这里集中转换成 Flutter 侧稳定的状态模型。
    return AndroidPermissionSnapshot(
      accessibilityGranted: map['accessibilityGranted'] == true,
      overlayGranted: map['overlayGranted'] == true,
    );
  }

  static const unsupported = AndroidPermissionSnapshot(
    accessibilityGranted: false,
    overlayGranted: false,
  );
}

class SinglePointOverlaySnapshot {
  const SinglePointOverlaySnapshot({
    required this.isEnabled,
    required this.taskRunState,
    this.executedCount = 0,
  });

  final bool isEnabled;
  final TaskRunState taskRunState;
  final int executedCount;

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
    );
  }

  static const disabled = SinglePointOverlaySnapshot(
    isEnabled: false,
    taskRunState: TaskRunState.idle,
  );
}

class AndroidPermissionService {
  AndroidPermissionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'float_clicker/android_permissions';

  final MethodChannel _channel;

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
    _channel.setMethodCallHandler(
      onChanged == null
          ? null
          : (call) async {
              final arguments = call.arguments;
              if (arguments is! Map<Object?, Object?>) {
                return;
              }

              if (call.method == 'singlePointOverlayStateChanged') {
                onChanged(SinglePointOverlaySnapshot.fromMap(arguments));
                return;
              }

              if (call.method == 'singlePointClickingStateChanged') {
                onChanged(
                  SinglePointOverlaySnapshot(
                    isEnabled: true,
                    taskRunState: arguments['taskRunState'] is String
                        ? TaskRunState.fromName(
                            arguments['taskRunState'] as String?,
                          )
                        : (arguments['isRunning'] == true
                              ? TaskRunState.running
                              : TaskRunState.idle),
                    executedCount:
                        (arguments['executedCount'] as num?)?.toInt() ?? 0,
                  ),
                );
                return;
              }

              throw MissingPluginException();
            },
    );
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
}
