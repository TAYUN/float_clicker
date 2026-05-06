import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:float_clicker/app.dart';

void main() {
  const permissionChannel = MethodChannel('float_clicker/android_permissions');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'getPermissionSnapshot') {
            return {'accessibilityGranted': false, 'overlayGranted': true};
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
}
