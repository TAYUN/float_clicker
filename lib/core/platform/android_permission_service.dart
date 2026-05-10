import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/global_overlay_appearance_settings.dart';
import '../../features/clicker/clicker_settings.dart';
import '../../features/multi_point/multi_point_settings.dart';

typedef SinglePointOverlayStateChanged =
    FutureOr<void> Function(SinglePointOverlaySnapshot snapshot);
typedef MultiPointOverlayStateChanged =
    FutureOr<void> Function(MultiPointOverlaySnapshot snapshot);
typedef MultiPointTargetPositionChanged =
    FutureOr<void> Function(MultiPointTargetPositionChange change);
typedef LoadedProfileButtonPositionChanged =
    FutureOr<void> Function(LoadedProfileButtonPositionChange change);
typedef MultiProfileExecutionPanelStateChanged =
    FutureOr<void> Function(MultiProfileExecutionPanelStateChange change);
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

class AndroidNativeRefreshResult<T> {
  const AndroidNativeRefreshResult({
    required this.permissionSnapshot,
    required this.overlaySnapshot,
  });

  final AndroidPermissionSnapshot permissionSnapshot;
  final T overlaySnapshot;
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

class MultiPointOverlaySnapshot {
  const MultiPointOverlaySnapshot({
    required this.modeEnabled,
    required this.taskRunState,
    required this.targets,
    this.overlayUiSettings,
    this.completedRounds = 0,
    this.currentRound = 0,
    this.executedActionCountInCurrentRound = 0,
    this.currentTargetId,
    this.errorCode,
  });

  final bool modeEnabled;
  final TaskRunState taskRunState;
  final MultiPointTargets targets;
  final MultiPointOverlayUiSettings? overlayUiSettings;
  final int completedRounds;
  final int currentRound;
  final int executedActionCountInCurrentRound;
  final String? currentTargetId;
  final String? errorCode;

  factory MultiPointOverlaySnapshot.fromMap(Map<Object?, Object?> map) {
    return MultiPointOverlaySnapshot(
      modeEnabled: map['modeEnabled'] == true,
      taskRunState: TaskRunState.fromName(map['taskRunState'] as String?),
      targets: _multiPointTargetsFromMap(map),
      overlayUiSettings: _multiPointOverlayUiSettingsFromMap(map),
      completedRounds: (map['completedRounds'] as num?)?.toInt() ?? 0,
      currentRound: (map['currentRound'] as num?)?.toInt() ?? 0,
      executedActionCountInCurrentRound:
          (map['executedActionCountInCurrentRound'] as num?)?.toInt() ?? 0,
      currentTargetId: map['currentTargetId'] as String?,
      errorCode: map['errorCode'] as String?,
    );
  }

  static final disabled = MultiPointOverlaySnapshot(
    modeEnabled: false,
    taskRunState: TaskRunState.idle,
    targets: MultiPointTargets.defaults(),
  );
}

class MultiPointTargetPositionChange {
  const MultiPointTargetPositionChange({
    required this.id,
    required this.x,
    required this.y,
  });

  final String id;
  final double x;
  final double y;

