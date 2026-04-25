extends Node

const HeroDataClass = preload("res://scripts/data/hero_data.gd")

## GameManager 是旧代码兼容门面。
## 权威状态分别在 EconomyService / RunStateService / HeroStateService。

signal gold_changed(amount: int)
signal day_changed(day: int)
signal hour_changed(hour: int, phase_name: String)
signal health_changed(amount: int)
signal prestige_changed(value: int)
signal income_changed(amount: int)
signal xp_changed(value: int)
signal level_changed(value: int)
signal level_reward_applied(level: int, reward: Dictionary, summary: Dictionary)
signal game_over(won: bool)
signal futura_triggered()

var stats_total_battles: int = 0
var stats_total_wins: int = 0
var stats_total_losses: int = 0
var stats_total_gold_earned: int = 0

var gold: int:
	get:
		return EconomyService.gold
	set(value):
		EconomyService.gold = maxi(value, 0)
		EconomyService.gold_changed.emit(EconomyService.gold)

var income: int:
	get:
		return EconomyService.income
	set(value):
		EconomyService.income = maxi(value, 0)
		EconomyService.income_changed.emit(EconomyService.income)

var current_day: int:
	get:
		return RunStateService.current_day
	set(value):
		RunStateService.current_day = maxi(value, 1)
		RunStateService.day_changed.emit(RunStateService.current_day)

var current_hour: int:
	get:
		return RunStateService.current_hour
	set(value):
		RunStateService.current_hour = PhaseService.get_hour_index(value)
		RunStateService.hour_changed.emit(RunStateService.current_hour, get_current_phase_name())

var prestige: int:
	get:
		return RunStateService.prestige
	set(value):
		RunStateService.prestige = clampi(value, 0, RunStateService.max_prestige)
		RunStateService.prestige_changed.emit(RunStateService.prestige)

var max_prestige: int:
	get:
		return RunStateService.max_prestige
	set(value):
		RunStateService.max_prestige = maxi(value, 1)
		RunStateService.prestige = mini(RunStateService.prestige, RunStateService.max_prestige)
		RunStateService.prestige_changed.emit(RunStateService.prestige)

var prestige_zero_count: int:
	get:
		return RunStateService.prestige_zero_count
	set(value):
		RunStateService.prestige_zero_count = maxi(value, 0)

var wins: int:
	get:
		return RunStateService.wins
	set(value):
		RunStateService.wins = maxi(value, 0)

var losses: int:
	get:
		return RunStateService.losses
	set(value):
		RunStateService.losses = maxi(value, 0)

var pvp_wins: int:
	get:
		return RunStateService.pvp_wins
	set(value):
		RunStateService.pvp_wins = maxi(value, 0)
		RunStateService.pvp_wins_changed.emit(RunStateService.pvp_wins)

var selected_hero: HeroDataClass:
	get:
		return HeroStateService.selected_hero
	set(value):
		if value == null:
			HeroStateService.reset()
		else:
			HeroStateService.select_hero(value)

var player_health: int:
	get:
		return HeroStateService.player_health
	set(value):
		HeroStateService.player_health = clampi(value, 0, HeroStateService.get_max_health())
		if HeroStateService.selected_hero != null:
			HeroStateService.selected_hero.current_hp = HeroStateService.player_health
		HeroStateService.health_changed.emit(HeroStateService.player_health)

var xp: int:
	get:
		return HeroStateService.xp
	set(value):
		HeroStateService.xp = maxi(value, 0)
		HeroStateService.xp_changed.emit(HeroStateService.xp)

var level: int:
	get:
		return HeroStateService.level
	set(value):
		HeroStateService.level = maxi(value, 1)
		HeroStateService.level_changed.emit(HeroStateService.level)

func _ready() -> void:
	call_deferred("_connect_service_signals")
	print("GameManager 已初始化")

func _connect_service_signals() -> void:
	if not EconomyService.gold_changed.is_connected(_on_service_gold_changed):
		EconomyService.gold_changed.connect(_on_service_gold_changed)
	if not EconomyService.income_changed.is_connected(_on_service_income_changed):
		EconomyService.income_changed.connect(_on_service_income_changed)
	if not RunStateService.day_changed.is_connected(_on_service_day_changed):
		RunStateService.day_changed.connect(_on_service_day_changed)
	if not RunStateService.hour_changed.is_connected(_on_service_hour_changed):
		RunStateService.hour_changed.connect(_on_service_hour_changed)
	if not RunStateService.prestige_changed.is_connected(_on_service_prestige_changed):
		RunStateService.prestige_changed.connect(_on_service_prestige_changed)
	if not RunStateService.last_chance_triggered.is_connected(_on_service_last_chance_triggered):
		RunStateService.last_chance_triggered.connect(_on_service_last_chance_triggered)
	if not RunStateService.run_failed.is_connected(_on_service_run_failed):
		RunStateService.run_failed.connect(_on_service_run_failed)
	if not HeroStateService.health_changed.is_connected(_on_service_health_changed):
		HeroStateService.health_changed.connect(_on_service_health_changed)
	if not HeroStateService.xp_changed.is_connected(_on_service_xp_changed):
		HeroStateService.xp_changed.connect(_on_service_xp_changed)
	if not HeroStateService.level_changed.is_connected(_on_service_level_changed):
		HeroStateService.level_changed.connect(_on_service_level_changed)
	if not RewardService.level_reward_applied.is_connected(_on_service_level_reward_applied):
		RewardService.level_reward_applied.connect(_on_service_level_reward_applied)

