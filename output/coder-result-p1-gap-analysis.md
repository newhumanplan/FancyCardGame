# FancyCardGame P1 差距分析报告（核实版）

**日期**: 2026-04-14
**基准 commit**: 814db44
**核查人**: Coder Agent

---

## 逐项核实结果

### 🔴 P0 — 核心玩法缺失

#### P0-1: 24个MVP物品数据化 + 商店从池抽取
**状态**: ❌ 未实现
**说明**:
- 18个 .tres 文件存在但**未被引用**（商店完全用 `_create_random_item()` 运行时随机生成属性）
- 策划定义24个物品具体数值（如铁剑 15伤害 CD3s），代码用 `randi_range()` 随机
- 无 items_config.json 或物品池数据
- 商店不区分物品池，所有物品随机生成
**涉及文件**: item_data.gd, 新建 items_config.json, shop_ui.gd

#### P0-2: 触发链系统（相邻联动 + 位置加成）
**状态**: ❌ 未实现
**说明**:
- `battle_system.gd` 和 `item_effects.gd` 无任何 adjacent/neighbor/position_bonus 相关代码
- 物品完全独立触发，无联动机制
- `item_data.gd` 有 `slot_index` 字段但未在战斗中使用
**涉及文件**: battle_system.gd, item_effects.gd

#### P0-3: 怪物扩展到10个 + 特殊技能
**状态**: ❌ 未实现
**说明**:
- 仅3个怪物：史莱姆(T1)、哥布林(T2)、食人魔(T3)
- 缺少：蝙蝠(T1)、骷髅兵(T1)、狼(T2)、蜘蛛(T2)、哥布林酋长(精英T2)、骷髅法师(精英T2)、史莱姆王(BossT3)、亡灵骑士(BossT3)
- 怪物无特殊技能（偷窃、闪避、连击、毒网、火球术等）
**涉及文件**: battle_ui.gd, monster_data.gd

#### P0-4: 英雄物品池限制
**状态**: ⚠️ 部分实现（框架存在，数据为空）
**说明**:
- `hero_data.gd` 有 `@export var available_items: Array[String] = []` 字段
- **但数组为空**，战士/法师均无限制
- 商店 `shop_ui.gd` 未读取 `available_items` 做过滤
**涉及文件**: hero_data.gd, main.gd, shop_ui.gd

#### P0-5: 战利品系统（战斗掉落物品/技能）
**状态**: ❌ 未实现
**说明**:
- 战斗胜利仅掉落金币（`gold_reward_min/max`）
- 无物品掉落逻辑
- 无技能掉落逻辑
- 策划要求：普通怪20-40%、精英60-80%、Boss 100%
**涉及文件**: battle_ui.gd, game_manager.gd

---

### 🟡 P1 — 重要功能

#### P1-1: 英雄 attack/defense 属性 + 伤害公式
**状态**: ❌ 未实现
**说明**:
- `hero_data.gd` 仅有 max_hp / crit_chance，**无 attack / defense 字段**
- 策划要求：伤害 = 基础 × (1 + ATK%)，受伤 = 原始 × (1 - DEF%)
- 当前伤害计算仅用物品基础值 × 稀有度 × 暴击
**涉及文件**: hero_data.gd, battle_system.gd

#### P1-2: 技能系统扩展（触发类 + 协同类 + 槽位）
**状态**: ⚠️ 部分实现
**说明**:
- ✅ 属性类技能：5个已实现（skills_config.json + skill_manager）
- ✅ 英雄被动：6种效果类型（passive_skill.gd）+ 战士/法师各2个
- ✅ 技能效果应用：skill_effects.gd 已集成到 battle_system
- ❌ 触发类技能（开场爆发/反击姿态/连锁反应）：未实现
- ❌ 协同类技能（左侧强化/相邻支援）：未实现
- ❌ 技能槽位系统（2-6槽，Day5/10+1）：未实现
- ❌ 技能获取（怪物掉落）：未实现
**涉及文件**: skill_manager.gd, skill_data.gd, battle_system.gd

#### P1-3: 商店刷新/锁定机制
**状态**: ❌ 未实现
**说明**:
- `_refresh_shop_items()` 仅刷新UI显示
- 无手动刷新按钮
- 无锁定功能
- 无免费/付费刷新计数
**涉及文件**: shop_ui.gd

#### P1-4: 物品出售功能
**状态**: ❌ 未实现
**说明**:
- shop_ui.gd 和 inventory_ui.gd 均无 sell 相关代码
**涉及文件**: inventory_ui.gd 或 shop_ui.gd

#### P1-5: 合成系统重构
**状态**: ⚠️ 需确认
**说明**:
- 现有合成逻辑在 `shop_ui.gd`：两个同稀有度 → 更高稀有度
- 策划文档**无合成系统**
- 需 PM 确认：移除？还是作为扩展功能保留？
**涉及文件**: shop_ui.gd

