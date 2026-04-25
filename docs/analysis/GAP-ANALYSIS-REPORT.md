# FancyCardGame 差距分析报告

审计日期：2026-04-25

根目录 `PLANNING_GAP_ANALYSIS.md` 是当前权威差距分析。本文保留在旧路径，供
`docs/analysis/` 入口读取。

> 2026-04-25 状态说明：`T-RUN-6HOUR`、`T-PRESTIGE-LAST-CHANCE`、`T-RUN-XP-INCOME`
> 已完成基础迁移。本文保留历史差距，但当前优先级以后文“当前待做”为准。

## 结论

本轮审计发现的历史问题不是缺少更多 UI 或怪物，而是规则源冲突：

- 旧策划写 5 Hour，目标应为 6 Hour。
- 旧分析把回合制 PvP、EndTurn、最终 Boss 当成 P0，方向错误。
- `AGENTS.md` 曾引用缺失的 `config/codex-instructions.md`。
- 旧代码实现曾是 5 Hour，且阶段规则分散。
- XP/Level/Income 当时没有形成清晰规则和实现，现已完成基础链路。
- Item/Skill/Monster 的 effect model 不统一。
- 主流程 UI 缺少统一 `BazaarShell`，时间选择和商人界面仍偏普通面板。

## 正确 P0

| # | 差距 | 影响 | 修正方向 |
| --- | --- | --- | --- |
| P0-1 | Day/Hour 仍为 5 阶段（历史） | 核心节奏错误 | 已完成基础迁移；后续防回归 |
| P0-2 | Prestige 文档混乱 | 失败曲线错误 | 初始 20，PvP 失败扣当前 Day，第一次归零 Last Chance |
| P0-3 | XP/Level/Income 缺失（历史） | run 成长扁平 | 已完成基础链路；后续扩展奖励内容 |
| P0-4 | 状态重复 | 同步 bug 风险 | RunStateService/EconomyService/HeroStateService 归属明确 |
| P0-5 | Effect model 不统一 | 物品技能难扩展 | trigger/condition/target/effect 数据化 |
| P0-6 | 文档入口不稳定 | ACP 质量低 | 根目录文档 + AGENTS.md 成为单一真相源 |

## 正确 P1

| # | 差距 | 修正方向 |
| --- | --- | --- |
| P1-1 | Monster 仍像普通 RPG 敌人 | 怪物使用 board items + skills + reward pool |
| P1-2 | Skill 文档有固定槽位 | 改为拥有即生效的 passive/trigger 集合 |
| P1-3 | 商店经济过大 | 回到 15 gold / 7 income 量级 |
| P1-4 | PvP UI 文档使用“手牌/牌河” | 改为 board/items/snapshot 术语 |
| P1-5 | ACP 任务派发缺模板 | 使用根目录 `ACP_TASK_TEMPLATE.md` |

## 明确不是 P0 的旧项

这些方向不应继续实现：

- 回合制 PvP。
- EndTurn 按钮。
- PvP 中的商店/手牌/牌河。
- 10 胜后的最终 Boss。
- 固定 2 败淘汰。
- 5 Hour Day。

如果某个旧 UI 文档还提到这些词，只能作为归档参考，不作为新需求来源。

## 当前待做

当前代码中仍应重点检查：

- `scripts/game_manager.gd`：仍作为 facade/兼容层存在，需防止重新新增权威状态。
- `scripts/services/run_state.gd`：也保存 Day/Hour/Prestige/PvP wins。
- `scripts/services/phase_service.gd`：必须作为 Day/Hour 判断入口，避免回归散落判断。
- `scripts/main.gd`：存在 UI 流转和阶段文案，后续 UI shell 迁移风险较高。
- `scripts/ui/battle_ui.gd`、`scripts/ui/shop_ui.gd`、`scenes/main.tscn`：仍缺统一 BazaarShell。

实现前先搜索：

```bash
rg -n "current_hour|% 5|>= 5|== 4|Hour 5|5 个 Hour|5个Hour" scripts docs
rg -n "回合制|EndTurn|最终Boss|PvP商店|手牌|牌河" scripts docs
```

## 建议任务顺序

1. 已完成 `T-RUN-6HOUR`
2. 已完成 `T-RUN-XP-INCOME`
3. 已完成 `T-PRESTIGE-LAST-CHANCE`
4. `T-EFFECT-MODEL`
5. `T-MONSTER-REWARD`
6. `T-PVP-SNAPSHOT`
7. `T-UI-SHELL-DESIGN`
8. `T-UI-SHELL-FOUNDATION`
