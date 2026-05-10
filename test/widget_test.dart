import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/app.dart';
import 'package:float_clicker/core/settings/global_overlay_appearance_store.dart';

void main() {
  const permissionChannel = MethodChannel('float_clicker/android_permissions');
  const methodCodec = StandardMethodCodec();
  final methodCalls = <MethodCall>[];
  var nativeOverlayEnabled = false;
  var nativeMultiPointOverlayEnabled = false;
  var nativeMultiProfileExecutionEnabled = false;
  var nativeTaskRunState = 'idle';
  var nativeMultiPointTaskRunState = 'idle';
  var nativeMultiPointCompletedRounds = 0;
  var nativeMultiPointCurrentRound = 0;
  var nativeMultiPointExecutedInRound = 0;
  String? nativeMultiPointCurrentTargetId;
  var nativeExecutedCount = 0;
  var nativeOverlaySettings = <String, Object?>{};
  var nativeMultiPointSettings = <String, Object?>{};
  var nativeAccessibilityGranted = false;
  var nativeAccessibilityConnected = false;
  var nativeOverlayGranted = true;
  PlatformException? nativeStartFailure;

  Future<void> sendSinglePointClickingState(
    String taskRunState, {
    int executedCount = 0,
  }) async {
    nativeTaskRunState = taskRunState;
    nativeExecutedCount = executedCount;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointClickingStateChanged', {
              'taskRunState': taskRunState,
              'executedCount': executedCount,
              ...nativeOverlaySettings,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendSinglePointOverlayState({
    required bool isEnabled,
    required String taskRunState,
    int executedCount = 0,
  }) async {
    nativeOverlayEnabled = isEnabled;
    nativeTaskRunState = taskRunState;
    nativeExecutedCount = executedCount;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointOverlayStateChanged', {
              'isEnabled': isEnabled,
              'taskRunState': taskRunState,
              'executedCount': executedCount,
              if (isEnabled) ...nativeOverlaySettings,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendPermissionSnapshot({
    required bool accessibilityGranted,
    required bool accessibilityConnected,
    required bool overlayGranted,
  }) async {
    nativeAccessibilityGranted = accessibilityGranted;
    nativeAccessibilityConnected = accessibilityConnected;
    nativeOverlayGranted = overlayGranted;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('permissionSnapshotChanged', {
              'accessibilityGranted': accessibilityGranted,
              'accessibilityConnected': accessibilityConnected,
              'overlayGranted': overlayGranted,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendMultiPointTargetPosition({
    required String id,
    required int x,
    required int y,
  }) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('onMultiPointTargetPositionChanged', {
              'id': id,
              'x': x,
              'y': y,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendLoadedProfileButtonPosition({
    required String profileId,
    required int x,
    required int y,
  }) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('onLoadedProfileButtonPositionChanged', {
              'profileId': profileId,
              'x': x,
              'y': y,
            }),
          ),
          (_) {},
        );
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisibleText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      await scrollDown(tester);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    methodCalls.clear();
    nativeOverlayEnabled = false;
    nativeMultiPointOverlayEnabled = false;
    nativeMultiProfileExecutionEnabled = false;
    nativeTaskRunState = 'idle';
    nativeMultiPointTaskRunState = 'idle';
    nativeMultiPointCompletedRounds = 0;
    nativeMultiPointCurrentRound = 0;
    nativeMultiPointExecutedInRound = 0;
    nativeMultiPointCurrentTargetId = null;
    nativeExecutedCount = 0;
    nativeOverlaySettings = _defaultNativeOverlaySettings();
    nativeMultiPointSettings = _defaultNativeMultiPointSettings();
    nativeAccessibilityGranted = false;
    nativeAccessibilityConnected = false;
    nativeOverlayGranted = true;
    nativeStartFailure = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getPermissionSnapshot') {
            return {
              'accessibilityGranted': nativeAccessibilityGranted,
              'accessibilityConnected': nativeAccessibilityConnected,
              'overlayGranted': nativeOverlayGranted,
            };
          }
          if (call.method == 'getSinglePointOverlaySnapshot') {
            return {
              'isEnabled': nativeOverlayEnabled,
              'taskRunState': nativeTaskRunState,
              'executedCount': nativeExecutedCount,
              if (nativeOverlayEnabled) ...nativeOverlaySettings,
            };
          }
          if (call.method == 'getMultiPointOverlaySnapshot') {
            return {
              'modeEnabled': nativeMultiPointOverlayEnabled,
              'taskRunState': nativeMultiPointTaskRunState,
              'completedRounds': nativeMultiPointCompletedRounds,
              'currentRound': nativeMultiPointCurrentRound,
              'executedActionCountInCurrentRound':
                  nativeMultiPointExecutedInRound,
              ...nativeMultiPointCurrentTargetId == null
                  ? const <String, Object?>{}
                  : {'currentTargetId': nativeMultiPointCurrentTargetId},
              ...nativeMultiPointSettings,
            };
          }
          if (call.method == 'showSinglePointOverlay') {
            nativeOverlayEnabled = true;
            nativeTaskRunState = 'idle';
            nativeExecutedCount = 0;
            nativeOverlaySettings = _objectMap(call.arguments);
            return null;
          }
          if (call.method == 'showMultiPointOverlay') {
            nativeMultiPointOverlayEnabled = true;
            nativeMultiPointTaskRunState = 'idle';
            nativeMultiPointSettings = _objectMap(call.arguments);
            return null;
          }
          if (call.method == 'showMultiProfileExecutionOverlay') {
            nativeMultiProfileExecutionEnabled = true;
            return null;
          }
          if (call.method == 'updateMultiProfileExecutionOverlay') {
            return null;
          }
          if (call.method == 'hideMultiProfileExecutionOverlay') {
            nativeMultiProfileExecutionEnabled = false;
            return null;
          }
          if (call.method == 'hideMultiPointOverlay') {
            nativeMultiPointOverlayEnabled = false;
            nativeMultiPointTaskRunState = 'idle';
            return null;
          }
          if (call.method == 'updateMultiPointTargets') {
            nativeMultiPointSettings = {
              ...nativeMultiPointSettings,
              ..._objectMap(call.arguments),
            };
            return null;
          }
          if (call.method == 'updateMultiPointOverlayUiSettings') {
            nativeMultiPointSettings = {
              ...nativeMultiPointSettings,
              ..._objectMap(call.arguments),
            };
            return null;
          }
          if (call.method == 'updateMultiPointSettings') {
            nativeMultiPointSettings = {
              ...nativeMultiPointSettings,
              ..._objectMap(call.arguments),
            };
            return null;
          }
          if (call.method == 'startMultiPointClicking') {
            nativeMultiPointTaskRunState = 'running';
            nativeMultiPointCurrentRound = 1;
            return null;
          }
          if (call.method == 'pauseMultiPointClicking') {
            nativeMultiPointTaskRunState = 'paused';
            return null;
          }
          if (call.method == 'resumeMultiPointClicking') {
            final repeatCount =
                (nativeMultiPointSettings['repeatCount'] as num?)?.toInt() ??
                10;
            final infiniteLoop =
                nativeMultiPointSettings['infiniteLoop'] as bool? ?? false;
            final targets =
                nativeMultiPointSettings['targets'] as List<Object?>? ??
                const [];
            final hasEnabledTarget = targets.any(
              (target) =>
                  target is Map<Object?, Object?> && target['enabled'] == true,
            );
            if (!hasEnabledTarget) {
              throw PlatformException(
                code: 'no_enabled_targets',
                message: '请至少启用 1 个点位后再继续。',
              );
            }
            if (!infiniteLoop &&
                nativeMultiPointCompletedRounds >= repeatCount) {
              nativeMultiPointTaskRunState = 'idle';
              nativeMultiPointCurrentRound = 0;
              nativeMultiPointExecutedInRound = 0;
              nativeMultiPointCurrentTargetId = null;
              return null;
            }
            nativeMultiPointTaskRunState = 'running';
            return null;
          }
          if (call.method == 'endMultiPointClicking') {
            nativeMultiPointTaskRunState = 'idle';
            nativeMultiPointCompletedRounds = 0;
            nativeMultiPointCurrentRound = 0;
            nativeMultiPointExecutedInRound = 0;
            nativeMultiPointCurrentTargetId = null;
            return null;
          }
          if (call.method == 'hideSinglePointOverlay') {
            nativeOverlayEnabled = false;
            nativeTaskRunState = 'idle';
            nativeExecutedCount = 0;
            return null;
          }
          if (call.method == 'startSinglePointClicking') {
            final failure = nativeStartFailure;
            if (failure != null) {
              throw failure;
            }
            nativeTaskRunState = 'running';
            return null;
          }
          if (call.method == 'pauseSinglePointClicking') {
            nativeTaskRunState = 'paused';
            return null;
          }
          if (call.method == 'resumeSinglePointClicking') {
            nativeTaskRunState = 'running';
            return null;
          }
          if (call.method == 'endSinglePointClicking') {
            nativeTaskRunState = 'idle';
            nativeExecutedCount = 0;
            return null;
          }
          if (call.method == 'stopSinglePointClicking') {
            nativeTaskRunState = 'idle';
            nativeExecutedCount = 0;
            return null;
          }
          if (call.method == 'updateSinglePointOverlayUiSettings') {
            nativeOverlaySettings = _objectMap(call.arguments);
            return null;
          }
          if (call.method == 'updateGlobalOverlayAppearanceSettings') {
            return null;
          }
          if (call.method == 'sendAppToBackground') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('Home navigates to single point mode and guide', (tester) async {
    await tester.pumpWidget(const FloatClickerApp());

    expect(find.text('Float Clicker'), findsOneWidget);
    expect(find.text('权限状态'), findsOneWidget);
    expect(find.text('单点模式'), findsOneWidget);

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('未启动'), findsOneWidget);
    expect(find.text('开启单点模式'), findsOneWidget);

    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('执行任务'), findsOneWidget);

    await tester.tap(find.text('介绍向导'));
    await tester.pumpAndSettle();

    expect(find.text('1. 开启单点模式'), findsOneWidget);
    await scrollDown(tester);
    expect(find.text('6. 需要完全退出时，关闭单点模式并移除悬浮组件'), findsOneWidget);
  });

  testWidgets('Single point settings are saved back to mode page', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('间隔 500 ms，次数 10，普通模式'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '800');
    await tester.enterText(find.byType(EditableText).at(1), '80');
    await tester.enterText(find.byType(EditableText).at(2), '3');
    await tapVisibleText(tester, '保存');

    expect(find.text('间隔 800 ms，次数 3，普通模式'), findsOneWidget);
  });

  testWidgets('Single point settings persist after leaving mode page', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '900');
    await tester.enterText(find.byType(EditableText).at(1), '90');
    await tester.enterText(find.byType(EditableText).at(2), '4');
    await tapVisibleText(tester, '保存');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('间隔 900 ms，次数 4，普通模式'), findsOneWidget);
  });

  testWidgets('Home navigates to multi point mode with default targets', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');

    expect(find.text('多点模式'), findsOneWidget);
    expect(find.text('点位列表'), findsOneWidget);
    expect(find.text('点位 1'), findsOneWidget);
    expect(find.text('点位 2'), findsOneWidget);
    expect(find.text('开启多点悬浮层'), findsOneWidget);
    expect(find.text('间隔 500 ms，循环 10 轮，普通模式'), findsOneWidget);
    expect(find.text('默认配置'), findsOneWidget);
  });

  testWidgets('Multi point profile manager creates and selects profile', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    expect(find.text('多点配置'), findsOneWidget);
    await tester.tap(find.text('新建配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('新配置'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '720');
    await tapVisibleText(tester, '保存');

    expect(find.text('间隔 720 ms，循环 10 轮，普通模式'), findsOneWidget);
  });

  testWidgets('Multi point profile manager renames profile from menu', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('配置操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), '刷副本');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('刷副本'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('刷副本'), findsOneWidget);
  });

  testWidgets('Multi point profile manager loads and unloads profile', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· 已加载', findRichText: true), findsOneWidget);

    await tester.tap(find.text('新建配置'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· 未加载', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('配置操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载到执行区'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· 已加载', findRichText: true), findsNWidgets(2));

    await tester.tap(find.byTooltip('配置操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('从执行区卸载'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· 未加载', findRichText: true), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('新配置'), findsOneWidget);
  });

  testWidgets('Multi point execution preview sends loaded profiles', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配置操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载到执行区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '开启执行控件预览');

    final showCall = methodCalls.lastWhere(
      (call) => call.method == 'showMultiProfileExecutionOverlay',
    );
    final arguments = showCall.arguments as Map<Object?, Object?>;
    final loadedProfiles = arguments['loadedProfiles'] as List<Object?>;
    expect(loadedProfiles, hasLength(2));
    expect(
      loadedProfiles.cast<Map<Object?, Object?>>().map(
        (profile) => profile['displayName'],
      ),
      ['默认配置', '新配置'],
    );
    final firstProfile = loadedProfiles.first as Map<Object?, Object?>;
    expect(firstProfile['settings'], {
      'intervalMs': 500,
      'repeatCount': 10,
      'infiniteLoop': false,
      'tapDurationMs': 50,
    });
    final targets = firstProfile['targets'] as List<Object?>;
    expect(targets, hasLength(2));
    expect((targets.first as Map<Object?, Object?>)['enabled'], isTrue);
    expect(nativeMultiProfileExecutionEnabled, isTrue);

    await tapVisibleText(tester, '关闭执行控件预览');

    expect(
      methodCalls.where(
        (call) => call.method == 'hideMultiProfileExecutionOverlay',
      ),
      isNotEmpty,
    );
    expect(nativeMultiProfileExecutionEnabled, isFalse);
  });

  testWidgets('Multi point execution preview toggles a single control', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配置操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载到执行区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '开启执行控件预览');
    methodCalls.clear();

    await tapVisibleText(tester, '新配置 控件');

    final updateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateMultiProfileExecutionOverlay',
    );
    final arguments = updateCall.arguments as Map<Object?, Object?>;
    final loadedProfiles = arguments['loadedProfiles'] as List<Object?>;
    expect(loadedProfiles, hasLength(1));
    expect(
      (loadedProfiles.single as Map<Object?, Object?>)['displayName'],
      '默认配置',
    );
    expect(find.text('隐藏该配置控件'), findsOneWidget);
    expect(find.text('显示该配置控件'), findsOneWidget);
  });

  testWidgets('Multi point execution preview persists button position', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tapVisibleText(tester, '开启执行控件预览');

    await sendLoadedProfileButtonPosition(profileId: 'default', x: 144, y: 288);
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '关闭执行控件预览');
    methodCalls.clear();
    await tapVisibleText(tester, '开启执行控件预览');

    final showCall = methodCalls.lastWhere(
      (call) => call.method == 'showMultiProfileExecutionOverlay',
    );
    final arguments = showCall.arguments as Map<Object?, Object?>;
    final loadedProfiles = arguments['loadedProfiles'] as List<Object?>;
    final profile = loadedProfiles.single as Map<Object?, Object?>;

    expect(profile['buttonPositionX'], 144);
    expect(profile['buttonPositionY'], 288);
  });

  testWidgets(
    'Multi point execution preview keeps position after control hide and show',
    (tester) async {
      await tester.pumpWidget(const FloatClickerApp());

      await tapVisibleText(tester, '多点模式');
      await tester.tap(find.text('默认配置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('配置操作').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('加载到执行区'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tapVisibleText(tester, '开启执行控件预览');
      final showCall = methodCalls.lastWhere(
        (call) => call.method == 'showMultiProfileExecutionOverlay',
      );
      final showArguments = showCall.arguments as Map<Object?, Object?>;
      final shownProfiles = showArguments['loadedProfiles'] as List<Object?>;
      final newProfile = shownProfiles.cast<Map<Object?, Object?>>().firstWhere(
        (profile) => profile['displayName'] == '新配置',
      );
      final newProfileId = newProfile['profileId'] as String;

      await sendLoadedProfileButtonPosition(
        profileId: newProfileId,
        x: 222,
        y: 333,
      );
      await tester.pumpAndSettle();
      methodCalls.clear();

      await tapVisibleText(tester, '新配置 控件');
      var updateCall = methodCalls.lastWhere(
        (call) => call.method == 'updateMultiProfileExecutionOverlay',
      );
      var updateArguments = updateCall.arguments as Map<Object?, Object?>;
      var loadedProfiles = updateArguments['loadedProfiles'] as List<Object?>;
      expect(loadedProfiles, hasLength(1));

      methodCalls.clear();
      await tapVisibleText(tester, '新配置 控件');

      updateCall = methodCalls.lastWhere(
        (call) => call.method == 'updateMultiProfileExecutionOverlay',
      );
      updateArguments = updateCall.arguments as Map<Object?, Object?>;
      loadedProfiles = updateArguments['loadedProfiles'] as List<Object?>;
      final restoredProfile = loadedProfiles
          .cast<Map<Object?, Object?>>()
          .firstWhere((profile) => profile['profileId'] == newProfileId);

      expect(restoredProfile['buttonPositionX'], 222);
      expect(restoredProfile['buttonPositionY'], 333);
    },
  );

  testWidgets('Multi point target edits persist after leaving page', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');

    await tester.tap(find.byTooltip('新增点位'));
    await tester.pumpAndSettle();

    expect(find.text('点位 3'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除点位').first);
    await tester.pumpAndSettle();

    expect(find.text('点位 3'), findsNothing);
    expect(find.textContaining('禁用'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '多点模式');

    expect(find.text('点位 1'), findsOneWidget);
    expect(find.text('点位 2'), findsOneWidget);
    expect(find.textContaining('禁用'), findsOneWidget);
  });

  testWidgets('Multi point settings are saved back to mode page', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '650');
    await tester.enterText(find.byType(EditableText).at(1), '75');
    await tester.enterText(find.byType(EditableText).at(2), '4');
    await tapVisibleText(tester, '极简模式');
    await tapVisibleText(tester, '保存');

    expect(find.text('间隔 650 ms，循环 4 轮，极简模式'), findsOneWidget);
  });

  testWidgets('Multi point task rejects execution without enabled targets', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');

    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '开启多点悬浮层');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '执行任务');

    expect(find.text('请至少启用 1 个点位后再执行。'), findsOneWidget);
  });

  testWidgets('Multi point page exposes pause resume and end actions', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tapVisibleText(tester, '开启多点悬浮层');
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '执行任务');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('正在点击'), findsOneWidget);

    await tapVisibleText(tester, '暂停任务');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('已暂停'), findsOneWidget);

    nativeMultiPointSettings = {...nativeMultiPointSettings, 'repeatCount': 1};
    nativeMultiPointCompletedRounds = 1;
    nativeMultiPointCurrentRound = 2;
    nativeMultiPointExecutedInRound = 0;

    await tapVisibleText(tester, '继续任务');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('多点编辑中'), findsOneWidget);
  });

  testWidgets('Multi point profile manager is blocked while running', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tapVisibleText(tester, '开启多点悬浮层');
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '执行任务');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认配置'));
    await tester.pumpAndSettle();

    expect(find.text('任务运行中不能管理配置，请先暂停或结束任务。'), findsOneWidget);
    expect(find.text('多点配置'), findsNothing);
  });

  testWidgets('Multi point target position callback is persisted', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tapVisibleText(tester, '多点模式');
    await tapVisibleText(tester, '开启多点悬浮层');
    await tester.pumpAndSettle();

    await sendMultiPointTargetPosition(id: 'p2', x: 345, y: 456);
    await tester.pumpAndSettle();

    expect(find.textContaining('坐标 (345, 456)'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final savedTargets =
        jsonDecode(preferences.getString('multi_point.targets_json')!)
            as List<Object?>;
    final p2 = savedTargets.cast<Map<String, Object?>>().firstWhere(
      (target) => target['id'] == 'p2',
    );

    expect(p2['x'], 345.0);
    expect(p2['y'], 456.0);
  });

  testWidgets('Overlay interaction mode persists after saving settings', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tapVisibleText(tester, '极简模式');
    await tapVisibleText(tester, '保存');

    expect(find.text('间隔 500 ms，次数 10，极简模式'), findsOneWidget);
  });

  testWidgets('Global settings persists component overlay scales', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('全局设置'));
    await tester.pumpAndSettle();

    expect(find.text('悬浮外观'), findsOneWidget);
    expect(find.text('悬浮点位大小'), findsOneWidget);
    expect(find.text('控制条大小'), findsOneWidget);
    expect(find.text('独立控件大小'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(3));

    await tester.drag(find.byType(Slider).at(0), const Offset(160, 0));
    await tester.drag(find.byType(Slider).at(1), const Offset(-80, 0));
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '保存');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.targetPointScaleKey),
      greaterThan(1.0),
    );
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.toolbarScaleKey),
      isNot(1.0),
    );
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.actionButtonScaleKey),
      1.0,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('全局设置'));
    await tester.pumpAndSettle();

    final savedTargetScale = preferences.getDouble(
      GlobalOverlayAppearanceStore.targetPointScaleKey,
    )!;
    expect(find.text('${(savedTargetScale * 100).round()}%'), findsOneWidget);
  });

  testWidgets('Legacy global overlay scale migrates to component scales', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GlobalOverlayAppearanceStore.overlayControlScaleKey: 1.3,
    });

    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('全局设置'));
    await tester.pumpAndSettle();

    expect(find.text('130%'), findsNWidgets(3));

    await tapVisibleText(tester, '恢复默认');
    expect(find.text('100%'), findsNWidgets(3));
    await tapVisibleText(tester, '保存');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.targetPointScaleKey),
      1.0,
    );
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.toolbarScaleKey),
      1.0,
    );
    expect(
      preferences.getDouble(GlobalOverlayAppearanceStore.actionButtonScaleKey),
      1.0,
    );
  });

  testWidgets('Saving settings syncs native overlay when mode is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '700');
    await tester.enterText(find.byType(EditableText).at(1), '70');
    await tester.enterText(find.byType(EditableText).at(2), '2');
    await tapVisibleText(tester, '保存');

    final updateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateSinglePointSettings',
    );
    expect(updateCall.arguments, {
      'intervalMs': 700,
      'repeatCount': 2,
      'infiniteLoop': false,
      'tapDurationMs': 70,
    });

    final overlayUpdateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateSinglePointOverlayUiSettings',
    );
    expect(
      (overlayUpdateCall.arguments as Map<Object?, Object?>)['interactionMode'],
      'normal',
    );

    expect(
      methodCalls.where(
        (call) => call.method == 'updateGlobalOverlayAppearanceSettings',
      ),
      isEmpty,
    );
  });

  testWidgets('Opening single point overlay sends global control scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GlobalOverlayAppearanceStore.targetPointScaleKey: 1.1,
      GlobalOverlayAppearanceStore.toolbarScaleKey: 1.2,
      GlobalOverlayAppearanceStore.actionButtonScaleKey: 1.3,
    });

    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    final showCall = methodCalls.lastWhere(
      (call) => call.method == 'showSinglePointOverlay',
    );
    final arguments = showCall.arguments as Map<Object?, Object?>;
    expect(arguments['overlayControlScale'], closeTo(1.2, 0.001));
    expect(arguments['targetPointScale'], closeTo(1.1, 0.001));
    expect(arguments['toolbarScale'], closeTo(1.2, 0.001));
    expect(arguments['actionButtonScale'], closeTo(1.3, 0.001));
  });

  testWidgets('Saving global settings syncs native overlay appearance', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('全局设置'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider).at(2), const Offset(160, 0));
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '保存');

    final appearanceUpdateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateGlobalOverlayAppearanceSettings',
    );
    final arguments = appearanceUpdateCall.arguments as Map<Object?, Object?>;
    expect(arguments['overlayControlScale'], greaterThan(1.0));
    expect(arguments['targetPointScale'], 1.0);
    expect(arguments['toolbarScale'], 1.0);
    expect(arguments['actionButtonScale'], greaterThan(1.0));
  });

  testWidgets('Native finished event resets single point running UI', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    expect(find.text('正在点击'), findsOneWidget);
    expect(find.text('暂停任务'), findsOneWidget);

    await sendSinglePointClickingState('idle');
    await tester.pump();

    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('执行任务'), findsOneWidget);
  });

  testWidgets('Single point page exposes pause resume and end actions', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('暂停任务'));
    await tester.pumpAndSettle();

    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('继续任务'), findsOneWidget);
    expect(find.text('结束任务'), findsOneWidget);

    await tester.tap(find.text('继续任务'));
    await tester.pumpAndSettle();

    expect(find.text('正在点击'), findsOneWidget);

    await tester.tap(find.text('结束任务'));
    await tester.pumpAndSettle();

    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('执行任务'), findsOneWidget);
  });

  testWidgets('Native pause protocol switches UI to paused state', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('暂停任务'));
    await tester.pumpAndSettle();

    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('继续任务'), findsOneWidget);
    expect(find.text('Android 尚未实现 pauseSinglePointClicking。'), findsNothing);
  });

  testWidgets('Single point page explains accessibility start failure', (
    tester,
  ) async {
    nativeStartFailure = PlatformException(
      code: 'accessibility_service_unavailable',
      message: 'Accessibility service is not running.',
    );

    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    expect(
      find.text('无障碍服务未连接，请先在系统设置中开启 Float Clicker 无障碍服务。'),
      findsOneWidget,
    );
    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('执行任务'), findsOneWidget);
  });

  testWidgets('Single point page displays native executed count', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    await sendSinglePointClickingState('running', executedCount: 3);
    await tester.pump();

    expect(find.text('已执行 3 / 10 次'), findsOneWidget);

    await tester.tap(find.text('暂停任务'));
    await tester.pumpAndSettle();

    expect(find.text('已执行 3 / 10 次'), findsOneWidget);
  });

  testWidgets('Home displays native running progress snapshot', (tester) async {
    nativeOverlayEnabled = true;
    nativeTaskRunState = 'running';
    nativeExecutedCount = 4;

    await tester.pumpWidget(const FloatClickerApp());
    await tester.pumpAndSettle();

    expect(find.text('单点任务执行中'), findsOneWidget);
    expect(find.text('已执行 4 次'), findsOneWidget);
  });

  testWidgets(
    'Home system back sends app to background without hiding overlay',
    (tester) async {
      nativeOverlayEnabled = true;

      await tester.pumpWidget(const FloatClickerApp());
      await tester.pumpAndSettle();

      methodCalls.clear();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        methodCalls.where((call) => call.method == 'sendAppToBackground'),
        hasLength(1),
      );
      expect(
        methodCalls.where((call) => call.method == 'hideSinglePointOverlay'),
        isEmpty,
      );
    },
  );

  testWidgets('Home and mode page both receive native overlay events', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    await sendSinglePointOverlayState(
      isEnabled: true,
      taskRunState: 'running',
      executedCount: 5,
    );
    await tester.pump();

    expect(find.text('正在点击'), findsOneWidget);
    expect(find.text('已执行 5 / 10 次'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('单点任务执行中'), findsOneWidget);
    expect(find.text('已执行 5 次'), findsOneWidget);
  });

  testWidgets('Home distinguishes accessibility grant and service connection', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());
    await tester.pumpAndSettle();

    await sendPermissionSnapshot(
      accessibilityGranted: true,
      accessibilityConnected: false,
      overlayGranted: true,
    );
    await tester.pump();

    expect(find.text('服务未连接'), findsOneWidget);
    expect(find.text('已开启'), findsOneWidget);
  });

  testWidgets('Home refresh retries accessibility connection after resume', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());
    await tester.pumpAndSettle();
    nativeAccessibilityGranted = true;
    nativeAccessibilityConnected = false;

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      nativeAccessibilityConnected = true;
    });

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('已连接'), findsOneWidget);
  });

  testWidgets('Single point page exits when overlay permission is revoked', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    await sendPermissionSnapshot(
      accessibilityGranted: false,
      accessibilityConnected: false,
      overlayGranted: false,
    );
    await tester.pump();

    expect(find.text('悬浮窗权限已关闭，单点模式已退出。'), findsOneWidget);
    expect(find.text('未启动'), findsOneWidget);
    expect(find.text('开启单点模式'), findsOneWidget);
  });

  testWidgets('Single point page ends task when accessibility disconnects', (
    tester,
  ) async {
    nativeAccessibilityGranted = true;
    nativeAccessibilityConnected = true;

    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    await sendPermissionSnapshot(
      accessibilityGranted: true,
      accessibilityConnected: false,
      overlayGranted: true,
    );
    await tester.pump();

    expect(find.text('无障碍服务已断开，点击任务已结束。'), findsOneWidget);
    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('执行任务'), findsOneWidget);
  });

  testWidgets(
    'Single point page keeps native running state while accessibility reconnects',
    (tester) async {
      nativeAccessibilityGranted = true;
      nativeAccessibilityConnected = false;
      nativeOverlayEnabled = true;
      nativeTaskRunState = 'running';
      nativeExecutedCount = 5;

      Future<void>.delayed(const Duration(milliseconds: 300), () {
        nativeAccessibilityConnected = true;
      });

      await tester.pumpWidget(const FloatClickerApp());
      await tester.tap(find.text('单点模式'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('正在点击'), findsOneWidget);
      expect(find.text('已执行 5 / 10 次'), findsOneWidget);
      expect(find.text('执行任务'), findsNothing);
    },
  );

  testWidgets('Multi point page refreshes native snapshot after resume', (
    tester,
  ) async {
    nativeAccessibilityGranted = true;
    nativeAccessibilityConnected = true;
    nativeMultiPointOverlayEnabled = true;
    nativeMultiPointTaskRunState = 'running';

    await tester.pumpWidget(const FloatClickerApp());
    await tapVisibleText(tester, '多点模式');
    await tester.pumpAndSettle();

    expect(find.text('正在点击'), findsOneWidget);

    nativeMultiPointTaskRunState = 'paused';
    nativeAccessibilityConnected = false;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      nativeAccessibilityConnected = true;
    });

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('已暂停'), findsOneWidget);
    await scrollDown(tester);
    expect(find.text('继续任务'), findsOneWidget);
  });

  testWidgets('Native overlay position changes are persisted', (tester) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    nativeOverlaySettings = {
      ...nativeOverlaySettings,
      'targetPositionX': 321,
      'targetPositionY': 432,
    };
    await sendSinglePointOverlayState(isEnabled: true, taskRunState: 'idle');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    methodCalls.clear();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tapVisibleText(tester, '保存');

    final overlayUpdateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateSinglePointOverlayUiSettings',
    );
    final arguments = overlayUpdateCall.arguments as Map<Object?, Object?>;
    expect(arguments['targetPositionX'], 321);
    expect(arguments['targetPositionY'], 432);
  });

  testWidgets('Leaving mode page keeps native single point overlay enabled', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    methodCalls.clear();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      methodCalls.where((call) => call.method == 'hideSinglePointOverlay'),
      isEmpty,
    );

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('关闭单点模式'), findsOneWidget);
  });

  testWidgets('Toolbar close event resets mode page state', (tester) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();

    await sendSinglePointOverlayState(isEnabled: false, taskRunState: 'idle');
    await tester.pump();

    expect(find.text('未启动'), findsOneWidget);
    expect(find.text('开启单点模式'), findsOneWidget);
  });
}

