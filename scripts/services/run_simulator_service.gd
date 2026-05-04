class_name RunSimulatorService
extends RefCounted

const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EventManagerClass = preload("res://scripts/data/event_manager.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemAcquisitionClass = preload("res://scripts/data/item_acquisition.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const PvpGhostServiceClass = preload("res://scripts/services/pvp_ghost_service.gd")

const DEFAULT_SEED_COUNT: int = 32
const DEFAULT_BASE_SEED: int = 420240
const DEFAULT_MAX_DAYS: int = 10
const REPORT_SCHEMA_VERSION: int = 1

const MAJOR_PHASES: Array[String] = [
	"merchant",
	"service_vendor",
	"event",
	"pve",
	"pvp",
	"reward_choice",
	"level_up",
]

static func run_balance_suite(config: Dictionary = {}) -> Dictionary:
	var seed_count: int = clampi(int(config.get("seed_count", DEFAULT_SEED_COUNT)), 1, 50)
	var base_seed: int = int(config.get("base_seed", DEFAULT_BASE_SEED))
	var max_days: int = maxi(int(config.get("max_days", DEFAULT_MAX_DAYS)), 1)
	var runs: Array[Dictionary] = []
	var coverage: Dictionary = _new_coverage()
	var outliers: Array[Dictionary] = []
	var soft_locks: Array[Dictionary] = []

	for index in range(seed_count):
		var run_config: Dictionary = config.duplicate(true)
		run_config["seed"] = base_seed + index
		run_config["max_days"] = max_days
		run_config["force_last_chance_probe"] = index == 0 or bool(config.get("force_last_chance_probe", false))
		run_config["force_inventory_pressure"] = index == 1 or bool(config.get("force_inventory_pressure", false))
		var run_result: Dictionary = simulate_run(run_config)
		runs.append(run_result)
		_merge_coverage(coverage, run_result)
		soft_locks.append_array(_tagged_entries(run_result.get("soft_locks", []), int(run_result.get("seed", 0))))
		outliers.append_array(_detect_run_outliers(run_result))

	return {
		"schema_version": REPORT_SCHEMA_VERSION,
		"base_seed": base_seed,
		"seed_count": seed_count,
		"max_days": max_days,
		"runs_completed": runs.size(),
		"coverage": coverage,
		"acceptance": _build_acceptance(runs, coverage, soft_locks),
		"aggregate": _build_aggregate(runs),
		"outliers": outliers,
		"soft_locks": soft_locks,
		"runs": runs,
	}

static func simulate_run(config: Dictionary = {}) -> Dictionary:
	var seed_value: int = int(config.get("seed", DEFAULT_BASE_SEED))
	var max_days: int = maxi(int(config.get("max_days", DEFAULT_MAX_DAYS)), 1)
	var stop_at_pvp_wins: int = maxi(int(config.get("stop_at_pvp_wins", BattleProgressionService.PVP_WINS_FOR_CLEAR)), 1)
	var force_last_chance_probe: bool = bool(config.get("force_last_chance_probe", false))
	var force_inventory_pressure: bool = bool(config.get("force_inventory_pressure", false))

	seed(seed_value)
	_reset_runtime()

	var hero_type: HeroDataClass.HeroType = _hero_type_for_seed(seed_value)
	var hero = HeroFactoryService.create_hero(hero_type)
	GameManager.select_hero(hero)

	var inventory: LinearInventoryClass = LinearInventoryClass.new()
	var stash: LinearInventoryClass = LinearInventoryClass.new()
	_grant_starter_items(hero_type, inventory, stash)
	if force_inventory_pressure:
		_fill_inventory_with_probe_items(inventory)
		_fill_inventory_with_probe_items(stash)

	var event_manager: EventManagerClass = EventManagerClass.new()
	var run: Dictionary = {
		"seed": seed_value,
		"hero": hero.hero_name if hero != null else "Unknown",
		"terminal_state": "max_days_reached",
		"completed": false,
		"soft_locks": [],
		"coverage": _new_coverage(),
		"curves": [],
		"action_log": [],
		"inventory_pressure_probe": force_inventory_pressure,
		"last_chance_probe": force_last_chance_probe,
	}
	_record_curve(run, inventory, stash, "start")

	var guard: int = 0
	while RunStateService.current_day <= max_days and RunStateService.pvp_wins < stop_at_pvp_wins:
		guard += 1
		if guard > max_days * PhaseService.MAX_HOURS_PER_DAY + 6:
			_add_soft_lock(run, "guard_exhausted", "Exceeded expected hour loop")
			run["terminal_state"] = "soft_lock"
			break

		var hour: int = RunStateService.current_hour
		var day: int = RunStateService.current_day
		var options: Array[Dictionary] = event_manager.generate_options(hour, day)
		if options.is_empty():
			_add_soft_lock(run, "no_options", "Day %d Hour %d generated no options" % [day, hour])
			run["terminal_state"] = "soft_lock"
			break

		var selected: Dictionary = _choose_option(options, run)
		if selected.is_empty():
			_add_soft_lock(run, "no_actionable_option", "Day %d Hour %d had no actionable option" % [day, hour])
			run["terminal_state"] = "soft_lock"
			break

		var action_type: String = str(selected.get("type", ""))
		match action_type:
			"shop":
				_execute_merchant(selected, inventory, stash, run)
			"service_vendor":
				_execute_service_vendor(selected, event_manager, inventory, stash, run)
			"random_event":
				_execute_random_event(selected, event_manager, inventory, stash, run)
			"monster":
				_execute_pve(selected, inventory, stash, run)
			"pvp":
				_execute_pvp(day, inventory, stash, run, force_last_chance_probe)
			_:
				_add_soft_lock(run, "unsupported_option_type", action_type)
				run["terminal_state"] = "soft_lock"
				break

		_resolve_all_choices(inventory, stash, run)
		if str(run.get("terminal_state", "")) == "soft_lock":
			break

		var previous_day: int = RunStateService.current_day
		GameManager.next_hour()
		if RunStateService.current_day > previous_day:
			var hook_summary: Dictionary = ItemAcquisitionClass.apply_hour_start_hooks(inventory, stash, "sim_day_start")
			(run["action_log"] as Array).append({
				"day": RunStateService.current_day,
				"hour": RunStateService.current_hour,
				"type": "day_start_hooks",
				"summary": hook_summary,
			})
		_resolve_all_choices(inventory, stash, run)
		_record_curve(run, inventory, stash, "after_hour")

		if RunStateService.pvp_wins >= stop_at_pvp_wins:
			run["terminal_state"] = "pvp_wins_clear"
			break
		if RunStateService.prestige_zero_count >= 2:
			run["terminal_state"] = "prestige_failure"
			break

	run["completed"] = (run["soft_locks"] as Array).is_empty()
	run["final"] = _snapshot_state(inventory, stash)
	run["curve_summary"] = _summarize_curves(run.get("curves", []))
	return run

static func write_report(report: Dictionary, status_dir: String) -> Dictionary:
	var absolute_dir: String = ProjectSettings.globalize_path(status_dir) if status_dir.begins_with("user://") else ProjectSettings.globalize_path("res://" + status_dir)
	var make_result: int = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		return {"success": false, "errors": ["mkdir_failed:%s:%d" % [absolute_dir, make_result]]}

	var json_path: String = absolute_dir.path_join("balance_report.json")
	var markdown_path: String = absolute_dir.path_join("balance_report.md")
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		return {"success": false, "errors": ["write_failed:%s" % json_path]}
	json_file.store_string(JSON.stringify(report, "\t"))
	json_file.close()

	var md_file: FileAccess = FileAccess.open(markdown_path, FileAccess.WRITE)
	if md_file == null:
		return {"success": false, "errors": ["write_failed:%s" % markdown_path]}
	md_file.store_string(_build_markdown_report(report))
	md_file.close()
	return {
		"success": true,
		"json_path": json_path,
		"markdown_path": markdown_path,
	}

static func _execute_merchant(selected: Dictionary, inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary) -> void:
	_mark_coverage(run, "merchant")
	var hero_type: HeroDataClass.HeroType = HeroStateService.selected_hero.hero_type if HeroStateService.selected_hero != null else HeroDataClass.HeroType.MAK
	var shelf: Array[ItemDataClass] = EconomyService.generate_merchant_shelf(selected, inventory, stash, RunStateService.current_day, hero_type, 5)
	var purchased: Dictionary = {}
	for index in range(shelf.size()):
		var item: ItemDataClass = shelf[index]
		if item == null or not EconomyService.can_afford(item.buy_price):
			continue
		if not ItemAcquisitionClass.can_accept_item(item, inventory, stash, false):
			continue
		if not EconomyService.spend_gold(item.buy_price):
			continue
		var copy: ItemDataClass = item.duplicate() as ItemDataClass
		copy.slot_index = -1
		var grant_result: Dictionary = ItemAcquisitionClass.grant_item(copy, inventory, stash, false)
		if bool(grant_result.get("success", false)):
			ItemAcquisitionClass.apply_on_buy_hooks(copy, inventory, stash)
			purchased = {"id": copy.source_id, "name": copy.item_name, "price": item.buy_price, "index": index}
			break
		EconomyService.add_gold(item.buy_price)

	(run["action_log"] as Array).append({
		"day": RunStateService.current_day,
		"hour": RunStateService.current_hour,
		"type": "merchant",
		"merchant_id": str(selected.get("merchant_id", "")),
		"shelf_size": shelf.size(),
		"purchased": purchased,
		"left_without_purchase": purchased.is_empty(),
	})

static func _execute_service_vendor(selected: Dictionary, event_manager: EventManagerClass, inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary) -> void:
	_mark_coverage(run, "service_vendor")
	var service_id: String = str(selected.get("service_id", ""))
	var result: String = event_manager.execute_service_vendor(service_id, RunStateService.current_day, GameManager, inventory, stash)
	(run["action_log"] as Array).append({"day": RunStateService.current_day, "hour": RunStateService.current_hour, "type": "service_vendor", "service_id": service_id, "result": result})

static func _execute_random_event(selected: Dictionary, event_manager: EventManagerClass, inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary) -> void:
	_mark_coverage(run, "event")
	var event_id: String = str(selected.get("event_id", ""))
	var result: String = event_manager.execute_random_event(event_id, RunStateService.current_day, GameManager, inventory, stash)
	(run["action_log"] as Array).append({"day": RunStateService.current_day, "hour": RunStateService.current_hour, "type": "event", "event_id": event_id, "result": result})

static func _execute_pve(selected: Dictionary, inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary) -> void:
	_mark_coverage(run, "pve")
	var monster_id: String = str(selected.get("monster_id", ""))
	var monster = BazaarContentClass.create_monster(monster_id, RunStateService.current_day)
	if monster == null:
		_add_soft_lock(run, "monster_create_failed", monster_id)
		return
	var result: Dictionary = BattleProgressionService.apply_battle_result(true, false, monster, inventory, stash)
	(run["action_log"] as Array).append({"day": RunStateService.current_day, "hour": RunStateService.current_hour, "type": "pve", "monster_id": monster_id, "won": true, "result": result})

static func _execute_pvp(day: int, inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary, force_last_chance_probe: bool) -> void:
	_mark_coverage(run, "pvp")
	var player_snapshot = PvpGhostServiceClass.capture_player_ghost_snapshot(GameManager, inventory, stash)
	player_snapshot.snapshot_id = "sim_seed_%d_day%02d_hour%02d" % [int(run.get("seed", 0)), day, RunStateService.current_hour]
	var opponent = PvpGhostServiceClass.pick_snapshot_for_day(day, PvpGhostServiceClass.DEFAULT_CURATED_PATH, player_snapshot.power_score, PvpGhostServiceClass.DEFAULT_LOCAL_PLAYTEST_DIR, player_snapshot.snapshot_id)
	var won: bool = _determine_pvp_result(day, player_snapshot.power_score, int(opponent.power_score), int(run.get("seed", 0)), force_last_chance_probe)
	var result: Dictionary = BattleProgressionService.apply_battle_result(won, true, PvpGhostServiceClass.ghost_snapshot_to_monster(opponent), inventory, stash)
	if bool(result.get("last_chance", false)):
		_mark_coverage(run, "last_chance")
	if bool(result.get("run_failed", false)):
		run["terminal_state"] = "prestige_failure"
	(run["action_log"] as Array).append({
		"day": day,
		"hour": RunStateService.current_hour,
		"type": "pvp",
		"won": won,
		"player_power": player_snapshot.power_score,
		"opponent_power": opponent.power_score,
		"opponent_id": opponent.snapshot_id,
		"result": result,
	})

static func _resolve_all_choices(inventory: LinearInventoryClass, stash: LinearInventoryClass, run: Dictionary) -> void:
	var guard: int = 0
	while RewardService.has_pending_choice():
		guard += 1
		if guard > 16:
			_add_soft_lock(run, "reward_choice_guard_exhausted", "Too many pending choices")
			return
		var choice: Dictionary = RewardService.get_active_choice()
		var index: int = _choose_reward_index(choice, inventory, stash)
		if index < 0:
			_add_soft_lock(run, "reward_choice_unresolvable", str(choice))
			return
		var result: Dictionary = RewardService.resolve_active_choice(index, inventory, stash)
		if not bool(result.get("resolved", false)):
			_add_soft_lock(run, "reward_choice_resolve_failed", str(choice))
			return
		_mark_coverage(run, "reward_choice")
		if str(choice.get("type", "")) == RewardService.CHOICE_TYPE_LEVEL_UP:
			_mark_coverage(run, "level_up")
		(run["action_log"] as Array).append({"day": RunStateService.current_day, "hour": RunStateService.current_hour, "type": "reward_choice", "choice_type": str(choice.get("type", "")), "selected_index": index, "option": result.get("option", {}), "summary": result.get("summary", {})})

static func _choose_reward_index(choice: Dictionary, inventory: LinearInventoryClass, stash: LinearInventoryClass) -> int:
	var options: Array = choice.get("options", [])
	var fallback_index: int = -1
	var useful_index: int = -1
	for index in range(options.size()):
		if not options[index] is Dictionary:
			continue
		var option: Dictionary = options[index] as Dictionary
		var kind: String = str(option.get("kind", ""))
		if kind == "fallback" or kind == "gold":
			fallback_index = index
		if _reward_can_apply(option.get("reward", {}), inventory, stash):
			if kind == "item" or kind == "monster_item":
				return index
			if useful_index < 0:
				useful_index = index
	if useful_index >= 0:
		return useful_index
	return fallback_index

static func _reward_can_apply(reward_variant: Variant, inventory: LinearInventoryClass, stash: LinearInventoryClass) -> bool:
	if not reward_variant is Dictionary:
		return false
	var reward: Dictionary = reward_variant as Dictionary
	var item_refs: Array = []
	for key in ["item_id", "item_ids", "item_pool", "items"]:
		if not reward.has(key):
			continue
		var value: Variant = reward[key]
		if value is Array:
			item_refs.append_array(value)
		else:
			item_refs.append(value)
	if item_refs.is_empty():
		return true
	for ref in item_refs:
		var item_id: String = str(ref.get("id", "") if ref is Dictionary else ref)
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		if item != null and ItemAcquisitionClass.can_accept_item(item, inventory, stash, true):
			return true
	return false

static func _determine_pvp_result(day: int, player_power: int, opponent_power: int, seed_value: int, force_last_chance_probe: bool) -> bool:
	if force_last_chance_probe and RunStateService.prestige_zero_count == 0:
		return false
	var score_delta: int = player_power - opponent_power
	var threshold: int = -120 + ((seed_value + day * 37) % 260)
	return score_delta >= threshold

static func _choose_option(options: Array[Dictionary], run: Dictionary) -> Dictionary:
	var coverage: Dictionary = run.get("coverage", {})
	var priorities: Array[String] = []
	if not bool(coverage.get("merchant", false)):
		priorities.append("shop")
	if not bool(coverage.get("service_vendor", false)):
		priorities.append("service_vendor")
	if not bool(coverage.get("event", false)):
		priorities.append("random_event")
	priorities.append_array(["monster", "pvp", "service_vendor", "shop", "random_event"])
	for desired_type in priorities:
		for option in options:
			if str(option.get("type", "")) == desired_type:
				return option.duplicate(true)
	return options[0].duplicate(true)

static func _reset_runtime() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameManager.reset_stats()

static func _hero_type_for_seed(seed_value: int) -> HeroDataClass.HeroType:
	var heroes: Array[HeroDataClass.HeroType] = [HeroDataClass.HeroType.MAK, HeroDataClass.HeroType.VANESSA, HeroDataClass.HeroType.PYGMALIEN, HeroDataClass.HeroType.DOOLEY]
	return heroes[abs(seed_value) % heroes.size()]

static func _grant_starter_items(hero_type: HeroDataClass.HeroType, inventory: LinearInventoryClass, stash: LinearInventoryClass) -> void:
	var item_ids: Array[String] = BazaarContentClass.get_hero_item_ids(hero_type)
	var granted: int = 0
	for item_id in item_ids:
		if granted >= 3:
			break
		var item: ItemDataClass = BazaarContentClass.create_item(item_id, BazaarContentClass.RARITY_BRONZE)
		if item == null:
			continue
		var result: Dictionary = ItemAcquisitionClass.grant_item(item, inventory, stash, true)
		if bool(result.get("success", false)):
			granted += 1

static func _fill_inventory_with_probe_items(inventory: LinearInventoryClass) -> void:
	if inventory == null:
		return
	var probe_ids: Array[String] = ["catalyst", "hemlock", "fire_potion", "venom", "chocolate_bar", "extract", "med_kit", "scrap", "ruby", "emerald"]
	for slot in range(LinearInventoryClass.TOTAL_SLOTS):
		if inventory.get_item_at(slot) != null:
			continue
		for probe_id in probe_ids:
			var item: ItemDataClass = BazaarContentClass.create_item(probe_id, BazaarContentClass.RARITY_DIAMOND)
			if item != null and inventory.place_item(item, slot):
				break

static func _new_coverage() -> Dictionary:
	return {"merchant": false, "service_vendor": false, "event": false, "pve": false, "pvp": false, "reward_choice": false, "level_up": false, "last_chance": false, "counts": {}}

static func _mark_coverage(run: Dictionary, phase: String) -> void:
	var coverage: Dictionary = run.get("coverage", {})
	coverage[phase] = true
	var counts: Dictionary = coverage.get("counts", {})
	counts[phase] = int(counts.get(phase, 0)) + 1
	coverage["counts"] = counts
	run["coverage"] = coverage

static func _merge_coverage(coverage: Dictionary, run: Dictionary) -> void:
	var run_coverage: Dictionary = run.get("coverage", {})
	for key in run_coverage.keys():
		if key == "counts":
			continue
		coverage[key] = bool(coverage.get(key, false)) or bool(run_coverage.get(key, false))
	var counts: Dictionary = coverage.get("counts", {})
	var run_counts: Dictionary = run_coverage.get("counts", {})
	for key in run_counts.keys():
		counts[key] = int(counts.get(key, 0)) + int(run_counts.get(key, 0))
	coverage["counts"] = counts

static func _build_acceptance(runs: Array[Dictionary], coverage: Dictionary, soft_locks: Array[Dictionary]) -> Dictionary:
	var missing: Array[String] = []
	for phase in MAJOR_PHASES:
		if not bool(coverage.get(phase, false)):
			missing.append(phase)
	return {
		"seed_run_count_ok": runs.size() >= 20 and runs.size() <= 50,
		"no_crash_or_soft_lock": soft_locks.is_empty(),
		"major_phases_covered": missing.is_empty(),
		"missing_major_phases": missing,
		"last_chance_reached": bool(coverage.get("last_chance", false)),
		"curves_reported": true,
		"outliers_flagged": true,
		"deterministic_headless_entry": "tests/test_run_simulator_balance_gate.gd",
	}

static func _build_aggregate(runs: Array[Dictionary]) -> Dictionary:
	var final_gold: Array[int] = []
	var final_health: Array[int] = []
	var final_prestige: Array[int] = []
	var final_level: Array[int] = []
	var final_items: Array[int] = []
	var terminal_counts: Dictionary = {}
	for run in runs:
		var final: Dictionary = run.get("final", {})
		final_gold.append(int(final.get("gold", 0)))
		final_health.append(int(final.get("health", 0)))
		final_prestige.append(int(final.get("prestige", 0)))
		final_level.append(int(final.get("level", 0)))
		final_items.append(int(final.get("item_count", 0)))
		var terminal: String = str(run.get("terminal_state", "unknown"))
		terminal_counts[terminal] = int(terminal_counts.get(terminal, 0)) + 1
	return {"gold": _stats(final_gold), "health": _stats(final_health), "prestige": _stats(final_prestige), "level": _stats(final_level), "item_count": _stats(final_items), "terminal_counts": terminal_counts}

static func _detect_run_outliers(run: Dictionary) -> Array[Dictionary]:
	var outliers: Array[Dictionary] = []
	var final: Dictionary = run.get("final", {})
	var seed_value: int = int(run.get("seed", 0))
	if int(final.get("gold", 0)) > 120:
		outliers.append({"seed": seed_value, "metric": "gold", "value": int(final.get("gold", 0)), "reason": "high_gold"})
	if int(final.get("prestige", 0)) <= 2:
		outliers.append({"seed": seed_value, "metric": "prestige", "value": int(final.get("prestige", 0)), "reason": "low_prestige"})
	if int(final.get("health", 0)) <= int(final.get("max_health", 1)) / 4:
		outliers.append({"seed": seed_value, "metric": "health", "value": int(final.get("health", 0)), "reason": "low_health"})
	if str(run.get("terminal_state", "")) == "prestige_failure" and int(final.get("day", 0)) <= 5:
		outliers.append({"seed": seed_value, "metric": "terminal_state", "value": "prestige_failure", "reason": "early_failure"})
	return outliers

static func _snapshot_state(inventory: LinearInventoryClass, stash: LinearInventoryClass) -> Dictionary:
	return {
		"day": RunStateService.current_day,
		"hour": RunStateService.current_hour,
		"gold": EconomyService.gold,
		"income": EconomyService.income,
		"xp": HeroStateService.xp,
		"level": HeroStateService.level,
		"health": HeroStateService.player_health,
		"max_health": HeroStateService.get_max_health(),
		"prestige": RunStateService.prestige,
		"pvp_wins": RunStateService.pvp_wins,
		"wins": RunStateService.wins,
		"losses": RunStateService.losses,
		"board_size": _occupied_slots(inventory),
		"stash_size": _occupied_slots(stash),
		"item_count": inventory.items.size() + stash.items.size(),
		"pending_choices": 1 if RewardService.has_pending_choice() else 0,
	}

static func _record_curve(run: Dictionary, inventory: LinearInventoryClass, stash: LinearInventoryClass, label: String) -> void:
	var point: Dictionary = _snapshot_state(inventory, stash)
	point["label"] = label
	(run["curves"] as Array).append(point)

static func _summarize_curves(curves: Array) -> Dictionary:
	var gold: Array[int] = []
	var health: Array[int] = []
	var prestige: Array[int] = []
	var board_size: Array[int] = []
	var item_count: Array[int] = []
	for point in curves:
		if not point is Dictionary:
			continue
		gold.append(int((point as Dictionary).get("gold", 0)))
		health.append(int((point as Dictionary).get("health", 0)))
		prestige.append(int((point as Dictionary).get("prestige", 0)))
		board_size.append(int((point as Dictionary).get("board_size", 0)))
		item_count.append(int((point as Dictionary).get("item_count", 0)))
	return {"gold": _stats(gold), "health": _stats(health), "prestige": _stats(prestige), "board_size": _stats(board_size), "item_count": _stats(item_count)}

static func _stats(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"min": 0, "max": 0, "avg": 0.0}
	var min_value: int = values[0]
	var max_value: int = values[0]
	var total: int = 0
	for value in values:
		min_value = mini(min_value, value)
		max_value = maxi(max_value, value)
		total += value
	return {"min": min_value, "max": max_value, "avg": float(total) / float(values.size())}

static func _occupied_slots(inventory: LinearInventoryClass) -> int:
	if inventory == null:
		return 0
	var occupied: int = 0
	for slot in inventory.slots:
		if int(slot) >= 0:
			occupied += 1
	return occupied

static func _add_soft_lock(run: Dictionary, reason: String, detail: String) -> void:
	(run["soft_locks"] as Array).append({"day": RunStateService.current_day, "hour": RunStateService.current_hour, "reason": reason, "detail": detail})

static func _tagged_entries(entries: Array, seed_value: int) -> Array[Dictionary]:
	var tagged: Array[Dictionary] = []
	for entry in entries:
		if entry is Dictionary:
			var tagged_entry: Dictionary = (entry as Dictionary).duplicate(true)
			tagged_entry["seed"] = seed_value
			tagged.append(tagged_entry)
	return tagged

static func _build_markdown_report(report: Dictionary) -> String:
	var acceptance: Dictionary = report.get("acceptance", {})
	var aggregate: Dictionary = report.get("aggregate", {})
	var coverage: Dictionary = report.get("coverage", {})
	var lines: Array[String] = []
	lines.append("# Run QA Balance Simulation")
	lines.append("")
	lines.append("- base_seed: `%d`" % int(report.get("base_seed", 0)))
	lines.append("- seed_count: `%d`" % int(report.get("seed_count", 0)))
	lines.append("- runs_completed: `%d`" % int(report.get("runs_completed", 0)))
	lines.append("- no_crash_or_soft_lock: `%s`" % str(acceptance.get("no_crash_or_soft_lock", false)))
	lines.append("- major_phases_covered: `%s`" % str(acceptance.get("major_phases_covered", false)))
	lines.append("- last_chance_reached: `%s`" % str(acceptance.get("last_chance_reached", false)))
	lines.append("")
	lines.append("## Coverage")
	lines.append("")
	var counts: Dictionary = coverage.get("counts", {})
	for phase in ["merchant", "service_vendor", "event", "pve", "pvp", "reward_choice", "level_up", "last_chance"]:
		lines.append("- %s: `%s` count `%d`" % [phase, str(coverage.get(phase, false)), int(counts.get(phase, 0))])
	lines.append("")
	lines.append("## Aggregate Curves")
	lines.append("")
	for metric in ["gold", "health", "prestige", "level", "item_count"]:
		var stats: Dictionary = aggregate.get(metric, {})
		lines.append("- %s: min `%s`, max `%s`, avg `%.2f`" % [metric, str(stats.get("min", 0)), str(stats.get("max", 0)), float(stats.get("avg", 0.0))])
	lines.append("")
	lines.append("## Outliers")
	lines.append("")
	var outliers: Array = report.get("outliers", [])
	if outliers.is_empty():
		lines.append("- none")
	else:
		for outlier in outliers:
			if outlier is Dictionary:
				lines.append("- seed `%d` %s=`%s` reason `%s`" % [int((outlier as Dictionary).get("seed", 0)), str((outlier as Dictionary).get("metric", "")), str((outlier as Dictionary).get("value", "")), str((outlier as Dictionary).get("reason", ""))])
	lines.append("")
	lines.append("## Terminal States")
	lines.append("")
	var terminal_counts: Dictionary = aggregate.get("terminal_counts", {})
	for terminal in terminal_counts.keys():
		lines.append("- %s: `%d`" % [str(terminal), int(terminal_counts[terminal])])
	lines.append("")
	return "\n".join(lines)
