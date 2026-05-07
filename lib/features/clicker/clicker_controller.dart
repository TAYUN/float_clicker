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
  bool get isSinglePointModeEnabled => _isSinglePointModeEnabled;

  void updateSinglePointSettings(SinglePointSettings settings) {
    _settings = settings.clickerSettings;
    _overlayUiSettings = settings.overlayUiSettings;
    notifyListeners();
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
