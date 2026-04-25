# 游戏流程详细设计

更新时间：2026-04-25

根目录 `GAME_RULES.md` 是完整流程的权威规则。

## 完整 Run 流程

```text
开始游戏
  -> 选择英雄
  -> 初始化 run: Day 1, Hour 0, Prestige 20, gold 15, income 7, level 1
  -> Hour 0: 商店/事件/免费奖励
  -> Hour 1: 商店/事件/免费奖励
  -> Hour 2: PvE 三选一并自动战斗
  -> Hour 3: 商店/事件/免费奖励
  -> Hour 4: 商店/事件/免费奖励
  -> Hour 5: PvP/Ghost 自动战斗
  -> Day +1，回到 Hour 0
  -> 10 PvP wins 胜利 / Prestige 第二次归零失败
```

## 初始化

- 选择 hero。
- 初始化 board/stash。
- 设置起始 gold、income、Prestige、XP、level。
- 生成 Day 1 Hour 0 option。

## 非战斗 Hour

可出现：

- item vendor
- skill trainer
- free reward
- special event
- service vendor

结算后：

- 获得 1 XP。
- 检查是否 level up。
- 推进到下一 Hour。

## PvE Hour

1. 生成 3 个 monster options。
2. 玩家选择 1 个。
3. 构建 BattleSnapshot。
4. 自动战斗。
5. 结算 gold、XP、item/skill/loot。
6. 检查 level up。
7. 推进到 Hour 3。

## PvP Hour

1. 获取或生成 ghost snapshot。
2. 自动战斗。
3. 胜利：`pvp_wins += 1`。
4. 失败：Prestige 扣当前 Day。
5. Prestige 首次归零触发 Last Chance。
6. 10 胜则 run 胜利，否则进入下一 Day。

## Level-up

- 默认 8 XP 升级。
- 升级可以连续触发。
- 升级奖励应该暂停流程，等玩家选择。
- 选择奖励后再继续 Hour 推进或战斗后结算。

## 场景与 UI

可保留以下场景/界面概念：

- MainMenu
- HeroSelect
- Main / RunScreen / BazaarShell
- TimeSelectView（替代旧 EventOptionPanel）
- MerchantStateView（替代旧 ShopUI 弹窗）
- MonsterSelect（可复用 TimeSelectView 三节点布局）
- BattleUI / BattleStateView
- RewardPanel
- LevelUpPanel
- ResultPanel

主流程布局以 `docs/planning/ui-layout-reference.md` 为准。时间选择、商人、战斗都应共用
左侧时钟、玩家 Board 和底部 HUD；不要把 EventOptionPanel 或 ShopUI 做成遮挡棋盘的全屏弹窗。

## 明确不做

- 10 胜后的最终 Boss。
- 回合制 PvP。
- EndTurn。
- PvP 中的商店/手牌/牌河。
- 固定 2 败淘汰。

## 当前实现状态

已完成基础迁移：

- Day/Hour 已迁移到 6 Hour 基础链路。
- Prestige / Last Chance 已完成基础规则。
- XP/Level/Income 已完成基础运行链路。

仍需继续处理：

- GameManager 和 service 层状态重复。
- Event/Shop/Battle UI 仍未统一到 `BazaarShell`。
- Effect model、monster reward、PvP snapshot 仍需后续任务完善。
