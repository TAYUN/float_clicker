# Git 分支管理复盘：P6 与多点 hotfix

## 背景

- P6 多配置管理已经在 `codex/p6-profile-management` 分支上开发并提交。
- P6 真机验证过程中发现基础多点模式存在严重问题：多点任务显示在执行，但底层应用没有实际点击效果。
- 这个问题位于 Android 多点 Overlay/调度链路，不属于 P6 profile 管理本身。

## 本次分支选择

实际采用的流程：

```text
main
  └─ codex/fix-multi-point-touch-through
       └─ 修复基础多点执行点击无效

main  fast-forward 合入 hotfix

codex/p6-profile-management
  └─ merge main，把 hotfix 带回 P6 分支
```

这样做的原因：

- `main` 只接收基础多点 hotfix，不接收 P6 多配置管理代码。
- P6 分支继续保留自己的开发进度，同时继承 main 上的基础修复。
- hotfix 可以独立验证、独立回滚，也方便后续追踪问题来源。

## 本次提交关系

- `5bf869f feat(multi-point): 添加多配置管理`
  - P6 分支上的多配置管理提交。
- `3db8f20 fix(multi-point): 透传运行中目标点触摸`
  - 从 `main` 拉出的 hotfix 提交。
  - 已快进合入本地 `main`。
- `b16f815 fix(multi-point): 合并多点触摸透传修复`
  - P6 分支合并 `main` 后产生的合并提交。
  - 解决了阶段管理文档中 hotfix 记录和 P6 记录的冲突。

## 冲突处理

合并 `main` 回 P6 分支时，只有一个文档冲突：

- `docs/开发计划/多点模式开发阶段管理.md`

冲突原因：

- P6 分支记录了 P6 多配置管理状态和重命名问题复盘。
- hotfix 分支记录了基础多点执行点击无效的修复。
- 两边都改了“设计调整记录”表格附近内容。

处理原则：

- 保留 P6 的阶段状态与复盘记录。
- 保留 hotfix 的基础多点问题修复记录。
- 不让 hotfix 覆盖 P6 文档，也不让 P6 文档吞掉 hotfix 记录。

## 推荐规则

- 如果 bug 属于当前功能分支新增能力，就在当前功能分支修。
- 如果 bug 属于 `main` 已有基础能力，应从 `main` 新开 hotfix 分支修。
- hotfix 修完后先合入 `main`，再把 `main` 合回仍在开发的功能分支。
- 不要从功能分支开 hotfix 后直接合入 `main`，否则容易把未完成的新功能一起带进主线。
- 合并冲突时优先判断“哪部分是主线修复，哪部分是功能分支记录”，不要简单选一边覆盖。

## 后续注意

- 推送时需要同时推送：
  - `main`
  - `codex/fix-multi-point-touch-through`
  - `codex/p6-profile-management`
- 如果远端分支已经被别人更新，先 fetch 并重新确认拓扑，不直接强推。
- P6 真机验收应基于已经合入 hotfix 的 `codex/p6-profile-management` 分支继续进行。
