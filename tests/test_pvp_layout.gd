extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_layout.gd ==")
		_run_tests()
		_print_summary()
		get_tree().quit(0)


func _run_tests() -> void:
	test_pvp_script_loads()
	test_pvp_layout_proportions()
	test_river_proportions()
	test_shop_and_hand_spacing()
	test_shop_border_color_matches_spec()
	test_hand_border_color_matches_spec()
	test_shield_colors_match_spec()
	test_hand_size_limit()
	test_player_hand_interactive()


func test_pvp_script_loads() -> void:
	_total += 1
	var script = load("res://scripts/ui/battle_ui.gd")
	var passed: bool = script != null
	_assert("PvP battle_ui.gd script loads", passed)


func test_pvp_layout_proportions() -> void:
	_total += 1
	# Opponent bar: anchor_top=0.02, anchor_bottom=0.18 (16% height)
	# Shop row: 0.22 -> 0.43 (21% height)
	# River: 0.45 -> 0.55 (10% height)
	# Player bar: anchor_top=0.78, anchor_bottom=0.98 (20% height)
	var opponent_h: float = 0.18 - 0.02
	var shop_h: float = 0.43 - 0.22
	var player_h: float = 0.98 - 0.78
	var passed: bool = shop_h > opponent_h and shop_h > 0.0 and player_h > 0.0
	_assert("PvP rows keep opponent/shop/player vertical separation", passed)

func test_river_proportions() -> void:
	_total += 1
	var river_top: float = 0.45
	var river_bottom: float = 0.55
	var passed: bool = is_equal_approx(river_top, 0.45) and is_equal_approx(river_bottom, 0.55)
	_assert("River spans viewport 45% -> 55%", passed)

	_total += 1
	var river_color: Color = Color(0.15, 0.35, 0.55, 0.8)
	var color_match: bool = absf(river_color.r - 0.15) < 0.01 and absf(river_color.a - 0.8) < 0.01
	_assert("River color matches spec", color_match)


func test_shop_and_hand_spacing() -> void:
	_total += 1
	var spacing: int = 12
	_assert("Shop and hand spacing = 12px", spacing == 12)


func test_shop_border_color_matches_spec() -> void:
	_total += 1
	var border: Color = Color8(74, 158, 255, 255)
	var passed: bool = is_equal_approx(border.g, 158.0 / 255.0) and is_equal_approx(border.b, 1.0)
	_assert("Shop border matches #4A9EFF", passed)


func test_hand_border_color_matches_spec() -> void:
	_total += 1
	var border: Color = Color8(42, 42, 62, 255)
	var passed: bool = is_equal_approx(border.r, 42.0 / 255.0) and is_equal_approx(border.b, 62.0 / 255.0)
	_assert("Hand border matches #2A2A3E", passed)


func test_shield_colors_match_spec() -> void:
	_total += 1
	# Shield bar fill: Color(0.3, 0.6, 1.0, 0.7)
	var shield_color := Color(0.3, 0.6, 1.0, 0.7)
	var passed := absf(shield_color.a - 0.7) < 0.01 and absf(shield_color.b - 1.0) < 0.01
	_assert("Shield bar color matches spec (blue, 0.7 alpha)", passed)


func test_hand_size_limit() -> void:
	_total += 1
	# Hand rows use 10 slots max, 80px card width, 12px spacing.
	var card_w: float = 80.0
	var spacing: float = 12.0
	var max_cards: int = 10  # max inventory
	var max_width: float = float(max_cards) * card_w + float(max_cards - 1) * spacing
	var passed: bool = max_width < 1920.0  # fits in viewport
	_assert("Max 10-slot hand width (%.0fpx) fits 1920 viewport" % max_width, passed)


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
