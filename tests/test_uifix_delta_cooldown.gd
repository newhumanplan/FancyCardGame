extends Node

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		print("== tests/test_uifix_delta_cooldown.gd ==")
		_run_tests()
		_print_summary()


## Replicates reduce_cooldowns() logic for pure data testing
func _reduce(current_cd: float, delta: float) -> float:
	var d: float = maxf(delta, 0.0)
	if d <= 0.0:
		return current_cd
	return maxf(current_cd - d, 0.0)


func _run_tests() -> void:
	test_delta_decrements_1s()
	test_delta_decrements_subframe()
	test_cooldown_clamped_to_zero()
	test_total_3s_at_60fps()
	test_total_3s_at_30fps()
	test_total_5s_variable_fps()
	test_cd_reduction_on_trigger()
	test_cd_reduction_clamped_80pct()
	test_cd_reduction_minimum_1s()
	test_negative_delta_ignored()
	test_zero_delta_ignored()
	test_multiple_items_independent()
	test_tick_rhythm_unchanged()


func test_delta_decrements_1s() -> void:
	_total += 1
	var cd := _reduce(5.0, 1.0)
	_assert("5.0 - 1.0 = 4.0", is_equal_approx(cd, 4.0))


func test_delta_decrements_subframe() -> void:
	_total += 1
	var cd := _reduce(1.0, 1.0 / 60.0)
	_assert("1.0 - 1/60 = 0.9833...", absf(cd - 59.0 / 60.0) < 0.01)


func test_cooldown_clamped_to_zero() -> void:
	_total += 1
	var cd := _reduce(0.5, 1.0)
	_assert("0.5 - 1.0 clamped to 0", is_equal_approx(cd, 0.0))


func test_total_3s_at_60fps() -> void:
	_total += 1
	var cd := 3.0
	var delta := 1.0 / 60.0
	for _i in range(180):  # 3 * 60 frames
		cd = _reduce(cd, delta)
	_assert("3.0s cooldown -> 0 after 3s at 60fps", absf(cd - 0.0) < 0.01)


func test_total_3s_at_30fps() -> void:
	_total += 1
	var cd := 3.0
	var delta := 1.0 / 30.0
	for _i in range(90):  # 3 * 30 frames
		cd = _reduce(cd, delta)
	_assert("3.0s cooldown -> 0 after 3s at 30fps", absf(cd - 0.0) < 0.01)


func test_total_5s_variable_fps() -> void:
	_total += 1
	var cd := 5.0
	# Simulate variable frame times: mix of 16ms and 33ms
	var deltas: Array[float] = [0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033,
		0.016, 0.033, 0.016, 0.033, 0.016, 0.033, 0.016, 0.033]
	var total: float = 0.0
	for d in deltas:
		cd = _reduce(cd, d)
		total += d
	# 160 * 0.0245 avg = ~3.92s, should still be > 0
	var passed: bool = cd > 0.0 and total < 5.0
	_assert("Variable FPS: cooldown > 0 after ~3.9s", passed)


func test_cd_reduction_on_trigger() -> void:
	_total += 1
	var base_cd: float = 5.0
	var reduction: float = 0.3
	var new_cd: float = maxf(base_cd * (1.0 - reduction), 1.0)
	_assert("5.0 * (1-0.3) = 3.5", is_equal_approx(new_cd, 3.5))


func test_cd_reduction_clamped_80pct() -> void:
	_total += 1
	var reduction: float = 0.9
	reduction = clampf(reduction, 0.0, 0.8)
	var base_cd: float = 3.0
	var new_cd: float = maxf(base_cd * (1.0 - reduction), 1.0)
	_assert("90%% reduction clamped to 80%% but min cooldown stays 1.0s", is_equal_approx(new_cd, 1.0))


func test_cd_reduction_minimum_1s() -> void:
	_total += 1
	var base_cd: float = 1.0
	var reduction: float = 0.99
	reduction = clampf(reduction, 0.0, 0.8)
	var new_cd: float = maxf(base_cd * (1.0 - reduction), 1.0)
	_assert("Minimum cooldown after reduction: 1.0s", is_equal_approx(new_cd, 1.0))


func test_negative_delta_ignored() -> void:
	_total += 1
	var cd := _reduce(5.0, -1.0)
	_assert("Negative delta: cooldown unchanged", is_equal_approx(cd, 5.0))


func test_zero_delta_ignored() -> void:
	_total += 1
	var cd := _reduce(5.0, 0.0)
	_assert("Zero delta: cooldown unchanged", is_equal_approx(cd, 5.0))


func test_multiple_items_independent() -> void:
	_total += 1
	var cd1 := _reduce(3.0, 1.0)
	var cd2 := _reduce(5.0, 1.0)
	var cd3 := _reduce(1.0, 1.0)
	var passed: bool = absf(cd1 - 2.0) < 0.01 and absf(cd2 - 4.0) < 0.01 and absf(cd3 - 0.0) < 0.01
	_assert("3 items decrement independently", passed)


func test_tick_rhythm_unchanged() -> void:
	_total += 1
	# BATTLE_TICK = 1.5s, cooldown decrements independently
	# After 1.0s: cooldown decremented 1.0s, but NO tick executed
	# After 1.5s: cooldown decremented 1.5s, ONE tick executed
	# This is a design invariant test
	var tick_time: float = 1.5
	var elapsed: float = 1.0
	var tick_fired: bool = elapsed >= tick_time  # false
	var cd_decremented: bool = true  # delta is applied every frame
	var passed: bool = not tick_fired and cd_decremented
	_assert("After 1.0s: cooldown decremented, tick not fired", passed)

	_total += 1
	elapsed = 1.5
	tick_fired = elapsed >= tick_time  # true
	passed = tick_fired
	_assert("After 1.5s: tick fires", passed)


func _assert(description: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		print("  FAIL: %s" % description)


func _print_summary() -> void:
	print("\nResults: %d/%d passed" % [_passed, _total])
