# DATA_MODEL.md

本文档定义 FancyCardGame 的数据模型。实现时优先用 Resource、typed Dictionary
或明确 class_name，避免 UI 和 battle system 各自发明字段。

## 命名约定

- id 使用稳定 snake_case，例如 `iron_sword`、`fanged_inglet`。
- 展示名使用 `display_name` 或现有 `item_name` / `monster_name`。
- tier 使用 Bazaar-like 五档：Bronze、Silver、Gold、Diamond、Legendary。
- size 使用 Small/Medium/Large，占 1/2/3 格。
- tags 使用小写字符串数组，便于筛选和效果系统匹配。

## RunState

权威 run 状态应包含：

```gdscript
class_name RunState

var current_day: int = 1
var current_hour: int = 0  # 0..5
var gold: int = 15
var income: int = 7
var xp: int = 0
var level: int = 1
var xp_per_level: int = 8
var prestige: int = 20
var max_prestige: int = 20
var last_chance_used: bool = false
var pvp_wins: int = 0
var selected_hero_id: String = ""
var seed: int = 0
```

不要在 GameManager、RunStateService、PhaseService 中重复保存互相冲突的
`current_hour`、`prestige`、`pvp_wins`。迁移前如果必须兼容旧接口，旧接口应代理到
唯一权威状态源。

## HeroData

```gdscript
class_name HeroData

@export var id: String
@export var display_name: String
@export var max_health: int
@export var current_health: int
@export var starting_gold: int = 15
@export var starting_income: int = 7
@export var starting_items: Array[String] = []
@export var starting_skills: Array[String] = []
@export var item_pool_tags: Array[String] = []
@export var hero_tags: Array[String] = []
```

英雄不提供基础攻击/防御作为主战斗来源。伤害、护盾、治疗主要由 item/skill effect
产生。

## ItemData

推荐字段：

```gdscript
class_name ItemData

@export var id: String
@export var display_name: String
@export var description: String
@export var tier: String = "bronze"
@export var size: String = "small"
@export var tags: Array[String] = []
@export var price: int = 4
@export var value: int = 2
@export var cooldown: float = 3.0
@export var crit_chance: float = 0.0
@export var ammo: int = -1
@export var effects: Array[Dictionary] = []
@export var upgrade_to: String = ""
```

当前代码的 `damage`、`shield`、`heal`、`poison_damage` 等字段可作为过渡层，但目标是
统一收敛到 `effects`。新增物品时优先写 effects，不要继续扩大平铺字段。

## SkillData

```gdscript
class_name SkillData

@export var id: String
@export var display_name: String
@export var tier: String = "bronze"
@export var tags: Array[String] = []
@export var source: String = "level_up"
@export var effects: Array[Dictionary] = []
@export var hero_id: String = ""
```

技能没有固定槽位。玩家拥有的技能集合全部生效，限制来自获取来源、唯一性和 tier，
而不是 2-6 个 skill slot。

## MonsterData

```gdscript
class_name MonsterData

@export var id: String
@export var display_name: String
@export var tier: String = "bronze"
@export var min_day: int = 1
@export var level: int = 1
@export var max_health: int = 100
@export var board_items: Array[String] = []
@export var skills: Array[String] = []
@export var reward: Dictionary = {}
```

Reward 示例：

```gdscript
{
	"gold": 2,
	"xp": 3,
	"item_pool": ["fang", "pelt"],
	"skill_pool": ["deadly_eye"],
	"loot_pool": []
}
```

怪物不是只有 attack/cooldown 的简单敌人。即使 MVP 简化，也应按 board items +
skills 建模，方便后续和玩家战斗系统共用。

## Reward

P1 起运行时奖励统一使用 Dictionary，并通过 `RewardService.apply_reward()` 应用：

```gdscript
{
	"gold": 4,
	"xp": 2,
	"income": 1,
	"max_health": 5,
	"heal": 10,
	"prestige": 1
}
```

当前已接入来源：

- Hour complete: `{"xp": 1}`
- New day income: `{"gold": EconomyService.income}`
- PvE win: `MonsterData.get_reward()`
- Level-up reward table: demo 阶段支持 max health / income / gold

后续 item、skill、loot、upgrade、enchant、board slot 等也应扩展到同一 reward model，
不要在 UI 或单个事件分支中直接改多个 service。

## EventOption

Hour 0/1/3/4 展示的选项统一为 EventOption：

```gdscript
{
	"id": "bronze_weapon_vendor",
	"type": "vendor",
	"display_name": "Weapon Vendor",
	"cost": 0,
	"payload": {
		"vendor_type": "item",
		"tags": ["weapon"],
		"tier": "bronze"
	}
}
```

常见 type：`vendor`、`skill_trainer`、`free_reward`、`special_event`、`monster`、
`pvp`。

## BattleSnapshot

PvP ghost 和战斗回放依赖快照，不应读取实时 run state：

```gdscript
{
	"day": 3,
	"hour": 5,
	"hero_id": "vanessa",
	"level": 4,
	"max_health": 550,
	"board": [],
	"stash": [],
	"skills": [],
	"prestige": 16,
	"pvp_wins": 2
}
```

生成 PvP 匹配时使用 snapshot，避免对手数据被后续 UI 操作或 run state 改写。

## Resource 与 JSON

- 设计数据可来自 JSON/CSV/Resource，但进入战斗前必须转换为强类型 runtime。
- Resource 保存基础数据；runtime 保存本场战斗临时状态。
- 不要把 cooldown_remaining、temporary bonus、trigger count 写回基础 Resource。
- JSON 字段缺失时必须有默认值和 warning。

## 迁移注意

当前代码已有 `ItemData`、`MonsterData`、`SkillData`，但字段与目标模型不完全一致。
后续任务应遵循：

1. 新系统先兼容旧字段。
2. 新数据优先写入目标字段。
3. 完成迁移后删除重复字段和兼容分支。
4. 每次迁移都更新本文档和 `ARCHITECTURE.md`。
