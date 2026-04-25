extends Node
const HeroDataClass = preload("res://scripts/data/hero_data.gd")

## HeroState - 英雄/生命值管理
## 从 GameManager 提取

signal health_changed(amount: int)
signal max_health_changed(value: int)
signal xp_changed(value: int)
signal level_changed(value: int)
signal level_up(level: int)

const XP_PER_LEVEL: int = 8

var selected_hero: HeroDataClass = null
var player_health: int = 100
var xp: int = 0
var level: int = 1

func select_hero(hero: HeroDataClass) -> void:
	selected_hero = hero
	player_health = hero.max_hp if hero else 100
	if selected_hero != null:
		selected_hero.current_hp = player_health
		print("已选择英雄: %s (%s)" % [hero.hero_name, hero.get_type_name()])
	health_changed.emit(player_health)

func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual: int = mini(amount, player_health)
	player_health -= actual
	if selected_hero != null:
		selected_hero.current_hp = player_health
	health_changed.emit(player_health)
	return actual

func heal(amount: int) -> void:
	if amount <= 0:
		return
	player_health = mini(player_health + amount, get_max_health())
	if selected_hero != null:
		selected_hero.current_hp = player_health
	health_changed.emit(player_health)

func get_max_health() -> int:
	if selected_hero == null:
		return 100
	return selected_hero.max_hp

func add_xp(amount: int) -> Dictionary:
	var result: Dictionary = {
		"amount": maxi(amount, 0),
		"old_xp": xp,
		"new_xp": xp,
		"old_level": level,
		"new_level": level,
		"levels_gained": [],
	}
	if amount <= 0:
		return result
	xp += amount
	while xp >= XP_PER_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		result["levels_gained"].append(level)
		level_changed.emit(level)
		level_up.emit(level)
	xp_changed.emit(xp)
	result["new_xp"] = xp
	result["new_level"] = level
	return result

func add_max_health(amount: int) -> int:
	if amount <= 0 or selected_hero == null:
		return 0
	selected_hero.max_hp += amount
	player_health = mini(player_health + amount, selected_hero.max_hp)
	selected_hero.current_hp = player_health
	max_health_changed.emit(selected_hero.max_hp)
	health_changed.emit(player_health)
	return amount

func reset() -> void:
	selected_hero = null
	player_health = 100
	xp = 0
	level = 1
	health_changed.emit(player_health)
	max_health_changed.emit(get_max_health())
	xp_changed.emit(xp)
	level_changed.emit(level)
