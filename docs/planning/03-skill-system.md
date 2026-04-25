# 技能系统策划案

更新时间：2026-04-25

根目录 `DATA_MODEL.md` 和 `EFFECT_SYSTEM.md` 是技能数据与效果的权威规则。

## 核心定义

Skill 是被动或条件触发效果。玩家拥有的 skill 默认全部生效，不使用固定技能槽。
限制来自获取来源、唯一性、tier、hero/tag 条件，而不是 2-6 个装备槽。

## Skill 字段

- id
- display_name
- tier：Bronze/Silver/Gold/Diamond/Legendary
- tags
- source：hero_start、level_up、skill_trainer、event、monster_reward
- effects
- hero_id：为空表示通用技能

## 技能分类

### 属性类

- 增加 Max Health
- 增加某 tag 物品效果
- 减少某 tag 物品 cooldown
- 提升 crit chance

### 触发类

- 战斗开始触发
- 使用某 tag 物品后触发
- 暴击后触发
- 受到伤害后触发
- 获得护盾/治疗后触发

### 协同类

- 相邻物品增强
- 指定 tag 组合增强
- 大/中/小物品联动
- Burn/Poison/Shield/Heal/Weapon 构筑联动

## 获取来源

- 英雄初始 skill。
- Level-up 奖励。
- Skill trainer/vendor。
- 事件奖励。
- Monster reward。

P0 至少实现 level-up 和 monster reward 两个来源之一，避免技能只存在于配置文件。

## MVP 技能示例

| Skill | Tier | 效果 |
| --- | --- | --- |
| 力量强化 | Bronze | Weapon damage +10 |
| 铁壁 | Bronze | Shield item +15% shield |
| 治愈之心 | Bronze | Heal item +15% heal |
| 快速装配 | Silver | 战斗开始 Haste 1 个 Tool 2 秒 |
| 腐蚀技巧 | Silver | 使用 Poison item 后 Charge 相邻 item 1 秒 |
| 火上浇油 | Gold | Burn tick 时随机 Weapon 获得 crit chance |

## 当前实现差距

当前代码已有 `SkillData`、`PassiveSkillData`、`SkillManager` 和 `skills_config.json`，
但文档中的固定技能槽设计已废弃。后续任务应把技能作为可收集的 passive/trigger
集合，而不是做装备槽 UI。
