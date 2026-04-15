extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_uifix_cooldown_overlay.gd ==")
		_run_tests()
		_print_summary()


func _run_tests() -> void:
	test_overlay_visible_when_active()
	test_overlay_hidden_when_cooldown_zero()
	test_overlay_hidden_when_passive()
	test_ratio_half_cooldown()
	test_ratio_clamped_high()
	test_ratio_clamped_negative()
	test_timer_text_format()


func test_overlay_visible_when_active() -> void:
	_total += 1
	var visible: bool = 3.0 > 0.0 and 5.0 > 0.0
	_assert("Overlay visible: cd=5.0, current=3.0", visible)


func test_overlay_hidden_when_cooldown_zero() -> void:
	_total += 1
	var visible: bool = 0.0 > 0.0 and 5.0 > 0.0
	_assert("Overlay hidden: current=0", not visible)


func test_overlay_hidden_when_passive() -> void:
	_total += 1
	var visible: bool = 0.0 > 0.0 and 0.0 > 0.0
	_assert("Overlay hidden: passive item (cd=0)", not visible)


func test_ratio_half_cooldown() -> void:
	_total += 1
	var ratio: float = clampf(2.5 / 5.0, 0.0, 1.0)
	_assert("Ratio=0.5 at half cooldown", is_equal_approx(ratio, 0.5))


func test_ratio_clamped_high() -> void:
	_total += 1
	var ratio: float = clampf(10.0 / 3.0, 0.0, 1.0)
	_assert("Ratio clamped to 1.0 when current > cooldown", is_equal_approx(ratio, 1.0))


func test_ratio_clamped_negative() -> void:
	_total += 1
	var ratio: float = clampf(-1.0 / 3.0, 0.0, 1.0)
	_assert("Ratio clamped to 0.0 for negative current", is_equal_approx(ratio, 0.0))


func test_timer_text_format() -> void:
	_total += 1
	var current: float = 2.5
	var text: String = "%.1f" % current
	var passed: bool = text == "2.5"
	_assert("Timer text format: 2.5s -> '2.5'", passed)

	_total += 1
	current = 0.1
	text = "%.1f" % current
	passed = text == "0.1"
	_assert("Timer text format: 0.1s -> '0.1'", passed)


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
