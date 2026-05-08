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
  var nativeTaskRunState = 'idle';
  var nativeExecutedCount = 0;
  var nativeOverlaySettings = <String, Object?>{};
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
    nativeTaskRunState = 'idle';
    nativeExecutedCount = 0;
    nativeOverlaySettings = _defaultNativeOverlaySettings();
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
          if (call.method == 'showSinglePointOverlay') {
            nativeOverlayEnabled = true;
            nativeTaskRunState = 'idle';
            nativeExecutedCount = 0;
            nativeOverlaySettings = _objectMap(call.arguments);
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

Map<String, Object?> _objectMap(Object? value) {
  return Map<String, Object?>.from(value as Map<Object?, Object?>);
}
