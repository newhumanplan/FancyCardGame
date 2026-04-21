extends Node
const HeroDataClass = preload("res://scripts/data/hero_data.gd")

## HeroState - 英雄/生命值管理
## 从 GameManager 提取

signal health_changed(amount: int)

var selected_hero: HeroDataClass = null
var player_health: int = 100

func select_hero(hero: HeroDataClass) -> void:
	selected_hero = hero
	player_health = hero.max_hp if hero else 100
	print("已选择英雄: %s (%s)" % [hero.hero_name, hero.get_type_name()])

func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual: int = mini(amount, player_health)
	player_health -= actual
	health_changed.emit(-actual)
	return actual

func heal(amount: int) -> void:
	if selected_hero == null:
		return
	player_health = mini(player_health + amount, selected_hero.max_hp)
	health_changed.emit(amount)

func get_max_health() -> int:
	if selected_hero == null:
		return 100
	return selected_hero.max_hp

func reset() -> void:
	selected_hero = null
	player_health = 100
