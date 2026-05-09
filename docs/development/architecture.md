# Float Clicker 架构说明

本文档记录项目架构、模块边界、核心状态流和重要设计取舍。

## 1. 项目定位

Float Clicker 是 Android 自动点击工具。

Flutter 侧负责：

- 页面 UI。
- 配置编辑。
- 配置持久化。
- 权限状态展示。
- 通过 MethodChannel 调用 Android 原生能力。
- 接收 Android 状态回调并刷新页面。

Android 原生侧负责：

- 悬浮窗创建、更新、移除。
- 无障碍 `dispatchGesture()`。
- 点击任务调度。
- 权限和服务状态收尾。
- 横竖屏和屏幕尺寸变化后的悬浮组件校正。

## 2. Flutter 模块

```text
lib/
- app.dart
- main.dart
- core/
  - platform/
    - android_permission_service.dart
  - settings/
    - global_overlay_appearance_settings.dart
    - global_overlay_appearance_store.dart
  - theme/
    - app_theme.dart
- features/
  - home/
    - home_page.dart
  - clicker/
    - clicker_page.dart
    - clicker_settings.dart
    - clicker_settings_store.dart
    - clicker_settings_page.dart
    - clicker_controller.dart
    - clicker_guide_page.dart
  - multi_point/
    - multi_point_settings.dart
    - multi_point_settings_store.dart
  - settings/
    - global_settings_page.dart
```

边界：

- `features/clicker` 是单点模式。
- `features/multi_point` 是多点模式。
- `core/settings` 放跨模式全局配置。
- `core/platform/android_permission_service.dart` 是当前 Flutter 到 Android 的平台服务入口。

## 3. Android 模块

```text
android/app/src/main/kotlin/com/example/float_clicker/
- MainActivity.kt
- FloatClickerAccessibilityService.kt
- AccessibilityServiceStateBus.kt
- SinglePointOverlayManager.kt
- SinglePointClickScheduler.kt
- SinglePointTaskState.kt
- OverlayWindowHelper.kt
- OverlayInteractionState.kt
- OverlayAppearanceSettings.kt
- TargetOverlayComponent.kt
- ToolbarOverlayComponent.kt
- CollapsedToolbarComponent.kt
- ActionButtonOverlayComponent.kt
```

当前已稳定能力：

- 单点悬浮点。
- 完整控制条。
- 简洁模式收起图标。
- 极简/简洁独立执行控件。
- 全局外观缩放。
- `WindowManager` 安全操作。
- 横竖屏可见范围校正。
- 单点任务三态调度。

## 4. MethodChannel

当前 channel：

```text
float_clicker/android_permissions
```

现有单点方法包括：

- `getPermissionSnapshot`
- `openAccessibilitySettings`
- `openOverlaySettings`
- `showSinglePointOverlay`
- `hideSinglePointOverlay`
- `getSinglePointOverlaySnapshot`
- `updateSinglePointSettings`
- `updateSinglePointOverlayUiSettings`
- `updateGlobalOverlayAppearanceSettings`
- `startSinglePointClicking`
- `pauseSinglePointClicking`
- `resumeSinglePointClicking`
- `endSinglePointClicking`
- `showMultiPointOverlay`
- `hideMultiPointOverlay`
- `getMultiPointOverlaySnapshot`
- `updateMultiPointTargets`
- `updateMultiPointOverlayUiSettings`
- `startMultiPointClicking`
- `pauseMultiPointClicking`
- `resumeMultiPointClicking`
- `endMultiPointClicking`

多点 Overlay 和基础执行方法已接入；当前进入 P5 联调验收阶段，阶段细分和最新状态以 `docs/开发计划/多点模式开发阶段管理.md` 为准。

## 5. 单点模式状态流

```text
Flutter 页面
  -> AndroidPermissionService
  -> MethodChannel
  -> MainActivity
  -> SinglePointOverlayManager
  -> SinglePointClickScheduler
  -> FloatClickerAccessibilityService
```

Android 是悬浮层和任务执行的事实来源。Flutter 页面展示状态、发起操作、保存配置，并接收 Android 快照。

任务状态：

```text
idle -> running -> paused -> running -> idle
```

结束任务时清空本轮进度，但不一定关闭悬浮层。

## 6. 多点模式目标架构

基础多点第一版：

```text
Flutter MultiPointSettingsStore
  -> MultiPoint 页面
  -> AndroidPermissionService 多点方法
  -> MultiPointOverlayManager
  -> MultiPointTargetOverlayComponent 列表
  -> AutomationTaskScheduler
  -> AccessibilityGestureExecutor
  -> FloatClickerAccessibilityService
```

演进原则：

- 多点 Overlay 新增独立 manager。
- 控制条、收起图标、独立执行控件、外观 metrics 和窗口 helper 尽量复用。
- 不把 `SinglePointClickScheduler` 继续膨胀为多模式调度器。
- 通用调度内核按阶段抽出，避免一次性重写单点主链路。

## 7. 多点当前架构边界

已完成：

- `MultiPointTarget`
- `MultiPointSettings`
- `MultiPointOverlayUiSettings`
- `MultiPointSettingsStore`
- `multi_point.targets_json`
- Flutter 多点页面和设置页
- Android 多点 Overlay、点位组件和控制组件复用
- 点位和控制组件位置回传
- 多点横竖屏边界、单点/多点互斥、权限撤销和窗口异常处理
- 通用手势执行器和基础多点顺序调度
- 多点 `start/pause/resume/endMultiPointClicking` 三态控制接入

当前推荐下一步是 P5 剩余专项验收。

P5 只做：

- 验证基础多点第一版联调链路。
- 验证权限、互斥、全禁用点位、悬浮窗权限撤销、无障碍断开、横竖屏和单点回归。
- 只修验收中发现的明确可复现问题。

P5 不进入多配置、高级连招、多执行控件或文档外新 UI 能力。

## 8. 后期多配置执行

后期多配置执行独立设计，不进入基础多点第一版。

目标模型：

```text
MultiPointProfile
- targets
- settings
- overlayUiSettings
- advancedOptions

LoadedMultiPointProfile
- profileId
- buttonPosition
- order
```

原则：

- 当前基础多点配置后续可迁移成默认 profile。
- 多个配置可以加载到悬浮执行区。
- 同一时间只允许一个配置任务执行。
- 执行模式可以隐藏点位和控制条，但必须保留展开入口和停止能力。

详细设计见：

- `docs/需求文档/悬浮多点多配置执行设计文档.md`

## 9. 关键风险

- 多点开发影响单点稳定行为。
- 横竖屏后悬浮组件位置和坐标语义混乱。
- 运行中编辑点位结构导致调度进度失效。
- 过早引入多配置、高级连招或并行任务，扩大第一版范围。
- Flutter 和 Android MethodChannel 字段不一致。

风险控制：

- 每阶段更新 `docs/开发计划/多点模式开发阶段管理.md`。
- 涉及共享组件时回归单点验收。
- 坐标语义统一为悬浮组件左上角持久化，执行时换算中心点。
- `running` 禁止点位结构编辑。
- `paused` 允许结构编辑，但继续时从当前轮第一个启用点重新开始。
