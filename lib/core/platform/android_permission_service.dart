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
      return AndroidPermissionSnapshot.unsupported;
    }

    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getPermissionSnapshot',
    );
    return AndroidPermissionSnapshot.fromMap(result ?? const {});
  }

  Future<void> openAccessibilitySettings() async {
    await _invokeAndroidOnly('openAccessibilitySettings');
  }

  Future<void> openOverlaySettings() async {
    await _invokeAndroidOnly('openOverlaySettings');
  }

  Future<void> _invokeAndroidOnly(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _channel.invokeMethod<void>(method);
  }
}