  factory MultiPointTargetPositionChange.fromMap(Map<Object?, Object?> map) {
    return MultiPointTargetPositionChange(
      id: (map['id'] as String?)?.trim() ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LoadedProfileButtonPositionChange {
  const LoadedProfileButtonPositionChange({
    required this.profileId,
    required this.x,
    required this.y,
  });

  final String profileId;
  final int x;
  final int y;

  factory LoadedProfileButtonPositionChange.fromMap(Map<Object?, Object?> map) {
    return LoadedProfileButtonPositionChange(
      profileId: (map['profileId'] as String?)?.trim() ?? '',
      x: (map['x'] as num?)?.toInt() ?? 0,
      y: (map['y'] as num?)?.toInt() ?? 0,
    );
  }
}

class MultiProfileExecutionPanelStateChange {
  const MultiProfileExecutionPanelStateChange({required this.isPanelCollapsed});

  final bool isPanelCollapsed;

  factory MultiProfileExecutionPanelStateChange.fromMap(
    Map<Object?, Object?> map,
  ) {
    return MultiProfileExecutionPanelStateChange(
      isPanelCollapsed: map['isPanelCollapsed'] == true,
    );
  }
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

MultiPointOverlayUiSettings? _multiPointOverlayUiSettingsFromMap(
  Map<Object?, Object?> map,
) {
  if (map['interactionMode'] is! String) {
    return null;
  }

  final defaults = MultiPointOverlayUiSettings.defaults;
  return MultiPointOverlayUiSettings(
    interactionMode: OverlayInteractionMode.fromName(
      map['interactionMode'] as String?,
    ),
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

MultiPointTargets _multiPointTargetsFromMap(Map<Object?, Object?> map) {
  final targets = map['targets'];
  if (targets is! List<Object?>) {
    return MultiPointTargets.defaults();
  }

  // 原生快照和本地持久化使用同一组点位字段，统一走模型解析以复用坏数据兜底。
  return MultiPointTargets.fromJsonList(targets);
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

  static const List<Duration> _accessibilityReconnectRetrySchedule = [
    Duration.zero,
    Duration(milliseconds: 300),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

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

  Future<void> sendAppToBackground() async {
    // 主页系统返回只表示用户想离开 App；悬浮窗是否关闭必须由“关闭模式”入口决定。
    await _invokeAndroidOnly('sendAppToBackground', ignoreMissingPlugin: true);
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

  Future<void> showMultiPointOverlay({
    required MultiPointConfiguration configuration,
    GlobalOverlayAppearanceSettings appearanceSettings =
        GlobalOverlayAppearanceSettings.defaults,
  }) async {
    await _invokeAndroidOnly(
      'showMultiPointOverlay',
      arguments: {
        ..._multiPointSettingsArguments(configuration.settings),
        ..._multiPointOverlayUiSettingsArguments(
          configuration.overlayUiSettings,
        ),
        ..._multiPointTargetsArguments(configuration.targets),
        ..._globalOverlayAppearanceArguments(appearanceSettings),
      },
    );
  }

  Future<void> hideMultiPointOverlay() async {
    await _invokeAndroidOnly('hideMultiPointOverlay');
  }

  Future<void> showMultiProfileExecutionOverlay({
    required MultiPointProfileState profileState,
    GlobalOverlayAppearanceSettings appearanceSettings =
        GlobalOverlayAppearanceSettings.defaults,
    bool isPanelCollapsed = false,
  }) async {
    await _invokeAndroidOnly(
      'showMultiProfileExecutionOverlay',
      arguments: {
        ..._loadedProfileArguments(profileState),
        ..._multiProfileExecutionUiArguments(
          isPanelCollapsed: isPanelCollapsed,
        ),
        ..._globalOverlayAppearanceArguments(appearanceSettings),
      },
    );
  }

  Future<void> updateMultiProfileExecutionOverlay({
    required MultiPointProfileState profileState,
    GlobalOverlayAppearanceSettings appearanceSettings =
        GlobalOverlayAppearanceSettings.defaults,
    bool isPanelCollapsed = false,
  }) async {
    await _invokeAndroidOnly(
      'updateMultiProfileExecutionOverlay',
      arguments: {
        ..._loadedProfileArguments(profileState),
        ..._multiProfileExecutionUiArguments(
          isPanelCollapsed: isPanelCollapsed,
        ),
        ..._globalOverlayAppearanceArguments(appearanceSettings),
      },
      ignoreMissingPlugin: true,
    );
  }

  Future<void> hideMultiProfileExecutionOverlay() async {
    await _invokeAndroidOnly(
      'hideMultiProfileExecutionOverlay',
      ignoreMissingPlugin: true,
    );
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

  Future<MultiPointOverlaySnapshot> getMultiPointOverlaySnapshot() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return MultiPointOverlaySnapshot.disabled;
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getMultiPointOverlaySnapshot',
      );
      return MultiPointOverlaySnapshot.fromMap(result ?? const {});
    } on MissingPluginException {
      return MultiPointOverlaySnapshot.disabled;
    }
  }

  Future<AndroidNativeRefreshResult<SinglePointOverlaySnapshot>>
  refreshSinglePointStateWithAccessibilityRetry() {
    return _refreshNativeStateWithAccessibilityRetry(
      getOverlaySnapshot: getSinglePointOverlaySnapshot,
    );
  }

  Future<AndroidNativeRefreshResult<MultiPointOverlaySnapshot>>
  refreshMultiPointStateWithAccessibilityRetry() {
    return _refreshNativeStateWithAccessibilityRetry(
      getOverlaySnapshot: getMultiPointOverlaySnapshot,
    );
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

  Future<void> updateMultiPointTargets(MultiPointTargets targets) async {
    await _invokeAndroidOnly(
      'updateMultiPointTargets',
      arguments: _multiPointTargetsArguments(targets),
      ignoreMissingPlugin: true,
    );
  }

  Future<void> updateMultiPointSettings(MultiPointSettings settings) async {
    await _invokeAndroidOnly(
      'updateMultiPointSettings',
      arguments: _multiPointSettingsArguments(settings),
      ignoreMissingPlugin: true,
    );
  }

  Future<void> updateMultiPointOverlayUiSettings(
    MultiPointOverlayUiSettings settings,
  ) async {
    await _invokeAndroidOnly(
      'updateMultiPointOverlayUiSettings',
      arguments: _multiPointOverlayUiSettingsArguments(settings),
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

  Future<void> startMultiPointClicking() async {
    await _invokeAndroidOnly('startMultiPointClicking');
  }

  Future<void> pauseMultiPointClicking() async {
    await _invokeAndroidOnly('pauseMultiPointClicking');
  }

  Future<void> resumeMultiPointClicking() async {
    await _invokeAndroidOnly('resumeMultiPointClicking');
  }

  Future<void> endMultiPointClicking() async {
    await _invokeAndroidOnly('endMultiPointClicking');
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

  void setMultiPointOverlayStateChanged(
    MultiPointOverlayStateChanged? onChanged,
  ) {
    if (onChanged == null) {
      _multiPointOverlayListeners.remove(_listenerKey);
    } else {
      _multiPointOverlayListeners[_listenerKey] = onChanged;
    }
  }

  void setMultiPointTargetPositionChanged(
    MultiPointTargetPositionChanged? onChanged,
  ) {
    if (onChanged == null) {
      _multiPointTargetPositionListeners.remove(_listenerKey);
    } else {
      _multiPointTargetPositionListeners[_listenerKey] = onChanged;
    }
  }

  void setLoadedProfileButtonPositionChanged(
    LoadedProfileButtonPositionChanged? onChanged,
  ) {
    if (onChanged == null) {
      _loadedProfileButtonPositionListeners.remove(_listenerKey);
    } else {
      _loadedProfileButtonPositionListeners[_listenerKey] = onChanged;
    }
  }

  void setMultiProfileExecutionPanelStateChanged(
    MultiProfileExecutionPanelStateChanged? onChanged,
  ) {
    if (onChanged == null) {
      _multiProfileExecutionPanelStateListeners.remove(_listenerKey);
    } else {
      _multiProfileExecutionPanelStateListeners[_listenerKey] = onChanged;
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

  Map<String, Object?> _multiPointSettingsArguments(
    MultiPointSettings settings,
  ) {
    return {
      'intervalMs': settings.intervalMs,
      'repeatCount': settings.repeatCount,
      'infiniteLoop': settings.infiniteLoop,
      'tapDurationMs': settings.tapDurationMs,
    };
  }

  Map<String, Object?> _multiPointOverlayUiSettingsArguments(
    MultiPointOverlayUiSettings settings,
  ) {
    return {
      'interactionMode': settings.interactionMode.name,
      'toolbarPositionX': settings.toolbarPositionX,
      'toolbarPositionY': settings.toolbarPositionY,
      'collapsedToolbarPositionX': settings.collapsedToolbarPositionX,
      'collapsedToolbarPositionY': settings.collapsedToolbarPositionY,
      'actionButtonPositionX': settings.actionButtonPositionX,
      'actionButtonPositionY': settings.actionButtonPositionY,
      'isToolbarCollapsed': settings.isToolbarCollapsed,
    };
  }

  Map<String, Object?> _multiPointTargetsArguments(MultiPointTargets targets) {
    return {
      // 点位坐标传左上角，Android 侧负责窗口显示和后续点击中心点换算。
      'targets': targets.toJsonList(),
    };
  }

  Map<String, Object?> _loadedProfileArguments(
    MultiPointProfileState profileState,
  ) {
    final profilesById = {
      for (final profile in profileState.profiles) profile.id: profile,
    };
    return {
      // P7.2.2 开始执行控件会直接启动绑定 profile；这里传保存后的完整快照，
      // 避免原生侧回读当前编辑页状态而执行错配置。
      'loadedProfiles': [
        for (final loadedProfile in profileState.loadedProfiles)
          if (loadedProfile.isVisible &&
              profilesById.containsKey(loadedProfile.profileId) &&
              profilesById[loadedProfile.profileId]!.targets.hasEnabledTarget)
            {
              'profileId': loadedProfile.profileId,
              'displayName': profilesById[loadedProfile.profileId]!.name,
              'order': loadedProfile.order,
              'settings': profilesById[loadedProfile.profileId]!.settings
                  .toJson(),
              'targets': profilesById[loadedProfile.profileId]!.targets
                  .toJsonList(),
              if (loadedProfile.buttonPositionX != null)
                'buttonPositionX': loadedProfile.buttonPositionX,
              if (loadedProfile.buttonPositionY != null)
                'buttonPositionY': loadedProfile.buttonPositionY,
            },
      ],
    };
  }

  Map<String, Object?> _multiProfileExecutionUiArguments({
    required bool isPanelCollapsed,
  }) {
    return {
      // P7.3.1 的收起状态只属于当前预览生命周期，关闭重开预览默认展开。
      'isPanelCollapsed': isPanelCollapsed,
    };
  }

  Map<String, Object?> _globalOverlayAppearanceArguments(
    GlobalOverlayAppearanceSettings settings,
  ) {
    return {
      // overlayControlScale 保留给旧 Android 端兼容；新端优先读取下面三个分组件比例。
      'overlayControlScale': GlobalOverlayAppearanceSettings.normalizeScale(
        settings.overlayControlScale,
      ),
      'targetPointScale': GlobalOverlayAppearanceSettings.normalizeScale(
        settings.targetPointScale,
      ),
      'toolbarScale': GlobalOverlayAppearanceSettings.normalizeScale(
        settings.toolbarScale,
      ),
      'actionButtonScale': GlobalOverlayAppearanceSettings.normalizeScale(
        settings.actionButtonScale,
      ),
    };
  }

  static final Map<Object, SinglePointOverlayStateChanged>
  _singlePointOverlayListeners = {};
  static final Map<Object, MultiPointOverlayStateChanged>
  _multiPointOverlayListeners = {};
  static final Map<Object, MultiPointTargetPositionChanged>
  _multiPointTargetPositionListeners = {};
  static final Map<Object, LoadedProfileButtonPositionChanged>
  _loadedProfileButtonPositionListeners = {};
  static final Map<Object, MultiProfileExecutionPanelStateChanged>
  _multiProfileExecutionPanelStateListeners = {};
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

      if (call.method == 'multiPointOverlayStateChanged') {
        final snapshot = MultiPointOverlaySnapshot.fromMap(arguments);
        for (final listener in List<MultiPointOverlayStateChanged>.of(
          _multiPointOverlayListeners.values,
        )) {
          await listener(snapshot);
        }
        return;
      }

      if (call.method == 'onMultiPointTargetPositionChanged') {
        final change = MultiPointTargetPositionChange.fromMap(arguments);
        // 空 id 说明原生侧传参异常，直接丢弃，避免误改第一条点位。
        if (change.id.isEmpty) {
          return;
        }
        for (final listener in List<MultiPointTargetPositionChanged>.of(
          _multiPointTargetPositionListeners.values,
        )) {
          await listener(change);
        }
        return;
      }

      if (call.method == 'onLoadedProfileButtonPositionChanged') {
        final change = LoadedProfileButtonPositionChange.fromMap(arguments);
        // profileId 是按钮位置的唯一归属，缺失时不能猜测到当前 active profile。
        if (change.profileId.isEmpty) {
          return;
        }
        for (final listener in List<LoadedProfileButtonPositionChanged>.of(
          _loadedProfileButtonPositionListeners.values,
        )) {
          await listener(change);
        }
        return;
      }

      if (call.method == 'onMultiProfileExecutionPanelStateChanged') {
        final change = MultiProfileExecutionPanelStateChange.fromMap(arguments);
        for (final listener in List<MultiProfileExecutionPanelStateChanged>.of(
          _multiProfileExecutionPanelStateListeners.values,
        )) {
          await listener(change);
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

  Future<AndroidNativeRefreshResult<T>>
  _refreshNativeStateWithAccessibilityRetry<T>({
    required Future<T> Function() getOverlaySnapshot,
  }) async {
    var permissionSnapshot = AndroidPermissionSnapshot.unsupported;
    late T overlaySnapshot;

    for (final delay in _accessibilityReconnectRetrySchedule) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      permissionSnapshot = await getSnapshot();
      overlaySnapshot = await getOverlaySnapshot();
      if (!_shouldRetryAccessibilityConnection(permissionSnapshot)) {
        break;
      }
    }

    return AndroidNativeRefreshResult(
      permissionSnapshot: permissionSnapshot,
      overlaySnapshot: overlaySnapshot,
    );
  }

  bool _shouldRetryAccessibilityConnection(AndroidPermissionSnapshot snapshot) {
    return snapshot.accessibilityGranted && !snapshot.accessibilityConnected;
  }
}