func _on_service_gold_changed(amount: int) -> void:
	gold_changed.emit(amount)

func _on_service_income_changed(amount: int) -> void:
	income_changed.emit(amount)

func _on_service_day_changed(day: int) -> void:
	day_changed.emit(day)

func _on_service_hour_changed(hour: int, phase_name: String) -> void:
	hour_changed.emit(hour, phase_name)

func _on_service_prestige_changed(value: int) -> void:
	prestige_changed.emit(value)

func _on_service_health_changed(amount: int) -> void:
	health_changed.emit(amount)

func _on_service_xp_changed(value: int) -> void:
	xp_changed.emit(value)

func _on_service_level_changed(value: int) -> void:
	level_changed.emit(value)

func _on_service_level_reward_applied(level_value: int, reward: Dictionary, summary: Dictionary) -> void:
	level_reward_applied.emit(level_value, reward, summary)

func _on_service_last_chance_triggered() -> void:
	futura_triggered.emit()

func _on_service_run_failed() -> void:
	game_over.emit(false)

func get_current_phase_name() -> String:
	return PhaseService.get_current_phase_name(current_hour)

func next_hour() -> void:
	var previous_day: int = current_day
	RewardService.apply_reward({"xp": 1}, "hour_complete")
	RunStateService.next_hour()
	if current_day > previous_day:
		RewardService.apply_reward({"gold": EconomyService.income}, "day_income")

func is_pvp_hour() -> bool:
	return PhaseService.is_pvp_phase(current_hour)

func is_battle_hour() -> bool:
	return PhaseService.can_battle(current_hour)

func reset_day_hour() -> void:
	RunStateService.current_day = 1
	RunStateService.current_hour = 0
	RunStateService.day_changed.emit(RunStateService.current_day)
	RunStateService.hour_changed.emit(RunStateService.current_hour, get_current_phase_name())

func select_hero(hero: HeroDataClass) -> void:
	if hero == null:
		return
	HeroStateService.select_hero(hero)

func get_gold() -> int:
	return EconomyService.get_gold()

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	EconomyService.add_gold(amount)
	record_gold_earned(amount)

func add_income(amount: int) -> void:
	EconomyService.add_income(amount)

func add_xp(amount: int) -> Dictionary:
	return RewardService.apply_reward({"xp": amount}, "direct_xp")

func apply_reward(reward: Dictionary, source: String = "") -> Dictionary:
	return RewardService.apply_reward(reward, source)

func add_max_health(amount: int) -> int:
	return HeroStateService.add_max_health(amount)

func spend_gold(amount: int) -> bool:
	return EconomyService.spend_gold(amount)

func can_afford(amount: int) -> bool:
	return EconomyService.can_afford(amount)

func get_prestige_bonus() -> float:
	return RunStateService.get_prestige_bonus()

func get_prestige_percent() -> float:
	return RunStateService.get_prestige_percent()

func add_prestige(amount: int) -> void:
	RunStateService.add_prestige(amount)

func remove_prestige(amount: int) -> Dictionary:
	return RunStateService.remove_prestige(amount)

func buy_prestige(amount: int, cost: int) -> bool:
	return BattleProgressionService.buy_prestige(amount, cost)

func on_battle_win() -> void:
	BattleProgressionService.apply_battle_result(true, false)

func on_battle_lose() -> void:
	BattleProgressionService.apply_battle_result(false, false)

func on_pvp_win() -> void:
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, true)
	if bool(result.get("run_won", false)):
		finish_run(true)

func on_pvp_lose() -> void:
	BattleProgressionService.apply_battle_result(false, true)

func finish_run(won: bool) -> void:
	game_over.emit(won)

func get_max_health() -> int:
	return HeroStateService.get_max_health()

func take_damage(amount: int) -> int:
	return HeroStateService.take_damage(amount)

func heal(amount: int) -> void:
	HeroStateService.heal(amount)

func record_battle_win() -> void:
	stats_total_battles += 1
	stats_total_wins += 1

func record_battle_loss() -> void:
	stats_total_battles += 1
	stats_total_losses += 1

func record_gold_earned(amount: int) -> void:
	if amount > 0:
		stats_total_gold_earned += amount

func reset_stats() -> void:
	stats_total_battles = 0
	stats_total_wins = 0
	stats_total_losses = 0
	stats_total_gold_earned = 0
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()

func reset() -> void:
	reset_run("partial")

func reset_run(mode: String = "partial") -> void:
	match mode:
		"partial":
			EconomyService.reset()
			RunStateService.reset(false)
			HeroStateService.reset()
		"full":
			reset_stats()
		"stats":
			stats_total_battles = 0
			stats_total_wins = 0
			stats_total_losses = 0
			stats_total_gold_earned = 0
			RunStateService.wins = 0
			RunStateService.losses = 0
			RunStateService.pvp_wins = 0
			RunStateService.pvp_wins_changed.emit(0)
		_:
			push_warning("Unknown reset_run mode: %s" % mode)

func full_reset() -> void:
	reset_run("full")
