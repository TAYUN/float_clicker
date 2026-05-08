# Float Clicker 测试与验收规范

本文档记录项目测试策略、常用命令和手动验收范围。

## 1. 基本原则

- 核心模型和持久化逻辑优先补单元测试。
- 页面行为变化优先补 Widget 测试或明确手动验收项。
- Android 悬浮窗、无障碍、权限和横竖屏行为必须进行真机验证。
- 多点开发中涉及共享组件时，必须考虑单点模式回归。
- 无法自动验证的内容，要在交付说明里列出原因和剩余风险。

## 2. 常用命令

Flutter 静态检查：

```powershell
flutter analyze
```

Flutter 测试：

```powershell
flutter test
```

Android debug 包构建：

```powershell
flutter build apk --debug
```

建议顺序：

1. 纯 Dart/Flutter 模型或 store 改动：`flutter analyze` + `flutter test`。
2. Flutter 页面改动：`flutter analyze` + `flutter test`，必要时手动跑 App。
3. Android 原生或 MethodChannel 改动：以上命令再加 `flutter build apk --debug`。
4. 悬浮窗、无障碍、权限、横竖屏：必须补真机验收说明。

## 3. 当前测试文件

```text
test/widget_test.dart
test/multi_point_settings_store_test.dart
```

多点 P1 已完成，后续回归仍需关注：

- 默认 2 个启用点位。
- 最多 12 个点位。
- 不允许删除到 0 个点位对象。
- 允许禁用全部点位，但执行前校验失败。
- `multi_point.targets_json` 读写。
- 坏 JSON 或缺字段时兜底。
- 排序、删除后 `id` 稳定，显示序号可重新计算。

## 4. 单点回归

如果改动影响以下文件或共享逻辑，需要考虑单点回归：

- `lib/core/platform/android_permission_service.dart`
- `lib/features/clicker/*`
- `android/app/src/main/kotlin/com/example/float_clicker/*Overlay*`
- `android/app/src/main/kotlin/com/example/float_clicker/OverlayWindowHelper.kt`
- `android/app/src/main/kotlin/com/example/float_clicker/FloatClickerAccessibilityService.kt`
- `android/app/src/main/kotlin/com/example/float_clicker/MainActivity.kt`

回归参考：

- `docs/验收清单/单点模式真机验收清单.md`

重点确认：

- 普通、简洁、极简三种模式仍可用。
- 执行、暂停、继续、结束状态正确。
- 全局悬浮外观缩放不打断任务。
- `dispatchGesture()` 失败不会卡在 `running`。
- 悬浮窗权限撤销或窗口异常不会崩溃。
- 横竖屏切换后组件仍可见。

## 5. 多点基础验收方向

多点 P1：

- 模型默认值正确。
- store 可保存和读取。
- 点位 JSON 兼容坏数据。
- 测试覆盖状态约束。

多点 P2：

- 首页多点入口可进入。
- 多点模式页面能加载 P1 持久化配置。
- 多点设置页面能保存点击参数和悬浮交互模式。
- 点位列表支持新增、删除、启用、禁用、排序。
- 不能删除到 0 个点位对象。
- 禁用全部点位时，执行入口拒绝并提示至少启用 1 个点位。
- Android 未完成能力有明确提示，不静默失败。

多点 P3-P5 后续验收：

- 新增、删除、启用、禁用、排序点位。
- 运行中结构编辑入口禁用。
- 暂停中结构变化后继续语义正确。
- 悬浮层只显示启用点位。
- 任务按启用点位顺序点击。
- 横竖屏后所有点位和控制组件保持可见。
- 单点开启时，多点开启返回 `mode_conflict`。

## 6. 真机验收记录建议

每次真机验收建议记录：

```text
设备：
Android 版本：
App 构建：
验证日期：
验证范围：
通过项：
失败项：
备注：
```

如果发现问题，应在 `docs/调试问题/` 下新增或更新问题记录。
