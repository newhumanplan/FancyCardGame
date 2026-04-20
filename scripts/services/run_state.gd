extends Node

## RunState - 天数/小时/声望/胜负统计
## 从 GameManager 提取

signal day_changed(day: int)
signal hour_changed(hour: int, phase_name: String)
signal prestige_changed(value: int)
signal battle_ended(won: bool, gold_reward: int)

var current_day: int = 1
var current_hour: int = 0
var prestige: int = 20
var max_prestige: int = 100
var prestige_zero_count: int = 0
var wins: int = 0
var losses: int = 0
var pvp_wins: int = 0

## 阶段: 0=采购, 1=采购, 2=打怪, 3=采购, 4=PvP
const PHASE_HOURS = {
	0: "采购阶段",
	1: "采购阶段",
	2: "战斗阶段",
	3: "采购阶段",
	4: "PvP阶段"
}

func get_current_phase_name() -> String:
	return PHASE_HOURS.get(current_hour % 5, "未知")

func next_hour() -> void:
	current_hour += 1
	if current_hour >= 5:
		current_hour = 0
		current_day += 1
		print("进入第 %d 天" % current_day)
		day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

func add_prestige(amount: int) -> void:
	prestige = mini(prestige + amount, max_prestige)
	prestige_changed.emit(prestige)

func remove_prestige(amount: int) -> void:
	prestige -= amount
	if prestige <= 0:
		prestige = 0
		prestige_zero_count += 1
		print("Prestige 归零！次数: %d" % prestige_zero_count)
	prestige_changed.emit(prestige)

func get_prestige_bonus() -> float:
	return float(prestige) / 100.0

func get_prestige_percent() -> float:
	return float(prestige) / float(max_prestige)

func reset() -> void:
	current_day = 1
	current_hour = 0
	wins = 0
	losses = 0
	pvp_wins = 0
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())
