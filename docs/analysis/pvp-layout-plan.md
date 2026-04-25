# PvP 布局分析（归档修正版）

更新时间：2026-04-25

本文件旧版包含“手牌背面、对手技能隐藏、结束回合”等错误方向。当前只保留可用于
自动战斗 UI 的布局结论。

主流程截图级布局以 `docs/planning/ui-layout-reference.md` 为准；本文只用于
`BattleStateView` 内部信息优先级参考。

## 目标

构建 Bazaar-like PvP/Ghost 自动战斗界面：

- 双方 hero 状态清晰。
- 双方 board items 可见。
- 双方 skills 可见。
- cooldown、shield、damage、status 清晰展示。
- 战斗中不可操作物品。

## 建议布局

```text
OpponentArea
  OpponentHeroStatus
  OpponentSkillList
  OpponentBoardItems

BattleCenter
  Clock / Day / Hour / N-10 Wins
  BattleLog
  EffectLayer

PlayerArea
  PlayerBoardItems
  PlayerSkillList
  PlayerHeroStatus
  ContinueButton after result
```

## 不再采用

- Hand / 手牌。
- Card back / 对手背面卡。
- Hidden opponent skills。
- EndTurn。
- PvP shop。
- River as a card-game lane。

## 优先级

P0：

- 对手 board 正面可见。
- 对手 skill 可见。
- 战斗自动进行且不可交互。
- 胜场计数器。

P1：

- cooldown overlay 和状态动效。
- S/M/L 尺寸占格。
- PvP ghost snapshot 数据。

P2：

- 更精细的头像、背景、特效和回放。
