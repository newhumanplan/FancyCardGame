# 怪物系统策划案

更新时间：2026-04-27

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

## 全量 Wiki 怪物目录

占位怪物已废弃。怪物数据现在从 The Bazaar wiki 生成，详见
`docs/planning/08-monster-wiki-catalog.md`。

当前覆盖：

- 101 个 wiki 怪物页面。
- 332 个怪物相关或怪物 board 引用道具。
- 133 个怪物相关或怪物 board 引用技能。
- PvE 选项按 `day == monster.level` 取真实怪物池；Day 1 继续是以下 6 个真实早期怪物。

| 名称 | Tier | HP | 奖励 | Board |
| --- | --- | --- | --- | --- |
| Banannabal | Bronze | 100 | 2 Gold + 2 XP | Med Kit, Bluenanas, Duct Tape, Overheal Haste |
| Fanged Inglet | Bronze | 100 | 2 Gold + 2 XP | Pelt, Fang, Deadly Eye |
| Haunted Kimono | Bronze | 100 | 2 Gold + 2 XP | Scrap, Silk Scarf, Haunting Flight |
| Kyver Drone | Bronze | 100 | 2 Gold + 2 XP | Insect Wing, Stinger, Langxian, Eagle Talisman, Trained |
| Pyro | Bronze | 100 | 2 Gold + 2 XP | Cinders, Lighter, Fiery |
| Viper | Silver | 75 | 3 Gold + 2 XP | Gland, Fang, Extract, Lash Out |

## 当前实现差距

当前 `MonsterData` 已有 tier、HP、monster_items、monster_skills、gold reward 和
XP reward。怪物目录和基础战斗数值已迁移到 wiki 数据，但以下内容还需要继续补齐：

- tier enum 仍是三档，应迁移到 Bronze/Silver/Gold/Diamond/Legendary 五档。
- 怪物技能只有通用字段生效：start Poison/Burn/Shield，以及基础 Damage/Shield/Poison/Burn 加成；复杂条件、Flying、Overheal、防死亡、公式型效果仍需要逐条实现。
- 胜利奖励尚未做 item/skill reward 选择 UI。
