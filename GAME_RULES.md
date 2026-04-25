# GAME_RULES.md

本文档是 FancyCardGame 的玩法规则单一真相源。目标不是完整克隆线上版本的所有
内容，而是做一个 The Bazaar-like demo：保留 Day/Hour、自动战斗、物品构筑、
Prestige、XP/Level、商店/事件/PvE/PvP 的核心体验。

## 设计目标

- 玩家在非战斗阶段通过商店、事件、怪物奖励和升级奖励构筑 build。
- 战斗阶段是自动战斗，物品和技能按 cooldown、trigger、status 自行结算。
- 每个 run 的目标是取得 10 场 PvP/Ghost 胜利。
- 失败由 Prestige 系统决定，不是固定失败次数。

## Day / Hour

每个 Day 固定 6 个 Hour，内部索引使用 0-5：

| Hour | 类型 | 规则 |
| --- | --- | --- |
| 0 | Vendor/Event/Free | 商店、事件、免费奖励三选一或同类变体 |
| 1 | Vendor/Event/Free | 第一次 PvE 前的第二次构筑机会 |
| 2 | PvE Encounter | 从 3 个怪物中选择 1 个进入自动战斗 |
| 3 | Vendor/Event/Free | PvE 后继续构筑 |
| 4 | Vendor/Event/Free | PvP 前最后一次构筑机会 |
| 5 | PvP/Ghost Fight | 与同 Day 的异步对手镜像自动战斗 |

完成一个非战斗 Hour 后推进到下一 Hour。完成 Hour 5 后进入下一 Day 的 Hour 0。
所有 “start of hour” 效果在进入新 Hour 时触发。

## Run 胜负

- 初始 Prestige: 20。
- PvP 胜利：`pvp_wins += 1`，达到 10 胜则 run 胜利。
- PvP 失败：扣除 Prestige，扣除量等于当前 Day。
- Prestige 第一次归零：触发 Futura/Last Chance，给予补偿选项并恢复到 1。
- Prestige 第二次归零：run 失败。
- PvE 失败不直接结束 run，具体惩罚由怪物/事件奖励表定义。

## Economy

- 默认起始经济目标：15 gold、7 income。
- 每个 Day 的经济曲线应围绕 income、出售、事件和战斗奖励增长。
- 商店价格不要用 100-500 这种脱离 Bazaar-like 经济的数值。
- 物品有 `price` 和 `value`；出售通常基于 value 的一部分，特殊物品可覆写。
- 刷新、锁定、免费选项和 vendor 品质共同控制购物节奏。

## XP / Level

- 每完成一个 Hour，玩家获得 1 XP。
- 默认每 8 XP 升 1 级。
- 升级奖励可以提供 Max Health、board slot、item、skill、loot、upgrade、enchant、
  income 或 hero-specific reward。
- XP 是核心节奏系统；不要用单纯加金币替代升级奖励。
- Demo 阶段的已实现升级奖励表优先给 Max Health、Income 和少量 Gold，后续再扩展
  board slot、item、skill、upgrade、enchant。

## Board / Stash

- 主 board 是线性槽位系统。
- Small/Medium/Large 分别占 1/2/3 个连续槽位。
- 物品可有 tags，例如 Weapon、Shield、Heal、Tool、Food、Friend、Toy、Poison、
  Burn、Vehicle、Property 等。
- Stash 用于暂存物品；只有 board 上的物品参与战斗，除非效果明确允许 stash 生效。

## Combat

- 战斗自动进行，玩家不做实时输入。
- 双方都有 board、health、shield、status、skills 和 item runtime。
- 物品按 cooldown 触发，触发后产生 effect，effect 再进入结算队列。
- 常见效果：Damage、Shield、Heal、Burn、Poison、Regeneration、Haste、Slow、
  Freeze、Charge、Reload、Ammo、Destroy、Cleanse、Crit。
- 战斗结束后显示结果，等待玩家确认进入奖励或下一阶段。

## PvE Encounter

- Hour 2 显示 3 个怪物选项。
- 怪物应展示名称、tier、health、board、技能、主要奖励和风险。
- 怪物 tier：Bronze、Silver、Gold、Diamond、Legendary。
- PvE 奖励至少包含 gold 和 XP，可附带 monster item、monster skill、loot 或事件票。
- 高 tier 怪物应给更高 XP/奖励，但需要更强 build 才能稳定击败。

## PvP / Ghost

- PvP 是异步镜像自动战斗。
- 可展示对手 hero、board、skills、Prestige/Day 信息和战斗日志。
- 战斗中不允许购买、拖拽物品、选牌、点 EndTurn 或执行回合制操作。
- PvP UI 可以有上下对称布局，但文案应使用 board/items，不使用“手牌/牌河/回合”。

## Skills

- Skill 是被动或条件触发效果，不使用固定技能槽。
- 来源：英雄初始、level-up、skill trainer、事件、monster reward。
- Skill 有 tier 和 tags，可与 item tags/trigger 交互。
- Skill 不应直接写死在 UI；应走数据模型和效果系统。

## Shops / Events

- Vendor/Event/Free 是 Hour 0/1/3/4 的主要内容。
- Vendor 可以卖 item、skill、loot 或特殊服务。
- Event 可以给 gold、XP、Max Health、Income、item、skill、upgrade、enchant 或条件奖励。
- Free option 是节奏调节器，避免玩家在空商店中无事可做。

## Demo 优先级

P0:
- 6 Hour Day 循环
- Prestige 20、按 Day 扣除、Futura/Last Chance、10 胜
- XP/Level/Income 基础实现
- 数据驱动 item/skill/monster/effect
- 自动战斗与关键词效果

P1:
- Monster reward item/skill
- Vendor/Trainer/Free option 多样化
- Level-up 奖励表
- PvP ghost 数据快照

当前实现进度：

- 6 Hour、Prestige、Last Chance、10 胜已进入 P0 实现。
- XP/Level/Income 已有基础运行链路：Hour XP、New Day income、PvE XP、Level-up demo reward。
- P1 剩余重点是 monster item/skill reward、vendor/trainer/free 多样化和 PvP ghost snapshot。

P2:
- 更多英雄、enchant、特殊事件、复杂怪物 AI、完整数据库导入。
