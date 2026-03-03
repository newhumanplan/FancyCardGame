extends Node
class_name StageManager

## 预加载资源类型
const UnitResource = preload("res://resources/unit.gd")

## 关卡管理器
## 负责管理游戏关卡流程、关卡数据和进度

# 当前关卡
var current_stage: int = 1

# 最大关卡数
var max_stage: int = 5

# 关卡数据缓存
var stage_data_cache: Dictionary = {}

# 信号定义
signal stage_changed(stage_num: int)
signal stage_complete(stage_num: int)
signal game_complete()
signal stage_started(stage_num: int)

func _ready() -> void:
	# 初始化关卡数据
	_init_stage_data()
	print("StageManager 已初始化 - 当前关卡: %d/%d" % [current_stage, max_stage])

## 初始化关卡数据
func _init_stage_data() -> void:
	# Stage 1: 简单敌人 (2-3只史莱姆)
	stage_data_cache[1] = {
		"stage_number": 1,
		"name": "新手森林",
		"description": "这里是史莱姆的栖息地，适合新手练习战斗技巧。",
		"enemy_count": 2,
		"enemy_types": ["slime", "slime"],
		"gold_reward": 30,
		"item_rewards": ["health_potion"],
		"difficulty": "easy"
	}
	
	# Stage 2: 中等敌人 (3-4只哥布林)
	stage_data_cache[2] = {
		"stage_number": 2,
		"name": "哥布林营地",
		"description": "一群危险的哥布林占据了这条路。",
		"enemy_count": 3,
		"enemy_types": ["goblin", "goblin", "goblin"],
		"gold_reward": 50,
		"item_rewards": ["health_potion", "mana_potion"],
		"difficulty": "medium"
	}
	
	# Stage 3: 精英敌人 (4-5只敌人)
	stage_data_cache[3] = {
		"stage_number": 3,
		"name": "骷髅洞穴",
		"description": "这里有大量骷髅战士把守。",
		"enemy_count": 4,
		"enemy_types": ["skeleton", "skeleton", "goblin", "goblin"],
		"gold_reward": 80,
		"item_rewards": ["health_potion", "iron_sword", "leather_armor"],
		"difficulty": "hard"
	}
	
	# Stage 4: Boss 预备 (5-6只敌人)
	stage_data_cache[4] = {
		"stage_number": 4,
		"name": "半兽人大本营",
		"description": "半兽人首领的巢穴，击败他们就能挑战最终Boss！",
		"enemy_count": 5,
		"enemy_types": ["orc", "orc", "goblin", "goblin", "skeleton"],
		"gold_reward": 120,
		"item_rewards": ["steel_sword", "chain_armor", "health_potion"],
		"difficulty": "hard"
	}
	
	# Stage 5: Boss 关卡 (1 Boss + 小怪)
	stage_data_cache[5] = {
		"stage_number": 5,
		"name": "龙之巢穴",
		"description": "最终的挑战！击败恶龙，成为真正的英雄！",
		"enemy_count": 2,
		"enemy_types": ["dragon", "goblin"],
		"gold_reward": 300,
		"item_rewards": ["dragon_sword", "dragon_armor", "legendary_potion"],
		"difficulty": "boss"
	}

## 获取关卡数据
func get_stage_data(stage_num: int) -> Dictionary:
	if stage_data_cache.has(stage_num):
		return stage_data_cache[stage_num]
	return {}

## 获取当前关卡数据
func get_current_stage_data() -> Dictionary:
	return get_stage_data(current_stage)

## 进入下一关
func next_stage() -> bool:
	if current_stage >= max_stage:
		game_complete.emit()
		return false
	
	current_stage += 1
	stage_changed.emit(current_stage)
	print("进入第 %d 关: %s" % [current_stage, get_stage_data(current_stage).get("name", "")])
	return true

## 完成当前关卡
func complete_stage() -> void:
	stage_complete.emit(current_stage)
	print("第 %d 关完成！获得奖励: %d 金币" % [current_stage, get_stage_data(current_stage).get("gold_reward", 0)])

## 重置关卡进度
func reset_stages() -> void:
	current_stage = 1
	stage_changed.emit(current_stage)
	print("关卡已重置")

## 获取敌人配置
func get_enemy_config(enemy_type: String) -> Dictionary:
	var configs := {
		"slime": {"name": "史莱姆", "hp": 50, "attack": 8, "defense": 2, "speed": 5},
		"goblin": {"name": "哥布林", "hp": 70, "attack": 12, "defense": 4, "speed": 8},
		"skeleton": {"name": "骷髅战士", "hp": 90, "attack": 15, "defense": 6, "speed": 7},
		"orc": {"name": "半兽人", "hp": 120, "attack": 18, "defense": 8, "speed": 6},
		"dragon": {"name": "炎龙", "hp": 200, "attack": 25, "defense": 12, "speed": 10}
	}
	return configs.get(enemy_type, {"name": enemy_type, "hp": 50, "attack": 10, "defense": 5, "speed": 5})

## 根据关卡生成敌人
func generate_enemies_for_stage() -> Array:
	var stage := get_current_stage_data()
	if stage.is_empty():
		return []
	
	var enemies: Array = []
	var enemy_types: Array = stage.get("enemy_types", [])
	
	for i in range(enemy_types.size()):
		var enemy_type: String = enemy_types[i]
		var config: Dictionary = get_enemy_config(enemy_type)
		
		# 根据关卡难度调整属性
		var hp_mult := 1.0
		var atk_mult := 1.0
		var def_mult := 1.0
		
		match stage.get("difficulty", "easy"):
			"medium":
				hp_mult = 1.2
				atk_mult = 1.15
				def_mult = 1.1
			"hard":
				hp_mult = 1.4
				atk_mult = 1.3
				def_mult = 1.2
			"boss":
				hp_mult = 1.6
				atk_mult = 1.5
				def_mult = 1.4
		
		var enemy := UnitResource.new(
			config.get("name", enemy_type) + " Lv." + str(current_stage),
			int(config.get("hp", 50) * hp_mult),
			int(config.get("attack", 10) * atk_mult),
			int(config.get("defense", 5) * def_mult),
			config.get("speed", 5),
			0.05,
			1.5
		)
		enemies.append(enemy)
	
	return enemies

## 获取关卡进度文本
func get_progress_text() -> String:
	return "第 %d 关 / 共 %d 关" % [current_stage, max_stage]

## 检查是否已完成所有关卡
func is_game_complete() -> bool:
	return current_stage >= max_stage

## 获取当前关卡难度
func get_current_difficulty() -> String:
	return get_stage_data(current_stage).get("difficulty", "easy")
