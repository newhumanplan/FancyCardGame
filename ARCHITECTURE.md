# ARCHITECTURE.md

本文档描述 FancyCardGame 的目标架构，以及当前实现中需要谨慎处理的迁移点。

## 当前状态

项目已经有可运行的 Godot demo，但存在几个结构性问题：

- Day/Hour 规则分散在 `GameManager`、`RunStateService`、`PhaseService` 和部分 UI 中。
- 当前代码仍是 5 Hour 循环，目标规则是 6 Hour。
- `GameManager` 与 service 层保存重复状态，存在同步风险。
- `main.gd` 负责过多流程和 UI glue，容易继续膨胀。
- 物品/技能效果部分平铺在数据字段中，尚未完全收敛为 effect model。
- 主流程 UI 目前由 `EventPanel`、`ShopUI`、`BattleUI` 和动态 `HeroBarLayer` 分散组成，
  没有统一的 Bazaar-like 棋盘壳，导致时间选择、商人、战斗布局不一致。

后续开发必须把“目标规则”和“当前实现”分开看。不要因为现有代码是 5 Hour，就继续
把 5 Hour 写入新功能。

## 目标分层

```text
scenes/
  main.tscn                 组合 UI 和页面

scripts/
  main.gd                   应用入口和高层场景流转
  services/
    run_state.gd            Run 状态唯一来源
    phase_service.gd        Day/Hour 规则与阶段判断
    economy_service.gd      Gold / Income / price / sell
    hero_state.gd           Hero health / level / xp
    reward_service.gd       Reward dictionary application and level-up rewards
    game_flow_service.gd    Hour 推进、事件选择、奖励入口
    battle_progression_service.gd
  data/
    item_data.gd
    skill_data.gd
    monster_data.gd
    linear_inventory.gd
    effect_definition.gd    目标新增：trigger/effect 数据
  systems/
    battle_system.gd        自动战斗、effect queue、runtime
  ui/
    bazaar_shell.gd         目标新增：主流程 UI 骨架和槽位管理
    time_select_view.gd     目标新增：Hour option / monster choice 三节点选择
    merchant_state_view.gd  目标新增：商人头像 + 货架状态
    bottom_hud_panel.gd     目标新增：血条、头像、技能、仓库、金币/收入
    player_board_panel.gd   目标新增：玩家 Board 常驻渲染
    inventory_ui.gd
    shop_ui.gd              迁移期兼容；目标由 MerchantStateView 替代
    battle_ui.gd            迁移期兼容；目标填充 BazaarShell 槽位
    item_detail_panel.gd
```

当前 `battle_system.gd` 在 `scripts/` 根目录，是 Autoload。可以保留位置，但职责应按
上面的 systems 约束执行。

## 状态归属

| 状态 | 权威归属 | 说明 |
| --- | --- | --- |
| `current_day` | RunStateService | 1-based |
| `current_hour` | RunStateService + PhaseService 判断 | 0-5 |
| `prestige` | RunStateService | 初始 20，按 Day 扣除 |
| `last_chance_used` | RunStateService | 替代 `prestige_zero_count` 更清晰 |
| `pvp_wins` | RunStateService | 10 胜结束 |
| `gold` | EconomyService | 起始 15 |
| `income` | EconomyService | 起始 7 |
| `xp` / `level` | HeroStateService 或 RunStateService | 必须唯一，不要双写 |
| `selected_hero` | HeroStateService | GameManager 只做代理 |
| board / stash | Inventory model | UI 只显示 |
| battle runtime | BattleSystem | 战斗结束后丢弃 |

迁移期间允许 `GameManager` 作为 facade 保留旧方法，但不能再新增新的权威状态字段。

## 主要模块职责

### RunStateService

- 保存 run 进度：Day、Hour、Prestige、PvP wins、last chance。
- 发出 `day_changed`、`hour_changed`、`prestige_changed`、`run_ended`。
- 不负责 UI，不负责战斗细节。

### PhaseService

- 定义 6 Hour 表。
- 提供 `is_vendor_hour()`、`is_pve_hour()`、`is_pvp_hour()`、`get_phase_name()`。
- 所有 hour 判断必须经过这里。

### GameFlowService

- 进入新 Hour 时生成 event options。
- 完成 event/combat/reward 后请求 RunState 推进。
- 触发 level-up、income、start-of-hour effect。

### EconomyService

- 管理 gold、income、购买、出售、刷新、锁定成本。
- 提供 price/value 计算。
- 不直接创建 UI。

### HeroStateService

- 管理 hero、max health、current health、XP、level、skills。
- 处理 XP/level 状态；升级后的奖励由 `RewardService` 应用。
- 不直接打开 level-up UI，只发信号。

