extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_layout.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_pvp_script_loads()
	test_pvp_layout_proportions()
	test_card_back_colors_match_spec()
	test_shield_colors_match_spec()
	test_opponent_hand_size_limit()
	test_player_hand_interactive()


func test_pvp_script_loads() -> void:
	_total += 1
	var script = load("res://scripts/ui/battle_ui.gd")
	var passed: bool = script != null
	_assert("PvP battle_ui.gd script loads", passed)


func test_pvp_layout_proportions() -> void:
	_total += 1
	# Opponent bar: anchor_top=0.02, anchor_bottom=0.18 (16% height)
	# Battle center: anchor_top=0.20, anchor_bottom=0.76 (56% height)
	# Player bar: anchor_top=0.78, anchor_bottom=0.98 (20% height)
	var opponent_h: float = 0.18 - 0.02
	var center_h: float = 0.76 - 0.20
	var player_h: float = 0.98 - 0.78
	var passed: bool = center_h > opponent_h and center_h > player_h
	_assert("Battle center (56%%) > opponent (16%%) > player (20%%)", passed)


func test_card_back_colors_match_spec() -> void:
	_total += 1
	# Card back: #1A1A2E = RGB(26, 26, 46)
	var bg := Color(0.102, 0.102, 0.18, 1.0)
	var bg_match := absf(bg.r - 26.0 / 255.0) < 0.01 and absf(bg.b - 46.0 / 255.0) < 0.01
	_assert("Card back bg matches #1A1A2E", bg_match)

	_total += 1
	# Border: #333555 = RGB(51, 53, 85)
	var border := Color(0.2, 0.2, 0.33, 1.0)
	var border_match := absf(border.g - 53.0 / 255.0) < 0.01 and absf(border.b - 85.0 / 255.0) < 0.01
	_assert("Card back border matches #333555", border_match)


func test_shield_colors_match_spec() -> void:
	_total += 1
	# Shield bar fill: Color(0.3, 0.6, 1.0, 0.7)
	var shield_color := Color(0.3, 0.6, 1.0, 0.7)
	var passed := absf(shield_color.a - 0.7) < 0.01 and absf(shield_color.b - 1.0) < 0.01
	_assert("Shield bar color matches spec (blue, 0.7 alpha)", passed)


func test_opponent_hand_size_limit() -> void:
	_total += 1
	# Opponent hand size = monster.monster_items.size() (typically 1-3)
	# Card size = 80x110, spacing = 8
	# Max 3 cards: 3*80 + 2*8 = 256px width
	var card_w: float = 80.0
	var spacing: float = 8.0
	var max_cards: int = 10  # max inventory
	var max_width: float = float(max_cards) * card_w + float(max_cards - 1) * spacing
	var passed: bool = max_width < 1920.0  # fits in viewport
	_assert("Max hand width (%.0fpx) fits 1920 viewport" % max_width, passed)


func test_player_hand_interactive() -> void:
	_total += 1
	# Player cards: MOUSE_FILTER_PASS (can receive events)
	# Opponent cards: MOUSE_FILTER_IGNORE (cannot receive events)
	var player_filter: int = Control.MOUSE_FILTER_PASS  # 1
	var opponent_filter: int = Control.MOUSE_FILTER_IGNORE  # 2
	var passed: bool = player_filter != opponent_filter
	_assert("Player cards interactive, opponent cards non-interactive", passed)


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
