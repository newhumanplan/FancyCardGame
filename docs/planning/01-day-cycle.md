# Day 循环系统策划案

更新时间：2026-04-25

根目录 `GAME_RULES.md` 是当前权威规则。本文保留为 Day/Hour 细化策划，已按
The Bazaar-like 目标修订。

## 每天结构：6 个 Hour

内部索引使用 0-5：

| Hour | 内容 | 说明 |
| --- | --- | --- |
| 0 | 商店/事件/免费奖励 | 第一次构筑机会 |
| 1 | 商店/事件/免费奖励 | PvE 前第二次构筑机会 |
| 2 | PvE Encounter | 从 3 个怪物中选择 1 个，进入自动战斗 |
| 3 | 商店/事件/免费奖励 | PvE 后继续补强 |
| 4 | 商店/事件/免费奖励 | PvP 前最后一次构筑机会 |
| 5 | PvP/Ghost Fight | 与同 Day 的异步镜像自动战斗 |

完成 Hour 5 后进入下一 Day 的 Hour 0。

## Hour 推进规则

- 非战斗 Hour：玩家选择 1 个 option，结算后推进 Hour。
- PvE Hour：选择怪物并完成战斗/奖励后推进 Hour。
- PvP Hour：完成自动战斗、结算 Prestige/胜场后推进到下一 Day。
- 每个 Hour 结束默认获得 1 XP。
- Start-of-hour 效果在进入新 Hour 时结算。

## 胜负条件

- 胜利：累计 10 场 PvP/Ghost 胜利。
- 失败：Prestige 第二次归零。
- 初始 Prestige：20。
- PvP 失败扣除 Prestige，扣除量 = 当前 Day。
- 第一次 Prestige 归零触发 Futura/Last Chance，并恢复到 1。
- PvE 失败不直接结束 run，惩罚由具体 encounter 定义。

## XP / Level / Income

- 起始经济目标：15 gold、7 income。
- 每完成 1 个 Hour 获得 1 XP。
- 默认 8 XP 升 1 级。
- 升级奖励可给 Max Health、board slot、item、skill、loot、upgrade、enchant、
  income 或 hero-specific reward。

## MVP 范围

MVP 不应退化成“商店 -> 打怪”的 2 阶段循环。可以简化 option 内容，但 Day 骨架
必须保持 6 Hour：

- Hour 0/1/3/4：至少提供基础商店和一个免费奖励。
- Hour 2：至少提供 3 个怪物选项。
- Hour 5：可先使用本地生成的 ghost snapshot。
- XP/Level/Income 可以先用小表实现，但状态必须存在。

## 当前实现状态

`T-RUN-6HOUR` 已完成基础迁移。后续任务仍需要防回归，尤其是不要在新代码里重新写
`% 5`、`>= 5`、`== 4` 之类散落判断。需要重点关注：

- `scripts/game_manager.gd`
- `scripts/services/run_state.gd`
- `scripts/services/phase_service.gd`
- 部分 `scripts/main.gd` UI 文案和判断

所有阶段判断应集中到 `PhaseService`。
