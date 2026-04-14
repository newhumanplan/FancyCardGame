class_name EventManager
extends RefCounted

## 事件管理器 — 管理事件注册、随机选择、效果执行
## 将 main.gd 中硬编码的事件逻辑提取到此模块

## 事件执行回调类型（由 main.gd 注入）
## 回调签名: func(event_type: String) -> void
var event_callback: Callable

## ============ 随机事件定义 ============

## 随机事件列表（ID, 名称, 图标, 权重）
var _random_events: Array[Dictionary] = [
	{"id": "merchant_bonus", "name": "慷慨商人", "icon": "💰", "weight": 15},
	{"id": "healing_fountain", "name": "治愈之泉", "icon": "⛲", "weight": 12},
	{"id": "pickpocket", "name": "遭遇小偷", "icon": "🦹", "weight": 10},
	{"id": "treasure", "name": "隐藏宝藏", "icon": "💎", "weight": 8},
	{"id": "heal", "name": "好心旅人", "icon": "🧑‍🤝‍🧑", "weight": 12},
	{"id": "bandits", "name": "遭遇盗贼", "icon": "🗡️", "weight": 10},
	{"id": "wounded_hero", "name": "受伤英雄", "icon": "🤕", "weight": 8},
	{"id": "storm", "name": "暴风雨", "icon": "⛈️", "weight": 8},
	{"id": "strange_merchant", "name": "神秘商人", "icon": "🎭", "weight": 8},
	{"id": "ancient_shrine", "name": "古老祭坛", "icon": "⛩️", "weight": 8},
	{"id": "thief_guild", "name": "盗贼公会", "icon": "🏴‍☠️", "weight": 6},
	{"id": "blessed_rest", "name": "受祝福的休息", "icon": "✨", "weight": 10},
]

func _build_option(text: String, option_type: String, event_id: String = "") -> Dictionary:
	var option := {"text": text, "type": option_type}
	if not event_id.is_empty():
		option["event_id"] = event_id
	return option

## ============ 事件选项生成 ============

## 生成事件选项列表（替代 main.gd 中的 _generate_event_options）
## 返回最多3个选项字典: [{"text": "...", "icon": "...", "type": "..."}]
func generate_options(hour: int, day: int) -> Array[Dictionary]:
	if hour == 4:
		return [_build_option("⚔️ PvP 对战", "pvp")]

	var options: Array[Dictionary] = []
	options.append(_build_option("🏪 商人", "shop"))
	options.append(_build_option("👹 怪物", "monster"))

	var extra_types := ["random_event", "treasure", "camp", "shop", "monster"]
	var extra_type: String = extra_types.pick_random()
	match extra_type:
		"random_event":
			var evt = _pick_random_event(day)
			if not evt.is_empty():
				options.append(_build_option("%s %s" % [evt.get("icon", ""), evt.get("name", "随机事件")], "random_event", str(evt.get("id", ""))))
		"treasure":
			options.append(_build_option("💎 宝库", "treasure"))
		"camp":
			options.append(_build_option("⛺ 营地", "camp"))
		"shop":
			options.append(_build_option("🏪 商人", "shop"))
		"monster":
			options.append(_build_option("👹 怪物", "monster"))

	options.shuffle()
	return options

## 按权重随机选择一个随机事件
func _pick_random_event(day: int) -> Dictionary:
	# 过滤掉不符合天数要求的事件
	var eligible: Array[Dictionary] = []
	for evt in _random_events:
		var min_day: int = int(evt.get("min_day", 0))
		var max_day: int = int(evt.get("max_day", 0))
		if day < min_day:
			continue
		if max_day > 0 and day > max_day:
			continue
		eligible.append(evt)

	if eligible.is_empty():
		return {}

	# 按权重随机
	var total_weight: int = 0
	for evt in eligible:
		total_weight += evt.get("weight", 10)

	if total_weight <= 0:
		return eligible[0]
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for evt in eligible:
		cumulative += evt.get("weight", 10)
		if roll < cumulative:
			return evt

	return eligible[0]

