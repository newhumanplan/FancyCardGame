# T-PVE-REWORK 怪物战斗布局重构策划案

更新时间：2026-04-25

本文件已按 Bazaar-like 自动战斗术语修订。PvE 怪物战斗不是回合制卡牌战斗，也不使用
手牌/牌河/结束回合概念。

主流程截图级布局以 `docs/planning/ui-layout-reference.md` 为准；本文只用于
`BattleStateView` 的 PvE 数据展示参考。

## 目标

PvE 战斗展示怪物 board 与玩家 board，强调自动战斗可读性：

- 怪物在上，玩家在下。
- 怪物 board items 和 skills 可见。
- 玩家 board items 和 skills 可见。
- 中央区域显示 battle log、clock/status/effect。
- 战斗结束后显示 Continue，不自动跳走。

## 建议布局

```text
OpponentArea
  MonsterHeroStatus
  MonsterSkillList
  MonsterBoardItems

BattleCenter
  BattleLog
  EffectLayer
  Timer / Status

PlayerArea
  PlayerBoardItems
  PlayerSkillList
  PlayerHeroStatus
  ContinueButton after result
```

## 改动策略

推荐将 PvE 和 PvP 统一到一个 `_create_battle_layout(mode)`，但数据输入不同：

- PvE：使用 MonsterData/MonsterSnapshot。
- PvP：使用 Ghost BattleSnapshot。

BattleUI 只展示，不结算奖励、不推进 Hour。

## 验收标准

| # | 功能点 | 通过条件 |
| --- | --- | --- |
| 1 | 怪物 board 可见 | 显示怪物物品、技能、cooldown |
| 2 | 玩家 board 可见 | 显示玩家物品、技能、cooldown |
| 3 | 自动战斗 | 战斗中没有 EndTurn 或手牌操作 |
| 4 | 结果确认 | 战斗结束后等待玩家点击 Continue |
| 5 | PvE/PvP 切换 | 两种模式切换无报错、无残留 UI |
| 6 | Godot 验证 | headless 加载无脚本错误 |
