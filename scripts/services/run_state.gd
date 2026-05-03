extends Node

## RunState - 天数/小时/声望/胜负统计
## 从 GameManager 提取

signal day_changed(day: int)
signal hour_changed(hour: int, phase_name: String)
signal prestige_changed(value: int)
signal battle_ended(won: bool, gold_reward: int)
signal last_chance_triggered()
signal run_failed()
signal pvp_wins_changed(value: int)
signal battle_start_status_bonus_changed(status_id: String, amount: float)

const STARTING_PRESTIGE: int = 20

var current_day: int = 1
var current_hour: int = 0
var prestige: int = STARTING_PRESTIGE
var max_prestige: int = STARTING_PRESTIGE
var prestige_zero_count: int = 0
var last_chance_used: bool = false
var wins: int = 0
var losses: int = 0
var pvp_wins: int = 0
var battle_start_status_bonuses: Dictionary = {}

func get_current_phase_name() -> String:
	return PhaseService.get_current_phase_name(current_hour)

func next_hour() -> void:
	current_hour += 1
	if current_hour >= PhaseService.MAX_HOURS_PER_DAY:
		current_hour = 0
		current_day += 1
		print("进入第 %d 天" % current_day)
		day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())

func add_prestige(amount: int) -> void:
	if amount <= 0:
		return
	prestige = clampi(prestige + amount, 0, max_prestige)
	prestige_changed.emit(prestige)

func remove_prestige(amount: int) -> Dictionary:
	var result: Dictionary = {
		"amount": maxi(amount, 0),
		"prestige": prestige,
		"last_chance": false,
		"run_failed": false,
	}
	if amount <= 0:
		return result

	var old_prestige: int = prestige
	prestige = maxi(prestige - amount, 0)
	prestige_changed.emit(prestige)
	result["prestige"] = prestige

	if old_prestige > 0 and prestige == 0:
		if not last_chance_used:
			last_chance_used = true
			prestige_zero_count = 1
			prestige = 1
			result["prestige"] = prestige
			result["last_chance"] = true
			print("Prestige 首次归零，触发 Last Chance")
			prestige_changed.emit(prestige)
			last_chance_triggered.emit()
		else:
			prestige_zero_count = 2
			result["run_failed"] = true
			print("Prestige 再次归零，Run 失败")
			run_failed.emit()

	return result

func get_prestige_bonus() -> float:
	return 1.0 + (float(prestige) / 100.0)

func get_prestige_percent() -> float:
	if max_prestige <= 0:
		return 0.0
	return float(prestige) / float(max_prestige)

func add_pvp_win() -> int:
	pvp_wins += 1
	pvp_wins_changed.emit(pvp_wins)
	return pvp_wins

func add_battle_start_status_bonus(status_id: String, amount: float, source: String = "") -> float:
	var normalized_id: String = str(status_id).strip_edges().to_lower()
	if normalized_id.is_empty() or amount <= 0.0:
		return float(battle_start_status_bonuses.get(normalized_id, 0.0))
	battle_start_status_bonuses[normalized_id] = float(battle_start_status_bonuses.get(normalized_id, 0.0)) + amount
	battle_start_status_bonus_changed.emit(normalized_id, float(battle_start_status_bonuses[normalized_id]))
	if not source.is_empty():
		print("Run battle-start status bonus %s +%.1f from %s" % [normalized_id, amount, source])
	return float(battle_start_status_bonuses[normalized_id])

func get_battle_start_status_bonuses() -> Dictionary:
	return battle_start_status_bonuses.duplicate(true)

func reset(full: bool = true) -> void:
	current_day = 1
	current_hour = 0
	wins = 0
	losses = 0
	pvp_wins = 0
	battle_start_status_bonuses.clear()
	if full:
		prestige = STARTING_PRESTIGE
		prestige_zero_count = 0
		last_chance_used = false
	day_changed.emit(current_day)
	hour_changed.emit(current_hour, get_current_phase_name())
	prestige_changed.emit(prestige)
	pvp_wins_changed.emit(pvp_wins)
