# UI Refactor Task Plan

更新时间：2026-04-25

本文用于把 `docs/planning/ui-layout-reference.md` 拆成可派发给 Codex ACP 的小任务。
任何任务都必须遵循三阶段 ACP：`[DESIGN ONLY]` -> `[REVIEW DESIGN]` -> `[DIRECT IMPLEMENT]`。

## 总原则

- 一次只改一个可验收的 UI 切片。
- 每个任务必须明确涉及文件、禁止项和截图级验收标准。
- UI 只展示状态和发出用户意图；结算、扣钱、推进 Hour、战斗奖励都在 service/system。
- 不要在旧 `EventPanel`、全屏 `ShopUI` 或动态 `HeroBarLayer` 上继续叠功能。
- 如果需要临时兼容旧 UI，必须在任务总结中写清楚迁移边界。

## T-UI-SHELL-DESIGN

目标：只做技术设计，不写代码。

必须产出：

- `.codex-status/T-UI-SHELL-DESIGN/design_doc.md`
- `BazaarShell` 节点树设计。
- 槽位 API：如何显示 `TimeSelectView`、`MerchantStateView`、`BattleStateView`。
- 数据绑定方案：玩家 Board、底部 HUD、左侧时钟的数据从哪里来。
- 迁移路径：哪些旧节点保留兼容，哪些节点停止扩展。

验收标准：

- 方案引用 `docs/planning/ui-layout-reference.md`。
- 方案明确不在 UI 中做经济/战斗/Hour 结算。
- 方案包含 1920x1080 和窄屏适配策略。

## T-UI-SHELL-FOUNDATION

目标：实现 `BazaarShell` 基础骨架，不迁移具体业务界面。

建议范围：

- 新增 `scenes/ui/bazaar_shell.tscn`
- 新增 `scripts/ui/bazaar_shell.gd`
- 新增或拆出 `BottomHudPanel`、`PlayerBoardPanel`、`LeftClockPanel`
- 在 `main.tscn` / `main.gd` 中接入但保留旧界面开关

验收标准：

- Shell 能在空状态下显示左侧时钟、玩家 Board 占位、底部 HUD 占位。
- 这些区域使用稳定 anchors，窗口尺寸变化时不互相重叠。
- 旧流程仍可进入游戏，不因接入 shell 破坏启动。
- Godot headless 0 ERROR。

## T-UI-TIME-SELECT

目标：把 Hour option 选择迁移为截图二的上中部三节点布局。

建议范围：

- 新增 `scenes/ui/time_select_view.tscn`
- 新增 `scripts/ui/time_select_view.gd`
- 替换或绕过 `main.tscn` 里的旧 `EventPanel`
- `main.gd` 只负责把 options 传入 view，并监听 selected signal

验收标准：

- 上中部横向显示 3 个选择节点。
- 选择节点使用图像/头像/徽章式主体，不是三个文字按钮。
- 玩家 Board、底部 HUD、左侧时钟保持可见。
- 点击 option 后只发出 signal；奖励结算和 Hour 推进不在 view 内完成。
- 1920x1080 手动截图通过。

## T-UI-MERCHANT-SHELF

目标：把当前商店弹窗迁移为截图三的商人货架布局。

建议范围：

- 新增 `scenes/ui/merchant_state_view.tscn`
- 新增 `scripts/ui/merchant_state_view.gd`
- 逐步替换 `scenes/shop_panel.tscn` / `scripts/ui/shop_ui.gd`
- 商品卡可复用现有 item card 渲染，但必须放在 `UpperBoardPanel`

验收标准：

- 商人头像位于顶部中心。
- 3-5 个商品显示在玩家 Board 上方的货架区。
- 玩家 Board、底部 HUD、钱包区域保持可见。
- 刷新、锁定、购买发 signal 或调用 service API，不直接改权威状态。
- 不再出现主界面级标题“商人商店”和底部关闭按钮条。

## T-UI-BATTLE-SHELL

目标：让战斗界面填充 `BazaarShell`，对齐截图一。

建议范围：

- 将 `BattleUI` 拆出或包裹为 `BattleStateView`
- 敌方/怪物 Board 填充 `UpperBoardPanel`
- 玩家 Board 使用共享 `PlayerBoardPanel`
- 右侧操作区显示继续按钮和必要战斗操作
- 清理旧 `hand/river/shop` 命名，至少不在新增 API 中继续扩散

验收标准：

- 敌方/怪物 Board 在上，玩家 Board 在下。
- 敌方/怪物物品正面可见但不可交互。
- 战斗期间无 EndTurn、PvP 商店、手牌、牌河。
- 战斗结束后 `Continue` 出现在右侧操作区。
- 底部 HUD 和左侧时钟与时间选择/商人状态位置一致。

## T-UI-SCREENSHOT-QA

目标：建立人工截图验收流程，防止布局回退。

建议范围：

- 更新 `ACCEPTANCE_CHECKLIST.md` 或补充测试说明。
- 为 1920x1080、1366x768、移动/窄屏尺寸列出检查项。
- 如项目后续接入截图测试，可在此任务中增加脚本。

验收标准：

- 三种状态截图中，左侧时钟和底部 HUD 在同一位置。
- 时间选择和商人不会遮挡玩家 Board。
- 商人商品在玩家 Board 上方。
- 战斗没有普通文本日志大面板占据棋盘。

## 推荐派发模板片段

```text
[DESIGN ONLY] 任务: T-UI-...

你在 /Users/Allenz/Projects/FancyCardGame 工作。
必须先读:
- AGENTS.md
- ARCHITECTURE.md
- CODING_STANDARDS.md
- ACCEPTANCE_CHECKLIST.md
- docs/planning/ui-layout-reference.md
- docs/planning/ui-refactor-task-plan.md

本任务只允许设计，不写代码。
请分析现有 scenes/scripts，输出 design_doc.md，包含改动范围、节点树、信号/API、风险和验收方式。
```

```text
[DIRECT IMPLEMENT] 任务: T-UI-...

按已通过审查的 design_doc.md 实现。
必须遵循 docs/planning/ui-layout-reference.md。
完成后运行 Godot headless，并写 .codex-status/{task_id}/summary.md、changed_files.md、
test_results.json、cr_signoff.json、godot_verify.json。
```