---

### 🟢 P2 — 体验优化

#### P2-1: 背包拖拽排列
**状态**: ⚠️ 部分实现
**说明**:
- `inventory_ui.gd` 有完整拖拽框架：dragging_item, drag_start_slot, drag_ghost, item_drag_started/ended 信号
- 约54处 drag/Drag/_input 相关代码
- 需验证是否完整可用
**涉及文件**: inventory_ui.gd

#### P2-2: 物品详情面板完善
**状态**: ⚠️ 部分实现
**说明**:
- `item_detail_panel.gd` 存在（引用 ItemData + LinearInventory）
- 需验证信息完整度
**涉及文件**: item_detail_panel.gd

#### P2-3: 怪物选择独立界面
**状态**: ❌ 未实现
**说明**:
- 怪物选择在 battle_ui.gd 内部处理，无独立场景
- 策划要求 MonsterSelect.tscn
**涉及文件**: 新建 monster_select_ui.gd

#### P2-4: 场景切换系统
**状态**: ❌ 未实现
**说明**:
- 单场景 main.tscn，所有面板通过 visible 切换
- 策划要求6个独立场景
**涉及文件**: 场景重构

#### P2-5: 关键词补全（Slow/Freeze/Haste/Destroy + 温度）
**状态**: ⚠️ 部分实现
**说明**:
- ✅ `item_effects.gd` 定义了常量：EFFECT_STUN, EFFECT_FREEZE
- ✅ `item_data.gd` 有 stun_duration, is_immune 字段
- ✅ `item_data.gd` has_special_effect() 检测 stun/immune
- ❌ Slow（减速）：未实现
- ❌ Haste（加速）：未实现（passive_skill 有 COOLDOWN_REDUCTION 但非物品关键词）
- ❌ Destroy（摧毁）：未实现
- ❌ 温度状态（Heated/Chilled）：未实现
- ❌ 上述关键词在 battle_system 的 _process_active_effects 中未处理
**涉及文件**: item_data.gd, item_effects.gd, battle_system.gd

---

## 补充发现（策划案有但未列出）

#### P0-6（补充）: 被动技能效果不完整
**说明**: `passive_skill.gd` 中 SHIELD_BONUS/COOLDOWN_REDUCTION/DAMAGE_REFLECTION/LIFESTEAL 的 `apply_to_hero()` 都是 `pass`（空实现），实际效果在 battle_system 中处理，但 battle_system 仅处理了 LIFESTEAL 和 DAMAGE_REFLECTION。**SHIELD_BONUS 仅在战斗开始时一次性转化为治疗**，不够完整。

#### P1-6（补充）: 物品协同系统
**说明**: 策划"物品系统§六 物品协同"定义了基础协同（剑+盾、两把同武器+20%），当前完全未实现。

#### P1-7（补充）: 物品被动效果
**说明**: 策划定义力量戒指（被动 Damage+5）、速度护符（被动 CD-0.5s），当前物品被动效果无实现。

---

## 汇总表

| 编号 | 任务 | 状态 | 工作量 |
|------|------|------|--------|
| P0-1 | 24个MVP物品数据化 | ❌ 未实现 | 大 |
| P0-2 | 触发链系统 | ❌ 未实现 | 大 |
| P0-3 | 怪物扩展到10个 | ❌ 未实现 | 中 |
| P0-4 | 英雄物品池限制 | ⚠️ 框架存在 | 小 |
| P0-5 | 战利品系统 | ❌ 未实现 | 中 |
| P0-6 | 被动技能效果补全 | ⚠️ 部分 | 小 |
| P1-1 | 英雄 ATK/DEF | ❌ 未实现 | 中 |
| P1-2 | 技能系统扩展 | ⚠️ 部分 | 中 |
| P1-3 | 商店刷新/锁定 | ❌ 未实现 | 小 |
| P1-4 | 物品出售 | ❌ 未实现 | 小 |
| P1-5 | 合成系统（保留，标记为审视） | ⚠️ 保留待审视 | 小 |
| P1-6 | 物品协同系统 | ❌ 未实现 | 中 |
| P1-7 | 物品被动效果 | ❌ 未实现 | 小 |
| P2-1 | 背包拖拽 | ⚠️ 框架存在 | 验证 |
| P2-2 | 详情面板 | ⚠️ 存在 | 验证 |
| P2-3 | 怪物选择UI | ❌ 未实现 | 中 |
| P2-4 | 场景切换 | ❌ 未实现 | 大 |
| P2-5 | 关键词补全 | ⚠️ 部分 | 中 |

**统计**: ❌ 未实现 11项 / ⚠️ 部分实现 6项 / ✅ 已实现 0项（来自差距清单）
