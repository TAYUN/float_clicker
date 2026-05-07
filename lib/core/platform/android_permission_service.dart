import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  }) async {
    // 这些配置会被 Android 的 SinglePointOverlayManager 保存，
    // 点击时再交给 SinglePointClickScheduler 生成每次点击请求。
    await _invokeAndroidOnly('showSinglePointOverlay', {
      'intervalMs': intervalMs,
      'repeatCount': repeatCount,
      'infiniteLoop': infiniteLoop,
      'tapDurationMs': tapDurationMs,
    });
  }

  Future<void> hideSinglePointOverlay() async {
    await _invokeAndroidOnly('hideSinglePointOverlay');
  }

  Future<void> updateSinglePointSettings({
    required int intervalMs,
    required int repeatCount,
    required bool infiniteLoop,
    required int tapDurationMs,
  }) async {
    await _invokeAndroidOnly('updateSinglePointSettings', {
      'intervalMs': intervalMs,
      'repeatCount': repeatCount,
      'infiniteLoop': infiniteLoop,
      'tapDurationMs': tapDurationMs,
    });
  }

  Future<void> startSinglePointClicking() async {
    await _invokeAndroidOnly('startSinglePointClicking');
  }

  Future<void> stopSinglePointClicking() async {
    await _invokeAndroidOnly('stopSinglePointClicking');
  }

  Future<void> _invokeAndroidOnly(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Widget 测试和非 Android 宿主没有原生 MethodChannel 实现，直接跳过。
    }
  }
}