### RewardService

- 接收统一奖励字典，例如 `{ "gold": 4, "xp": 2, "income": 1 }`。
- 将 gold/income/xp/max_health/heal/prestige 分发到权威 service。
- 根据 level-up 表应用 demo 阶段升级奖励，并发出 `level_reward_applied`。
- 不保存权威状态，不打开 UI。

### BattleSystem

- 输入 BattleSnapshot。
- 创建 item runtime、status runtime、effect queue。
- 自动 tick 并发出日志、状态变化和结果。
- 不推进 Hour，不改商店，不直接写 run state。

### UI Controllers

- 渲染 state。
- 接收点击、拖拽、hover。
- 通过 signal / service API 发起请求。
- 不做业务结算。

### BazaarShell UI

主流程 UI 必须遵循 `docs/planning/ui-layout-reference.md`。战斗、时间选择、商人不是三个
互相覆盖的全屏弹窗，而是同一个 `BazaarShell` 的不同填充状态。

- `BazaarShell` 管理固定槽位：左侧时钟、顶部上下文、上方动态区、玩家 Board、底部 HUD、
  右侧操作区、覆盖层。
- `BottomHudPanel` 和 `PlayerBoardPanel` 在时间选择、商人、战斗中保持同一位置和同一数据源。
- `TimeSelectView` 只填充上中部三个选择节点，不能遮挡玩家 Board 和底部 HUD。
- `MerchantStateView` 只填充商人头像与货架，购买/刷新/锁定通过 signal 请求 service。
- `BattleUI` / `BattleStateView` 只展示 BattleSnapshot 和 runtime 状态，不能推进 Hour、
  发奖励或改 Prestige。
- 旧 `EventPanel`、全屏 `ShopUI`、动态 `HeroBarLayer` 只能作为迁移期兼容层，不得继续扩展。

## 数据流

进入新 Hour：

```text
RunStateService.next_hour()
  -> PhaseService.get_phase()
  -> GameFlowService.generate_options()
  -> UI displays options
  -> player chooses option
  -> service executes option
  -> rewards / battle / shop complete
  -> RunStateService.next_hour()
```

进入战斗：

```text
GameFlowService requests battle
  -> builds BattleSnapshot for both sides
  -> BattleSystem.start(snapshot)
  -> BattleSystem emits battle_ended
  -> BattleProgressionService applies reward / prestige via RewardService
  -> GameFlowService returns to flow
```

## 迁移路线

P0:

1. 把 PhaseService 改为 6 Hour，并让所有 hour 判断调用它。
2. 选定 RunStateService 为 run 状态唯一来源。
3. GameManager 旧字段改为代理或逐步删除。
4. 增加 XP/Level/Income 状态。
5. 战斗胜负只返回结果，由 BattleProgressionService 处理 Prestige/奖励。

P1:

1. 引入 EffectDefinition / EffectRuntime。
2. ItemData/SkillData/MonsterData 兼容旧字段并支持 effects。
3. PvP 使用 BattleSnapshot。
4. Shop/Event/Level-up 都走统一 reward model。

UI 重构:

1. 新增 `BazaarShell` 和常驻 `BottomHudPanel` / `PlayerBoardPanel` / `LeftClockPanel`。
2. 将 `EventPanel` 迁移为 `TimeSelectView`，按三节点截图布局显示 Hour options。
3. 将 `ShopUI` 迁移为 `MerchantStateView`，商品货架位于玩家 Board 上方。
4. 将 `BattleUI` 接入 `BazaarShell`，清理 `hand/river/shop` 旧命名。
5. 增加截图级手动验收和至少 1920x1080 + 一个窄屏尺寸检查。

当前 P1 进度：

- `RewardService` 已提供统一奖励入口。
- 完成 Hour 会通过 RewardService 获得 1 XP。
- 进入新 Day 会通过 RewardService 发放当前 income 的 gold。
- PvE 胜利会从 MonsterData reward/gold/xp 字段发放奖励。
- Level-up demo 表已支持 Max Health、Income、Gold。

## 代码修改准则

- 改 Day/Hour 前，先全局搜索 `current_hour`、`% 5`、`>= 5`、`== 4`。
- 改 Prestige 前，先全局搜索 `prestige`、`prestige_zero_count`、`on_pvp_lose`。
- 改战斗效果前，先读 `EFFECT_SYSTEM.md`，不要直接在 UI 中分支。
- 改数据字段前，先更新 `DATA_MODEL.md`。
- 改主流程 UI 前，先读 `docs/planning/ui-layout-reference.md`，不要继续扩展旧
  `EventPanel` / `ShopUI` 弹窗结构。
- 迁移旧系统时保留兼容测试，避免一次性大爆炸重构。
