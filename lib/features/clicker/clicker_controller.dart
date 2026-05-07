import 'package:flutter/foundation.dart';

import 'clicker_settings.dart';

class ClickerController extends ChangeNotifier {
  ClickerSettings _settings = ClickerSettings.defaults;
  OverlayUiSettings _overlayUiSettings = OverlayUiSettings.defaults;

  // 这些状态只表示 Flutter 页面当前认为的状态。
  // 真正的悬浮窗和点击任务在 Android 原生侧维护，页面操作成功后才同步切换这里。
  TaskRunState _taskRunState = TaskRunState.idle;
  bool _isSinglePointModeEnabled = false;

  ClickerSettings get settings => _settings;
  OverlayUiSettings get overlayUiSettings => _overlayUiSettings;
  TaskRunState get taskRunState => _taskRunState;
  bool get isRunning => _taskRunState == TaskRunState.running;
  bool get isPaused => _taskRunState == TaskRunState.paused;
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

  void updateOverlayUiSettings(OverlayUiSettings settings) {
    _overlayUiSettings = settings;
    notifyListeners();
  }

  void updateSinglePointSettings(SinglePointSettings settings) {
    _settings = settings.clickerSettings;
    _overlayUiSettings = settings.overlayUiSettings;
    notifyListeners();
  }

  void toggleRunning() {
    if (!_isSinglePointModeEnabled) {
      return;
    }

    // 点击任务必须依附于单点模式悬浮窗；未开启模式时不允许进入运行态。
    setTaskRunState(isRunning ? TaskRunState.idle : TaskRunState.running);
  }

  void setRunning(bool value) {
    setTaskRunState(value ? TaskRunState.running : TaskRunState.idle);
  }

  void setTaskRunState(TaskRunState value) {
    if (!_isSinglePointModeEnabled && value != TaskRunState.idle) {
      return;
    }

    if (_taskRunState == value) {
      return;
    }

    _taskRunState = value;
    notifyListeners();
  }

  void setSinglePointModeState({
    required bool isEnabled,
    bool? isRunning,
    TaskRunState? taskRunState,
  }) {
    final nextTaskRunState = isEnabled
        ? (taskRunState ??
              (isRunning == null
                  ? _taskRunState
                  : (isRunning ? TaskRunState.running : TaskRunState.idle)))
        : TaskRunState.idle;
    if (_isSinglePointModeEnabled == isEnabled &&
        _taskRunState == nextTaskRunState) {
      return;
    }

    _isSinglePointModeEnabled = isEnabled;
    _taskRunState = nextTaskRunState;
    notifyListeners();
  }

  void toggleSinglePointMode() {
    setSinglePointModeState(isEnabled: !_isSinglePointModeEnabled);
  }
}
