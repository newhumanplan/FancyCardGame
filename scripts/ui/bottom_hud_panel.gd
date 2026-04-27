class_name BottomHudPanel
extends Control

## Persistent bottom HUD for the Bazaar shell.

signal stash_requested()

const WARRIOR_AVATAR_PATH: String = "res://assets/art/ui/ui_avatar_warrior.png"
const MAGE_AVATAR_PATH: String = "res://assets/art/ui/ui_avatar_mage.png"
const CHEST_ICON_PATH: String = "res://assets/art/ui/ui_chest_icon.png"

var _game_manager: Node = null
var _hero_state: Node = null
var _economy: Node = null

@onready var hp_bar: ProgressBar = $HudFrame/HealthBar
@onready var hp_label: Label = $HudFrame/HealthBar/HPLabel
@onready var avatar_texture: TextureRect = $HudFrame/HeroPortraitArea/Avatar
@onready var hero_name_label: Label = $HudFrame/HeroPortraitArea/HeroNameLabel
@onready var level_label: Label = $HudFrame/HeroPortraitArea/LevelLabel
@onready var xp_label: Label = $HudFrame/HeroPortraitArea/XPLabel
@onready var gold_label: Label = $HudFrame/WalletArea/GoldLabel
@onready var income_label: Label = $HudFrame/WalletArea/IncomeLabel
@onready var stash_button: Button = $HudFrame/StashButtonArea/StashButton
@onready var passive_skill_area: HBoxContainer = $HudFrame/PassiveSkillArea

var combat_status_label: Label = null

func _ready() -> void:
	stash_button.pressed.connect(_on_stash_pressed)
	_setup_chest_icon()
	_create_combat_status_label()
	_hide_passive_area_until_icons_exist()

func bind_services(game_manager: Node, hero_state: Node, economy: Node) -> void:
	_game_manager = game_manager
	_hero_state = hero_state
	_economy = economy
	_connect_service_signals()
	refresh_all()

func refresh_all() -> void:
	_refresh_health()
	_refresh_hero()
	_refresh_level()
	_refresh_wallet()

func set_combat_status(burn_value: float, poison_value: float, regen_value: float = 0.0) -> void:
	_create_combat_status_label()
	var parts: Array[String] = []
	if burn_value > 0.0:
		parts.append("灼烧 %.0f" % burn_value)
	if poison_value > 0.0:
		parts.append("中毒 %.0f" % poison_value)
	if regen_value > 0.0:
		parts.append("再生 %.0f" % regen_value)
	combat_status_label.text = "  ".join(parts)
	combat_status_label.visible = not parts.is_empty()

func _connect_service_signals() -> void:
	if _game_manager != null:
		if _game_manager.has_signal("health_changed") and not _game_manager.health_changed.is_connected(_on_health_changed):
			_game_manager.health_changed.connect(_on_health_changed)
		if _game_manager.has_signal("gold_changed") and not _game_manager.gold_changed.is_connected(_on_gold_changed):
			_game_manager.gold_changed.connect(_on_gold_changed)
		if _game_manager.has_signal("income_changed") and not _game_manager.income_changed.is_connected(_on_income_changed):
			_game_manager.income_changed.connect(_on_income_changed)
		if _game_manager.has_signal("xp_changed") and not _game_manager.xp_changed.is_connected(_on_xp_changed):
			_game_manager.xp_changed.connect(_on_xp_changed)
		if _game_manager.has_signal("level_changed") and not _game_manager.level_changed.is_connected(_on_level_changed):
			_game_manager.level_changed.connect(_on_level_changed)
	if _hero_state != null:
		if _hero_state.has_signal("max_health_changed") and not _hero_state.max_health_changed.is_connected(_on_max_health_changed):
			_hero_state.max_health_changed.connect(_on_max_health_changed)

func _refresh_health() -> void:
	var current_hp: int = _get_int(_game_manager, "player_health", 100)
	var max_hp: int = 100
	if _game_manager != null and _game_manager.has_method("get_max_health"):
		max_hp = int(_game_manager.get_max_health())
	hp_bar.max_value = maxf(float(max_hp), 1.0)
	hp_bar.value = clampf(float(current_hp), 0.0, hp_bar.max_value)
	hp_label.text = "%d" % current_hp

func _create_combat_status_label() -> void:
	if combat_status_label != null:
		return
	combat_status_label = Label.new()
	combat_status_label.name = "CombatStatusLabel"
	combat_status_label.visible = false
	combat_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combat_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_status_label.add_theme_font_size_override("font_size", 12)
	combat_status_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42, 1.0))
	combat_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_status_label.anchor_left = 0.58
	combat_status_label.anchor_top = 0.0
	combat_status_label.anchor_right = 0.78
	combat_status_label.anchor_bottom = 0.06
	combat_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HudFrame.add_child(combat_status_label)

func _refresh_hero() -> void:
	var hero: Object = null
	if _game_manager != null:
		hero = _game_manager.get("selected_hero")
	if hero == null:
		hero_name_label.text = "Hero"
		avatar_texture.texture = null
		return

	hero_name_label.text = str(hero.get("hero_name"))
	var avatar_path: String = WARRIOR_AVATAR_PATH
	if int(hero.get("hero_type")) == 1:
		avatar_path = MAGE_AVATAR_PATH
	if ResourceLoader.exists(avatar_path):
		avatar_texture.texture = load(avatar_path)

func _refresh_level() -> void:
	var level: int = _get_int(_game_manager, "level", 1)
	var xp: int = _get_int(_game_manager, "xp", 0)
	var xp_max: int = 8
	if _hero_state != null:
		xp_max = int(_hero_state.get("XP_PER_LEVEL")) if _hero_state.get("XP_PER_LEVEL") != null else 8
	level_label.text = "Lv %d" % level
	xp_label.text = "XP %d/%d" % [xp, xp_max]

func _refresh_wallet() -> void:
	gold_label.text = "Gold %d" % _get_int(_game_manager, "gold", 0)
	income_label.text = "Income %d" % _get_int(_game_manager, "income", 0)

func _setup_chest_icon() -> void:
	if not ResourceLoader.exists(CHEST_ICON_PATH):
		return
	var icon: Texture2D = load(CHEST_ICON_PATH)
	stash_button.icon = icon
	stash_button.expand_icon = true

func _hide_passive_area_until_icons_exist() -> void:
	for child in passive_skill_area.get_children():
		child.queue_free()
	passive_skill_area.visible = false

func _get_int(source: Object, property_name: String, fallback: int) -> int:
	if source == null:
		return fallback
	var value: Variant = source.get(property_name)
	if value == null:
		return fallback
	return int(value)

func _on_stash_pressed() -> void:
	stash_requested.emit()

func _on_health_changed(_amount: int) -> void:
	_refresh_health()

func _on_max_health_changed(_value: int) -> void:
	_refresh_health()

func _on_gold_changed(_amount: int) -> void:
	_refresh_wallet()

func _on_income_changed(_amount: int) -> void:
	_refresh_wallet()

func _on_xp_changed(_value: int) -> void:
	_refresh_level()

func _on_level_changed(_value: int) -> void:
	_refresh_level()
