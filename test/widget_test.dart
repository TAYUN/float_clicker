import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/app.dart';

void main() {
  const permissionChannel = MethodChannel('float_clicker/android_permissions');
  const methodCodec = StandardMethodCodec();
  final methodCalls = <MethodCall>[];
  final missingNativeMethods = <String>{};
  var nativeOverlayEnabled = false;
  var nativeTaskRunState = 'idle';

  Future<void> sendSinglePointClickingState(String taskRunState) async {
    nativeTaskRunState = taskRunState;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointClickingStateChanged', {
              'taskRunState': taskRunState,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendSinglePointOverlayState({
    required bool isEnabled,
    required String taskRunState,
  }) async {
    nativeOverlayEnabled = isEnabled;
    nativeTaskRunState = taskRunState;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointOverlayStateChanged', {
              'isEnabled': isEnabled,
              'taskRunState': taskRunState,
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
    missingNativeMethods.clear();
    nativeOverlayEnabled = false;
    nativeTaskRunState = 'idle';
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          methodCalls.add(call);
          if (missingNativeMethods.contains(call.method)) {
            throw MissingPluginException();
          }
          if (call.method == 'getPermissionSnapshot') {
            return {'accessibilityGranted': false, 'overlayGranted': true};
          }
          if (call.method == 'getSinglePointOverlaySnapshot') {
            return {
              'isEnabled': nativeOverlayEnabled,
              'taskRunState': nativeTaskRunState,
            };
          }
          if (call.method == 'showSinglePointOverlay') {
            nativeOverlayEnabled = true;
            nativeTaskRunState = 'idle';
            return null;
          }
          if (call.method == 'hideSinglePointOverlay') {
            nativeOverlayEnabled = false;
            nativeTaskRunState = 'idle';
            return null;
          }
          if (call.method == 'startSinglePointClicking') {
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
            return null;
          }
          if (call.method == 'stopSinglePointClicking') {
            nativeTaskRunState = 'idle';
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

  testWidgets('Unimplemented native pause keeps running UI unchanged', (
    tester,
  ) async {
    missingNativeMethods.add('pauseSinglePointClicking');

    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('执行任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('暂停任务'));
    await tester.pumpAndSettle();

    expect(find.text('正在点击'), findsOneWidget);
    expect(find.text('暂停任务'), findsOneWidget);
    expect(find.text('Android 尚未实现 pauseSinglePointClicking。'), findsOneWidget);
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
