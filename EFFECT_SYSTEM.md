# EFFECT_SYSTEM.md

本文档定义物品、技能、怪物和事件的触发/效果模型。实现时优先扩展这套模型，
不要在 UI 或单个 battle 分支里写一次性逻辑。

## 核心概念

Effect System 分为四层：

1. Trigger：什么时候发生。
2. Condition：是否满足条件。
3. Target：作用于谁或哪些物品。
4. Effect：具体改变 combat/run state 的动作。

推荐数据形态：

```gdscript
{
	"trigger": "on_item_used",
	"condition": {"tag": "weapon"},
	"target": {"side": "self", "selector": "adjacent"},
	"effect": {"type": "haste", "amount": 1.0}
}
```

## 战斗结算顺序

每个 battle tick 按以下顺序处理：

1. 推进 battle clock。
2. 更新持续状态：Burn、Poison、Regeneration 等。
3. 更新 item cooldown、Freeze、Slow、Haste、Charge、Ammo。
4. 找出 cooldown 完成且可触发的 item。
5. 按 board 顺序和 tie-break 规则触发 item。
6. 触发 item 的主 effect。
7. 发出事件，例如 `item_used`、`damage_dealt`、`shield_gained`。
8. 收集由 skill/item 监听事件产生的次级 effect。
9. 按队列结算次级 effect，并应用 internal cooldown / chain guard。
10. 检查死亡、胜负和 sandstorm 等终局条件。

## Trigger

P0 Trigger:

| Trigger | 说明 |
| --- | --- |
| `on_battle_start` | 战斗开始 |
| `on_cooldown_ready` | 物品冷却完成并自动使用 |
| `on_item_used` | 任意物品使用后 |
| `on_tag_used` | 特定 tag 物品使用后 |
| `on_damage_dealt` | 造成伤害后 |
| `on_damage_taken` | 受到伤害后 |
| `on_shield_gained` | 获得护盾后 |
| `on_heal` | 治疗后 |
| `on_crit` | 暴击后 |
| `on_enemy_status_applied` | 给敌人添加状态后 |

P1 Trigger:

| Trigger | 说明 |
| --- | --- |
| `on_hour_start` | 进入新 Hour |
| `on_sell` | 出售物品 |
| `on_buy` | 购买物品 |
| `on_level_up` | 升级奖励结算 |
| `on_faint_once` | 每场战斗首次濒死/死亡替代 |

## Target

常用 target selector：

| Selector | 说明 |
| --- | --- |
| `self_hero` | 自己英雄 |
| `enemy_hero` | 敌方英雄 |
| `this_item` | 触发的物品 |
| `left_item` / `right_item` | 左/右相邻物品 |
| `adjacent` | 左右相邻物品 |
| `random_item` | 随机物品 |
| `random_tag` | 随机带某 tag 的物品 |
| `all_items` | 全部物品 |
| `enemy_random_item` | 敌方随机物品 |
| `enemy_all_items` | 敌方全部物品 |

Target 选择必须明确 side：`self`、`enemy`、`both`。不要在 effect 内部再猜测目标。

## Effect Keywords

P0 必须支持：

| Keyword | 语义 |
| --- | --- |
| `damage` | 对目标英雄造成即时伤害，可暴击 |
| `shield` | 增加护盾，护盾优先吸收 damage |
| `heal` | 即时治疗，不超过 max health |
| `burn` | 持续伤害，可按秒 tick |
| `poison` | 持续伤害，可与 burn 分开结算 |
| `regeneration` | 持续治疗 |
| `haste` | 缩短目标物品剩余 cooldown |
| `slow` | 延长目标物品剩余 cooldown |
| `freeze` | 暂停目标物品 cooldown 一段时间 |
| `charge` | 让目标物品向 ready 状态推进 |
| `crit_chance` | 提高暴击率，可限本场战斗 |
| `cleanse` | 移除负面状态 |

P1 支持：

| Keyword | 语义 |
| --- | --- |
| `ammo` | 物品使用消耗弹药，无弹药时不能触发 |
| `reload` | 恢复 ammo |
| `destroy` | 本场战斗禁用目标物品 |
| `multicast` | 一次 cooldown ready 触发多次主 effect |
| `value_gain` | 提升物品 value |
| `upgrade` | 提升物品 tier |
| `enchant` | 给物品添加附魔 |

## Chain Guard

为了避免无限触发链，所有监听型 effect 必须支持至少一种保护：

- `internal_cooldown`: 同一来源 effect 在 N 秒内只能触发一次。
- `max_triggers_per_fight`: 每场战斗最多触发 N 次。
- `chain_depth_limit`: 单次根触发最多展开 N 层。
- `source_event_id`: 同一事件不能被同一 effect 重复消费。

P0 默认：

```text
chain_depth_limit = 8
max_triggered_effects_per_tick = 64
```

超过限制时记录 warning，并停止继续展开，不要卡死战斗。

## Item Runtime

每个进入战斗的 item 都需要 runtime，不要直接修改基础数据资源：

```gdscript
{
	"item_id": "iron_sword",
	"cooldown_remaining": 0.0,
	"cooldown_base": 3.0,
	"ammo": -1,
	"disabled": false,
	"freeze_remaining": 0.0,
	"temporary_modifiers": [],
	"trigger_counts": {}
}
```

## Status Runtime

Hero/monster status 推荐用统一结构：

```gdscript
{
	"burn": 0.0,
	"poison": 0.0,
	"regeneration": 0.0,
	"shield": 0,
	"temporary_modifiers": []
}
```

同名状态是否叠加、刷新或取最大值必须由 keyword 定义，不要散落在调用方。

## 示例

武器造成伤害并给相邻 Poison item 充能：

```gdscript
[
	{
		"trigger": "on_cooldown_ready",
		"target": {"side": "enemy", "selector": "hero"},
		"effect": {"type": "damage", "amount": 20}
	},
	{
		"trigger": "on_tag_used",
		"condition": {"tag": "weapon"},
		"target": {"side": "self", "selector": "adjacent", "tag": "poison"},
		"effect": {"type": "charge", "amount": 1.0},
		"internal_cooldown": 1.0
	}
]
```

受到伤害时获得护盾并反击：

```gdscript
[
	{
		"trigger": "on_damage_taken",
		"target": {"side": "self", "selector": "hero"},
		"effect": {"type": "shield", "amount": 30},
		"internal_cooldown": 4.0
	},
	{
		"trigger": "on_shield_gained",
		"target": {"side": "enemy", "selector": "hero"},
		"effect": {"type": "damage", "amount": 15},
		"max_triggers_per_fight": 3
	}
]
```
