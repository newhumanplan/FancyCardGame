# 全量怪物 Wiki 目录接入记录

更新时间：2026-04-27

本文件记录 The Bazaar 怪物、相关道具和怪物技能的全量接入方式。目标是让后续 ACP/Codex 开发不再手写占位怪物，而是先从 wiki 生成的权威目录取数据。

## 数据来源

- The Bazaar Wiki `Category:Monsters`: https://thebazaar.wiki.gg/wiki/Category:Monsters
- The Bazaar Wiki Cargo `items`: https://thebazaar.wiki.gg/wiki/Special:CargoTables/items
- The Bazaar Wiki Cargo `skills`: https://thebazaar.wiki.gg/wiki/Special:CargoTables/skills
- 示例校验页面：Viper / Banannabal / Boarrior / Coconut Crab / Giant Mosquito

## 生成入口

脚本：

`/Users/Allenz/Projects/FancyCardGame/tools/fetch_bazaar_wiki_catalog.py`

输出：

`/Users/Allenz/Projects/FancyCardGame/scripts/data/wiki_monster_catalog.gd`

生成命令：

```bash
python3 tools/fetch_bazaar_wiki_catalog.py --project-root .
```

需要同步下载 wiki 插图时：

```bash
python3 tools/fetch_bazaar_wiki_catalog.py --project-root . --download-assets
```

## 当前覆盖

`WikiMonsterCatalog` 当前从 wiki 生成：

| 类型 | 数量 | 说明 |
| --- | ---: | --- |
| 怪物 | 101 | 来自 `Category:Monsters`，过滤 namespace 0 页面 |
| 相关道具 | 332 | 包含 `collection HOLDS "Monster"` 和所有怪物 board 引用的跨英雄道具 |
| 相关技能 | 133 | 包含 `collection HOLDS "Monster"` 和所有怪物 page 引用的技能 |

PvE 选项现在按 `day == monster.level` 从 `WikiMonsterCatalog` 取怪物。Day 1 仍然得到真实 6 个早期怪物；Day 2 起会进入对应 level 的全量怪物池。

## 运行时代码入口

- `/Users/Allenz/Projects/FancyCardGame/scripts/data/bazaar_content.gd`
  - `get_all_monster_specs()`
  - `get_monster_specs_for_day(day)`
  - `create_monster(monster_id, level)`
  - `create_day1_monster(monster_id)` 作为兼容入口保留
- `/Users/Allenz/Projects/FancyCardGame/scripts/data/event_manager.gd`
  - PvE hour 使用 `get_monster_specs_for_day(day)`
- `/Users/Allenz/Projects/FancyCardGame/scripts/main.gd`
  - 事件选择里的 `monster_id` 会传入实际战斗，不再选 A 打 B

## 已实现的通用战斗效果

生成器会从 wiki effect 文本解析以下基础数值，并转成 `ItemData` / monster item 字段：

- Damage
- Shield
- Heal
- Burn
- Poison
- Regeneration
- Slow count / duration
- Freeze count / duration
- Haste count / duration
- Crit chance 数值展示

怪物技能已解析并运行的通用字段：

- `start_poison`
- `start_burn`
- `start_shield`
- `burn_bonus`
- `poison_bonus`
- `shield_bonus`
- `damage_bonus`

这些字段覆盖了 Viper 的 Lash Out、Pyro 的 Fiery，以及部分后续怪物的开局状态和基础数值加成。

## 当前仍需专项实现的机制

以下 wiki 技能/道具效果无法只靠文本数值解析完全复刻，需要逐条进入战斗 hook 或 board hook：

- 复杂条件：first time、while above/below half health、when enemy uses、when item starts Flying。
- Board 定位：leftmost、adjacent、item to the left/right、front/back row 等精确引用。
- 经济/战外：sell、destroy、visit merchant、start of day、gain Prestige、recover Prestige。
- 变形/附魔：transform、enchant、copy、spawn specific item。
- 动态公式：equal to Max Health、equal to Poison/Regen/Burn、per item type、per cooldown、per value。
- 防死亡/无敌/清除状态：would die、take no damage、cleanse。
- 完整 crit 伤害与 multicast 的怪物侧模拟。

开发规则：新增怪物或技能功能时，不要在 UI 层写特殊判断。优先补 `BattleSystem` 的通用 hook；只有真实规则确实是命名特例时，才在 `source_id` / `skill_id` 分支里处理，并补测试。

## 验收测试

核心测试：

```bash
CODEX_GODOT_TEST=res://tests/test_bazaar_content.gd /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/.codex_test_runner.gd
CODEX_GODOT_TEST=res://tests/test_event_manager.gd /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/.codex_test_runner.gd
```

当前断言覆盖：

- wiki 全量怪物目录可用且数量 >= 100。
- Day 2 包含 Coconut Crab 和 Giant Mosquito。
- Boarrior 的多个单独 Cargo item query 能正确解析为 7 个道具。
- Boarrior 的 skill list 不会误吸 item query。
- Lash Out 的开局 Poison 被解析为 `start_poison`。
- Tusked Helm 这类怪物相关道具能解析出基础 Damage。
