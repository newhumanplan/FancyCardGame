# PLANNING_GAP_ANALYSIS.md

审计日期：2026-04-25

本文档对齐 The Bazaar 公开资料、现有策划文档和当前 Godot 实现，列出会影响后续
ACP/Codex 开发质量的差距。根因不是“代码写得不够勤快”，而是规则源不稳定：旧文档、
旧代码和目标玩法互相矛盾。

> 2026-04-25 状态说明：`T-RUN-6HOUR`、`T-PRESTIGE-LAST-CHANCE`、`T-RUN-XP-INCOME`
> 已完成基础迁移。本文的 P0 表保留为“历史差距与目标规则”记录，当前仍优先关注
> effect model、monster reward、PvP snapshot 和 UI shell。

## 参考资料

- Mobalytics Day Guide：6 Hour Day，Hour 2 PvE，Hour 5 PvP，起始经济 15 gold / 7 income。
- Mobalytics Prestige Guide：10 PvP wins，Prestige 初始 20，PvP 失败按当前 Day 扣除，归零有一次 Last Chance。
- The Bazaar Wiki Level Up：8 XP 升级，升级给 Max Health、board slots 和特殊奖励。
- Mobalytics PvE Encounters：PvE 奖励包含 gold、XP、物品/技能掉落。
- BazaarDB：item/skill/monster 以 tags、size、tier、cooldown、ammo、tooltip/effect 等字段组织。

## 总体判断

本轮文档审计时发现的主要问题是规则和架构源曾经不稳定：

1. 根目录 `AGENTS.md` 以前引用了不存在的 `config/codex-instructions.md`。
2. 多份策划文档仍写 5 Hour、固定 2 败或简化 Prestige。
3. 分析报告把“回合制 PvP / EndTurn / 最终 Boss”列成 P0，这是反方向。
4. 旧代码曾实现 5 Hour，且阶段规则分散在多处。
5. XP/Level/Income 是 Bazaar-like 核心节奏，现已完成基础链路，后续仍需内容扩展。
6. 物品/技能效果还缺统一 DSL，后续很容易继续硬编码。
7. 主流程 UI 缺少统一 `BazaarShell`，时间选择、商人、战斗被做成不同弹窗/页面，
   与参考截图的同一棋盘壳不一致。

## P0 差距

| 差距 | 影响 | 修正方向 |
| --- | --- | --- |
| 5 Hour Day（历史） | 破坏 Bazaar-like 节奏，PvE/PvP 位置错误 | 已完成基础迁移；后续防回归 |
| 规则源冲突 | Agent 会按不同文档写出互相冲突代码 | 根目录文档作为单一真相源，旧文档同步修正 |
| Prestige 旧设定 | 固定 2 败/初始 10 会误导失败曲线 | 初始 20，输 PvP 扣当前 Day，第一次归零 Last Chance |
| 缺 XP/Level/Income（历史） | 只剩买物品和金币，run 成长扁平 | 已完成基础链路；后续扩展奖励内容 |
| 状态重复 | GameManager/Service 双写导致 bug | RunStateService 成为权威状态源，GameManager 代理 |
| 效果模型不足 | 新物品/技能容易写成散落 if | 建立 trigger/condition/target/effect 模型 |

## P1 差距

| 差距 | 影响 | 修正方向 |
| --- | --- | --- |
| Monster 仍像普通 RPG 敌人 | PvE 缺少“怪物也有 build”的味道 | 怪物用 board items + skills + reward pool |
| Skill 文档写技能槽 | 偏离 Bazaar-like passive/trigger skill | 移除固定槽位概念，改为拥有即生效 |
| 商店经济过大 | 价格和奖励脱离 Bazaar-like 节奏 | 回到 15 gold / 7 income 量级 |
| PvP UI 文档使用手牌/牌河 | 误导 agent 做卡牌对战 | 改为 board/items/opponent snapshot 术语 |
| 缺 ACP 任务模板 | 派发任务时上下文不足 | 使用 `ACP_TASK_TEMPLATE.md` |
| 主流程 UI 布局未固化 | Event/Shop/Battle 各自实现，难以验收功能 | 以 `docs/planning/ui-layout-reference.md` 为权威，建立 `BazaarShell` |
| 时间选择 UI 像菜单按钮 | 无法复刻参考截图的上中部三节点布局 | 迁移为 `TimeSelectView`，底部 HUD 和玩家 Board 常驻 |
| 商人 UI 像普通商店弹窗 | 商品、商人、玩家 Board 不在同一棋盘壳 | 迁移为 `MerchantStateView`，商人货架位于玩家 Board 上方 |

## P2 差距

| 差距 | 影响 | 修正方向 |
| --- | --- | --- |
| Level-up 奖励表不完整 | 成长节点少 | 先做 demo 表，再扩展英雄差异 |
| Enchant 未建模 | 后期 build 缺爆点 | P2 引入 enchant effect |
| PvP ghost 数据源未定义 | 未来匹配难实现 | 使用 BattleSnapshot |
| 数据导入未统一 | 后续内容扩展成本高 | JSON/CSV/Resource 统一字段后再批量导入 |

## 明确降级或删除的旧方向

以下内容不应再作为 P0/P1：

- 回合制 PvP。
- EndTurn 按钮。
- PvP 中的商店、手牌、牌河。
- 10 胜后的最终 Boss 战。
- 固定 2 败淘汰。
- Day 只包含 5 个 Hour。

这些不是“还没做完的功能”，而是会把项目带离 The Bazaar-like 目标的错误方向。

## 建议实施顺序

1. 文档源修正：完成本轮根目录文档和旧文档同步。
2. 已完成 `T-RUN-6HOUR`：PhaseService/RunState/GameManager/main 迁移 6 Hour。
3. 已完成 `T-RUN-XP-INCOME`：加入 XP、Level、Income 基础链路。
4. 已完成 `T-PRESTIGE-LAST-CHANCE`：Prestige 归零和 Last Chance 基础规则统一。
5. `T-EFFECT-MODEL`：建立 EffectDefinition/EffectRuntime。
6. `T-MONSTER-REWARD`：怪物 board/skill/reward 数据化。
7. `T-PVP-SNAPSHOT`：PvP 使用 ghost snapshot，不读实时 UI 状态。
8. `T-UI-SHELL-DESIGN`：按 `ui-layout-reference.md` 设计统一 BazaarShell。
9. `T-UI-SHELL-FOUNDATION`：实现常驻底部 HUD、玩家 Board、左侧时钟。
10. `T-UI-TIME-SELECT`：替换旧 EventPanel。
11. `T-UI-MERCHANT-SHELF`：替换旧 ShopUI 弹窗。
12. `T-UI-BATTLE-SHELL`：BattleUI 接入 BazaarShell，清理旧术语。

## 当前实施状态

- `T-RUN-6HOUR`：已完成基础迁移。
- `T-PRESTIGE-LAST-CHANCE`：已完成基础规则。
- `T-RUN-XP-INCOME`：已完成基础运行链路，包括 Hour XP、New Day income、PvE XP、
  Level-up demo reward 和主 UI 显示。
- 下一步优先级应转向 `T-EFFECT-MODEL`、`T-MONSTER-REWARD` 和 `T-PVP-SNAPSHOT`，
  不要重复实现新的 XP/Income 状态源。
- UI 布局已新增权威规范 `docs/planning/ui-layout-reference.md`。如果目标是先让 demo
  可被肉眼验证，应把 `T-UI-SHELL-DESIGN` 和 `T-UI-SHELL-FOUNDATION` 提到近期优先级，
  否则功能继续开发会被混乱 UI 掩盖。
