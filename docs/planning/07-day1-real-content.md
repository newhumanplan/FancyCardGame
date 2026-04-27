# Day 1 真实内容实现文档

更新时间：2026-04-27

本文件记录 demo 阶段已经接入的 The Bazaar 真实 Day 1 内容范围。Mak 与 Day 1 事件/商人仍以本文件为准；全量怪物目录已经拆到 `docs/planning/08-monster-wiki-catalog.md`：

- Mak 的完整 wiki 道具池（Cargo `collection HOLDS 'Mak'`，含不同起始品级）
- Day 1 可遇到的怪物（全量怪物见 08 文档）
- Day 1 可出现的通用事件与 Mak 相关事件

## 数据来源

主要来源：

- [The Bazaar Wiki - Mak](https://thebazaar.wiki.gg/wiki/Mak)
- [The Bazaar Wiki - Mak Items](https://thebazaar.wiki.gg/wiki/Mak_Items)
- [The Bazaar Wiki - Monsters](https://thebazaar.wiki.gg/wiki/Monsters)
- [The Bazaar Wiki - Events](https://thebazaar.wiki.gg/wiki/Events)
- [The Bazaar Wiki - Viper](https://thebazaar.wiki.gg/wiki/Viper)
- [The Bazaar Wiki - Banannabal](https://thebazaar.wiki.gg/wiki/Banannabal)
- [The Bazaar Wiki - Fanged Inglet](https://thebazaar.wiki.gg/wiki/Fanged_Inglet)
- [The Bazaar Wiki - Haunted Kimono](https://thebazaar.wiki.gg/wiki/Haunted_Kimono)
- [The Bazaar Wiki - Kyver Drone](https://thebazaar.wiki.gg/wiki/Kyver_Drone)
- [The Bazaar Wiki - Pyro](https://thebazaar.wiki.gg/wiki/Pyro)

补充校验来源：

- wiki.gg Cargo 表：`Special:CargoTables/items`、`Special:CargoTables/events`
- BazaarDB 页面可作为 2026 年新 patch 的对照，但本次以 wiki.gg 为权威；BazaarDB 经常有 Cloudflare 拦截，不能作为 ACP 自动抓取的唯一来源。

## 当前代码入口

真实内容集中在：

- `/Users/Allenz/Projects/FancyCardGame/scripts/data/bazaar_content.gd`
- `/Users/Allenz/Projects/FancyCardGame/scripts/data/wiki_monster_catalog.gd`
- `/Users/Allenz/Projects/FancyCardGame/tools/fetch_bazaar_wiki_catalog.py`

禁止再在 UI 或战斗脚本里新增临时怪物、临时事件、临时 Mak 道具。需要补数据时，应先扩展 `BazaarContent`，再由 UI/战斗层消费。

## Mak Demo 角色

| 字段 | 当前值 | 来源/说明 |
| --- | --- | --- |
| 角色名 | Mak | wiki |
| 玩法标签 | Potion, Reagent, Burn, Poison, Regen | wiki |
| Demo HP | 100 | 当前工程默认值；wiki 页面没有稳定暴露英雄初始 HP，后续需用客户端实测确认 |
| 基础暴击 | 5% | 当前工程默认值；后续需用客户端实测确认 |
| 可用道具池 | Mak item catalog | wiki Cargo items |

## Mak 道具池

已录入 `MAK_BRONZE_ITEMS` 与 `MAK_ADDITIONAL_ITEMS`，通过 `BazaarContent.get_mak_item_specs()` 统一消费，并用于商店、事件奖励和 Mak 英雄可用道具池。

当前已覆盖 110+ 条 Mak wiki 道具数据。Bronze 初始可购池继续保留在 `MAK_BRONZE_ITEMS`，Silver/Gold/Diamond 起始道具进入 `MAK_ADDITIONAL_ITEMS`，数值按 `starting_tier` 对齐，不再用旧的稀有度倍率二次放大。

| 道具 | 尺寸 | 冷却 | Bronze 数值 |
| --- | --- | --- | --- |
| Aludel | Medium | 7.0 | Poison 4 |
| Barbed Claws | Small | 6.0 | Damage 5 |
| Bottled Lightning | Small | 6.0 | Damage 20, Burn 2, Ammo 1, Crit 100% |
| Calcinator | Medium | 7.0 | Burn 6 |
| Candles | Medium | 9.0 | Burn 8 |
| Emerald | Small | 7.0 | Poison 1 |
| Fire Potion | Small | 5.0 | Burn 6, Ammo 1 |
| Fireflies | Small | 7.0 | Burn 3 |
| Fungal Spores | Small | 5.0 | Poison item scaling effect |
| Hourglass | Small | Passive | Adjacent cooldown reduction |
| Ice Claw | Medium | 9.0 | Damage 40, Freeze 1 item |
| Incense | Small | 6.0 | Slow 1 item, Regen 2 |
| Leeches | Medium | 8.0 | Damage 20, Lifesteal |
| Letter Opener | Small | 5.0 | Damage 10, Crit 100% |
| Magic Carpet | Medium | 6.0 | Damage 50 |
| Mortar & Pestle | Medium | 7.0 | Lifesteal weapon scaling effect |
| Mothmeal | Small | 5.0 | Slow 1 item |
| Myrrh | Small | 6.0 | Regen 1 |
| Nightshade | Medium | 6.0 | Poison 6 |
| Noxious Potion | Small | 5.0 | Poison 3, Ammo 1 |
| Optical Augment | Small | Passive | Start-fight self Poison / Crit link |
| Peacewrought | Medium | 8.0 | Regen 2 |
| Philosopher's Stone | Small | 5.0 | Regen 1 |
| Potion Potion | Medium | 2.0 | Transform into 2 small Potions, Ammo 1 |
| Quill and Ink | Small | 7.0 | Poison 1, Regen 1 |
| Refractor | Medium | 6.0 | Damage 20 |
| Retort | Medium | 6.0 | Poison 6 |
| Ruby | Small | 10.0 | Burn 3 |
| Smelling Salts | Small | 7.0 | Slow 1 item |
| Spider Mace | Small | 10.0 | Damage 10 |
| Sulphur | Small | 7.0 | Burn 2 |
| Sword Cane | Medium | 4.0 | Damage 10 |
| Tazidian Dagger | Small | 6.0 | Damage 5 |
| Venom | Small | Passive | Left weapon Poison trigger |
| Venomander | Small | 6.0 | Poison 1, Regen 1 |
| Venomous Dose | Small | 4.0 | Poison both players 2, gain Regen 2 |

注意：表中只列早期 demo 重点 Bronze 道具的战斗关键值。完整列表以代码和 wiki Cargo 为准；新增道具已接入图片、尺寸、cost、cooldown、ammo、tags、tooltip 原文和可解析的基础战斗数值。

## Day 1 怪物池

| 怪物 | Tier | HP | Gold | XP | 技能 | 道具 |
| --- | --- | --- | --- | --- | --- | --- |
| Banannabal | Bronze | 100 | 2 | 2 | Overheal Haste | Med Kit, Bluenanas, Duct Tape |
| Fanged Inglet | Bronze | 100 | 2 | 2 | Deadly Eye | Pelt, Fang |
| Haunted Kimono | Bronze | 100 | 2 | 2 | Haunting Flight | Scrap, Silk Scarf |
| Kyver Drone | Bronze | 100 | 2 | 2 | Trained | Insect Wing, Stinger, Langxian, Eagle Talisman |
| Pyro | Bronze | 100 | 2 | 2 | Fiery | Cinders, Lighter |
| Viper | Silver | 75 | 3 | 2 | Lash Out | Gland, Fang, Extract |

当前实现：

- Day 1 PvE 从以上真实怪物池随机生成。
- 怪物道具沿用玩家同一套 10 格棋盘 UI。
- 有冷却道具会正常倒计时并触发。
- Pyro 的 Fiery 已应用到 Lighter：Bronze Lighter 基础 Burn 2，怪物技能 +1，因此战斗表现为 Burn 3。
- Viper 的 Lash Out 在战斗开始时对玩家施加 3 点 Poison；Poison 按真实状态 tick 结算，不再立即近似扣血。
- Potion Potion 已按“本场战斗变形成 2 个小型 Potion，战斗结束后恢复原物品”实现。
- Quill and Ink 的 Poison 与 Regen 已进入真实战斗状态池：Poison 每秒结算，Regen 每秒回血并在 Poison 伤害前抵消等量 Poison。
- Day 1 / Mak 道具的核心跨物品战斗交互已经接入统一的 item-use hook：
  - Venom：监听左侧 Weapon 使用，施加 2/3/4/5 Poison；自身为 Passive，不会单独按 tick 触发。
  - Slow / Freeze / Haste：已接入通用冷却调度近似实现；Slow/Freeze 会延后敌方物品冷却，Haste 会推进己方物品冷却。
  - Duct Tape：监听左侧 item 使用并 Shield 5/10/15/15；玩家和怪物共用同一规则，主动 Slow 已接入。
  - Candles / Spider Mace：Small item use 或 Poison 事件会按规则 Charge 当前冷却。
  - Emerald / Ruby / Fungal Spores：会给其他 item 或 Poison/Burn item 添加战斗期 Poison/Burn 加成。
  - Nightshade / Refractor / Leeches：会响应 Heal/Regen、Poison、Burn 事件获得本场战斗成长。
  - Aludel / Quill and Ink / Barbed Claws：已按条件计算 Multicast。
  - Sword Cane：已根据相邻 Regen/Burn/Poison item 追加对应状态。
  - Venomous Dose：已同时 Poison 双方并给玩家 Regen。
  - Hourglass：已在战斗开始与重置冷却时降低相邻 item cooldown。

当前尚未完整模拟：

- Overheal Haste 的真实触发。
- Deadly Eye 对怪物武器的暴击加成。
- Haunting Flight 的 Flying 机制。
- Trained 的 Slow 后武器成长。

## Day 1 事件池

`BazaarContent.DAY1_EVENT_SPECS` 已按 wiki `Category:Event` 补齐 Day 1 可遇到且非其他英雄专属的事件。事件 option 必须使用真实事件名、真实 wiki 插图和真实出现时间，不再回退到 `treasure` / `camp` / 泛用占位卡。

| 事件 | 出现时间 | wiki 效果摘要 | 当前 demo 实现 |
| --- | --- | --- | --- |
| A Strange Mushroom | Day 1-2 | Mak 可 Brew a small Silver-tier Potion；也可 Sell It 得 4 Gold | 给 Mak 一个 small Silver Potion；背包满则得 4 Gold |
| Armory | Day 1+ | Get a free Weapon | 给一个 Mak Weapon |
| B1&B2 | Day 1, Hour 4 - Day 6 | Upgrade 1 Bronze-tier item | 升级背包中第一个 Bronze 道具 |
| Battlefield | Day 1+ | Get a free small Weapon | 给一个 small Mak Weapon |
| Borrow | Day 1-2 / 3-4 / 5-6 | Lose 1 Income and gain 8/7/6 Gold | 按天数扣 1 Income，给 8/7/6 Gold |
| Botanical Gardens | Day 1+ | Get a free Poison item | 给一个 Mak Poison item |
| Cache of Riches | Day 1+ | Gain 3/4/5 Gold | 按天数给 3/4/5 Gold |
| Candy Stash | Day 1-3 / 4-6 / 7-9 / 10+ | Get 3 Chocolate Bars | 给 3 个 Chocolate Bar |
| Cinder Chase | Day 1+ | Get Cinders | 给 Cinders |
| Extract Extract | Day 1+ | Get an Extract (+Poison) | 给 Extract |
| Finn's Big Bite | Day 1+ | Gain max Health | 当前按 level 给 Max Health |
| Furnace | Day 1+ | Get a small Burn item | 给 small Mak Burn item |
| Guard Locker | Day 1+ | Get a small Shield item | 给 small Mak Shield item |
| House Party | Day 1+ | Get a small Friend | 给 small Mak Friend |
| Invest in Yourself | Day 1-3 / 3-6 | Gain Income | 按天数给 Income |
| Jungle Ruins | Day 1-2 | Mak 可 Hunt for Reagents | 给 Silver Reagent |
| Look for Spare Change | Day 1+ | Get 3 Spare Change | 当前以 3 Gold 代替 Spare Change 道具 |
| Lost and Found | Day 1+ | Get a small non-Weapon item | 给 small non-Weapon item |
| Medicine Cabinet | Day 1+ | Get a small Heal or Regeneration item | 给 small Heal/Regen item |
| Obstacle Course | Day 1+ | Get a Slow item | 给 Slow item |
| Procure Medkit | Day 1+ | Get a Med Kit (+Heal) | 给 Med Kit |
| Racetrack | Day 1+ | Get a Haste item | 当前给 Smelling Salts |
| Regenerative Tincture | Day 1+ | Gain Regeneration equal to level | 当前给 Regen item |
| Relax | Day ?-3+ | Start next fight with 100 Shield per Level | 当前以被动形式加开战护盾；尚未做“仅下一场”自动过期 |
| Recycling Center | Day 1+ | Get a non-Weapon item | 给 non-Weapon item |
| Scrap Salvage | Day 1+ | Get Scrap (+Shield) | 给 Scrap |
| Sharpening Kit | Day 1+ | Get Sharpening Stone (+Damage) | 当前给 small Damage item |
| Snack Time | Day 1+ | Gain 20 Max Health per level | 按 level 给 Max Health |
| The Lost Crate | Day 1-5 | Open for Medium item / Return for Skill | 当前取 Open It：给 Medium Mak item |
| Tiny Furry Monster | Day 1, Hour 4 - Day 2 | Pet It +25 Max Health | +25 Max Health |
| Treasure Chest | Day 1+ | Get an item | 给 random Mak item |

## Day 1 商人池

`BazaarContent.DAY1_MERCHANT_SPECS` 已接入 wiki `Merchants` 页面中 day 1+、Mak 可用的 item merchant，并下载 portrait 到 `assets/art/merchants/wiki/`。

| 商人 | 出现时间 | 类型 | 当前 demo 实现 |
| --- | --- | --- | --- |
| Aila | Day 1+ | Weapon | 货架优先生成 Weapon |
| Ande | Day 1+ | Small | 货架优先生成 Small |
| Barkun | Day 1+ | Medium, Large | 当前以 Medium 为主 |
| Colt | Day 1+ | Ammo | 货架优先生成 Ammo |
| Curio | Day 1+ | Bronze, Junk | 货架优先生成 Bronze Junk |
| Eli | Day 1+ | Potion | 货架优先生成 Potion |
| Jay Jay | Day 1+ | Items | 通用 Mak item |
| Kina | Day 1+ | NonWeapon | 通用非武器限制后续补强 |
| Midsworth | Day 1+ | Small, Large | 当前以 Small 为主 |
| Silvia | Day 1+ | Silver | 可生成 Silver-tier item |

## Event Option 生成

当前 demo 采用真实内容优先的保守规则：

- PvE Hour：生成 3 个真实 Day 1 monster option。
- PvP Hour：生成 1 个 ghost/PvP option。
- 构筑 Hour：生成 1 个真实 Day 1 merchant + 2 个真实 Day 1 event。
- 随机 event 按 day range 与 weight 筛选，同一轮三选一内不重复。
- 禁止恢复早期占位 `treasure` / `camp` option；如果需要宝箱、休息、服务商人，应先补真实数据，再作为具体 event/vendor 放入池。

参考来源：

- The Bazaar Wiki `Category:Event` / 各 event 页面用于 event 名称、day range、效果摘要：https://thebazaar.wiki.gg/wiki/Category:Event
- The Bazaar Wiki `Merchants` / 各 merchant 页面用于 merchant 名称、day、type、portrait：https://thebazaar.wiki.gg/wiki/Merchants
- Mobalytics Day Guide 用于 day/hour 节奏参考：day 里有 PvE encounter、ghost/PvP fight，并提到 PvE 前可把物品放进 Stash：https://mobalytics.gg/the-bazaar/guides/day-guide

## 实现边界

本轮目标是“把临时占位符替换为真实第一天内容”，不是一次性复刻完整 The Bazaar 引擎。当前已经做到：

- 真实名称、tier、HP、Gold、XP、道具名、尺寸、冷却、主要数值。
- 商店、事件、PvE 都从真实数据层取内容。
- tips 使用真实 effect 文本。
- Burn/Poison/Regen 的基础 tick 规则已落地：Burn 0.5 秒一跳且跳后衰减 1，Poison 1 秒一跳且不自然衰减，Regen 1 秒回血并先抵消 Poison。

状态规则来源：

- Burn: https://thebazaar.wiki.gg/wiki/Burn
- Poison: https://thebazaar.wiki.gg/wiki/Poison
- Regeneration: https://thebazaar.wiki.gg/wiki/Regeneration
- Potion Potion: https://thebazaar.wiki.gg/wiki/Potion_Potion

仍需后续拆分的系统：

- Ammo 消耗与 Reload。
- Slow、Freeze、Haste、Flying 的真实状态机；当前只保留会影响已实现 hook 的 item-use 行为。
- Transform、Catalyst、Enchant。
- Sell trigger：Cinders、Extract、Scrap、Gland、Med Kit、Eagle Talisman 等出售触发仍未接入。
- Tazidian Dagger 的 Potion Ammo 加成、Letter Opener 的战斗期 Crit 递减、完整的 Enchantment 变体。
- “next fight only” 类型事件效果的过期。
- 战斗奖励选择 UI：胜利后应展示怪物 item/skill reward，而不是只结算 gold/xp。
