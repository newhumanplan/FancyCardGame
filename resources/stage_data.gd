extends Resource
class_name StageData

## 关卡数据资源
## 用于存储单个关卡的配置数据

@export var stage_number: int = 1
@export var stage_name: String = "新手森林"
@export var description: String = "这里是史莱姆的栖息地"
@export var enemy_count: int = 2
@export var enemy_types: Array[String] = ["slime", "slime"]
@export var gold_reward: int = 30
@export var item_rewards: Array[String] = ["health_potion"]
@export var difficulty: String = "easy"

func _init(
	p_stage_number: int = 1,
	p_name: String = "",
	p_description: String = "",
	p_enemy_count: int = 2,
	p_enemy_types: Array[String] = [],
	p_gold_reward: int = 30,
	p_item_rewards: Array[String] = [],
	p_difficulty: String = "easy"
) -> void:
	stage_number = p_stage_number
	stage_name = p_name
	description = p_description
	enemy_count = p_enemy_count
	enemy_types = p_enemy_types
	gold_reward = p_gold_reward
	item_rewards = p_item_rewards
	difficulty = p_difficulty

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"stage_number": stage_number,
		"name": stage_name,
		"description": description,
		"enemy_count": enemy_count,
		"enemy_types": enemy_types,
		"gold_reward": gold_reward,
		"item_rewards": item_rewards,
		"difficulty": difficulty
	}

## 从字典创建
static func from_dict(data: Dictionary) -> StageData:
	return StageData.new(
		data.get("stage_number", 1),
		data.get("name", ""),
		data.get("description", ""),
		data.get("enemy_count", 2),
		data.get("enemy_types", []),
		data.get("gold_reward", 30),
		data.get("item_rewards", []),
		data.get("difficulty", "easy")
	)