Map<String, Object?> _defaultNativeOverlaySettings() {
  return {
    'interactionMode': 'normal',
    'targetPositionX': 280,
    'targetPositionY': 260,
    'toolbarPositionX': 18,
    'toolbarPositionY': 180,
    'collapsedToolbarPositionX': 18,
    'collapsedToolbarPositionY': 180,
    'actionButtonPositionX': 18,
    'actionButtonPositionY': 260,
    'isToolbarCollapsed': false,
  };
}

Map<String, Object?> _defaultNativeMultiPointSettings() {
  return {
    'interactionMode': 'normal',
    'toolbarPositionX': 18,
    'toolbarPositionY': 180,
    'collapsedToolbarPositionX': 18,
    'collapsedToolbarPositionY': 180,
    'actionButtonPositionX': 18,
    'actionButtonPositionY': 260,
    'isToolbarCollapsed': false,
    'targets': [
      {
        'id': 'p1',
        'order': 1,
        'label': '1',
        'x': 280.0,
        'y': 260.0,
        'enabled': true,
      },
      {
        'id': 'p2',
        'order': 2,
        'label': '2',
        'x': 280.0,
        'y': 340.0,
        'enabled': true,
      },
    ],
  };
}

Map<String, Object?> _objectMap(Object? value) {
  return Map<String, Object?>.from(value as Map<Object?, Object?>);
}
