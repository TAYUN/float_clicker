import 'package:flutter/foundation.dart';

import 'clicker_settings.dart';

class ClickerController extends ChangeNotifier {
  ClickerSettings _settings = ClickerSettings.defaults;

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

    _isRunning = !_isRunning;
    notifyListeners();
  }

  void toggleSinglePointMode() {
    _isSinglePointModeEnabled = !_isSinglePointModeEnabled;
    if (!_isSinglePointModeEnabled) {
      _isRunning = false;
    }
    notifyListeners();
  }
}
