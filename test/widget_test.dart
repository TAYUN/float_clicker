import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:float_clicker/app.dart';

void main() {
  const permissionChannel = MethodChannel('float_clicker/android_permissions');
  const methodCodec = StandardMethodCodec();
  final methodCalls = <MethodCall>[];
  var nativeOverlayEnabled = false;
  var nativeClickingRunning = false;

  Future<void> sendSinglePointClickingState(bool isRunning) async {
    nativeClickingRunning = isRunning;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointClickingStateChanged', {
              'isRunning': isRunning,
            }),
          ),
          (_) {},
        );
  }

  Future<void> sendSinglePointOverlayState({
    required bool isEnabled,
    required bool isRunning,
  }) async {
    nativeOverlayEnabled = isEnabled;
    nativeClickingRunning = isRunning;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          permissionChannel.name,
          methodCodec.encodeMethodCall(
            MethodCall('singlePointOverlayStateChanged', {
              'isEnabled': isEnabled,
              'isRunning': isRunning,
            }),
          ),
          (_) {},
        );
  }

  setUp(() {
    methodCalls.clear();
    nativeOverlayEnabled = false;
    nativeClickingRunning = false;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getPermissionSnapshot') {
            return {'accessibilityGranted': false, 'overlayGranted': true};
          }
          if (call.method == 'getSinglePointOverlaySnapshot') {
            return {
              'isEnabled': nativeOverlayEnabled,
              'isRunning': nativeClickingRunning,
            };
          }
          if (call.method == 'showSinglePointOverlay') {
            nativeOverlayEnabled = true;
            nativeClickingRunning = false;
            return null;
          }
          if (call.method == 'hideSinglePointOverlay') {
            nativeOverlayEnabled = false;
            nativeClickingRunning = false;
            return null;
          }
          if (call.method == 'startSinglePointClicking') {
            nativeClickingRunning = true;
            return null;
          }
          if (call.method == 'stopSinglePointClicking') {
            nativeClickingRunning = false;
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
    expect(find.text('开始点击'), findsOneWidget);

    await tester.tap(find.text('介绍向导'));
    await tester.pumpAndSettle();

    expect(find.text('1. 开启单点模式'), findsOneWidget);
    expect(find.text('3. 点击播放形状按钮以执行点击操作'), findsOneWidget);
  });

  testWidgets('Single point settings are saved back to mode page', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('间隔 500 ms，次数 10'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), '800');
    await tester.enterText(find.byType(EditableText).at(1), '80');
    await tester.enterText(find.byType(EditableText).at(2), '3');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('间隔 800 ms，次数 3'), findsOneWidget);
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();

    expect(find.text('间隔 900 ms，次数 4'), findsOneWidget);
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final updateCall = methodCalls.lastWhere(
      (call) => call.method == 'updateSinglePointSettings',
    );
    expect(updateCall.arguments, {
      'intervalMs': 700,
      'repeatCount': 2,
      'infiniteLoop': false,
      'tapDurationMs': 70,
    });
  });

  testWidgets('Native finished event resets single point running UI', (
    tester,
  ) async {
    await tester.pumpWidget(const FloatClickerApp());

    await tester.tap(find.text('单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开启单点模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始点击'));
    await tester.pumpAndSettle();

    expect(find.text('正在点击'), findsOneWidget);
    expect(find.text('停止点击'), findsOneWidget);

    await sendSinglePointClickingState(false);
    await tester.pump();

    expect(find.text('单点模式已开启'), findsOneWidget);
    expect(find.text('开始点击'), findsOneWidget);
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

    await sendSinglePointOverlayState(isEnabled: false, isRunning: false);
    await tester.pump();

    expect(find.text('未启动'), findsOneWidget);
    expect(find.text('开启单点模式'), findsOneWidget);
  });
}
