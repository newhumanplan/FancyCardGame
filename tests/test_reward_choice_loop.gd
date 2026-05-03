extends Node

const MonsterDataClass = preload("res://scripts/data/monster_data.gd")

var _total: int = 0
var _passed: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	print("== tests/test_reward_choice_loop.gd ==")
	call_deferred("_run_tests_async")

func _run_tests_async() -> void:
	await test_battle_reward_choice_uses_shell_and_advances_after_selection()
	await test_level_up_choice_blocks_until_selection_then_shows_current_hour_options()
	_print_summary()

func test_battle_reward_choice_uses_shell_and_advances_after_selection() -> void:
	_reset_services()
	var main: Control = await _create_started_main()
	var shell: Control = main.get_node("BazaarShell")
	var battle_ui: Control = main.get_node("BattleUI")
	var event_panel: Control = main.get_node("EventPanel")
	GameManager.set("current_hour", 2)
	battle_ui.set("is_pvp", false)
	battle_ui.set("current_monster", _build_choice_monster({
		"gold": 4,
		"xp": 2,
		"item_pool": [{"id": "scrap", "tier": "Bronze"}],
		"skill_pool": [{"id": "toughness", "tier": "Bronze"}],
	}))

	var before_gold: int = EconomyService.gold
	var before_xp: int = HeroStateService.xp
	main.call("_on_battle_ended", true, 0)
	await get_tree().process_frame

	var reward_view: Node = _find_node(shell.get_node("UpperBoardPanel"), "RewardChoiceView")
	_assert_not_null(reward_view, "battle win opens RewardChoiceView in BazaarShell")
	_assert_true(not event_panel.visible, "battle reward choice keeps EventPanel hidden")
	_assert_eq(EconomyService.gold, before_gold, "battle reward choice does not grant gold before selection")
	_assert_eq(HeroStateService.xp, before_xp, "battle reward choice does not grant XP before selection")

	var fallback_button: Button = _find_node(reward_view, "RewardOptionButton2") as Button
	_assert_not_null(fallback_button, "battle reward choice exposes the fallback option button")
	if fallback_button != null:
		fallback_button.emit_signal("pressed")
	await get_tree().create_timer(1.15).timeout
	await get_tree().process_frame

	_assert_eq(GameManager.current_hour, 3, "battle reward choice advances to the next hour after selection")
	_assert_true(_find_node(shell.get_node("UpperBoardPanel"), "RewardChoiceView") == null, "battle reward choice clears after selection")
	_assert_not_null(_find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView"), "next hour options render after battle reward selection")
	_assert_eq(EconomyService.gold, before_gold + 4, "battle fallback selection grants the payout gold")
	_assert_eq(HeroStateService.xp, before_xp + 3, "battle fallback selection plus hour completion grants the expected XP")

	main.queue_free()
	await get_tree().process_frame

func test_level_up_choice_blocks_until_selection_then_shows_current_hour_options() -> void:
	_reset_services()
	var main: Control = await _create_started_main()
	var shell: Control = main.get_node("BazaarShell")
	GameManager.set("current_hour", 0)
	GameManager.set("xp", HeroStateService.XP_PER_LEVEL - 1)
	var before_max_health: int = GameManager.get_max_health()

	main.call("_auto_advance_hour")
	await get_tree().create_timer(1.15).timeout
	await get_tree().process_frame

	_assert_eq(GameManager.current_hour, 1, "auto advance still moves into the next hour before the level choice")
	_assert_not_null(_find_node(shell.get_node("UpperBoardPanel"), "RewardChoiceView"), "level-up opens RewardChoiceView instead of current hour options")
	_assert_true(_find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView") == null, "level-up choice blocks current hour options before selection")

	var reward_view: Node = _find_node(shell.get_node("UpperBoardPanel"), "RewardChoiceView")
	var health_button: Button = _find_node(reward_view, "RewardOptionButton0") as Button
	_assert_not_null(health_button, "level-up choice exposes the health option button")
	if health_button != null:
		health_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_eq(GameManager.current_hour, 1, "resolving the level-up choice does not skip an extra hour")
	_assert_true(GameManager.get_max_health() > before_max_health, "choosing the health reward updates the hero immediately")
	_assert_true(_find_node(shell.get_node("UpperBoardPanel"), "RewardChoiceView") == null, "level-up reward choice clears after selection")
	_assert_not_null(_find_node(shell.get_node("UpperBoardPanel"), "TimeSelectView"), "current hour options render after the level-up choice resolves")

	main.queue_free()
	await get_tree().process_frame

func _create_started_main() -> Control:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate() as Control
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_on_mak_selected")
	await get_tree().process_frame
	return main

func _reset_services() -> void:
	RewardService.reset_runtime_state()
	EconomyService.reset()
	RunStateService.reset(true)
	HeroStateService.reset()
	GameFlowService.set("_current_event_options", [])
	GameFlowService.set("_current_random_event_id", "")
	GameFlowService.set("_current_selected_option", {})
	GameManager.stats_total_battles = 0
	GameManager.stats_total_wins = 0
	GameManager.stats_total_losses = 0
	GameManager.stats_total_gold_earned = 0

func _build_choice_monster(reward: Dictionary) -> MonsterDataClass:
	var monster := MonsterDataClass.new()
	monster.monster_name = "Choice Tester"
	monster.max_hp = 100
	monster.current_hp = 100
	monster.reward = reward.duplicate(true)
	monster.gold_reward_min = int(reward.get("gold", 0))
	monster.gold_reward_max = int(reward.get("gold", 0))
	monster.xp_reward = int(reward.get("xp", 0))
	return monster

func _find_node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found: Node = _find_node(child, node_name)
		if found != null:
			return found
	return null

func _assert_true(condition: bool, label: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)

func _assert_eq(actual, expected, label: String) -> void:
	_assert_true(actual == expected, "%s | expected=%s actual=%s" % [label, str(expected), str(actual)])

func _assert_not_null(value, label: String) -> void:
	_assert_true(value != null, label)

func _print_summary() -> void:
	print("SUMMARY: %d/%d passed" % [_passed, _total])
	get_tree().quit(1 if _passed < _total else 0)
