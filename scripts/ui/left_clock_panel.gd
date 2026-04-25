class_name LeftClockPanel
extends Control

## Left-side Day/Hour/Prestige status panel for the Bazaar shell.

const HOUR_COUNT: int = 6
const ACTIVE_HOUR_COLOR: Color = Color(1.0, 0.78, 0.22, 1.0)
const SHOP_HOUR_COLOR: Color = Color(0.25, 0.62, 0.95, 1.0)
const PVE_HOUR_COLOR: Color = Color(0.9, 0.35, 0.24, 1.0)
const PVP_HOUR_COLOR: Color = Color(0.95, 0.75, 0.18, 1.0)
const INACTIVE_HOUR_COLOR: Color = Color(0.18, 0.16, 0.13, 1.0)

var _run_state: Node = null
var _phase_service: Node = null
var _hour_dots: Array[Panel] = []

@onready var day_label: Label = $Frame/Margin/Layout/DayLabel
@onready var phase_label: Label = $Frame/Margin/Layout/PhaseLabel
@onready var hour_grid: GridContainer = $Frame/Margin/Layout/HourGrid
@onready var prestige_label: Label = $Frame/Margin/Layout/PrestigeLabel
@onready var wins_label: Label = $Frame/Margin/Layout/WinsLabel

func _ready() -> void:
	_create_hour_dots()

func bind_run_state(run_state: Node, phase_service: Node) -> void:
	_run_state = run_state
	_phase_service = phase_service
	if _run_state == null:
		return
	if _run_state.has_signal("day_changed") and not _run_state.day_changed.is_connected(_on_day_changed):
		_run_state.day_changed.connect(_on_day_changed)
	if _run_state.has_signal("hour_changed") and not _run_state.hour_changed.is_connected(_on_hour_changed):
		_run_state.hour_changed.connect(_on_hour_changed)
	if _run_state.has_signal("prestige_changed") and not _run_state.prestige_changed.is_connected(_on_prestige_changed):
		_run_state.prestige_changed.connect(_on_prestige_changed)
	if _run_state.has_signal("pvp_wins_changed") and not _run_state.pvp_wins_changed.is_connected(_on_pvp_wins_changed):
		_run_state.pvp_wins_changed.connect(_on_pvp_wins_changed)
	refresh(
		int(_run_state.get("current_day")),
		int(_run_state.get("current_hour")),
		int(_run_state.get("prestige")),
		int(_run_state.get("pvp_wins"))
	)

func refresh(day: int, hour: int, prestige: int, pvp_wins: int) -> void:
	var hour_index: int = _get_hour_index(hour)
	day_label.text = "Day %d" % day
	phase_label.text = "Hour %d / %s" % [hour_index, _get_phase_name(hour_index)]
	prestige_label.text = "Prestige %d" % prestige
	wins_label.text = "%d/10 Wins" % pvp_wins
	_refresh_hour_dots(hour_index)

func _create_hour_dots() -> void:
	_hour_dots.clear()
	for child in hour_grid.get_children():
		child.queue_free()
	for index in range(HOUR_COUNT):
		var dot: Panel = Panel.new()
		dot.name = "HourDot%d" % index
		dot.custom_minimum_size = Vector2(28, 28)
		dot.add_theme_stylebox_override("panel", _create_dot_style(_get_hour_color(index, -1), index == 2 or index == 5))
		var label: Label = Label.new()
		label.text = str(index)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		dot.add_child(label)
		hour_grid.add_child(dot)
		_hour_dots.append(dot)

func _refresh_hour_dots(active_hour: int) -> void:
	for index in range(_hour_dots.size()):
		var dot: Panel = _hour_dots[index]
		if not is_instance_valid(dot):
			continue
		var is_active: bool = index == active_hour
		dot.add_theme_stylebox_override("panel", _create_dot_style(_get_hour_color(index, active_hour), is_active))

func _get_hour_index(hour: int) -> int:
	if _phase_service != null and _phase_service.has_method("get_hour_index"):
		return int(_phase_service.get_hour_index(hour))
	return posmod(hour, HOUR_COUNT)

func _get_phase_name(hour: int) -> String:
	if _phase_service != null and _phase_service.has_method("get_current_phase_name"):
		return str(_phase_service.get_current_phase_name(hour))
	match hour:
		2:
			return "PvE"
		5:
			return "PvP"
		_:
			return "Build"

func _get_hour_color(index: int, active_hour: int) -> Color:
	if index == active_hour:
		return ACTIVE_HOUR_COLOR
	if index == 2:
		return PVE_HOUR_COLOR.darkened(0.2)
	if index == 5:
		return PVP_HOUR_COLOR.darkened(0.2)
	if index >= 0 and index < HOUR_COUNT:
		return SHOP_HOUR_COLOR.darkened(0.35)
	return INACTIVE_HOUR_COLOR

func _create_dot_style(color: Color, highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.95, 0.82, 0.38, 1.0) if highlighted else Color(0.32, 0.28, 0.20, 1.0)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(14)
	return style

func _on_day_changed(day: int) -> void:
	refresh(day, int(_run_state.get("current_hour")), int(_run_state.get("prestige")), int(_run_state.get("pvp_wins")))

func _on_hour_changed(hour: int, _phase_name: String) -> void:
	refresh(int(_run_state.get("current_day")), hour, int(_run_state.get("prestige")), int(_run_state.get("pvp_wins")))

func _on_prestige_changed(value: int) -> void:
	refresh(int(_run_state.get("current_day")), int(_run_state.get("current_hour")), value, int(_run_state.get("pvp_wins")))

func _on_pvp_wins_changed(value: int) -> void:
	refresh(int(_run_state.get("current_day")), int(_run_state.get("current_hour")), int(_run_state.get("prestige")), value)
