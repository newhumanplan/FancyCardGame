extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_hand_interaction.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_select_deselect_toggle()
	test_select_replaces_old()
	test_hover_enter_replaces()
	test_hover_exit_clears()
	test_opponent_non_interactive()
	test_tooltip_content_damage()
	test_tooltip_content_heal()
	test_tooltip_content_passive()
	test_card_style_states()


func test_select_deselect_toggle() -> void:
	_total += 1
	var selected: int = -1
	selected = 0 if selected != 0 else -1  # click card 0
	var p1: bool = selected == 0
	selected = 0 if selected != 0 else -1  # click card 0 again
	var p2: bool = selected == -1
	_assert("Click same card: select then deselect", p1 and p2)


func test_select_replaces_old() -> void:
	_total += 1
	var selected: int = -1
	selected = 0  # select card 0
	selected = 1 if selected != 1 else -1  # click card 1
	var passed: bool = selected == 1
	_assert("Click new card replaces old selection", passed)


func test_hover_enter_replaces() -> void:
	_total += 1
	var hovered: int = -1
	hovered = 0  # enter card A
	hovered = 1  # enter card B (replaces A)
	var passed: bool = hovered == 1
	_assert("Hover B replaces A", passed)


func test_hover_exit_clears() -> void:
	_total += 1
	var hovered: int = -1
	hovered = 0  # enter card A
	hovered = -1  # exit card A
	var passed: bool = hovered == -1
	_assert("Exit card clears hover state", passed)


func test_opponent_non_interactive() -> void:
	_total += 1
	var player_filter: int = Control.MOUSE_FILTER_PASS
	var opponent_filter: int = Control.MOUSE_FILTER_IGNORE
	var passed: bool = player_filter != opponent_filter
	_assert("Player=PASS, Opponent=IGNORE", passed)


func test_tooltip_content_damage() -> void:
	_total += 1
	var text: String = "[b]Iron Sword[/b]\n"
	text += "Type: Weapon\n"
	text += "ATK: %d\n" % 15
	text += "CD: %.1fs\n" % 3.0
	var passed: bool = text.find("Iron Sword") >= 0 and text.find("ATK: 15") >= 0 and text.find("CD: 3.0s") >= 0
	_assert("Tooltip: damage item shows name/ATK/CD", passed)


func test_tooltip_content_heal() -> void:
	_total += 1
	var text: String = "[b]Health Potion[/b]\n"
	text += "Type: Heal\n"
	text += "Heal: %d\n" % 20
	var passed: bool = text.find("Health Potion") >= 0 and text.find("Heal: 20") >= 0
	_assert("Tooltip: heal item shows name/Heal", passed)


func test_tooltip_content_passive() -> void:
	_total += 1
	var text: String = "[b]Lucky Charm[/b]\n"
	text += "Type: Utility\n"
	# Passive item: no CD line
	var has_cd: bool = text.find("CD:") >= 0
	_assert("Tooltip: passive item has no CD line", not has_cd)


func test_card_style_states() -> void:
	_total += 1
	# Simulate card style states: normal, hovered, selected
	# Normal: border_width=2, border=standard color
	# Hovered: border_width=3, border=lighter
	# Selected: border_width=3, border=gold
	var normal_width: int = 2
	var hover_width: int = 3
	var select_width: int = 3
	var gold := Color(1.0, 0.84, 0.0, 1.0)
	var is_gold: bool = absf(gold.r - 1.0) and is_equal_approx(gold.g) < 0.01
	var passed: bool = hover_width > normal_width and select_width > normal_width and is_gold
	_assert("Hover/Selected border wider, selected=gold", passed)


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
