# 怪物系统策划案

更新时间：2026-04-25

根目录 `GAME_RULES.md` 和 `DATA_MODEL.md` 是 PvE Encounter 的权威规则。

## 核心流程

Hour 2 固定进入 PvE Encounter：

1. 显示 3 个怪物选项。
2. 玩家查看怪物 tier、health、board、skills、主要奖励。
3. 玩家选择 1 个怪物。
4. 进入自动战斗。
5. 结算 gold、XP、item/skill/loot reward。
6. 返回 Day 流程并推进 Hour。

## 怪物建模

怪物不是只有 HP/攻击的普通 RPG 敌人。Bazaar-like 怪物应该像玩家一样拥有：

- health
- board items
- skills
- tier
- reward pool
- 特殊规则或 tags

MVP 可以用简化 board，但不要只保留 `attack + cooldown`。

## Tier

| Tier | 用途 |
| --- | --- |
| Bronze | 同等级或低风险，适合稳定拿奖励 |
| Silver | 略强，奖励更好 |
| Gold | 明显挑战，需要 build 有强度 |
| Diamond | 高风险高回报 |
| Legendary | 特殊遭遇或后期挑战 |

## 奖励

每个怪物至少定义：

- gold
- XP
- item_pool
- skill_pool
- loot_pool

奖励随 tier 提升。P0 可以使用简化表：

| Tier | Gold | XP | 额外奖励 |
| --- | --- | --- | --- |
| Bronze | 2 | 3 | 低概率 item/skill |
| Silver | 3 | 3 | 中概率 item/skill |
| Gold | 4 | 3 | 较高概率 item/skill |
| Diamond | 5 | 4 | 高概率 item/skill |
| Legendary | 6 | 4 | 特殊 item/skill |

## MVP 怪物池

可以保留现有 fantasy 名称作为占位，但数据结构要按 Bazaar-like encounter 组织：

| 名称 | Tier | Board 方向 | 奖励方向 |
| --- | --- | --- | --- |
| 史莱姆 | Bronze | Heal/Regeneration 入门 | gold + XP |
| 蝙蝠 | Bronze | Haste/Small item | XP + 小物品 |
| 蜘蛛 | Silver | Poison/Slow | poison item/skill |
| 骷髅法师 | Silver | Burn/Spell-like item | burn item/skill |
| 狼 | Gold | Weapon/Crit | weapon item/skill |
| 史莱姆王 | Diamond | Regen/Shield scaling | monster item + skill |

## 当前实现差距

当前 `MonsterData` 已有 tier、HP、monster_items、gold reward 和 drop chance，
但 tier 仍是三档，怪物更像 `attack/cooldown` 敌人。后续应迁移到五档 tier、board
items、skills 和 reward pool。
