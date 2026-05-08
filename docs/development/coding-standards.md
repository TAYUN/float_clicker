# Float Clicker 编码规范

本文档记录本项目的代码风格和实现约束，供 AI 和开发者协作时使用。

## 1. 总体原则

- 先读需求文档和现有代码，再写实现。
- 改动保持最小化，不做无关重构。
- 优先复用项目已有模型、命名、目录和 helper。
- 写代码时加合适中文注释，重点解释复杂逻辑、边界条件和设计取舍。
- 不为了“架构更漂亮”提前引入后期能力。
- 新增依赖必须有明确收益，并先说明原因；默认不新增第三方状态管理、路由或代码生成依赖。

## 2. Flutter 代码规范

### 2.1 目录边界

当前目录约定：

```text
lib/
- app.dart
- main.dart
- core/
  - platform/
  - settings/
  - theme/
- features/
  - home/
  - clicker/
  - multi_point/
  - settings/
```

规则：

- 单点模式代码保留在 `lib/features/clicker/`。
- 多点模式代码放在 `lib/features/multi_point/`。
- 跨单点和多点共享的模型或服务放到 `lib/core/`，但不要过早抽象。
- 页面级状态可以先用 `StatefulWidget`，保持和现有页面一致。
- 配置持久化继续使用 `shared_preferences`，除非需求明确升级数据层。

### 2.2 命名和模型

- Dart 文件使用 `snake_case.dart`。
- 类、枚举使用 `PascalCase`。
- 字段、方法、局部变量使用 `camelCase`。
- 多点第一版模型使用 `MultiPoint*` 前缀，避免和单点模型混淆。
- 持久化 key 必须和需求文档一致，例如 `multi_point.targets_json`。
- JSON 字段保持稳定，后续新增字段要兼容旧数据。

### 2.3 注释

需要注释：

- 状态流转规则。
- 坐标语义，例如左上角坐标和点击中心点换算。
- 兼容旧数据或坏数据的兜底逻辑。
- MethodChannel 协议字段和错误码。
- 权限、悬浮窗、无障碍相关异常处理。

避免注释：

- 重复代码表面含义的注释。
- 大段解释和当前实现无关的未来规划。

### 2.4 UI 实现

- 复用现有 Material 风格和 `AppTheme`。
- 不引入营销式首页、重视觉 hero 或无关装饰。
- 多点基础第一版页面应偏工具型，信息清晰、操作明确。
- 运行中不可用的操作要禁用并给出清楚提示。
- 文案使用中文，状态名称和需求文档保持一致。

### 2.5 依赖约束

当前项目依赖很少：

- `shared_preferences`
- `flutter_lints`

默认不要引入：

- `go_router`
- `provider`
- `riverpod`
- `json_serializable`
- `freezed`
- `google_fonts`

如果确实需要新增依赖，必须先说明：

- 解决什么问题。
- 为什么现有能力不够。
- 对测试、构建和维护的影响。

## 3. Android Kotlin 代码规范

### 3.1 目录边界

Android 原生代码位于：

```text
android/app/src/main/kotlin/com/example/float_clicker/
```

当前关键类：

- `MainActivity.kt`：MethodChannel 入口、权限跳转和原生能力分发。
- `FloatClickerAccessibilityService.kt`：无障碍手势执行。
- `SinglePointOverlayManager.kt`：单点悬浮层管理。
- `SinglePointClickScheduler.kt`：单点任务调度。
- `MultiPointOverlayManager.kt`：多点悬浮层管理。
- `MultiPointTargetOverlayComponent.kt`：多点编号点位组件。
- `OverlayWindowHelper.kt`：悬浮窗 add/update/remove 安全封装和边界校正。
- `TargetOverlayComponent.kt`
- `ToolbarOverlayComponent.kt`
- `CollapsedToolbarComponent.kt`
- `ActionButtonOverlayComponent.kt`
- `OverlayAppearanceSettings.kt`
- `OverlayInteractionState.kt`

规则：

- 多点 Overlay 新增独立 manager，不把 `SinglePointOverlayManager` 膨胀成多模式管理器。
- 复用控制条、收起图标、独立执行控件和 `OverlayWindowHelper`。
- 不破坏单点已稳定的窗口安全封装和横竖屏校正策略。

### 3.2 权限和异常

- 创建悬浮窗前必须检查悬浮窗权限。
- 执行点击前必须检查无障碍服务实例。
- `dispatchGesture()` 返回 `false`、取消或服务断开时，任务必须安全停止。
- `WindowManager.addView/updateViewLayout/removeView` 必须通过安全封装处理。
- 模式冲突使用明确错误码，例如 `mode_conflict`。

### 3.3 坐标和尺寸

- 多点点位持久化保存悬浮组件左上角坐标。
- 真正点击时根据当前组件尺寸换算中心点。
- 缩放不改变持久化坐标语义。
- 横竖屏变化后必须校正点位、控制条、收起图标和独立控件可见范围。

## 4. MethodChannel 规范

- Flutter 和 Android 的字段名必须保持文档一致。
- 新增方法或错误码时，同步更新需求文档或阶段管理文档。
- Flutter 侧对 `MissingPluginException` 的兼容只能用于过渡阶段；会改变任务语义的方法不能静默忽略。
- Android 侧对 Flutter 入参必须有默认值和类型兜底。
- 错误码要稳定，Flutter 页面负责转成中文提示。

## 5. 当前多点阶段约束

P1：Flutter 多点模型和持久化已经完成。
P2：Flutter 多点页面已经完成。
P3：Android 多点 Overlay 已经完成。

当前推荐下一步是 P4.1：通用动作和手势执行器。

P4.1 包含：

- 定义 `AutomationAction`，第一版只包含 tap 动作。
- 新增或抽出 `AccessibilityGestureExecutor`。
- 统一处理 `dispatchGesture()` 返回 false、完成、取消和无障碍服务断开。
- 保持单点模式现有行为不回退。
- 为 P4.2 多点调度器预留接口，但不直接接入多点 UI。

P4.1 不包含：

- `start/pause/resume/endMultiPointClicking` 真实多点调度接入。
- `MultiPointClickScheduler` 或轮次进度。
- 多点页面暂停编辑语义调整。
- 高级连招 UI。
- 多配置 profile。
- 多个悬浮执行控件。

## 6. 格式化

- Dart 代码使用 `dart format` 或 `flutter format`。
- Kotlin 代码保持现有项目风格。
- 不做全仓格式化。
- 不对无关文件做换行符或空白 churn。
