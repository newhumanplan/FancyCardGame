# 物品触发机制策划案

更新时间：2026-04-25

根目录 `EFFECT_SYSTEM.md` 是触发/效果系统的权威文档。本文用于策划层描述。

## 核心模型

每个物品由以下部分组成：

- size：Small/Medium/Large，占 1/2/3 格。
- tier：Bronze/Silver/Gold/Diamond/Legendary。
- tags：Weapon、Shield、Heal、Tool、Food、Friend、Toy、Poison、Burn 等。
- cooldown：自动触发间隔。
- effects：由 trigger、condition、target、effect 组成的效果列表。

不要继续只用 `damage/shield/heal` 三个平铺字段表达新物品。旧字段可保留兼容，
新物品优先写 effects。

## Cooldown 系统

- 战斗开始时，物品获得 runtime cooldown。
- cooldown 到 0 后自动触发。
- 触发后重置为基础 cooldown。
- Haste/Charge 缩短剩余 cooldown。
- Slow/Freeze 延缓或暂停 cooldown。
- Ammo 物品需要有弹药才能触发。

## 触发条件

P0：

- cooldown 完成自动触发。
- 战斗开始触发。
- 任意物品使用后触发。
- 指定 tag 物品使用后触发。
- 造成/受到伤害后触发。
- 获得护盾、治疗、暴击、施加状态后触发。

P1：

- Hour 开始。
- 购买/出售。
- 升级。
- 首次濒死。

## 目标选择

常用目标：

- 自己/敌方 hero。
- 触发物品自身。
- 左右相邻物品。
- 随机带 tag 的物品。
- 全部物品。
- 敌方随机物品。

目标必须明确 side，不在 effect 内部猜测。

## P0 关键词

- Damage
- Shield
- Heal
- Burn
- Poison
- Regeneration
- Haste
- Slow
- Freeze
- Charge
- Crit
- Cleanse

## P1 关键词

- Ammo
- Reload
- Destroy
- Multicast
- Value Gain
- Upgrade
- Enchant

## 触发链保护

所有监听型效果必须支持保护机制：

- internal cooldown
- 每场触发次数上限
- chain depth limit
- 每 tick 最大 effect 数

默认建议：

```text
chain_depth_limit = 8
max_triggered_effects_per_tick = 64
```

超过限制时停止展开并记录 warning，不能卡死战斗。

## 示例

武器 + 毒物组合：

1. 剑 cooldown 完成，造成 20 damage。
2. 监听 `on_tag_used: weapon` 的毒瓶触发。
3. 毒瓶给敌方施加 5 poison，或给自身 charge 1 秒。

护盾 + 反击组合：

1. 玩家受到伤害。
2. 护盾物品获得 30 shield。
3. 监听 `on_shield_gained` 的饰品造成 15 damage。

## 当前实现差距

当前 `ItemData` 已有 cooldown、damage、shield、heal、poison、burn、regen 等字段，
但还缺少统一 trigger/effect 数据结构。后续新增复杂物品时，应先建立 effect
runtime，而不是继续在 `BattleSystem` 中为单个物品写分支。
