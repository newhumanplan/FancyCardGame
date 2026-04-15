extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_pvp_responsive.gd ==")
		_run_tests()
		_print_summary()
		get_tree().quit(0)


## Replicates _calculate_pvp_scale() logic for pure data testing
func _calc_scale(viewport_w: float, viewport_h: float) -> float:
	var base_w: float = 1920.0
	var base_h: float = 1080.0
	if viewport_w <= 0.0 or viewport_h <= 0.0:
		return 1.0
	var sx: float = viewport_w / base_w
	var sy: float = viewport_h / base_h
	return clampf(minf(sx, sy), 0.5, 1.0)


func _run_tests() -> void:
	test_scale_1920x1080_is_1x()
	test_scale_1280x720_is_067x()
	test_scale_960x540_is_05x()
	test_scale_800x600_preserves_aspect()
	test_scale_clamped_at_05_min()
	test_scale_clamped_at_10_max()
	test_scale_zero_viewport_returns_1()
	test_scale_negative_viewport_returns_1()
	test_scale_ultrawide_height_limited()
	test_scale_tall_width_limited()


func test_scale_1920x1080_is_1x() -> void:
	_total += 1
	var scale := _calc_scale(1920.0, 1080.0)
	_assert("1920x1080 -> 1.0x", is_equal_approx(scale, 1.0))


func test_scale_1280x720_is_067x() -> void:
	_total += 1
	var scale := _calc_scale(1280.0, 720.0)
	var expected: float = minf(1280.0 / 1920.0, 720.0 / 1080.0)
	_assert("1280x720 -> 0.667x", absf(scale - expected) < 0.01)


func test_scale_960x540_is_05x() -> void:
	_total += 1
	var scale := _calc_scale(960.0, 540.0)
	var expected: float = minf(960.0 / 1920.0, 540.0 / 1080.0)
	_assert("960x540 -> 0.5x (minimum)", absf(scale - expected) < 0.01)


func test_scale_800x600_preserves_aspect() -> void:
	_total += 1
	# 800/1920 = 0.417, 600/1080 = 0.556 -> min = 0.417, clamped to 0.5
	var scale := _calc_scale(800.0, 600.0)
	_assert("800x600 clamped to 0.5x", absf(scale - 0.5) < 0.01)


func test_scale_clamped_at_05_min() -> void:
	_total += 1
	var scale := _calc_scale(100.0, 100.0)
	_assert("100x100 clamped to 0.5x minimum", scale >= 0.499)


func test_scale_clamped_at_10_max() -> void:
	_total += 1
	var scale := _calc_scale(3840.0, 2160.0)
	_assert("3840x2160 clamped to 1.0x maximum", scale <= 1.001)


func test_scale_zero_viewport_returns_1() -> void:
	_total += 1
	var s1 := _calc_scale(0.0, 1080.0)
	_assert("Zero width -> 1.0 (guard)", is_equal_approx(s1, 1.0))
	_total += 1
	var s2 := _calc_scale(1920.0, 0.0)
	_assert("Zero height -> 1.0 (guard)", is_equal_approx(s2, 1.0))


func test_scale_negative_viewport_returns_1() -> void:
	_total += 1
	var scale := _calc_scale(-100.0, 1080.0)
	_assert("Negative width -> 1.0 (guard)", is_equal_approx(scale, 1.0))


func test_scale_ultrawide_height_limited() -> void:
	_total += 1
	# 2560/1920 = 1.33, 1080/1080 = 1.0 -> min = 1.0, clamped to 1.0
	var scale := _calc_scale(2560.0, 1080.0)
	_assert("Ultrawide 2560x1080 uses height ratio (1.0x)", is_equal_approx(scale, 1.0))


func test_scale_tall_width_limited() -> void:
	_total += 1
	# 1920/1920 = 1.0, 2160/1080 = 2.0 -> min = 1.0, clamped to 1.0
	var scale := _calc_scale(1920.0, 2160.0)
	_assert("Tall 1920x2160 uses width ratio (1.0x)", is_equal_approx(scale, 1.0))


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
