# PvP 对称布局策划文档（归档）

更新时间：2026-04-25

本文件原方案使用“手牌、对手背面、技能隐藏、结束回合”等卡牌对战概念，已不再作为
开发需求。后续 PvP 规则以根目录 `GAME_RULES.md` 和 `ARCHITECTURE.md` 为准。
主流程截图级布局以 `docs/planning/ui-layout-reference.md` 为准。

## 当前结论

PvP 是异步 ghost 自动战斗，不是回合制卡牌对战。

必须保留：

- 对手在上、玩家在下或等价清晰布局。
- 双方 hero、HP、shield、board items、skills、cooldown 可读。
- 对手 board 和 skill 应可见。
- 战斗中玩家不可操作物品，不购买，不点 EndTurn。
- 胜场显示为 `N/10 Wins`。

必须删除或避免：

- 对手手牌背面。
- 己方手牌正面。
- 对手技能隐藏。
- 结束回合按钮。
- PvP 中的商店/牌河/购买。

## 推荐布局语言

使用这些术语：

- OpponentBoard
- PlayerBoard
- BoardItem
- SkillList
- BattleLog
- CooldownOverlay
- WinCounter

不要使用这些术语：

- Hand
- River
- EndTurn
- Attack Turn / Defense Turn

## 验收标准

| # | 验收项 | 通过条件 |
| --- | --- | --- |
| 1 | 自动战斗 | 战斗中没有玩家实时行动按钮 |
| 2 | 对手信息透明 | 对手 board item 和 skill 可见 |
| 3 | 物品不可交互 | 战斗中 hover 可看信息，但不能拖拽/购买/使用 |
| 4 | 胜场显示 | 常驻显示 `N/10 Wins` |
| 5 | 规则一致 | 不出现 EndTurn、手牌、PvP 商店需求 |
