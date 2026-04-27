# FancyCardGame Agent Instructions

本文件是 Codex CLI / ACP 进入本项目时的最高优先级项目指令。当前实测
Codex CLI 会自动把根目录 `AGENTS.md` 带入模型上下文；不要依赖根目录
`codex.toml` 被自动读取，除非 ACP wrapper 明确实现了读取逻辑。

## 工作方式

- FancyCardGame 外层流程遵循 OpenClaw Workflow v4.1 / Agent Mailbox v1.1：Coder/native Codex 是代码执行者，Product 验收通过后由 PM 执行 push gate。
- 直接在当前项目目录实现任务，不要把任务转发给 OpenClaw、intercom 或其他 agent。
- 优先阅读本地文档；飞书链接只作为历史来源，除非任务明确要求重新读取飞书。
- 先确认需求和规则，再改代码。发现策划冲突时，按根目录文档优先级处理。
- 不要把当前代码现状当成正确规则；本项目仍存在旧规则残留和重构未完成状态。
- 只在用户或 mailbox/ACP 任务明确要求时提交本地 commit。未提交时，在交付说明中写清楚。
- **默认禁止 git push**：即使任务要求提交，也只做 local commit 并在 `.codex-status/{task_id}/commit.json` 标记 `pushed=false`。Product pass 后由 PM push。只有 Allen 在当前任务中明确授权 Dev push 时例外。

## 必读文档

每个实现任务开始前，至少阅读这些文件中与任务相关的部分：

1. `GAME_RULES.md` - Bazaar-like 核心玩法规则
2. `EFFECT_SYSTEM.md` - 物品/技能触发与效果系统
3. `DATA_MODEL.md` - 数据模型与字段约定
4. `ARCHITECTURE.md` - Godot 架构、状态归属、模块边界
5. `CODING_STANDARDS.md` - GDScript 编码规范
6. `TESTING.md` - 验证命令与测试策略
7. `ACCEPTANCE_CHECKLIST.md` - ACP/Codex 任务验收清单
8. `PLANNING_GAP_ANALYSIS.md` - 当前策划/实现差距

如果任务涉及主流程 UI、布局、商人、时间选择或战斗界面，还必须阅读：

9. `docs/planning/ui-layout-reference.md` - Bazaar-like 主界面棋盘壳和截图级布局规范
10. `docs/planning/ui-refactor-task-plan.md` - UI 重构的 ACP 任务拆分和验收顺序

旧文档位于 `docs/planning/`、`docs/analysis/`、`docs/program/`。如果旧文档
与根目录文档冲突，以根目录文档为准，并同步修正旧文档。

## 项目概览

- 项目：《大巴扎》风格自走棋卡牌 demo
- 引擎：Godot 4.6.1
- 语言：GDScript 2.0
- 项目路径：`/Users/Allenz/Projects/FancyCardGame`

## 核心规则红线

- 这是异步自动战斗的 hero builder / autobattler，不是回合制卡牌对战。
- 战斗中玩家不下指令，不点 EndTurn，不从 PvP 商店买牌，不操作手牌。
- 每天 6 个 Hour：0/1 为商店或事件，2 为 PvE，3/4 为商店或事件，5 为 PvP/Ghost。
- PvE Hour 让玩家从 3 个怪物中选 1 个；怪物有自己的 board、物品、技能和奖励。
- PvP 目标是 10 胜。Prestige 初始 20，输 PvP 扣当前 Day 数。
- Prestige 第一次归零触发 Futura/Last Chance，第二次归零才失败。
- XP/Level/Income 是核心成长系统；不要用固定 100-500 金币替代经济曲线。
- 主流程 UI 必须共用 `BazaarShell`：左侧时钟、玩家 Board、底部 HUD 在时间选择、
  商人和战斗中保持固定位置。

## 明确反目标

不要新增或强化这些设计，除非用户明确要求做一个不同于 The Bazaar 的分支：

- 回合制 PvP、攻击/防御回合、EndTurn 按钮
- PvP 中的手牌、牌河、牌店、战斗内购买
- 10 胜后的最终 Boss 战
- 固定 2 败淘汰
- 5 Hour Day 循环
- 只有金币奖励、没有 XP/Level/Income 的长期流程

## 架构原则

- Day/Hour、Prestige、XP、Income 只能有一个权威状态源。修改前先查
  `ARCHITECTURE.md` 的状态归属表。
- 业务逻辑放在 service / system，UI 只负责展示和输入转发。
- 主流程 UI 改动必须遵循 `docs/planning/ui-layout-reference.md`，不要继续扩展
  旧 `EventPanel` / 全屏 `ShopUI` 弹窗。
- 数据类保持可序列化、少依赖，不直接访问场景树。
- 战斗系统按“冷却 tick -> 触发 -> 效果队列 -> 状态结算”的模型实现。
- 新增关键词、触发器或奖励时，先更新 `EFFECT_SYSTEM.md` 或 `DATA_MODEL.md`。

## 交付要求

ACP 任务如果提供 `task_id`，完成后创建：

```text
.codex-status/{task_id}/
├── summary.md
├── changed_files.md
├── commit.json          # include hash/message/task_id/timestamp/pushed=false when committed
├── test_results.json
├── cr_signoff.json
└── godot_verify.json
```

没有 `task_id` 时，可使用简短 slug。文档任务可用 `summary.md` 和
`changed_files.md` 说明未运行 Godot 的原因；代码任务必须尽量运行 headless
验证，无法运行时写清阻塞。

## Git

- Commit format: `feat|fix|refactor|docs|style|test|chore(scope): subject`
- Local commit is allowed when requested by task; `git push` is forbidden by default.
- 不要回滚用户或其他 agent 的未提交改动。
- 只改任务相关文件；遇到无关 dirty worktree 直接绕开。
