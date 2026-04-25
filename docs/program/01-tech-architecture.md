# 技术架构文档

更新时间：2026-04-25

根目录 `ARCHITECTURE.md` 是当前权威架构文档。本文作为旧路径兼容说明，避免
ACP/Codex 只读取 `docs/program/` 时拿到过期架构。

## 技术栈

- Godot 4.6.1
- GDScript 2.0
- Resource / JSON 数据驱动
- Git

## 核心原则

- Day/Hour、Prestige、XP、Income 必须有唯一权威状态源。
- UI 不做业务结算，只展示 state 并发出用户意图。
- BattleSystem 只处理战斗 runtime，不推进 Hour，不直接改商店和 run flow。
- Item/Skill/Monster 尽量数据驱动，复杂逻辑收敛到 effect system。
- 旧 `GameManager` 可以作为 facade 过渡，但不要继续向里面添加新状态。

## 目标模块

```text
scripts/
  services/
    run_state.gd
    phase_service.gd
    economy_service.gd
    hero_state.gd
    game_flow_service.gd
    battle_progression_service.gd
  data/
    item_data.gd
    skill_data.gd
    monster_data.gd
    linear_inventory.gd
  ui/
    bazaar_shell.gd
    time_select_view.gd
    merchant_state_view.gd
    bottom_hud_panel.gd
    player_board_panel.gd
    inventory_ui.gd
    shop_ui.gd              # 迁移期兼容，目标由 MerchantStateView 替代
    battle_ui.gd            # 迁移期兼容，目标填充 BazaarShell
  battle_system.gd
  game_manager.gd
  main.gd
```

## Day/Hour

目标规则是 6 Hour：

- Hour 0/1/3/4：Vendor/Event/Free
- Hour 2：PvE Encounter
- Hour 5：PvP/Ghost Fight

所有判断应通过 `PhaseService`，不要在业务代码里散落 `% 5`、`>= 5`、`== 4`。

## 状态归属

| 状态 | 目标归属 |
| --- | --- |
| Day/Hour/Prestige/PvP wins/Last Chance | RunStateService |
| Gold/Income/Price/Sell/Refresh | EconomyService |
| Hero/Health/XP/Level/Skills | HeroStateService |
| Board/Stash | Inventory model |
| Battle runtime/status/effect queue | BattleSystem |

## 当前迁移重点

1. 已完成基础迁移：5 Hour -> 6 Hour。
2. 已完成基础迁移：Prestige / Last Chance、XP / Level / Income。
3. 继续收敛 GameManager 状态 -> Service 权威状态。
4. 平铺 item 字段 -> trigger/effect 数据。
5. PvP 实时状态 -> BattleSnapshot。
6. 主流程 UI -> `docs/planning/ui-layout-reference.md` 定义的 `BazaarShell`。

详细迁移路线见根目录 `ARCHITECTURE.md`。
