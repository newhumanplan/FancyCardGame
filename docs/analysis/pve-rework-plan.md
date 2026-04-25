# T-PVE-REWORK 怪物战斗布局分析

更新时间：2026-04-25

旧版文档混用了“手牌、河流”等卡牌对战术语。当前目标是 Bazaar-like 自动战斗 UI：
展示双方 board、skills、cooldown 和战斗日志，不提供战斗内操作。

主流程截图级布局以 `docs/planning/ui-layout-reference.md` 为准；本文只用于
`BattleStateView` 的 PvE/PvP 数据统一参考。

## 当前问题

- PvE UI 信息量不足。
- 怪物 board/skill 展示不完整。
- PvE 与 PvP 布局路径分裂，容易出现样式和状态残留。

## 修正目标

- 统一 PvE/PvP 的 BattleUI 框架。
- mode 决定数据来源和标题：`pve` 使用 monster，`pvp` 使用 ghost snapshot。
- 双方 board items 正面展示。
- 双方 skills 正面展示。
- 战斗中只允许观察，不允许拖拽、购买、EndTurn。

## 建议代码方向

| 文件 | 改动 |
| --- | --- |
| `scripts/ui/battle_ui.gd` | 抽出 `_create_battle_layout(mode)` |
| `scripts/ui/battle_ui.gd` | 抽出 `_render_board(side, items)` |
| `scripts/ui/battle_ui.gd` | 抽出 `_render_skill_list(side, skills)` |
| `scripts/ui/battle_ui.gd` | 战斗结束后显示 ContinueButton |
| `scripts/data/monster_data.gd` | 怪物暴露 board_items / skills |

## 验收标准

- PvE 显示 monster board 和 skill。
- PvP 显示 opponent board 和 skill。
- 不出现手牌、EndTurn、PvP 商店需求。
- 战斗结束等待玩家确认。
- Godot headless 无 script error。
