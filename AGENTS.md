# AGENTS.md

本文件是 Codex/AI 进入 Float Clicker 项目时优先读取的长期协作规则。

当前项目是 Flutter + Android 原生能力混合项目：Flutter 负责页面、配置和
MethodChannel；Android 原生侧负责悬浮窗、无障碍点击、任务调度和异常收尾。

## 1. 当前项目状态

- 单点模式已经基本稳定。
- 单点模式已完成 `idle / running / paused` 三态任务调度。
- 已完成普通、简洁、极简三种悬浮交互模式。
- 已完成 Overlay 组件拆分。
- 已完成全局悬浮外观配置，支持悬浮点位、控制条、独立控件分别缩放。
- 已处理 `dispatchGesture()` 返回 `false` 和手势取消后的安全收尾。
- 已给 `OverlayWindowHelper` 增加安全窗口操作封装。
- 单点模式真机验收已完成完整回归，后续改动必须保护单点回归。
- 多点模式已完成需求讨论和阶段拆分。
- P1：Flutter 多点模型与持久化已完成。
- P2：Flutter 多点页面已完成。
- P3：Android 多点 Overlay 已完成，包含多点点位显示、控制组件复用、位置回传、横竖屏、互斥、权限撤销和窗口异常边界。
- P4：通用手势执行与调度已完成。
- P5：多点联调与真机验收已验证。
- P6：多配置管理已验证。
- P7：多配置悬浮执行区正在按小阶段推进。
- 当前推荐下一步以 `docs/开发计划/多点模式开发阶段管理.md` 的“当前下一步”为准。

## 2. 必读文档

接手任务前，根据任务范围阅读相关文档。多点相关任务至少阅读：

- `docs/需求文档/单点模式需求文档.md`
- `docs/需求文档/悬浮交互模式设计文档.md`
- `docs/需求文档/全局悬浮外观配置设计文档.md`
- `docs/需求文档/多点模式前置设计文档.md`
- `docs/开发计划/多点模式开发阶段管理.md`
- `docs/验收清单/单点模式真机验收清单.md`
- `docs/调试问题/悬浮窗横竖屏贴边问题.md`

后期多配置执行相关任务再阅读：

- `docs/需求文档/悬浮多点多配置执行设计文档.md`

Codex/AI 固定验证工具说明：

- `docs/AI协作/Float Clicker 验证 MCP 服务.md`

AI 交接提示词维护在：

- `docs/AI协作/新对话交接提示词.md`

Codex 计划、执行和验收过程记录维护在：

- `docs/开发计划/Codex协作记录/`

## 3. 核心协作规则

- 写代码前先运行 `git status --short`，确认不会覆盖用户已有改动。
- 先理解现有结构和文档，再制定简短计划，最后执行改动。
- 改动保持最小化，优先沿用项目已有风格、命名和目录边界。
- 不随意重构无关代码，不改动与当前任务无关的行为。
- 写代码时要加合适中文注释，重点解释复杂逻辑、设计取舍和不明显边界。
- 新增或修改功能后必须验证；如果无法验证，需要说明原因和剩余风险。
- 每完成一个多点开发阶段，更新 `docs/开发计划/多点模式开发阶段管理.md`。
- 每次进入计划模式、形成多角色计划或执行 P 阶段验收时，在 `docs/开发计划/Codex协作记录/` 新建或更新本轮记录；计划先写清范围、步骤、验收标准和假设，执行后补充验证结果、问题和剩余风险。
- 如果开发中发现设计需要调整，先说明原因和影响范围，再同步更新需求文档、阶段计划和验收标准。

## 4. 当前多点阶段边界

基础多点第一版整体只做：

- 多个固定点位。
- 按启用点位顺序点击。
- 三态任务：`idle / running / paused`。
- 复用普通、简洁、极简悬浮交互。
- 复用全局悬浮外观配置。
- 复用单点已稳定的权限检查、横竖屏校正和异常收尾策略。

基础多点第一版不做：

- 长按、滑动、延迟动作 UI。
- 高级连招。
- 多配置 profile。
- 多个悬浮执行控件。
- 配置导入导出。
- 多任务并行执行。

后期多配置执行以 `MultiPointProfile` 为核心，已经单独建档，并在 P6/P7 按小阶段推进。

当前 P7 只做：

- 多配置加载列表、多个执行控件、profile 绑定真实执行和执行控件位置持久化等已拆分小阶段。
- 保持单任务执行模型，同一时间只运行一个 profile 任务。
- 每个小阶段都先明确 Scope、Plan、Acceptance Criteria 和暂不做内容。
- 更新阶段管理文档和 Codex 协作记录。

当前 P7 不做：

- 高级连招。
- 多任务并行执行。
- 未计划的贴边展开、折叠面板、暂停/继续执行控件和复杂执行模式。
- P8 长按、滑动、延迟和高级动作编排。

## 5. 多角色协作

复杂功能、跨模块任务或需要探索与验证分离的任务，可以使用
`.codex/skills/multi-role-feature/SKILL.md` 中的多角色流程。

角色分工：

- Explorer：读取代码、查找文件、梳理依赖和上下文。
- PM：拆分任务、定义范围、明确验收标准。
- Builder：按计划做最小化实现。
- Tester：运行测试、lint、回归检查和风险验证。
- Reporter：汇总改动、验证结果、风险和交付说明。

小任务可以合并角色，但仍保留“先收集上下文、再计划、再实现、最后验证”的顺序。

多角色或计划模式任务应把过程沉淀到 `docs/开发计划/Codex协作记录/`：

- PM 负责创建本轮记录并写入计划、范围、验收标准和假设。
- Tester 负责补充自动化检查、真机验收步骤、结果和未验证风险。
- Reporter 负责确认阶段文档与协作记录是否同步，并在交付中标注记录路径。

## 6. 项目代码规则

- Flutter 代码遵循当前项目 feature-based 结构。
- 单点相关代码在 `lib/features/clicker/`。
- 多点相关代码放在 `lib/features/multi_point/`。
- 跨模式共享配置放在 `lib/core/`。
- Android 原生悬浮窗和调度代码位于 `android/app/src/main/kotlin/com/example/float_clicker/`。
- 代码规范见 `docs/development/coding-standards.md`。
- 架构边界见 `docs/development/architecture.md`。
- 测试和验收策略见 `docs/development/testing.md`。

## 7. 验证命令

常规 Flutter 改动：

```powershell
flutter analyze
flutter test
```

涉及 Android 原生、权限、悬浮窗或无障碍能力的改动，还需要至少考虑：

```powershell
flutter build apk --debug
```

交付前建议补充：

```powershell
git diff --check
```

如果当前 Codex 会话已注册 Float Clicker verify MCP，可优先使用 `verify_debug_pipeline`、`flutter_analyze`、`flutter_test`、`flutter_build_debug_apk`、`adb_devices`、`adb_install_debug_apk` 和 `git_diff_check` 获取结构化验证结果。MCP 是 Codex/AI 的可选增强；没有 MCP 时，团队成员仍按上述原子命令完成验证。

需要格式化时才显式运行 `dart format` 或 `verify_debug_pipeline(format=true)`，避免验证步骤在未说明时修改文件。

真机相关行为必须补充手动验收说明。

## 8. 交付输出要求

每次交付时说明：

- 改了什么。
- 如何验证。
- 是否有风险或未完成项。
- 涉及的关键文件。
- 如果更新了阶段状态，说明更新了哪个阶段。
- 如果新建或更新了 Codex 协作记录，说明记录路径。
