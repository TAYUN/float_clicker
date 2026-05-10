---
name: multi-role-feature
description: Float Clicker 复杂功能、多阶段任务、跨 Flutter/Android 改动的多角色协作流程。
---

# Float Clicker 多角色功能开发流程

当任务涉及多点模式、MethodChannel、Android 悬浮窗、无障碍调度、阶段计划更新或较大范围验证时，使用本 Skill。

## 适用场景

- 多点模式 P1-P8 阶段开发。
- Flutter 页面、持久化、Android 原生能力之间的跨模块改动。
- 需要先确认需求边界再实现的任务。
- 需要把实现、验证和阶段管理分开的任务。
- 需要保护单点模式回归的任务。
- 需要在计划模式下沉淀计划、执行和验收记录的任务。

小型文档修改或单文件修复可以不用完整多角色流程，但仍要先检查 `git status`。

## 标准流程

1. Explorer 收集上下文。
   - 先读 `AGENTS.md`。
   - 根据任务阅读需求文档和 `docs/开发计划/多点模式开发阶段管理.md`。
   - 查找相关 Flutter、Android、测试文件。
   - 输出当前实现、关键文件和风险。

2. PM 确认范围。
   - 明确当前属于哪个阶段，例如 P1 / P2 / P3。
   - 明确本次做什么、不做什么。
   - 明确验收标准和需要更新的文档。
   - 需要形成计划时，在 `docs/开发计划/Codex协作记录/` 新建或更新本轮记录，先写 Summary、Scope、Plan、Acceptance Criteria、Assumptions。
   - 如果需求和文档冲突，先提出调整建议，不直接编码。

3. Builder 实施改动。
   - 按阶段边界最小化修改。
   - 遵循 `docs/development/coding-standards.md`。
   - 写必要中文注释，解释复杂状态、坐标语义、权限或异常边界。
   - 不把后期能力混入当前阶段。

4. Tester 验证结果。
   - Flutter 改动优先运行 `flutter analyze` 和 `flutter test`。
   - Android 原生改动至少考虑 `flutter build apk --debug`。
   - 如果当前 Codex 会话已注册 Float Clicker verify MCP，优先使用 `verify_debug_pipeline`、`flutter_analyze`、`flutter_test`、`flutter_build_debug_apk`、`adb_devices`、`adb_install_debug_apk` 和 `git_diff_check` 获取结构化验证结果。
   - 如果 verify MCP 不可用，回退到等价的原子 shell 命令；不要把 MCP 作为团队成员完成验证的硬依赖。
   - 需要格式化时才显式运行 `dart format` 或 `verify_debug_pipeline(format=true)`，避免验证步骤在未说明时修改文件。
   - 悬浮窗、权限、无障碍和横竖屏行为需要列出真机验收项。
   - 单点模式受影响时，参考 `docs/验收清单/单点模式真机验收清单.md` 回归。
   - 将验证命令、真机步骤、通过/失败项、未验证风险补充到本轮 Codex 协作记录。

5. Reporter 交付总结。
   - 汇总改动、验证、风险和关键文件。
   - 如果完成阶段任务，说明更新了阶段管理文档。
   - 确认是否更新了本轮 Codex 协作记录，并在交付中标注路径。
   - 如果有未验证项，明确原因和后续建议。

## 本项目阶段边界提醒

当前状态：P1 Flutter 多点模型与持久化、P2 Flutter 多点页面、P3 Android 多点 Overlay、P4 通用手势执行与调度、P5 多点联调与真机验收、P6 多配置管理均已完成并验证；P7 多配置悬浮执行区正在按小阶段推进。

P7 当前只做：

- 多配置加载列表、多个执行控件、profile 绑定真实执行和执行控件位置持久化等小阶段能力。
- 保持单任务执行模型，同一时间只运行一个 profile 任务。
- 每个小阶段都先建计划记录，明确本次做什么、不做什么和验收标准。
- 同步更新阶段管理文档和 `docs/开发计划/Codex协作记录/` 下的本轮记录。

P7 当前不做：

- 高级连招 UI。
- 多任务并行执行。
- 未计划的贴边展开、折叠面板、暂停/继续执行控件和复杂执行模式。
- P8 长按、滑动、延迟和高级动作编排。

## 固定验证工具

- 项目提供可选的 Float Clicker verify MCP，说明见 `docs/AI协作/Float Clicker 验证 MCP 服务.md`。
- MCP 适合 AI/Codex 获取结构化验证结果；团队成员没有 MCP 时仍可直接执行等价 shell 命令。
- 常规固定验证可用 `verify_debug_pipeline`，它可按参数执行 analyze、test、build、adb install 和 `git diff --check`。
- `dart_format` 或 `verify_debug_pipeline(format=true)` 会修改文件，只在明确需要格式化时使用。

## 计划与执行记录

- 目录：`docs/开发计划/Codex协作记录/`。
- 命名：`P阶段 任务名.md`，例如 `P5 剩余专项验收执行记录.md`。
- 计划阶段先写：Summary、Scope、Plan、Acceptance Criteria、Assumptions。
- 执行后补写：Implementation Changes、Verification、Issues、Risks、Next Steps。
- 阶段总状态仍写入 `docs/开发计划/多点模式开发阶段管理.md`，不要把流水记录塞进阶段总表。

## 发任务模板

```text
请使用 Float Clicker 多角色流程完成这个任务。

目标：
[写需求]

上下文：
[相关阶段 / 文档 / 文件 / 报错]

阶段边界：
- 当前阶段：[P?]
- 本次包含：[...]
- 本次不包含：[...]

约束：
- 先检查 git status。
- 先探索再实施。
- 不新增无关依赖。
- 不影响单点模式稳定行为。
- 改后必须验证。
- 如完成阶段任务，更新 docs/开发计划/多点模式开发阶段管理.md。
- 如进入计划模式或 P 阶段验收，更新 docs/开发计划/Codex协作记录/ 下的本轮记录。

完成标准：
- 功能可用或文档更新完整。
- 测试或检查通过，无法验证的说明原因。
- 列出修改文件与风险。
```

## 输出模板

```text
改动摘要：
- ...

验证结果：
- ...

阶段状态：
- ...

风险与未完成项：
- ...

Codex 协作记录：
- ...

关键文件：
- ...
```
