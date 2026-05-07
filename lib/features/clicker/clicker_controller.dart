import 'package:flutter/foundation.dart';

import 'clicker_settings.dart';

class ClickerController extends ChangeNotifier {
  ClickerSettings _settings = ClickerSettings.defaults;

  // 这两个状态只表示 Flutter 页面当前认为的状态。
  // 真正的悬浮窗和点击任务在 Android 原生侧维护，页面操作成功后才同步切换这里。
  bool _isRunning = false;
  bool _isSinglePointModeEnabled = false;

  ClickerSettings get settings => _settings;
  bool get isRunning => _isRunning;
  bool get isSinglePointModeEnabled => _isSinglePointModeEnabled;

  void updateSettings(ClickerSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  void updateInterval(String value) {
    final nextValue = int.tryParse(value);
    if (nextValue == null || nextValue <= 0) {
      return;
    }

    _settings = _settings.copyWith(intervalMs: nextValue);
    notifyListeners();
  }

  void updateRepeatCount(String value) {
    final nextValue = int.tryParse(value);
    if (nextValue == null || nextValue <= 0) {
      return;
    }

    _settings = _settings.copyWith(repeatCount: nextValue);
    notifyListeners();
  }

  void toggleInfiniteLoop(bool value) {
    _settings = _settings.copyWith(infiniteLoop: value);
    notifyListeners();
  }

  void updateTapDuration(String value) {
    final nextValue = int.tryParse(value);
    if (nextValue == null || nextValue <= 0) {
      return;
    }

    _settings = _settings.copyWith(tapDurationMs: nextValue);
    notifyListeners();
  }

  void toggleRunning() {
    if (!_isSinglePointModeEnabled) {
      return;
    }

    // 点击任务必须依附于单点模式悬浮窗；未开启模式时不允许进入运行态。
    setRunning(!_isRunning);
  }

  void setRunning(bool value) {
    if (!_isSinglePointModeEnabled && value) {
      return;
    }

    if (_isRunning == value) {
      return;
    }

    _isRunning = value;
    notifyListeners();
  }

  void setSinglePointModeState({required bool isEnabled, bool? isRunning}) {
    final nextRunning = isEnabled ? (isRunning ?? _isRunning) : false;
    if (_isSinglePointModeEnabled == isEnabled && _isRunning == nextRunning) {
      return;
    }

    _isSinglePointModeEnabled = isEnabled;
    _isRunning = nextRunning;
    notifyListeners();
  }

  void toggleSinglePointMode() {
    setSinglePointModeState(isEnabled: !_isSinglePointModeEnabled);
  }
}