## ============ 事件效果执行 ============

## 执行随机事件效果（返回描述文本）
## game_manager: GameManager autoload 引用
func execute_random_event(event_id: String, day: int, game_manager: Node) -> String:
	if game_manager == null:
		return "事件执行失败: GameManager 不存在"
	match event_id:
		"merchant_bonus":
			var gold = 8 + day * 2
			game_manager.add_gold(gold)
			return "慷慨商人! 获得 %d 金币!" % gold

		"healing_fountain":
			var heal_amount = maxi(game_manager.get_max_health() / 4, 1)
			game_manager.heal(heal_amount)
			return "治愈之泉! 恢复 %d HP!" % heal_amount

		"pickpocket":
			var stolen = mini(game_manager.gold, 5 + day * 2)
			game_manager.spend_gold(stolen)
			return "遭遇小偷! 损失 %d 金币!" % stolen

		"treasure":
			var gold = 10 + day * 3
			game_manager.add_gold(gold)
			return "发现隐藏宝藏! 获得 %d 金币!" % gold

		"heal":
			var heal = 15 + day * 2
			game_manager.heal(heal)
			return "遇到好心旅人! 恢复 %d HP!" % heal

		"bandits":
			var damage = 5 + day * 3
			game_manager.take_damage(damage)
			return "遭遇盗贼! 受到 %d 点伤害!" % damage

		"wounded_hero":
			game_manager.add_prestige(3)
			game_manager.add_gold(5)
			return "救助受伤英雄! 获得 5 金币，+3 声望!"

		"storm":
			var lost = 3 + day * 2
			game_manager.spend_gold(lost)
			game_manager.take_damage(3)
			return "暴风雨! 损失 %d 金币，受到 3 点伤害!" % lost

		"strange_merchant":
			var gold = 20 + day * 3
			game_manager.add_gold(gold)
			game_manager.take_damage(5)
			return "神秘商人! 获得 %d 金币但受到诅咒损失 5 HP!" % gold

		"ancient_shrine":
			var bonus_crit = 0.02 + float(day) * 0.005
			if game_manager.selected_hero:
				game_manager.selected_hero.crit_chance = clampf(game_manager.selected_hero.crit_chance + bonus_crit, 0.0, 1.0)
			return "古老祭坛! 暴击率 +%.1f%% (永久)!" % (bonus_crit * 100)

		"thief_guild":
			var stolen = 5 + day * 2
			game_manager.spend_gold(stolen)
			return "盗贼公会! 被收取保护费 %d 金币!" % stolen

		"blessed_rest":
			var heal_amount = maxi(game_manager.get_max_health() / 3, 1)
			game_manager.heal(heal_amount)
			game_manager.add_gold(5)
			return "受到祝福的休息! 恢复 %d HP，获得 5 金币!" % heal_amount

		_:
			return "未知事件!"

## 执行宝库事件
func execute_treasure_event(day: int, game_manager: Node) -> String:
	if game_manager == null:
		return "事件执行失败: GameManager 不存在"
	var gold = 15 + day * 5
	game_manager.add_gold(gold)
	return "发现古代宝库! 获得 %d 金币!" % gold

## 执行营地事件
func execute_camp_event(day: int, game_manager: Node) -> String:
	if game_manager == null:
		return "事件执行失败: GameManager 不存在"
	var heal = 20 + day * 5
	game_manager.heal(heal)
	game_manager.add_prestige(2)
	return "营地休息! 恢复 %d HP，+2 声望!" % heal

## 获取所有注册的随机事件列表（用于 UI 展示或调试）
func get_all_events() -> Array[Dictionary]:
	return _random_events.duplicate(true)

## 获取事件总数
func get_event_count() -> int:
	return _random_events.size()
