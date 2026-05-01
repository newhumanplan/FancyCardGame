class_name BattleUI
extends Control
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const ItemArtCatalogClass = preload("res://scripts/data/item_art_catalog.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

## 战斗面板 UI - 管理战斗界面和自动战斗循环
## 重构：纯物品触发战斗，移除独立攻击逻辑

const MonsterAIClass = preload("res://scripts/data/monster_ai.gd")
const SkillDataClass = preload("res://scripts/data/skill_data.gd")

const BATTLE_TICK: float = 0.5
const PVP_BASE_VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const PVP_MIN_SCALE: float = 0.5
const PVP_MAX_SCALE: float = 1.0
const MIN_ITEM_COOLDOWN: float = 1.0
const PVP_RESIZE_CHECK_INTERVAL: float = 2.0
const PVP_LEFT_PANEL_RIGHT: float = 0.15
const PVP_BOTTOM_PANEL_TOP: float = 0.50
const PVP_SHOP_ROW_LEFT: float = 0.28
const PVP_SHOP_ROW_RIGHT: float = 0.72
const PVP_SHOP_ROW_TOP: float = 0.15
const PVP_SHOP_ROW_BOTTOM: float = 0.31
const PVP_RIVER_LEFT: float = 0.15
const PVP_RIVER_RIGHT: float = 1.0
const PVP_RIVER_TOP: float = 0.42
const PVP_RIVER_BOTTOM: float = 0.46
const PVP_COMBAT_HAND_LEFT: float = 0.30
const PVP_COMBAT_HAND_RIGHT: float = 0.70
const PVP_COMBAT_HAND_TOP: float = 0.31
const PVP_COMBAT_HAND_BOTTOM: float = 0.40
const PVP_ITEM_BAR_LEFT: float = 0.20
const PVP_ITEM_BAR_RIGHT: float = 0.80
const PVP_ITEM_BAR_TOP: float = 0.76
const PVP_ITEM_BAR_BOTTOM: float = 0.85
const PVP_ITEM_SLOT_WIDTH: float = 0.045
const PVP_ITEM_SLOT_HEIGHT: float = 0.09
const PVP_TOP_CARD_WIDTH: float = 0.05
const PVP_TOP_CARD_HEIGHT: float = 0.11
const PVP_SHOP_CARD_COUNT: int = 5
const PVP_LEFT_PANEL_INSET_LEFT: float = 0.13
const PVP_LEFT_PANEL_INSET_RIGHT: float = 0.93
const PVP_LEFT_PANEL_WINS_TOP: float = 0.06
const PVP_LEFT_PANEL_WINS_BOTTOM: float = 0.18
const PVP_LEFT_PANEL_CLOCK_TOP: float = 0.24
const PVP_LEFT_PANEL_CLOCK_BOTTOM: float = 0.35
const PVP_CHEST_TOP: float = 0.88
const PVP_CHEST_BOTTOM: float = 0.98
const PVP_CLOCK_ICON: String = "res://assets/art/ui/pvp/pvp_clock_icon.png"
const PVP_AVATAR_FRAME: String = "res://assets/art/ui/pvp/pvp_avatar_frame.png"
const PVP_HERO_AVATAR: String = "res://assets/art/ui/pvp/pvp_hero_avatar.png"
## Bazaar风格 UI 资源
const PVP_AVATAR_WARRIOR: String = "res://assets/art/ui/ui_avatar_warrior.png"
const PVP_AVATAR_MAGE: String = "res://assets/art/ui/ui_avatar_mage.png"
const PVP_BG_GRADIENT: String = "res://assets/art/ui/ui_bg_gradient.png"
const PVP_EVENT_CARD_BG: String = "res://assets/art/ui/ui_event_card_bg.png"
const PVP_SHOP_CARD_BG: String = "res://assets/art/ui/ui_shop_card_bg.png"
const PVP_ITEM_SLOT_EMPTY: String = "res://assets/art/ui/ui_item_slot_empty.png"
const PVP_ITEM_CARD_BG: String = "res://assets/art/ui/ui_item_card_bg.png"
const PVP_CHEST_ICON: String = "res://assets/art/ui/ui_chest_icon.png"
const PVP_HAND_SLOT_COUNT: int = 10
const PVP_OPPONENT_SLOT_COUNT: int = 5
const SHELL_BOARD_SLOT_SPACING: int = 8
const SHELL_BOARD_SLOT_SIZE: Vector2 = Vector2(96, 192)
const PVP_RIVER_COLOR: Color = Color8(26, 92, 110, 235)
const PVP_SHOP_BORDER_COLOR: Color = Color8(74, 158, 255, 255)
const PVP_HAND_BORDER_COLOR: Color = Color8(42, 42, 62, 255)
const PVP_SHIELD_COLOR: Color = Color8(79, 195, 247, 255)
const PVP_TOOLTIP_WIDTH: float = 390.0
const PVP_TOOLTIP_GOLD: Color = Color(0.86, 0.64, 0.30, 1.0)

## GameManager 引用
var game_manager: Node

## 战斗系统引用
var battle_system: Node

## 背包系统引用
var inventory: LinearInventoryClass = null

## 敌人数据
var current_monster: MonsterDataClass = null

## 是否为 PvP 战斗
var is_pvp: bool = false

## 战斗结果缓存
var _last_battle_won: bool = false
var _last_gold_reward: int = 0

## 战斗状态
var is_battle_active: bool = false

## 战斗计时器
var battle_timer: float = 0.0
var elapsed_since_last_tick: float = 0.0

## 信号
signal battle_ended(won: bool, gold_reward: int)
signal battle_log(message: String)

## ============ UI 节点 ============

@onready var battle_panel: PanelContainer = $BattlePanel
@onready var title_label: Label = $BattlePanel/VBox/TitleLabel
@onready var player_name_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerNameLabel
@onready var player_hp_bar: ProgressBar = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerHPBar
@onready var player_hp_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerHPBar/PlayerHPText
@onready var player_atk_label: Label = $BattlePanel/VBox/BattleArea/PlayerArea/PlayerATKLabel
@onready var player_area: Control = $BattlePanel/VBox/BattleArea/PlayerArea
@onready var enemy_name_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyHPBar
@onready var enemy_hp_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyHPBar/EnemyHPText
@onready var enemy_atk_label: Label = $BattlePanel/VBox/BattleArea/EnemyArea/EnemyATKLabel
@onready var battle_log_label: RichTextLabel = $BattlePanel/VBox/BattleLogArea/BattleLogLabel
@onready var result_label: Label = $BattlePanel/VBox/ResultLabel
@onready var auto_battle_check: CheckButton = $BattlePanel/VBox/AutoBattleCheck
@onready var continue_button: Button = $BattlePanel/VBox/ContinueButton

## 自动战斗开关
var auto_battle: bool = true

## PvE 护盾 UI
var player_shield_bar: ProgressBar = null
var player_shield_label: Label = null

## PvP 动态布局节点
var pvp_root: Control = null
var pvp_left_panel: Control = null
var pvp_opponent_bar: PanelContainer = null
var pvp_player_bar: PanelContainer = null
var pvp_battle_center: Control = null
var pvp_river_rect: ColorRect = null
var pvp_opponent_name_label: Label = null
var pvp_opponent_hp_bar: ProgressBar = null
var pvp_opponent_hp_label: Label = null
var pvp_opponent_shield_bar: ProgressBar = null
var pvp_opponent_shield_label: Label = null
var pvp_opponent_status_label: Label = null
var pvp_opponent_meta_label: Label = null
var pvp_opponent_skill_labels: Array[Label] = []
var pvp_opponent_hand_container: Control = null
var pvp_shop_container: Control = null
var pvp_player_name_label: Label = null
var pvp_player_hp_bar: ProgressBar = null
var pvp_player_hp_label: Label = null
var pvp_player_shield_bar: ProgressBar = null
var pvp_player_shield_label: Label = null
var pvp_player_status_label: Label = null
var pvp_player_meta_label: Label = null
var pvp_player_skill_labels: Array[Label] = []
var pvp_player_hand_container: Control = null
var pvp_combat_hand_container: Control = null
var pvp_auto_battle_check: CheckButton = null
var pvp_end_turn_button: Button = null
var pvp_battle_log: RichTextLabel = null
var pvp_result_label: Label = null
var pvp_continue_button: Button = null
var pvp_clock_texture: TextureRect = null
var pvp_avatar_frame_opponent: TextureRect = null
var pvp_avatar_frame_player: TextureRect = null
var pvp_wins_label: Label = null
var pvp_clock_label: Label = null
var pvp_gold_label: Label = null
var pvp_player_card_panels: Array[Panel] = []
var pvp_opponent_card_panels: Array[Panel] = []
var pvp_combat_hand_panels: Array[Panel] = []
var pvp_selected_card: Panel = null
var pvp_hover_card: Panel = null
var pvp_tooltip_panel: PanelContainer = null
var pvp_tooltip_label: RichTextLabel = null
var _shell_layout: Control = null
var _uses_shell_layout: bool = false
var _pvp_content_scale: float = 1.0
var _pvp_resize_timer: float = 0.0

func _ready() -> void:
	game_manager = get_node("/root/GameManager")
	battle_system = get_node("/root/BattleSystem")

	battle_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	auto_battle_check.button_pressed = true
	auto_battle_check.toggled.connect(_on_auto_battle_toggled)
	continue_button.pressed.connect(_on_continue_pressed)

	if battle_system.has_signal("item_triggered"):
		battle_system.item_triggered.connect(_on_item_triggered)
	if battle_system.has_signal("monster_item_triggered"):
		battle_system.monster_item_triggered.connect(_on_monster_item_triggered)
	if battle_system.has_signal("effect_applied"):
		battle_system.effect_applied.connect(_on_effect_applied)

	print("BattleUI 已初始化")

## 自动战斗开关回调
func _on_auto_battle_toggled(toggled_on: bool) -> void:
	auto_battle = toggled_on
	if pvp_auto_battle_check != null and pvp_auto_battle_check.button_pressed != toggled_on:
		pvp_auto_battle_check.button_pressed = toggled_on
	if auto_battle_check.button_pressed != toggled_on:
		auto_battle_check.button_pressed = toggled_on

## ============ 战斗系统信号回调 ============

func _on_item_triggered(item_name: String, damage: int, is_crit: bool, target: String) -> void:
	var crit_text: String = "（暴击!）" if is_crit else ""
	_log("🗡️ [%s] 触发！造成 %d 伤害%s" % [item_name, damage, crit_text])

func _on_monster_item_triggered(monster_name: String, item_name: String, damage: int) -> void:
	_log("👹 [%s] 的 [%s] 触发！造成 %d 伤害" % [monster_name, item_name, damage])

func _on_effect_applied(item_name: String, effect_type: String, value: int, target: String) -> void:
	match effect_type:
		"shield":
			_log("🛡️ [%s] 触发！获得 %d 护盾" % [item_name, value])
		"heal":
			_log("💚 [%s] 触发！恢复 %d 生命" % [item_name, value])

## ============ 战斗控制 ============

func start_battle(monster: MonsterDataClass = null, pvp: bool = false, enemy_atk_bonus: int = 0) -> void:
	is_pvp = pvp
	battle_timer = 0.0
	elapsed_since_last_tick = 0.0
	_pvp_resize_timer = 0.0

	var main: Node = get_parent()
	_shell_layout = null
	_uses_shell_layout = false
	if main != null and main.has_node("InventoryUI"):
		inventory = main.get_node("InventoryUI").get_inventory()
		# Connect to inventory changes so hand display updates when items are bought
		if inventory.has_signal("inventory_changed"):
			if not inventory.inventory_changed.is_connected(_update_pvp_player_hand):
				inventory.inventory_changed.connect(_update_pvp_player_hand)
	if main != null and main.has_node("BazaarShell"):
		_shell_layout = main.get_node("BazaarShell") as Control
		_uses_shell_layout = _shell_layout != null and _shell_layout.visible

	if monster != null:
		current_monster = monster
	elif not is_pvp:
		current_monster = _generate_random_monster()
	else:
		current_monster = _create_pvp_enemy(enemy_atk_bonus)

	print("BattleUI inventory items count: %d" % inventory.items.size())
	if current_monster == null or inventory == null:
		return

	battle_system.start_battle(current_monster, inventory)

	_create_pvp_layout()

	_show_battle_panel()
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _uses_shell_layout else Control.MOUSE_FILTER_STOP
	_update_battle_ui()

	is_battle_active = true
	_log("⚔️ 战斗开始! %s 出现!" % current_monster.monster_name)

	if current_monster.monster_items.size() > 0:
		for monster_item in current_monster.monster_items:
			_log("   → %s (伤害:%d, CD:%.1fs)" % [
				monster_item["name"],
				_get_monster_item_effective_damage(monster_item),
				monster_item["cooldown"]
			])

## ============ 怪物生成 ============

func _assign_monster_ai(monster: MonsterDataClass, day: int) -> void:
	match monster.tier:
		MonsterDataClass.MonsterTier.TIER_1:
			monster.ai = MonsterAIClass.create_swarm()
		MonsterDataClass.MonsterTier.TIER_2:
			if randf() < 0.5:
				monster.ai = MonsterAIClass.create_technical()
			else:
				monster.ai = MonsterAIClass.create_defensive()
		MonsterDataClass.MonsterTier.TIER_3:
			monster.ai = MonsterAIClass.create_boss()
	print("👹 [%s] AI模式: %s" % [monster.monster_name, monster.ai.get_mode_name()])

func _generate_random_monster() -> MonsterDataClass:
	var monster: MonsterDataClass = BazaarContentClass.create_monster("", game_manager.current_day)
	if monster == null:
		push_error("BattleUI: failed to create a monster from BazaarContent.")
		return MonsterDataClass.new()
	_assign_monster_ai(monster, game_manager.current_day)
	return monster

func _create_pvp_enemy(enemy_atk_bonus: int = 0) -> MonsterDataClass:
	var monster: MonsterDataClass = MonsterDataClass.new()
	var hero_types: Array[int] = [0, 1]
	var random_hero_type: int = hero_types.pick_random()
	var day: int = game_manager.current_day

	if random_hero_type == 0:
		monster.monster_name = "PvP 战士"
		monster.max_hp = 200 + day * 15
		monster.monster_items = [
			_create_monster_item("战士之剑", ItemDataClass.Type.WEAPON, 12 + day, 15 + day + enemy_atk_bonus, 3.0),
			_create_monster_item("铁盾反击", ItemDataClass.Type.SHIELD, 10 + day, 5 + day + enemy_atk_bonus, 2.5)
		]
	else:
		monster.monster_name = "PvP 法师"
		monster.max_hp = 160 + day * 15
		monster.monster_items = [
			_create_monster_item("奥术法杖", ItemDataClass.Type.UTILITY, 14 + day, 22 + day * 2 + enemy_atk_bonus, 4.5)
		]

	monster.gold_reward_min = 0
	monster.gold_reward_max = 0
	monster.xp_reward = 0
	monster.current_hp = monster.max_hp
	monster.ai = MonsterAIClass.create_aggressive()

	if is_pvp:
		_log("⚔️ 对手: %s (HP: %.0f, 物品数: %d)" % [
			monster.monster_name,
			monster.max_hp,
			monster.monster_items.size()
		])

	return monster

func _create_monster_item(name: String, item_type: int, buy_price: int, damage: int, cooldown: float, shield: int = 0, heal: int = 0) -> Dictionary:
	var item_cooldown: float = maxf(cooldown, 0.0)
	if item_cooldown > 0.0:
		item_cooldown = maxf(item_cooldown, MIN_ITEM_COOLDOWN)
	return {
		"name": name,
		"type": item_type,
		"buy_price": max(buy_price, 0),
		"damage": max(damage, 0),
		"shield": max(shield, 0),
		"heal": max(heal, 0),
		"cooldown": item_cooldown,
		"current_cooldown": item_cooldown
	}

## ============ UI 管理 ============

func _show_battle_panel() -> void:
	battle_panel.visible = false
	if pvp_root == null:
		_create_pvp_layout()
	if pvp_root == null:
		push_error("BattleUI: pvp_root creation failed, falling back to battle_panel.tscn")
		battle_panel.visible = true
		return

	pvp_root.visible = true
	if pvp_result_label != null:
		pvp_result_label.visible = false
	if pvp_continue_button != null:
		pvp_continue_button.visible = false
	if pvp_battle_log != null:
		pvp_battle_log.clear()
	_reset_pvp_shield_ui()
	_sync_auto_battle_check_state()
	_update_pvp_player_hand()
	_update_pvp_opponent_hand()
	_setup_mode_specific()

func _hide_battle_panel() -> void:
	_update_shell_player_status({"burn": 0.0, "poison": 0.0, "regeneration": 0.0})
	if pvp_root != null:
		pvp_root.visible = false
	_destroy_pvp_layout()
	battle_panel.visible = false
	is_battle_active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## ============ PvP 布局 ============

func _create_pvp_layout() -> void:
	if pvp_root != null:
		return

	if _uses_shell_layout:
		_create_shell_battle_layout()
		return

	pvp_root = Control.new()
	pvp_root.name = "PvPRoot"
	pvp_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pvp_root.offset_left = -960.0
	pvp_root.offset_top = -540.0
	pvp_root.offset_right = 960.0
	pvp_root.offset_bottom = 540.0
	pvp_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pvp_root)
	_apply_pvp_content_scale()

	# Bazaar 背景渐变
	if ResourceLoader.exists(PVP_BG_GRADIENT):
		var bg_tex: TextureRect = TextureRect.new()
		bg_tex.name = "BattleBackground"
		bg_tex.texture = load(PVP_BG_GRADIENT)
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.z_index = -10
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pvp_root.add_child(bg_tex)

	_create_pvp_left_panel()
	_create_pvp_opponent_bar()
	_create_pvp_battle_center()
	_create_pvp_player_bar()
	_create_pvp_tooltip()
	_sync_auto_battle_check_state()
	_update_pvp_player_hand()
	_update_pvp_opponent_hand()
	_setup_mode_specific()

func _create_shell_battle_layout() -> void:
	if _shell_layout == null:
		_uses_shell_layout = false
		return

	if _shell_layout.has_method("show_run_shell"):
		_shell_layout.call("show_run_shell")
	if _shell_layout.has_method("clear_dynamic_regions"):
		_shell_layout.call("clear_dynamic_regions")
	if _shell_layout.has_method("set_board_interaction_enabled"):
		_shell_layout.call("set_board_interaction_enabled", false)

	pvp_root = Control.new()
	pvp_root.name = "BattleShellState"
	pvp_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pvp_root)
	_create_pvp_tooltip()

	var top_context: Control = _shell_layout.get_node_or_null("TopContextPanel") as Control
	var upper_board: Control = _shell_layout.get_node_or_null("UpperBoardPanel") as Control
	var right_actions: Control = _shell_layout.get_node_or_null("RightActionArea") as Control

	if top_context != null:
		_create_shell_opponent_context(top_context)
	if upper_board != null:
		_create_shell_opponent_board(upper_board)
	if right_actions != null:
		_create_shell_battle_actions(right_actions)

	_update_pvp_opponent_hand()
	_setup_mode_specific()

func _create_shell_opponent_context(parent: Control) -> void:
	pvp_opponent_bar = PanelContainer.new()
	pvp_opponent_bar.name = "OpponentContext"
	pvp_opponent_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pvp_opponent_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.13, 0.20, 0.0), Color(0.46, 0.38, 0.25, 0.0)))
	parent.add_child(pvp_opponent_bar)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pvp_opponent_bar.add_child(root)

	var portrait_area: Panel = Panel.new()
	portrait_area.name = "OpponentPortraitArea"
	portrait_area.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.13, 0.20, 0.82), Color(0.78, 0.56, 0.22, 0.9)))
	_set_percent_rect(portrait_area, 0.42, 0.08, 0.58, 0.68)
	root.add_child(portrait_area)

	pvp_avatar_frame_opponent = TextureRect.new()
	pvp_avatar_frame_opponent.name = "OpponentAvatar"
	pvp_avatar_frame_opponent.texture = load(PVP_AVATAR_FRAME)
	pvp_avatar_frame_opponent.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_avatar_frame_opponent.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_avatar_frame_opponent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_percent_rect(pvp_avatar_frame_opponent, 0.16, 0.04, 0.84, 0.62)
	portrait_area.add_child(pvp_avatar_frame_opponent)

	pvp_opponent_name_label = Label.new()
	pvp_opponent_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_opponent_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pvp_opponent_name_label.clip_text = true
	pvp_opponent_name_label.add_theme_font_size_override("font_size", 18)
	_set_percent_rect(pvp_opponent_name_label, 0.04, 0.62, 0.96, 0.88)
	portrait_area.add_child(pvp_opponent_name_label)

	var hp_stack: Control = _create_pvp_hp_stack()
	_set_percent_rect(hp_stack, 0.22, 0.72, 0.78, 0.94)
	root.add_child(hp_stack)
	pvp_opponent_hp_bar = hp_stack.get_node("HPBar") as ProgressBar
	pvp_opponent_hp_label = hp_stack.get_node("HPText") as Label
	pvp_opponent_shield_bar = hp_stack.get_node("ShieldBar") as ProgressBar
	pvp_opponent_shield_label = hp_stack.get_node("ShieldLabel") as Label
	pvp_opponent_status_label = hp_stack.get_node("StatusLabel") as Label

	pvp_opponent_meta_label = null
	pvp_opponent_skill_labels.clear()

func _create_shell_opponent_board(parent: Control) -> void:
	pvp_shop_container = Control.new()
	pvp_shop_container.name = "OpponentBoardContainer"
	pvp_shop_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pvp_shop_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pvp_shop_container)

func _create_shell_battle_actions(parent: Control) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "BattleActionColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(column)

	pvp_result_label = Label.new()
	pvp_result_label.name = "BattleResultLabel"
	pvp_result_label.visible = false
	pvp_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_result_label.add_theme_font_size_override("font_size", 18)
	column.add_child(pvp_result_label)

	pvp_continue_button = Button.new()
	pvp_continue_button.name = "BattleContinueButton"
	pvp_continue_button.text = "继续"
	pvp_continue_button.visible = false
	pvp_continue_button.custom_minimum_size = Vector2(120, 42)
	pvp_continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(pvp_continue_button)

func _setup_mode_specific() -> void:
	if pvp_shop_container != null:
		pvp_shop_container.visible = true
	if pvp_clock_texture != null:
		pvp_clock_texture.visible = true
	if pvp_end_turn_button != null:
		pvp_end_turn_button.visible = false

func _destroy_pvp_layout() -> void:
	if _uses_shell_layout and _shell_layout != null:
		if _shell_layout.has_method("clear_dynamic_regions"):
			_shell_layout.call("clear_dynamic_regions")
		if _shell_layout.has_method("set_board_interaction_enabled"):
			_shell_layout.call("set_board_interaction_enabled", true)

	if pvp_root != null and is_instance_valid(pvp_root):
		pvp_root.queue_free()

	pvp_root = null
	pvp_left_panel = null
	pvp_opponent_bar = null
	pvp_player_bar = null
	pvp_battle_center = null
	pvp_river_rect = null
	pvp_opponent_name_label = null
	pvp_opponent_hp_bar = null
	pvp_opponent_hp_label = null
	pvp_opponent_shield_bar = null
	pvp_opponent_shield_label = null
	pvp_opponent_status_label = null
	pvp_opponent_meta_label = null
	pvp_opponent_skill_labels.clear()
	pvp_opponent_hand_container = null
	pvp_shop_container = null
	pvp_player_name_label = null
	pvp_player_hp_bar = null
	pvp_player_hp_label = null
	pvp_player_shield_bar = null
	pvp_player_shield_label = null
	pvp_player_status_label = null
	pvp_player_meta_label = null
	pvp_player_skill_labels.clear()
	pvp_player_hand_container = null
	pvp_combat_hand_container = null
	pvp_auto_battle_check = null
	pvp_end_turn_button = null
	pvp_battle_log = null
	pvp_clock_texture = null
	pvp_avatar_frame_opponent = null
	pvp_avatar_frame_player = null
	pvp_wins_label = null
	pvp_clock_label = null
	pvp_gold_label = null
	pvp_result_label = null
	pvp_continue_button = null
	pvp_tooltip_panel = null
	pvp_tooltip_label = null
	_shell_layout = null
	_uses_shell_layout = false
	pvp_selected_card = null
	pvp_hover_card = null
	pvp_player_card_panels.clear()
	pvp_opponent_card_panels.clear()
	pvp_combat_hand_panels.clear()
	_pvp_content_scale = 1.0
	_pvp_resize_timer = 0.0

func _create_pvp_left_panel() -> void:
	pvp_left_panel = Control.new()
	pvp_left_panel.name = "LeftPanel"
	_set_percent_rect(pvp_left_panel, 0.0, 0.0, PVP_LEFT_PANEL_RIGHT, 1.0)
	pvp_left_panel.z_index = 5
	pvp_root.add_child(pvp_left_panel)

	var wins_box: PanelContainer = PanelContainer.new()
	wins_box.name = "WinsBox"
	_set_percent_rect(
		wins_box,
		PVP_LEFT_PANEL_INSET_LEFT,
		PVP_LEFT_PANEL_WINS_TOP,
		PVP_LEFT_PANEL_INSET_RIGHT,
		PVP_LEFT_PANEL_WINS_BOTTOM
	)
	wins_box.add_theme_stylebox_override("panel", _create_panel_style(Color(0.23, 0.20, 0.14, 0.96), Color(0.84, 0.72, 0.40, 1.0)))
	wins_box.z_index = 6
	pvp_left_panel.add_child(wins_box)

	var wins_center: CenterContainer = CenterContainer.new()
	wins_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wins_box.add_child(wins_center)

	pvp_wins_label = Label.new()
	pvp_wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_wins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pvp_wins_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_wins_label.add_theme_font_size_override("font_size", _scaled_int(28.0, 18, 34))
	wins_center.add_child(pvp_wins_label)

	var clock_box: PanelContainer = PanelContainer.new()
	clock_box.name = "ClockBox"
	_set_percent_rect(
		clock_box,
		PVP_LEFT_PANEL_INSET_LEFT,
		PVP_LEFT_PANEL_CLOCK_TOP,
		PVP_LEFT_PANEL_INSET_RIGHT,
		PVP_LEFT_PANEL_CLOCK_BOTTOM
	)
	clock_box.add_theme_stylebox_override("panel", _create_panel_style(Color(0.14, 0.16, 0.20, 0.96), Color(0.55, 0.60, 0.72, 1.0)))
	clock_box.z_index = 6
	pvp_left_panel.add_child(clock_box)

	var clock_vbox: VBoxContainer = VBoxContainer.new()
	clock_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_vbox.add_theme_constant_override("separation", _scaled_int(6.0, 4, 10))
	clock_box.add_child(clock_vbox)

	pvp_clock_texture = TextureRect.new()
	pvp_clock_texture.name = "ClockIcon"
	pvp_clock_texture.texture = load(PVP_CLOCK_ICON)
	pvp_clock_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_clock_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_clock_texture.custom_minimum_size = Vector2(_scaled_value(30.0, 22.0, 40.0), _scaled_value(30.0, 22.0, 40.0))
	pvp_clock_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_vbox.add_child(pvp_clock_texture)

	pvp_clock_label = Label.new()
	pvp_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_clock_label.add_theme_font_size_override("font_size", _scaled_int(16.0, 12, 20))
	clock_vbox.add_child(pvp_clock_label)

func _create_pvp_opponent_bar() -> void:
	pvp_opponent_bar = PanelContainer.new()
	pvp_opponent_bar.name = "OpponentBar"
	_set_percent_rect(pvp_opponent_bar, 0.45, 0.02, 0.65, 0.14)
	pvp_opponent_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.13, 0.20, 0.96), Color(0.25, 0.28, 0.40, 1.0)))
	pvp_root.add_child(pvp_opponent_bar)

	var root_hbox: HBoxContainer = HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", _scaled_int(18.0, 10, 22))
	pvp_opponent_bar.add_child(root_hbox)

	pvp_avatar_frame_opponent = TextureRect.new()
	pvp_avatar_frame_opponent.name = "AvatarFrame"
	pvp_avatar_frame_opponent.texture = load(PVP_AVATAR_FRAME)
	pvp_avatar_frame_opponent.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_avatar_frame_opponent.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_avatar_frame_opponent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_avatar_frame_opponent.custom_minimum_size = Vector2(_scaled_value(72.0, 48.0, 84.0), _scaled_value(72.0, 48.0, 84.0))
	root_hbox.add_child(pvp_avatar_frame_opponent)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", _scaled_int(6.0, 4, 10))
	root_hbox.add_child(info_box)

	pvp_opponent_name_label = Label.new()
	pvp_opponent_name_label.add_theme_font_size_override("font_size", _scaled_int(22.0, 16, 28))
	info_box.add_child(pvp_opponent_name_label)

	var hp_stack: Control = _create_pvp_hp_stack()
	info_box.add_child(hp_stack)
	pvp_opponent_hp_bar = hp_stack.get_node("HPBar") as ProgressBar
	pvp_opponent_hp_label = hp_stack.get_node("HPText") as Label
	pvp_opponent_shield_bar = hp_stack.get_node("ShieldBar") as ProgressBar
	pvp_opponent_shield_label = hp_stack.get_node("ShieldLabel") as Label

	pvp_opponent_meta_label = Label.new()
	pvp_opponent_meta_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.62, 1.0))
	pvp_opponent_meta_label.add_theme_font_size_override("font_size", _scaled_int(14.0, 11, 18))
	info_box.add_child(pvp_opponent_meta_label)

	pvp_opponent_skill_labels.clear()
	for skill_index in range(4):
		var skill_label: Label = _create_skill_slot_label("Empty")
		skill_label.visible = false
		pvp_opponent_skill_labels.append(skill_label)

func _create_pvp_battle_center() -> void:
	pvp_battle_center = Control.new()
	pvp_battle_center.name = "BattleCenter"
	_set_percent_rect(pvp_battle_center, PVP_LEFT_PANEL_RIGHT, 0.0, 1.0, PVP_BOTTOM_PANEL_TOP)
	pvp_root.add_child(pvp_battle_center)

	pvp_shop_container = Control.new()
	pvp_shop_container.name = "ShopContainer"
	_set_percent_rect(pvp_shop_container, PVP_SHOP_ROW_LEFT, PVP_SHOP_ROW_TOP, PVP_SHOP_ROW_RIGHT, PVP_SHOP_ROW_BOTTOM)
	pvp_root.add_child(pvp_shop_container)

	pvp_combat_hand_panels.clear()
	for shop_index in range(PVP_SHOP_CARD_COUNT):
		var shop_card: Panel = _create_pvp_shop_card_placeholder()
		pvp_shop_container.add_child(shop_card)
		pvp_combat_hand_panels.append(shop_card)

	pvp_river_rect = ColorRect.new()
	pvp_river_rect.name = "RiverDivider"
	pvp_river_rect.color = PVP_RIVER_COLOR
	pvp_river_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_percent_rect(pvp_river_rect, PVP_RIVER_LEFT, PVP_RIVER_TOP, PVP_RIVER_RIGHT, PVP_RIVER_BOTTOM)
	pvp_root.add_child(pvp_river_rect)

	pvp_combat_hand_container = Control.new()
	pvp_combat_hand_container.name = "CombatHandContainer"
	_set_percent_rect(pvp_combat_hand_container, PVP_COMBAT_HAND_LEFT, PVP_COMBAT_HAND_TOP, PVP_COMBAT_HAND_RIGHT, PVP_COMBAT_HAND_BOTTOM)
	pvp_root.add_child(pvp_combat_hand_container)

	pvp_result_label = Label.new()
	pvp_result_label.visible = false
	pvp_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_result_label.add_theme_font_size_override("font_size", _scaled_int(22.0, 16, 28))
	_set_percent_rect(pvp_result_label, 0.68, 0.88, 0.96, 0.93)
	pvp_root.add_child(pvp_result_label)

	pvp_continue_button = Button.new()
	pvp_continue_button.text = "继续"
	pvp_continue_button.visible = false
	pvp_continue_button.pressed.connect(_on_continue_pressed)
	_set_percent_rect(pvp_continue_button, 0.78, 0.935, 0.94, 0.98)
	pvp_root.add_child(pvp_continue_button)

func _create_pvp_player_bar() -> void:
	pvp_player_bar = PanelContainer.new()
	pvp_player_bar.name = "PlayerBar"
	_set_percent_rect(pvp_player_bar, 0.0, PVP_BOTTOM_PANEL_TOP, 1.0, 1.0)
	pvp_player_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.11, 0.14, 0.10, 0.92), Color(0.22, 0.30, 0.22, 0.8)))
	pvp_root.add_child(pvp_player_bar)

	pvp_avatar_frame_player = TextureRect.new()
	pvp_avatar_frame_player.name = "AvatarFrame"
	pvp_avatar_frame_player.texture = load(PVP_AVATAR_FRAME)
	pvp_avatar_frame_player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_avatar_frame_player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_avatar_frame_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_percent_rect(pvp_avatar_frame_player, 0.40, 0.60, 0.55, 0.76)
	pvp_root.add_child(pvp_avatar_frame_player)

	var hero_avatar: TextureRect = TextureRect.new()
	hero_avatar.name = "HeroAvatar"
	var hero_path := PVP_AVATAR_WARRIOR
	if GameManager.selected_hero != null and GameManager.selected_hero.hero_type == 1:
		hero_path = PVP_AVATAR_MAGE
	hero_avatar.texture = load(hero_path)
	hero_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_percent_rect(hero_avatar, 0.412, 0.612, 0.538, 0.748)
	pvp_root.add_child(hero_avatar)

	var hp_stack: Control = _create_pvp_hp_stack()
	_set_percent_rect(hp_stack, 0.29, 0.515, 0.58, 0.57)
	pvp_root.add_child(hp_stack)
	pvp_player_hp_bar = hp_stack.get_node("HPBar") as ProgressBar
	pvp_player_hp_label = hp_stack.get_node("HPText") as Label
	pvp_player_shield_bar = hp_stack.get_node("ShieldBar") as ProgressBar
	pvp_player_shield_label = hp_stack.get_node("ShieldLabel") as Label
	pvp_player_status_label = hp_stack.get_node("StatusLabel") as Label

	pvp_player_name_label = Label.new()
	pvp_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_player_name_label.add_theme_font_size_override("font_size", _scaled_int(22.0, 16, 28))
	_set_percent_rect(pvp_player_name_label, 0.39, 0.57, 0.56, 0.61)
	pvp_root.add_child(pvp_player_name_label)

	pvp_player_meta_label = Label.new()
	pvp_player_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pvp_player_meta_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55, 1.0))
	pvp_player_meta_label.add_theme_font_size_override("font_size", _scaled_int(16.0, 11, 20))
	_set_percent_rect(pvp_player_meta_label, 0.66, 0.80, 0.78, 0.85)
	pvp_root.add_child(pvp_player_meta_label)

	pvp_gold_label = Label.new()
	pvp_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pvp_gold_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.28, 1.0))
	pvp_gold_label.add_theme_font_size_override("font_size", _scaled_int(20.0, 13, 24))
	_set_percent_rect(pvp_gold_label, 0.80, 0.80, 0.94, 0.85)
	pvp_root.add_child(pvp_gold_label)

	var chest_box: PanelContainer = PanelContainer.new()
	chest_box.name = "ChestBox"
	_set_percent_rect(chest_box, 0.03, PVP_CHEST_TOP, 0.09, PVP_CHEST_BOTTOM)
	chest_box.add_theme_stylebox_override("panel", _create_panel_style(Color(0.32, 0.20, 0.08, 0.98), Color(0.78, 0.56, 0.22, 1.0)))
	pvp_root.add_child(chest_box)

	var chest_label: Label = Label.new()
	chest_label.text = "宝箱"
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chest_label.add_theme_font_size_override("font_size", _scaled_int(18.0, 12, 22))
	chest_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_box.add_child(chest_label)

	# 使用 Bazaar 风格宝箱图标
	if ResourceLoader.exists(PVP_CHEST_ICON):
		var chest_icon: TextureRect = TextureRect.new()
		chest_icon.texture = load(PVP_CHEST_ICON)
		chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chest_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chest_box.add_child(chest_icon)

	var left_skills: Control = Control.new()
	left_skills.name = "LeftSkills"
	_set_percent_rect(left_skills, 0.18, 0.62, 0.38, 0.74)
	pvp_root.add_child(left_skills)

	var right_skills: Control = Control.new()
	right_skills.name = "RightSkills"
	_set_percent_rect(right_skills, 0.57, 0.62, 0.77, 0.74)
	pvp_root.add_child(right_skills)

	pvp_player_skill_labels.clear()
	for skill_index in range(4):
		var skill_label: Label = _create_skill_slot_label("Empty")
		if skill_index < 2:
			left_skills.add_child(skill_label)
		else:
			right_skills.add_child(skill_label)
		pvp_player_skill_labels.append(skill_label)

	_layout_skill_slots(left_skills)
	_layout_skill_slots(right_skills)

	pvp_player_hand_container = Control.new()
	pvp_player_hand_container.name = "PlayerHandContainer"
	_set_percent_rect(pvp_player_hand_container, PVP_ITEM_BAR_LEFT, PVP_ITEM_BAR_TOP, PVP_ITEM_BAR_RIGHT, PVP_ITEM_BAR_BOTTOM)
	pvp_root.add_child(pvp_player_hand_container)

	pvp_auto_battle_check = null
	pvp_end_turn_button = null
	pvp_battle_log = null

func _update_pvp_player_hand() -> void:
	if pvp_player_hand_container == null:
		return

	pvp_hover_card = null
	pvp_selected_card = null
	_hide_pvp_tooltip()

	for child in pvp_player_hand_container.get_children():
		child.queue_free()
	pvp_player_card_panels.clear()
	if pvp_combat_hand_container != null:
		for child in pvp_combat_hand_container.get_children():
			child.queue_free()

	if inventory == null:
		_add_empty_player_slots(PVP_HAND_SLOT_COUNT)
		_add_empty_top_hand_slots(PVP_SHOP_CARD_COUNT)
		_layout_card_row(pvp_player_hand_container, PVP_ITEM_SLOT_WIDTH, PVP_ITEM_SLOT_HEIGHT, PVP_ITEM_BAR_RIGHT - PVP_ITEM_BAR_LEFT, PVP_ITEM_BAR_BOTTOM - PVP_ITEM_BAR_TOP)
		if pvp_combat_hand_container != null:
			_layout_card_row(pvp_combat_hand_container, PVP_TOP_CARD_WIDTH, PVP_TOP_CARD_HEIGHT, PVP_COMBAT_HAND_RIGHT - PVP_COMBAT_HAND_LEFT, PVP_COMBAT_HAND_BOTTOM - PVP_COMBAT_HAND_TOP)
		return

	var card_count: int = 0
	for item in inventory.items:
		var item_data: ItemDataClass = item as ItemDataClass
		if item_data == null:
			continue

		var card_panel: Panel = Panel.new()
		card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		card_panel.add_theme_stylebox_override("panel", _create_player_card_style(item_data))
		card_panel.set_meta("item_data", item_data)
		card_panel.mouse_entered.connect(_on_pvp_card_hovered.bind(card_panel))
		card_panel.mouse_exited.connect(_on_pvp_card_unhovered.bind(card_panel))
		card_panel.gui_input.connect(_on_pvp_card_input.bind(card_panel, item_data))
		pvp_player_hand_container.add_child(card_panel)
		pvp_player_card_panels.append(card_panel)
		card_count += 1

		_add_texture_background(card_panel, PVP_ITEM_CARD_BG, "ItemCardBackground", -1)

		var illustration: ColorRect = _create_illustration_block(item_data.type)
		card_panel.add_child(illustration)
		_add_item_art_texture(illustration, _get_battle_item_art_path(item_data))

		var stat_badges: GridContainer = _create_item_stat_badge_grid_from_item(item_data)
		if stat_badges.get_child_count() > 0:
			card_panel.add_child(stat_badges)

		var price_badge: Panel = _create_price_badge(item_data.buy_price)
		card_panel.add_child(price_badge)

		var content_vbox: VBoxContainer = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_vbox.offset_left = 6.0
		content_vbox.offset_top = 64.0
		content_vbox.offset_right = -6.0
		content_vbox.offset_bottom = -6.0
		content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		content_vbox.add_theme_constant_override("separation", 2)
		card_panel.add_child(content_vbox)

		var name_label: Label = Label.new()
		name_label.text = item_data.item_name
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_text = true
		name_label.max_lines_visible = 1
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
		name_label.add_theme_constant_override("outline_size", 1)
		content_vbox.add_child(name_label)

		var stat_label: Label = Label.new()
		stat_label.text = _get_item_stat_text(item_data)
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_label.clip_text = true
		stat_label.max_lines_visible = 1
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.add_theme_font_size_override("font_size", 10)
		stat_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
		content_vbox.add_child(stat_label)

		var cooldown_label: Label = Label.new()
		cooldown_label.name = "CooldownLabel"
		cooldown_label.text = _get_item_cooldown_text(item_data)
		cooldown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cooldown_label.clip_text = true
		cooldown_label.max_lines_visible = 1
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.add_theme_font_size_override("font_size", 10)
		cooldown_label.add_theme_color_override("font_color", Color(0.86, 0.90, 1.0, 1.0))
		content_vbox.add_child(cooldown_label)

		if item_data.cooldown > 0.0:
			var cooldown_overlay: ColorRect = _create_card_cooldown_overlay(item_data)
			cooldown_overlay.name = "CooldownOverlay"
			card_panel.add_child(cooldown_overlay)

		if pvp_combat_hand_container != null and card_count <= PVP_SHOP_CARD_COUNT:
			var top_card: Panel = _create_static_item_card(item_data, false)
			pvp_combat_hand_container.add_child(top_card)

	_add_empty_player_slots(maxi(PVP_HAND_SLOT_COUNT - card_count, 0))
	_add_empty_top_hand_slots(maxi(PVP_SHOP_CARD_COUNT - mini(card_count, PVP_SHOP_CARD_COUNT), 0))
	_layout_card_row(pvp_player_hand_container, PVP_ITEM_SLOT_WIDTH, PVP_ITEM_SLOT_HEIGHT, PVP_ITEM_BAR_RIGHT - PVP_ITEM_BAR_LEFT, PVP_ITEM_BAR_BOTTOM - PVP_ITEM_BAR_TOP)
	if pvp_combat_hand_container != null:
		_layout_card_row(pvp_combat_hand_container, PVP_TOP_CARD_WIDTH, PVP_TOP_CARD_HEIGHT, PVP_COMBAT_HAND_RIGHT - PVP_COMBAT_HAND_LEFT, PVP_COMBAT_HAND_BOTTOM - PVP_COMBAT_HAND_TOP)

func _update_pvp_opponent_hand() -> void:
	if pvp_shop_container == null:
		return
	pvp_opponent_card_panels.clear()
	if _uses_shell_layout:
		_update_shell_opponent_board()
		return

	for child in pvp_shop_container.get_children():
		child.queue_free()

	if current_monster == null:
		_add_empty_opponent_slots(PVP_OPPONENT_SLOT_COUNT)
		_layout_card_row(pvp_shop_container, PVP_TOP_CARD_WIDTH, PVP_TOP_CARD_HEIGHT, PVP_SHOP_ROW_RIGHT - PVP_SHOP_ROW_LEFT, PVP_SHOP_ROW_BOTTOM - PVP_SHOP_ROW_TOP, true)
		return

	if current_monster.monster_items.is_empty():
		_add_empty_opponent_slots(PVP_OPPONENT_SLOT_COUNT)
		_layout_card_row(pvp_shop_container, PVP_TOP_CARD_WIDTH, PVP_TOP_CARD_HEIGHT, PVP_SHOP_ROW_RIGHT - PVP_SHOP_ROW_LEFT, PVP_SHOP_ROW_BOTTOM - PVP_SHOP_ROW_TOP, true)
		return

	var card_count: int = 0
	for item_index in range(current_monster.monster_items.size()):
		var monster_item: Dictionary = current_monster.monster_items[item_index]
		var item_name: String = str(monster_item.get("name", "物品"))
		var item_type: int = _get_monster_item_type(monster_item)
		var item_cooldown: float = float(monster_item.get("cooldown", 0.0))

		var card_panel: Panel = Panel.new()
		card_panel.name = "OpponentItem_%s" % item_name
		card_panel.clip_contents = true
		card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		card_panel.set_meta("monster_item_index", item_index)
		card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_type, true))
		card_panel.mouse_entered.connect(_on_monster_item_hovered.bind(card_panel))
		card_panel.mouse_exited.connect(_on_monster_item_unhovered.bind(card_panel))
		pvp_shop_container.add_child(card_panel)
		pvp_opponent_card_panels.append(card_panel)
		card_count += 1

		_add_texture_background(card_panel, PVP_EVENT_CARD_BG, "EventCardBackground", -1)

		var illustration: ColorRect = _create_illustration_block(item_type)
		card_panel.add_child(illustration)
		_add_item_art_texture(illustration, _get_monster_item_art_path(monster_item))

		var stat_badges: GridContainer = _create_monster_stat_badge_grid(monster_item)
		if stat_badges.get_child_count() > 0:
			card_panel.add_child(stat_badges)

		var content_vbox: VBoxContainer = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_vbox.offset_left = 8.0
		content_vbox.offset_top = 66.0
		content_vbox.offset_right = -8.0
		content_vbox.offset_bottom = -8.0
		content_vbox.add_theme_constant_override("separation", 4)
		card_panel.add_child(content_vbox)

		var name_label: Label = Label.new()
		name_label.text = item_name
		name_label.clip_text = true
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		content_vbox.add_child(name_label)

		var cooldown_label: Label = Label.new()
		cooldown_label.name = "CooldownLabel"
		var cooldown_text: String = _get_monster_cooldown_text(monster_item)
		cooldown_label.text = cooldown_text
		cooldown_label.visible = not cooldown_text.is_empty()
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.add_theme_font_size_override("font_size", 10)
		cooldown_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 1.0))
		content_vbox.add_child(cooldown_label)

		if item_cooldown > 0.0:
			var cooldown_overlay: ColorRect = _create_monster_cooldown_overlay(monster_item)
			cooldown_overlay.name = "CooldownOverlay"
			card_panel.add_child(cooldown_overlay)

	_add_empty_opponent_slots(maxi(PVP_OPPONENT_SLOT_COUNT - card_count, 0))
	_layout_card_row(pvp_shop_container, PVP_TOP_CARD_WIDTH, PVP_TOP_CARD_HEIGHT, PVP_SHOP_ROW_RIGHT - PVP_SHOP_ROW_LEFT, PVP_SHOP_ROW_BOTTOM - PVP_SHOP_ROW_TOP, true)

func _update_shell_opponent_board() -> void:
	pvp_opponent_card_panels.clear()
	for child in pvp_shop_container.get_children():
		child.queue_free()

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "OpponentBoardMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	pvp_shop_container.add_child(margin)

	var board_root: Control = Control.new()
	board_root.name = "OpponentBoardRoot"
	board_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(board_root)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "OpponentSlotRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SHELL_BOARD_SLOT_SPACING)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_root.add_child(row)

	var item_layer: Control = Control.new()
	item_layer.name = "OpponentItemLayer"
	item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_layer.z_index = 5
	board_root.add_child(item_layer)

	for slot_index in range(PVP_HAND_SLOT_COUNT):
		row.add_child(_create_shell_board_slot(slot_index))

	if current_monster == null:
		return

	call_deferred("_populate_shell_opponent_item_layer", item_layer, row)

func _populate_shell_opponent_item_layer(item_layer: Control, row: HBoxContainer) -> void:
	if item_layer == null or row == null or not is_instance_valid(item_layer) or not is_instance_valid(row):
		return
	for child in item_layer.get_children():
		child.queue_free()
	pvp_opponent_card_panels.clear()
	if current_monster == null:
		return

	var slot_index: int = 0
	for item_index in range(current_monster.monster_items.size()):
		if slot_index >= PVP_HAND_SLOT_COUNT:
			break
		var monster_item: Dictionary = current_monster.monster_items[item_index]
		var slot_count: int = clampi(int(monster_item.get("slot_count", 1)), 1, 3)
		slot_count = mini(slot_count, PVP_HAND_SLOT_COUNT - slot_index)
		var item_rect: Rect2 = _get_shell_slot_span_rect(row, slot_index, slot_count)
		var item_panel: Panel = _create_shell_monster_item_panel(monster_item, item_index)
		item_panel.position = item_rect.position
		item_panel.size = item_rect.size
		item_panel.custom_minimum_size = item_rect.size
		item_layer.add_child(item_panel)
		pvp_opponent_card_panels.append(item_panel)
		slot_index += slot_count

func _get_shell_slot_span_rect(row: HBoxContainer, start_slot: int, slot_count: int, inset: float = 4.0) -> Rect2:
	if row == null or start_slot < 0 or start_slot >= row.get_child_count():
		return Rect2(Vector2.ZERO, SHELL_BOARD_SLOT_SIZE - Vector2(inset * 2.0, inset * 2.0))
	var end_slot: int = mini(start_slot + slot_count - 1, row.get_child_count() - 1)
	var first_slot: Control = row.get_child(start_slot) as Control
	var last_slot: Control = row.get_child(end_slot) as Control
	if first_slot == null or last_slot == null:
		return Rect2(Vector2.ZERO, SHELL_BOARD_SLOT_SIZE - Vector2(inset * 2.0, inset * 2.0))
	var parent_global: Vector2 = row.global_position
	var left: float = first_slot.global_position.x - parent_global.x + inset
	var top: float = first_slot.global_position.y - parent_global.y + inset
	var right: float = last_slot.global_position.x - parent_global.x + last_slot.size.x - inset
	var bottom: float = first_slot.global_position.y - parent_global.y + first_slot.size.y - inset
	return Rect2(Vector2(left, top), Vector2(maxf(right - left, 1.0), maxf(bottom - top, 1.0)))

func _create_shell_board_slot(slot_index: int, slot_count: int = 1) -> Panel:
	var slot: Panel = Panel.new()
	slot.name = "OpponentSlot%d" % slot_index
	var clamped_slot_count: int = clampi(slot_count, 1, 3)
	var slot_width: float = SHELL_BOARD_SLOT_SIZE.x * float(clamped_slot_count) + float(clamped_slot_count - 1) * SHELL_BOARD_SLOT_SPACING
	slot.custom_minimum_size = Vector2(slot_width, SHELL_BOARD_SLOT_SIZE.y)
	slot.set_meta("slot_span", clamped_slot_count)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _create_empty_hand_slot_style())

	var label: Label = Label.new()
	label.name = "SlotLabel"
	label.text = str(slot_index + 1) if clamped_slot_count == 1 else "%d-%d" % [slot_index + 1, slot_index + clamped_slot_count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.85))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 4.0
	label.offset_top = 4.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	return slot

func _create_shell_monster_item_panel(monster_item: Dictionary, item_index: int) -> Panel:
	var item_type: int = _get_monster_item_type(monster_item)
	var item_name: String = str(monster_item.get("name", "物品"))
	var cooldown: float = float(monster_item.get("cooldown", 0.0))

	var card: Panel = Panel.new()
	card.name = "OpponentItem_%s" % item_name
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = 4.0
	card.offset_top = 4.0
	card.offset_right = -4.0
	card.offset_bottom = -4.0
	card.set_meta("monster_item_index", item_index)
	card.add_theme_stylebox_override("panel", _create_card_front_style(item_type, true))
	card.mouse_entered.connect(_on_monster_item_hovered.bind(card))
	card.mouse_exited.connect(_on_monster_item_unhovered.bind(card))

	var art: ColorRect = ColorRect.new()
	art.name = "OpponentItemArt"
	art.color = _get_shell_item_art_color(item_type)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 2.0
	art.offset_top = 2.0
	art.offset_right = -2.0
	art.offset_bottom = -2.0
	card.add_child(art)
	_add_item_art_texture(art, _get_monster_item_art_path(monster_item))

	var stat_badges: GridContainer = _create_monster_stat_badge_grid(monster_item)
	if stat_badges.get_child_count() > 0:
		card.add_child(stat_badges)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "OpponentItemText"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 4.0
	stack.offset_top = 4.0
	stack.offset_right = -4.0
	stack.offset_bottom = -4.0
	card.add_child(stack)

	var name_label: Label = Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.max_lines_visible = 1
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	name_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(name_label)

	var cooldown_label: Label = Label.new()
	cooldown_label.name = "CooldownLabel"
	var cooldown_text: String = _get_monster_cooldown_text(monster_item, true)
	cooldown_label.text = cooldown_text
	cooldown_label.visible = not cooldown_text.is_empty()
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 10)
	stack.add_child(cooldown_label)

	if cooldown > 0.0:
		var cooldown_overlay: ColorRect = _create_monster_cooldown_overlay(monster_item)
		cooldown_overlay.name = "CooldownOverlay"
		card.add_child(cooldown_overlay)

	return card

func _get_shell_item_art_color(item_type: int) -> Color:
	match item_type:
		ItemDataClass.Type.WEAPON:
			return Color(0.6, 0.2, 0.2, 0.8)
		ItemDataClass.Type.SHIELD:
			return Color(0.2, 0.4, 0.7, 0.8)
		ItemDataClass.Type.HEAL:
			return Color(0.2, 0.6, 0.3, 0.8)
		ItemDataClass.Type.UTILITY:
			return Color(0.5, 0.2, 0.6, 0.8)
		_:
			return Color(0.35, 0.35, 0.4, 0.8)

func _set_percent_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	if control == null:
		return
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _scaled_value(base_value: float, min_value: float, max_value: float) -> float:
	return clampf(base_value * _get_pvp_scale(), min_value, max_value)

func _scaled_int(base_value: float, min_value: int, max_value: int) -> int:
	return int(round(_scaled_value(base_value, float(min_value), float(max_value))))

func _layout_skill_slots(skill_container: Control) -> void:
	if skill_container == null:
		return

	var children: Array = skill_container.get_children()
	if children.is_empty():
		return

	var slot_width_ratio: float = 0.28
	var slot_height_ratio: float = 0.84
	var gap_ratio: float = (1.0 - slot_width_ratio * children.size()) / float(children.size() + 1)
	var x_position: float = maxf(gap_ratio, 0.02)
	for child in children:
		var skill_label: Control = child as Control
		if skill_label == null:
			continue
		_set_percent_rect(skill_label, x_position, 0.08, x_position + slot_width_ratio, 0.08 + slot_height_ratio)
		x_position += slot_width_ratio + gap_ratio

func _layout_card_row(container: Control, slot_width: float, slot_height: float, region_width: float, region_height: float, mirrored: bool = false) -> void:
	if container == null:
		return

	var cards: Array = container.get_children()
	if cards.is_empty():
		return

	var card_width_ratio: float = clampf(slot_width / region_width, 0.05, 0.9)
	var card_height_ratio: float = clampf(slot_height / region_height, 0.3, 0.95)
	var gap_ratio: float = maxf((1.0 - card_width_ratio * cards.size()) / float(cards.size() + 1), 0.005)
	var y_position: float = clampf((1.0 - card_height_ratio) * 0.5, 0.0, 1.0 - card_height_ratio)

	if mirrored:
		# Mirrored: position from right to left
		var x_position: float = 1.0 - gap_ratio - card_width_ratio
		for child in cards:
			var card: Control = child as Control
			if card == null:
				continue
			_set_percent_rect(card, x_position, y_position, x_position + card_width_ratio, y_position + card_height_ratio)
			x_position -= card_width_ratio + gap_ratio
	else:
		# Normal: position from left to right
		var x_position: float = gap_ratio
		for child in cards:
			var card: Control = child as Control
			if card == null:
				continue
			_set_percent_rect(card, x_position, y_position, x_position + card_width_ratio, y_position + card_height_ratio)
			x_position += card_width_ratio + gap_ratio

func _create_static_item_card(item_data: ItemDataClass, opponent: bool) -> Panel:
	var card_panel: Panel = Panel.new()
	card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	card_panel.set_meta("item_data", item_data)
	card_panel.set_meta("is_static_opponent", opponent)
	card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_data.type, opponent))
	card_panel.mouse_entered.connect(_on_static_item_card_hovered.bind(card_panel, item_data, opponent))
	card_panel.mouse_exited.connect(_on_static_item_card_unhovered.bind(card_panel, item_data, opponent))
	_add_texture_background(card_panel, PVP_ITEM_CARD_BG, "ItemCardBackground", -1)

	var illustration: ColorRect = _create_illustration_block(item_data.type)
	card_panel.add_child(illustration)
	_add_item_art_texture(illustration, _get_battle_item_art_path(item_data))

	var stat_badges: GridContainer = _create_item_stat_badge_grid_from_item(item_data)
	if stat_badges.get_child_count() > 0:
		card_panel.add_child(stat_badges)

	if not opponent:
		var price_badge: Panel = _create_price_badge(item_data.buy_price)
		card_panel.add_child(price_badge)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_vbox.offset_left = 6.0
	content_vbox.offset_top = 64.0
	content_vbox.offset_right = -6.0
	content_vbox.offset_bottom = -6.0
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 2)
	card_panel.add_child(content_vbox)

	var name_label: Label = Label.new()
	name_label.text = item_data.item_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.max_lines_visible = 1
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	content_vbox.add_child(name_label)

	var stat_label: Label = Label.new()
	stat_label.text = _get_item_stat_text(item_data)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.clip_text = true
	stat_label.max_lines_visible = 1
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 10)
	stat_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	content_vbox.add_child(stat_label)

	return card_panel

func _update_pvp_battle_ui() -> void:
	if pvp_root == null:
		return

	var hero: HeroDataClass = game_manager.selected_hero
	var max_hp: int = game_manager.get_max_health()
	var player_hp: int = clampi(game_manager.player_health, 0, max_hp)
	var current_shield: float = 0.0
	if hero != null:
		current_shield = hero.current_shield

	if pvp_player_name_label != null:
		pvp_player_name_label.text = hero.hero_name if hero != null else "玩家"
	if pvp_player_hp_bar != null:
		pvp_player_hp_bar.max_value = maxf(float(max_hp), 1.0)
		pvp_player_hp_bar.value = player_hp
		_update_hp_bar_color(pvp_player_hp_bar)
	if pvp_player_hp_label != null:
		pvp_player_hp_label.text = "%d" % player_hp
	_update_pvp_shield_ui(pvp_player_shield_bar, pvp_player_shield_label, max_hp, current_shield)
	var player_status: Dictionary = _get_battle_status_totals("player")
	_update_combat_status_label(pvp_player_status_label, player_status)
	_update_shell_player_status(player_status)

	if pvp_player_meta_label != null:
		var crit_text: String = "暴击 %.0f%%" % (hero.crit_chance * 100.0) if hero != null else "暴击 0%"
		var item_count: int = inventory.items.size() if inventory != null else 0
		pvp_player_meta_label.text = "%s  |  🎒 %d" % [crit_text, item_count]
	if pvp_gold_label != null:
		pvp_gold_label.text = "金币 %d  收入 %d" % [int(game_manager.gold), int(game_manager.income)]
	if pvp_wins_label != null:
		var total_wins: int = int(game_manager.pvp_wins)
		pvp_wins_label.text = "🏆 %d/10" % total_wins
	if pvp_clock_label != null:
		pvp_clock_label.text = "Day %d\nLv %d\nPrestige %d" % [
			int(game_manager.current_day),
			int(game_manager.level),
			int(game_manager.prestige)
		]

	_update_skill_labels(pvp_player_skill_labels, _get_player_skill_names(), false)

	if current_monster != null:
		var opponent_hp: int = clampi(current_monster.current_hp, 0, current_monster.max_hp)
		var opponent_shield: float = 0.0
		for property_data in current_monster.get_property_list():
			if str(property_data.get("name", "")) == "current_shield":
				opponent_shield = float(current_monster.get("current_shield"))
				break

		if pvp_opponent_name_label != null:
			pvp_opponent_name_label.text = current_monster.monster_name
		if pvp_opponent_hp_bar != null:
			pvp_opponent_hp_bar.max_value = maxf(float(current_monster.max_hp), 1.0)
			pvp_opponent_hp_bar.value = opponent_hp
			_update_hp_bar_color(pvp_opponent_hp_bar)
		if pvp_opponent_hp_label != null:
			pvp_opponent_hp_label.text = "%d" % opponent_hp
		_update_pvp_shield_ui(pvp_opponent_shield_bar, pvp_opponent_shield_label, current_monster.max_hp, opponent_shield)
		_update_combat_status_label(pvp_opponent_status_label, _get_battle_status_totals("enemy"))
		if pvp_opponent_meta_label != null:
			pvp_opponent_meta_label.text = "物品 %d" % current_monster.monster_items.size()

	_update_pvp_opponent_skills()
	_update_pvp_player_hand_labels()

func _update_pvp_opponent_skills() -> void:
	_update_skill_labels(pvp_opponent_skill_labels, _get_monster_skill_names(), false)

func _get_battle_status_totals(target: String) -> Dictionary:
	if battle_system == null or not battle_system.has_method("get_status_totals"):
		return {"burn": 0.0, "poison": 0.0, "regeneration": 0.0}
	return battle_system.call("get_status_totals", target)

func _update_combat_status_label(label: Label, status_totals: Dictionary) -> void:
	if label == null:
		return
	var parts: Array[String] = []
	var burn_value: float = float(status_totals.get("burn", 0.0))
	var poison_value: float = float(status_totals.get("poison", 0.0))
	var regen_value: float = float(status_totals.get("regeneration", 0.0))
	if burn_value > 0.0:
		parts.append("灼烧 %.0f" % burn_value)
	if poison_value > 0.0:
		parts.append("中毒 %.0f" % poison_value)
	if regen_value > 0.0:
		parts.append("再生 %.0f" % regen_value)
	label.text = "  ".join(parts)
	label.visible = not parts.is_empty()

func _update_shell_player_status(status_totals: Dictionary) -> void:
	if not _uses_shell_layout or _shell_layout == null:
		return
	var bottom_hud: Control = _shell_layout.get_node_or_null("BottomHudPanel") as Control
	if bottom_hud == null or not bottom_hud.has_method("set_combat_status"):
		return
	bottom_hud.call(
		"set_combat_status",
		float(status_totals.get("burn", 0.0)),
		float(status_totals.get("poison", 0.0)),
		float(status_totals.get("regeneration", 0.0))
	)

func _update_pvp_cooldown_overlays() -> void:
	for card_panel in pvp_player_card_panels:
		if not is_instance_valid(card_panel):
			continue

		var item_data: ItemDataClass = card_panel.get_meta("item_data", null) as ItemDataClass
		if item_data == null:
			continue

		var cooldown_label: Label = card_panel.get_node_or_null("ContentVBox/CooldownLabel") as Label
		if cooldown_label != null:
			cooldown_label.text = _get_item_cooldown_text(item_data)

		var cooldown_overlay: ColorRect = card_panel.get_node_or_null("CooldownOverlay") as ColorRect
		if cooldown_overlay != null:
			_update_card_cooldown_overlay(cooldown_overlay, item_data)

	for card_panel in pvp_opponent_card_panels:
		if not is_instance_valid(card_panel):
			continue

		var monster_item: Dictionary = _get_monster_item_for_card(card_panel)
		if monster_item.is_empty():
			continue

		var cooldown_label: Label = card_panel.get_node_or_null("ContentVBox/CooldownLabel") as Label
		if cooldown_label == null:
			cooldown_label = card_panel.get_node_or_null("OpponentItemText/CooldownLabel") as Label
		if cooldown_label != null:
			var monster_cooldown_text: String = _get_monster_cooldown_text(monster_item, _uses_shell_layout)
			cooldown_label.text = monster_cooldown_text
			cooldown_label.visible = not monster_cooldown_text.is_empty()

		var monster_overlay: ColorRect = card_panel.get_node_or_null("CooldownOverlay") as ColorRect
		if monster_overlay == null and float(monster_item.get("cooldown", 0.0)) > 0.0:
			monster_overlay = _create_monster_cooldown_overlay(monster_item)
			monster_overlay.name = "CooldownOverlay"
			card_panel.add_child(monster_overlay)
		if monster_overlay != null:
			_update_monster_cooldown_overlay(monster_overlay, monster_item)

func _calculate_pvp_scale() -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0

	var scale_x: float = viewport_size.x / PVP_BASE_VIEWPORT_SIZE.x
	var scale_y: float = viewport_size.y / PVP_BASE_VIEWPORT_SIZE.y
	return clampf(minf(scale_x, scale_y), PVP_MIN_SCALE, PVP_MAX_SCALE)

func _apply_pvp_content_scale() -> void:
	if pvp_root == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_pvp_content_scale = _calculate_pvp_scale()
	pvp_root.pivot_offset = PVP_BASE_VIEWPORT_SIZE * 0.5
	pvp_root.scale = Vector2.ONE * _pvp_content_scale

func _get_pvp_scale() -> float:
	return _pvp_content_scale

func _refresh_pvp_responsive_layout() -> void:
	var previous_scale: float = _get_pvp_scale()
	_apply_pvp_content_scale()
	if is_equal_approx(previous_scale, _get_pvp_scale()):
		return

	_update_pvp_player_hand()
	_update_pvp_opponent_hand()
	_update_pvp_battle_ui()

## ============ 战斗循环 ============

func _process(delta: float) -> void:
	if not is_battle_active:
		return

	battle_system.reduce_cooldowns(delta)

	_pvp_resize_timer += delta
	if _pvp_resize_timer >= PVP_RESIZE_CHECK_INTERVAL:
		_pvp_resize_timer = 0.0
		_refresh_pvp_responsive_layout()
	_update_pvp_cooldown_overlays()

	if not auto_battle:
		return

	battle_timer += delta
	elapsed_since_last_tick += delta

	if battle_timer >= BATTLE_TICK:
		var elapsed_time: float = elapsed_since_last_tick
		battle_timer -= BATTLE_TICK
		elapsed_since_last_tick = maxf(elapsed_since_last_tick - BATTLE_TICK, 0.0)
		_execute_battle_tick(elapsed_time)

func _execute_battle_tick(elapsed_time: float = BATTLE_TICK) -> void:
	var battle_ended_now: bool = battle_system.execute_battle_tick(elapsed_time)
	_update_battle_ui()

	if battle_ended_now:
		var result: Dictionary = battle_system.get_battle_result()
		if result["won"]:
			_on_battle_win()
		else:
			_on_battle_lose()

func _update_battle_ui() -> void:
	if pvp_root != null:
		_update_pvp_battle_ui()
		return

	var max_hp: int = game_manager.get_max_health()
	var current_shield: float = 0.0
	if game_manager.selected_hero != null:
		current_shield = game_manager.selected_hero.current_shield

	player_name_label.text = game_manager.selected_hero.hero_name if game_manager.selected_hero else "玩家"
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = game_manager.player_health
	player_hp_label.text = "%d/%d" % [game_manager.player_health, max_hp]
	_update_shield_ui(max_hp, current_shield)

	if game_manager.selected_hero:
		player_atk_label.text = "暴击: %.0f%%" % (game_manager.selected_hero.crit_chance * 100.0)
	else:
		player_atk_label.text = ""

	if current_monster:
		enemy_name_label.text = current_monster.monster_name
		enemy_hp_bar.max_value = current_monster.max_hp
		enemy_hp_bar.value = current_monster.current_hp
		enemy_hp_label.text = "%d/%d" % [current_monster.current_hp, current_monster.max_hp]
		enemy_atk_label.text = "物品: %d" % current_monster.monster_items.size()

## ============ 护盾 UI ============

func _create_shield_ui() -> void:
	if player_area == null or player_shield_bar != null:
		return

	player_shield_bar = ProgressBar.new()
	player_shield_bar.name = "PlayerShieldBar"
	player_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_shield_bar.show_percentage = false
	player_shield_bar.min_value = 0.0
	player_shield_bar.visible = false
	player_shield_bar.add_theme_stylebox_override("background", _create_transparent_progress_style())
	player_shield_bar.add_theme_stylebox_override("fill", _create_shield_fill_style())
	player_area.add_child(player_shield_bar)

	player_shield_label = Label.new()
	player_shield_label.name = "PlayerShieldLabel"
	player_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_shield_label.visible = false
	player_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_shield_label.add_theme_color_override("font_color", PVP_SHIELD_COLOR)
	player_area.add_child(player_shield_label)

	_sync_shield_ui_layout()

func _sync_shield_ui_layout() -> void:
	if player_shield_bar == null or player_shield_label == null:
		return

	player_shield_bar.anchor_left = player_hp_bar.anchor_left
	player_shield_bar.anchor_top = player_hp_bar.anchor_top
	player_shield_bar.anchor_right = player_hp_bar.anchor_right
	player_shield_bar.anchor_bottom = player_hp_bar.anchor_bottom
	player_shield_bar.offset_left = player_hp_bar.offset_left
	player_shield_bar.offset_top = player_hp_bar.offset_top - 10.0
	player_shield_bar.offset_right = player_hp_bar.offset_right
	player_shield_bar.offset_bottom = player_hp_bar.offset_top - 2.0
	player_shield_bar.z_index = player_hp_bar.z_index + 1

	player_shield_label.anchor_left = player_hp_bar.anchor_left
	player_shield_label.anchor_top = player_hp_bar.anchor_top
	player_shield_label.anchor_right = player_hp_bar.anchor_right
	player_shield_label.anchor_bottom = player_hp_bar.anchor_top
	player_shield_label.offset_left = player_hp_bar.offset_left
	player_shield_label.offset_top = player_hp_bar.offset_top - 30.0
	player_shield_label.offset_right = player_hp_bar.offset_right
	player_shield_label.offset_bottom = player_hp_bar.offset_top - 10.0
	player_shield_label.z_index = player_shield_bar.z_index + 1

func _reset_shield_ui() -> void:
	if player_shield_bar == null or player_shield_label == null:
		return

	_sync_shield_ui_layout()
	player_shield_bar.max_value = 1.0
	player_shield_bar.value = 0.0
	player_shield_bar.visible = false
	player_shield_label.text = "🛡️ 0"
	player_shield_label.visible = false

func _update_shield_ui(max_hp: int, current_shield: float) -> void:
	if player_shield_bar == null or player_shield_label == null:
		return

	_sync_shield_ui_layout()
	var shield_value: float = clampf(current_shield, 0.0, float(max_hp))
	var has_shield: bool = shield_value > 0.0
	player_shield_bar.max_value = maxf(float(max_hp), 1.0)
	player_shield_bar.value = shield_value
	player_shield_bar.visible = has_shield
	player_shield_label.text = "🛡️ %d" % int(round(shield_value))
	player_shield_label.visible = has_shield

func _reset_pvp_shield_ui() -> void:
	_update_pvp_shield_ui(pvp_player_shield_bar, pvp_player_shield_label, 1, 0.0)
	_update_pvp_shield_ui(pvp_opponent_shield_bar, pvp_opponent_shield_label, 1, 0.0)

func _update_pvp_shield_ui(bar: ProgressBar, label: Label, max_hp: int, current_shield: float) -> void:
	if bar == null or label == null:
		return

	var shield_value: float = clampf(current_shield, 0.0, float(max_hp))
	var has_shield: bool = shield_value > 0.0
	bar.max_value = maxf(float(max_hp), 1.0)
	bar.value = shield_value
	bar.visible = has_shield
	label.text = "🛡️ %d" % int(round(shield_value))
	label.visible = has_shield

func _update_hp_bar_color(hp_bar: ProgressBar) -> void:
	if hp_bar == null or hp_bar.max_value <= 0.0:
		return

	var ratio: float = hp_bar.value / hp_bar.max_value
	var fill_style: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return

	var low_color: Color = Color(0.82, 0.22, 0.22, 1.0)
	var mid_color: Color = Color(0.90, 0.78, 0.22, 1.0)
	var high_color: Color = Color(0.20, 0.78, 0.28, 1.0)
	if ratio >= 0.5:
		fill_style.bg_color = mid_color.lerp(high_color, (ratio - 0.5) / 0.5)
	else:
		fill_style.bg_color = low_color.lerp(mid_color, ratio / 0.5)

## ============ 日志 ============

func _log(message: String) -> void:
	if pvp_battle_log != null:
		pvp_battle_log.append_text(message + "\n")
		pvp_battle_log.scroll_to_line(pvp_battle_log.get_line_count() - 1)
	else:
		battle_log_label.append_text(message + "\n")
		battle_log_label.scroll_to_line(battle_log_label.get_line_count() - 1)

	battle_log.emit(message)
	print(message)

## ============ 战斗结果 ============

func _on_battle_win() -> void:
	is_battle_active = false
	pvp_selected_card = null

	var gold_reward: int = 0

	_last_battle_won = true
	_last_gold_reward = gold_reward

	if pvp_result_label != null:
		if is_pvp:
			pvp_result_label.text = "🎉 胜利!"
		else:
			pvp_result_label.text = "🎉 胜利!"
		pvp_result_label.visible = true
	if pvp_continue_button != null:
		pvp_continue_button.visible = true
	elif not is_pvp:
		result_label.text = "🎉 胜利!"
		result_label.visible = true
		continue_button.visible = true

	_log("🎉 战斗胜利!")
	battle_system.end_battle()
	_update_pvp_cooldown_overlays()
	if inventory != null:
		inventory.inventory_changed.emit()

func _on_battle_lose() -> void:
	is_battle_active = false
	pvp_selected_card = null

	_last_battle_won = false
	_last_gold_reward = 0

	if pvp_result_label != null:
		if is_pvp:
			pvp_result_label.text = "💀 失败!"
		else:
			pvp_result_label.text = "💀 战斗失败!"
		pvp_result_label.visible = true
	if pvp_continue_button != null:
		pvp_continue_button.visible = true
	elif not is_pvp:
		result_label.text = "💀 战斗失败!"
		result_label.visible = true
		continue_button.visible = true

	_log("💀 战斗失败!")
	battle_system.end_battle()
	_update_pvp_cooldown_overlays()
	if inventory != null:
		inventory.inventory_changed.emit()

func _on_continue_pressed() -> void:
	_hide_battle_panel()
	battle_ended.emit(_last_battle_won, _last_gold_reward)

func get_battle_system() -> Node:
	return battle_system

## ============ PvP 辅助 ============

func _sync_auto_battle_check_state() -> void:
	if auto_battle_check != null:
		auto_battle_check.button_pressed = auto_battle
	if pvp_auto_battle_check != null:
		pvp_auto_battle_check.button_pressed = auto_battle

func _create_pvp_tooltip() -> void:
	if pvp_tooltip_panel != null:
		return

	pvp_tooltip_panel = PanelContainer.new()
	pvp_tooltip_panel.name = "PvPTooltip"
	pvp_tooltip_panel.visible = false
	pvp_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_tooltip_panel.z_index = 300

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.02, 0.96)
	style.border_color = PVP_TOOLTIP_GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	pvp_tooltip_panel.add_theme_stylebox_override("panel", style)
	pvp_tooltip_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	pvp_tooltip_label = RichTextLabel.new()
	pvp_tooltip_label.bbcode_enabled = true
	pvp_tooltip_label.fit_content = true
	pvp_tooltip_label.scroll_active = false
	pvp_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_tooltip_label.custom_minimum_size = Vector2(PVP_TOOLTIP_WIDTH, 0.0)
	pvp_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_tooltip_label.add_theme_font_size_override("normal_font_size", 18)
	pvp_tooltip_panel.add_child(pvp_tooltip_label)

	if pvp_root != null:
		pvp_root.add_child(pvp_tooltip_panel)

func _show_pvp_tooltip(card_panel: Panel, item_data: ItemDataClass) -> void:
	if pvp_tooltip_panel == null or pvp_tooltip_label == null:
		return

	pvp_tooltip_label.text = _build_item_tooltip_text(item_data)
	pvp_tooltip_panel.visible = true
	_position_pvp_tooltip(card_panel)

func _show_monster_item_tooltip(card_panel: Panel) -> void:
	if pvp_tooltip_panel == null or pvp_tooltip_label == null:
		return

	var monster_item: Dictionary = _get_monster_item_for_card(card_panel)
	if monster_item.is_empty():
		return

	pvp_tooltip_label.text = _build_monster_item_tooltip_text(monster_item)
	pvp_tooltip_panel.visible = true
	_position_pvp_tooltip(card_panel)

func _hide_pvp_tooltip() -> void:
	if pvp_tooltip_panel != null:
		pvp_tooltip_panel.visible = false

func _position_pvp_tooltip(anchor_control: Control) -> void:
	if pvp_tooltip_panel == null or anchor_control == null:
		return

	pvp_tooltip_panel.reset_size()
	var panel_size: Vector2 = pvp_tooltip_panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = Vector2(PVP_TOOLTIP_WIDTH + 32.0, 260.0)

	var card_rect: Rect2 = anchor_control.get_global_rect()
	var tip_pos: Vector2 = card_rect.position - Vector2(0.0, panel_size.y + 10.0)
	if tip_pos.y < 8.0:
		tip_pos.y = card_rect.position.y + card_rect.size.y + 10.0

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	tip_pos.x = clampf(tip_pos.x, 8.0, maxf(vp_size.x - panel_size.x - 8.0, 8.0))
	tip_pos.y = clampf(tip_pos.y, 8.0, maxf(vp_size.y - panel_size.y - 8.0, 8.0))
	pvp_tooltip_panel.global_position = tip_pos

func _build_item_tooltip_text(item_data: ItemDataClass) -> String:
	if item_data == null:
		return ""

	var lines: Array[String] = []
	lines.append("[b][color=#f8eddc]%s[/color][/b]" % _bbcode_escape(item_data.item_name))
	lines.append("[color=#dba34c]%s  %s  %s[/color]" % [
		item_data.get_size_text(),
		item_data.get_type_name(),
		item_data.get_rarity_name()
	])
	lines.append("")

	var has_stats: bool = false
	if item_data.damage > 0:
		lines.append("[color=#f0e6d2]> 造成 [color=#ff6b5f]%d[/color] 伤害[/color]" % item_data.get_rarity_adjusted_damage())
		has_stats = true
	if item_data.shield > 0:
		lines.append("[color=#f0e6d2]> 获得 [color=#6fc7ff]%d[/color] 护盾[/color]" % item_data.get_rarity_adjusted_shield())
		has_stats = true
	if item_data.heal > 0:
		lines.append("[color=#f0e6d2]> 恢复 [color=#72ef86]%d[/color] 生命[/color]" % item_data.get_rarity_adjusted_heal())
		has_stats = true
	if item_data.crit_chance > 0:
		lines.append("[color=#f0e6d2]> 暴击 [color=#d99cff]%.0f%%[/color][/color]" % (item_data.crit_chance * item_data.get_rarity_multiplier() * 100.0))
		has_stats = true
	if item_data.cooldown > 0.0:
		lines.append("[color=#f0e6d2]> 冷却 [color=#d8e6ff]%.1f 秒[/color][/color]" % maxf(item_data.cooldown, MIN_ITEM_COOLDOWN))
		has_stats = true
	if item_data.has_ammo_limit():
		var ammo_text: String = "%d/%d" % [item_data.get_current_ammo(), item_data.get_max_ammo()] if item_data.current_ammo >= 0 else "%d" % item_data.get_max_ammo()
		lines.append("[color=#f0e6d2]> 弹药 [color=#ffd36a]%s[/color][/color]" % ammo_text)
		has_stats = true
	if item_data.current_cooldown > 0.0:
		lines.append("[color=#c8d4f0]> 剩余 %.1f 秒[/color]" % item_data.current_cooldown)
	if not has_stats:
		lines.append("[color=#b8a88c]> 被动效果[/color]")

	if not item_data.description.is_empty():
		lines.append("")
		lines.append("[color=#f0e6d2]%s[/color]" % _bbcode_escape(item_data.description))

	if item_data.has_special_effect():
		lines.append("")
		lines.append("[color=#ffd36a]特殊效果: %s[/color]" % _bbcode_escape(item_data.get_special_effect_description()))

	return "\n".join(lines)

func _build_monster_item_tooltip_text(monster_item: Dictionary) -> String:
	var item_name: String = str(monster_item.get("name", "物品"))
	var item_type: int = _get_monster_item_type(monster_item)
	var cooldown: float = maxf(float(monster_item.get("cooldown", 0.0)), 0.0)
	var current_cooldown: float = maxf(float(monster_item.get("current_cooldown", 0.0)), 0.0)

	var lines: Array[String] = []
	lines.append("[b][color=#f8eddc]%s[/color][/b]" % _bbcode_escape(item_name))
	lines.append("[color=#dba34c]敌方道具  %s[/color]" % _get_item_type_name(item_type))
	lines.append("")

	var has_stats: bool = false
	var damage: int = _get_monster_item_effective_damage(monster_item)
	var shield: int = int(monster_item.get("shield", 0))
	var heal: int = int(monster_item.get("heal", 0))
	var burn: int = int(monster_item.get("burn", 0))
	var poison: int = int(monster_item.get("poison", 0))
	var regen: int = int(monster_item.get("regen", 0))
	if damage > 0:
		lines.append("[color=#f0e6d2]> 造成 [color=#ff6b5f]%d[/color] 伤害[/color]" % damage)
		has_stats = true
	if shield > 0:
		lines.append("[color=#f0e6d2]> 获得 [color=#6fc7ff]%d[/color] 护盾[/color]" % shield)
		has_stats = true
	if heal > 0:
		lines.append("[color=#f0e6d2]> 恢复 [color=#72ef86]%d[/color] 生命[/color]" % heal)
		has_stats = true
	if burn > 0:
		lines.append("[color=#f0e6d2]> 施加 [color=#ff9b45]%d[/color] 燃烧[/color]" % burn)
		has_stats = true
	if poison > 0:
		lines.append("[color=#f0e6d2]> 施加 [color=#60d878]%d[/color] 中毒[/color]" % poison)
		has_stats = true
	if regen > 0:
		lines.append("[color=#f0e6d2]> 获得 [color=#72ef86]%d[/color] 再生[/color]" % regen)
		has_stats = true
	var source_description: String = str(monster_item.get("description", ""))
	if not source_description.is_empty():
		lines.append("")
		lines.append("[color=#cbb58a]%s[/color]" % _bbcode_escape(source_description))
	if cooldown > 0.0:
		lines.append("[color=#f0e6d2]> 冷却 [color=#d8e6ff]%.1f 秒[/color][/color]" % maxf(cooldown, MIN_ITEM_COOLDOWN))
		has_stats = true
	if current_cooldown > 0.0:
		lines.append("[color=#c8d4f0]> 剩余 %.1f 秒[/color]" % current_cooldown)
	if not has_stats:
		lines.append("[color=#b8a88c]> 被动效果[/color]")

	return "\n".join(lines)

func _get_item_type_name(item_type: int) -> String:
	match item_type:
		ItemDataClass.Type.WEAPON: return "武器"
		ItemDataClass.Type.SHIELD: return "护盾"
		ItemDataClass.Type.HEAL: return "治疗"
		ItemDataClass.Type.UTILITY: return "工具"
		_: return "物品"

func _bbcode_escape(text: String) -> String:
	return text.replace("[", "\\[").replace("]", "\\]")

func _on_pvp_card_hovered(card_panel: Panel) -> void:
	if pvp_hover_card != null and is_instance_valid(pvp_hover_card) and pvp_hover_card != card_panel:
		_on_pvp_card_unhovered(pvp_hover_card)

	pvp_hover_card = card_panel
	var item_data: ItemDataClass = card_panel.get_meta("item_data", null) as ItemDataClass
	if item_data != null:
		card_panel.add_theme_stylebox_override("panel", _create_player_card_style(item_data, true))
		_show_pvp_tooltip(card_panel, item_data)

func _on_pvp_card_unhovered(card_panel: Panel = null) -> void:
	if card_panel == null or pvp_hover_card != card_panel:
		return

	if pvp_hover_card != null and is_instance_valid(pvp_hover_card):
		var item_data: ItemDataClass = pvp_hover_card.get_meta("item_data", null) as ItemDataClass
		var is_selected: bool = pvp_hover_card == pvp_selected_card
		if item_data != null:
			pvp_hover_card.add_theme_stylebox_override("panel", _create_player_card_style(item_data, false, is_selected))

	pvp_hover_card = null
	_hide_pvp_tooltip()

func _on_static_item_card_hovered(card_panel: Panel, item_data: ItemDataClass, opponent: bool) -> void:
	if card_panel == null or item_data == null:
		return
	card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_data.type, opponent, true))
	_show_pvp_tooltip(card_panel, item_data)

func _on_static_item_card_unhovered(card_panel: Panel, item_data: ItemDataClass, opponent: bool) -> void:
	if card_panel == null or item_data == null:
		return
	card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_data.type, opponent, false))
	_hide_pvp_tooltip()

func _on_monster_item_hovered(card_panel: Panel) -> void:
	var monster_item: Dictionary = _get_monster_item_for_card(card_panel)
	if monster_item.is_empty():
		return
	var item_type: int = _get_monster_item_type(monster_item)
	card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_type, true, true))
	_show_monster_item_tooltip(card_panel)

func _on_monster_item_unhovered(card_panel: Panel) -> void:
	var monster_item: Dictionary = _get_monster_item_for_card(card_panel)
	if not monster_item.is_empty():
		var item_type: int = _get_monster_item_type(monster_item)
		card_panel.add_theme_stylebox_override("panel", _create_card_front_style(item_type, true, false))
	_hide_pvp_tooltip()

func _on_pvp_card_input(event: InputEvent, card_panel: Panel, item_data: ItemDataClass) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if pvp_selected_card == card_panel:
			var old: Panel = pvp_selected_card
			pvp_selected_card = null
			old.add_theme_stylebox_override("panel", _create_player_card_style(item_data, false, false))
		else:
			if pvp_selected_card != null and is_instance_valid(pvp_selected_card):
				var old_data: ItemDataClass = pvp_selected_card.get_meta("item_data", null) as ItemDataClass
				if old_data != null:
					pvp_selected_card.add_theme_stylebox_override("panel", _create_player_card_style(old_data, false, false))

			pvp_selected_card = card_panel
			card_panel.add_theme_stylebox_override("panel", _create_player_card_style(item_data, false, true))

func _create_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	return style

func _create_card_back_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.102, 0.18, 1.0)
	style.border_color = Color(0.2, 0.2, 0.33, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _create_card_front_style(item_type: int, opponent: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var accent: Color = _get_illustration_color(item_type)
	style.bg_color = Color(0.20, 0.18, 0.14, 0.98) if opponent else Color(0.16, 0.16, 0.22, 0.98)
	style.border_color = accent.lerp(PVP_TOOLTIP_GOLD, 0.65) if hovered else accent.lerp(Color.WHITE, 0.22)
	style.set_border_width_all(3 if hovered else 2)
	style.set_corner_radius_all(6)
	return style

func _create_shop_card_style(active: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.15, 0.24, 0.96) if active else Color(0.10, 0.15, 0.24, 0.38)
	style.border_color = PVP_SHOP_BORDER_COLOR if active else Color(
		PVP_SHOP_BORDER_COLOR.r,
		PVP_SHOP_BORDER_COLOR.g,
		PVP_SHOP_BORDER_COLOR.b,
		0.45
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _create_empty_hand_slot_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.14, 0.85)
	style.border_color = Color(
		PVP_HAND_BORDER_COLOR.r,
		PVP_HAND_BORDER_COLOR.g,
		PVP_HAND_BORDER_COLOR.b,
		0.55
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _get_illustration_color(item_type: int) -> Color:
	match item_type:
		ItemDataClass.Type.WEAPON:
			return Color(0.6, 0.2, 0.2, 0.8)
		ItemDataClass.Type.SHIELD:
			return Color(0.2, 0.4, 0.7, 0.8)
		ItemDataClass.Type.HEAL:
			return Color(0.2, 0.6, 0.3, 0.8)
		ItemDataClass.Type.UTILITY:
			return Color(0.5, 0.2, 0.6, 0.8)
		_:
			return Color(0.35, 0.35, 0.4, 0.8)

func _create_price_badge(price: int) -> Panel:
	var badge: Panel = Panel.new()
	badge.name = "PriceBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_top = 1.0
	badge.anchor_right = 0.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 4.0
	badge.offset_top = -30.0
	badge.offset_right = 48.0
	badge.offset_bottom = -4.0
	badge.z_index = 21

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.64, 0.36, 0.08, 0.95)
	badge_style.border_color = Color(1.0, 0.74, 0.30, 0.95)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(5)
	badge.add_theme_stylebox_override("panel", badge_style)

	var badge_label: Label = Label.new()
	badge_label.text = str(price)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 14)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	badge_label.add_theme_constant_override("outline_size", 1)
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)

	return badge

func _create_item_stat_badge_grid_from_item(item_data: ItemDataClass) -> GridContainer:
	var grid: GridContainer = _create_stat_badge_grid()
	for stat in _collect_item_badge_stats(item_data):
		grid.add_child(_create_stat_badge(str(stat.get("text", "")), stat.get("color", Color.WHITE)))
	return grid

func _create_monster_stat_badge_grid(monster_item: Dictionary) -> GridContainer:
	var grid: GridContainer = _create_stat_badge_grid()
	for stat in _collect_monster_badge_stats(monster_item):
		grid.add_child(_create_stat_badge(str(stat.get("text", "")), stat.get("color", Color.WHITE)))
	return grid

func _create_stat_badge_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = "ItemStatBadgeGrid"
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.z_index = 20
	grid.anchor_left = 0.0
	grid.anchor_top = 0.0
	grid.anchor_right = 1.0
	grid.anchor_bottom = 0.0
	grid.offset_left = 4.0
	grid.offset_top = 4.0
	grid.offset_right = -4.0
	grid.offset_bottom = 52.0
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	return grid

func _collect_item_badge_stats(item_data: ItemDataClass) -> Array:
	var stats: Array = []
	if item_data == null:
		return stats

	var damage_value: int = item_data.get_rarity_adjusted_damage() if item_data.damage > 0 else 0
	var poison_value: int = int(round(item_data.poison_damage * item_data.get_rarity_multiplier())) if item_data.poison_damage > 0.0 else 0
	var burn_value: int = int(round(item_data.burn_damage * item_data.get_rarity_multiplier())) if item_data.burn_damage > 0.0 else 0
	var regen_value: int = int(round(item_data.regeneration * item_data.get_rarity_multiplier())) if item_data.regeneration > 0.0 else 0
	var heal_value: int = item_data.get_rarity_adjusted_heal() if item_data.heal > 0 else 0
	var shield_value: int = item_data.get_rarity_adjusted_shield() if item_data.shield > 0 else 0
	return _build_badge_stats(damage_value, poison_value, burn_value, regen_value, heal_value, shield_value)

func _collect_monster_badge_stats(monster_item: Dictionary) -> Array:
	var damage_value: int = _get_monster_item_effective_damage(monster_item)
	var poison_value: int = int(monster_item.get("poison", 0))
	var burn_value: int = int(monster_item.get("burn", 0))
	var regen_value: int = int(monster_item.get("regen", 0))
	var heal_value: int = int(monster_item.get("heal", 0))
	var shield_value: int = int(monster_item.get("shield", 0))
	return _build_badge_stats(damage_value, poison_value, burn_value, regen_value, heal_value, shield_value)

func _build_badge_stats(damage_value: int, poison_value: int, burn_value: int, regen_value: int, heal_value: int, shield_value: int) -> Array:
	var stats: Array = []
	if damage_value > 0:
		stats.append({"text": str(damage_value), "color": Color(0.86, 0.20, 0.17, 0.94)})
	if poison_value > 0:
		stats.append({"text": "毒 %d" % poison_value, "color": Color(0.20, 0.62, 0.30, 0.94)})
	if burn_value > 0:
		stats.append({"text": "火 %d" % burn_value, "color": Color(0.93, 0.42, 0.12, 0.94)})
	if regen_value > 0:
		stats.append({"text": "再 %d" % regen_value, "color": Color(0.20, 0.58, 0.52, 0.94)})
	if heal_value > 0:
		stats.append({"text": "疗 %d" % heal_value, "color": Color(0.26, 0.70, 0.34, 0.94)})
	if shield_value > 0:
		stats.append({"text": "盾 %d" % shield_value, "color": Color(0.20, 0.46, 0.78, 0.94)})
	return stats

func _create_stat_badge(text: String, color: Color) -> Panel:
	var badge: Panel = Panel.new()
	badge.name = "ItemStatBadge"
	badge.custom_minimum_size = Vector2(36, 20)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.name = "BadgeLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 1)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge

func _create_illustration_block(item_type: int) -> ColorRect:
	var illustration: ColorRect = ColorRect.new()
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.color = _get_illustration_color(item_type)
	illustration.anchor_left = 0.0
	illustration.anchor_top = 0.0
	illustration.anchor_right = 1.0
	illustration.anchor_bottom = 0.0
	illustration.offset_left = 4.0
	illustration.offset_top = 4.0
	illustration.offset_right = -4.0
	illustration.offset_bottom = 60.0
	return illustration

func _add_item_art_texture(parent: Control, texture_path: String) -> void:
	if parent == null or texture_path.is_empty():
		return
	var texture: Texture2D = ItemArtCatalogClass.load_texture(texture_path)
	if texture == null:
		return
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = "ItemArtTexture"
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture_rect)

func _get_battle_item_art_path(item_data: ItemDataClass) -> String:
	return ItemArtCatalogClass.get_item_texture_path(item_data)

func _get_monster_item_art_path(monster_item: Dictionary) -> String:
	return ItemArtCatalogClass.get_item_texture_path_by_source_id(str(monster_item.get("source_id", "")))

func _create_player_card_style(item_data: ItemDataClass, hovered: bool = false, selected: bool = false) -> StyleBoxFlat:
	var colors: Dictionary = _get_card_colors_by_rarity(item_data.rarity)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colors["background"]
	if selected:
		style.border_color = Color(1.0, 0.84, 0.0, 1.0)
		style.set_border_width_all(3)
	elif hovered:
		style.border_color = PVP_HAND_BORDER_COLOR.lerp(Color.WHITE, 0.3)
		style.set_border_width_all(3)
	else:
		style.border_color = PVP_HAND_BORDER_COLOR
		style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _add_empty_player_slots(empty_count: int) -> void:
	if pvp_player_hand_container == null or empty_count <= 0:
		return

	for slot_index in range(empty_count):
		var empty_panel: Panel = Panel.new()
		empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_panel.add_theme_stylebox_override("panel", _create_empty_hand_slot_style())
		_add_texture_background(empty_panel, PVP_ITEM_SLOT_EMPTY, "EmptySlotBackground", -1)
		pvp_player_hand_container.add_child(empty_panel)

func _add_empty_top_hand_slots(empty_count: int) -> void:
	if pvp_combat_hand_container == null or empty_count <= 0:
		return

	for slot_index in range(empty_count):
		var empty_panel: Panel = Panel.new()
		empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_panel.add_theme_stylebox_override("panel", _create_empty_hand_slot_style())
		_add_texture_background(empty_panel, PVP_ITEM_SLOT_EMPTY, "EmptySlotBackground", -1)
		pvp_combat_hand_container.add_child(empty_panel)

func _add_empty_opponent_slots(empty_count: int) -> void:
	if pvp_shop_container == null or empty_count <= 0:
		return

	for slot_index in range(empty_count):
		var empty_panel: Panel = Panel.new()
		empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_panel.add_theme_stylebox_override("panel", _create_empty_hand_slot_style())
		_add_texture_background(empty_panel, PVP_ITEM_SLOT_EMPTY, "EmptySlotBackground", -1)
		pvp_shop_container.add_child(empty_panel)

func _get_monster_item_type(monster_item: Dictionary) -> int:
	if monster_item.has("type"):
		return int(monster_item.get("type", ItemDataClass.Type.WEAPON))
	if int(monster_item.get("shield", 0)) > 0:
		return ItemDataClass.Type.SHIELD
	if int(monster_item.get("heal", 0)) > 0:
		return ItemDataClass.Type.HEAL
	if int(monster_item.get("damage", 0)) > 0:
		return ItemDataClass.Type.WEAPON
	return ItemDataClass.Type.UTILITY

func _get_monster_item_effective_damage(monster_item: Dictionary) -> int:
	var base_damage: int = int(monster_item.get("damage", 0))
	if base_damage <= 0:
		return 0
	var damage_mult: float = 1.0
	if current_monster != null and current_monster.ai != null:
		damage_mult = current_monster.ai.get_current_damage_multiplier(current_monster)
	return maxi(int(float(base_damage) * damage_mult), 0)

func _get_card_colors_by_rarity(rarity: int) -> Dictionary:
	match rarity:
		2:
			return {
				"background": Color(0.16, 0.28, 0.16, 1.0),
				"border": Color(0.34, 0.75, 0.34, 1.0)
			}
		3:
			return {
				"background": Color(0.15, 0.20, 0.35, 1.0),
				"border": Color(0.33, 0.55, 0.92, 1.0)
			}
		4:
			return {
				"background": Color(0.25, 0.14, 0.32, 1.0),
				"border": Color(0.73, 0.43, 0.95, 1.0)
			}
		_:
			return {
				"background": Color(0.26, 0.26, 0.28, 1.0),
				"border": Color(0.88, 0.88, 0.90, 1.0)
			}

func _create_skill_slot_label(initial_text: String) -> Label:
	var skill_label: Label = Label.new()
	skill_label.text = initial_text
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_label.clip_text = true
	skill_label.add_theme_font_size_override("font_size", _scaled_int(12.0, 9, 14))
	skill_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	skill_label.add_theme_stylebox_override("normal", _create_panel_style(Color(0.18, 0.20, 0.28, 1.0), Color(0.30, 0.34, 0.48, 1.0)))
	return skill_label

func _create_pvp_hp_stack() -> Control:
	var hp_stack: Control = Control.new()

	var hp_text: Label = Label.new()
	hp_text.name = "HPText"
	hp_text.text = "0"
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_set_percent_rect(hp_text, 0.0, 0.0, 0.28, 0.64)
	hp_text.add_theme_font_size_override("font_size", _scaled_int(36.0, 20, 42))
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	hp_text.add_theme_constant_override("outline_size", 2)
	hp_text.z_index = 10
	hp_stack.add_child(hp_text)

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(300.0, 12.0)
	hp_bar.show_percentage = false
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	_set_percent_rect(hp_bar, 0.32, 0.28, 1.0, 0.84)
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.75, 0.2, 1.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_bar.z_index = 1
	hp_stack.add_child(hp_bar)

	var shield_bar: ProgressBar = ProgressBar.new()
	shield_bar.name = "ShieldBar"
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar.show_percentage = false
	shield_bar.min_value = 0.0
	shield_bar.visible = false
	_set_percent_rect(shield_bar, 0.32, 0.10, 1.0, 0.24)
	shield_bar.add_theme_stylebox_override("background", _create_transparent_progress_style())
	shield_bar.add_theme_stylebox_override("fill", _create_shield_fill_style())
	shield_bar.z_index = 2
	hp_stack.add_child(shield_bar)

	var shield_label: Label = Label.new()
	shield_label.name = "ShieldLabel"
	shield_label.visible = false
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_set_percent_rect(shield_label, 0.70, 0.0, 1.0, 0.24)
	shield_label.add_theme_font_size_override("font_size", _scaled_int(10.0, 8, 12))
	shield_label.add_theme_color_override("font_color", PVP_SHIELD_COLOR)
	shield_label.z_index = 4
	hp_stack.add_child(shield_label)

	var status_label: Label = Label.new()
	status_label.name = "StatusLabel"
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", _scaled_int(12.0, 9, 15))
	status_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42, 1.0))
	_set_percent_rect(status_label, 0.32, 0.82, 1.0, 1.0)
	status_label.z_index = 5
	hp_stack.add_child(status_label)

	return hp_stack

func _create_pvp_shop_card_placeholder() -> Panel:
	var card: Panel = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25, 0.6)
	style.border_color = PVP_SHOP_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	# 使用 Bazaar 风格卡牌背景
	if ResourceLoader.exists(PVP_SHOP_CARD_BG):
		var bg_texture: TextureRect = TextureRect.new()
		bg_texture.name = "ShopCardBackground"
		bg_texture.texture = load(PVP_SHOP_CARD_BG)
		bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_texture.z_index = -2
		card.add_child(bg_texture)

	if ResourceLoader.exists(PVP_EVENT_CARD_BG):
		var event_texture: TextureRect = TextureRect.new()
		event_texture.name = "EventCardBackground"
		event_texture.texture = load(PVP_EVENT_CARD_BG)
		event_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		event_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		event_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		event_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		event_texture.z_index = -1
		card.add_child(event_texture)

	var center_label: Label = Label.new()
	center_label.text = "Shop"
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 16)
	center_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.92))
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(center_label)
	return card

func _add_texture_background(parent: Control, texture_path: String, node_name: String, z_index: int = -1) -> void:
	if parent == null or texture_path.is_empty():
		return
	var bg_texture: TextureRect = TextureRect.new()
	bg_texture.name = node_name
	bg_texture.texture = load(texture_path)
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_texture.z_index = z_index
	bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg_texture)

func _create_transparent_progress_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style

func _create_shield_fill_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PVP_SHIELD_COLOR.r, PVP_SHIELD_COLOR.g, PVP_SHIELD_COLOR.b, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _create_card_cooldown_overlay(item_data: ItemDataClass) -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)

	var timer_label: Label = Label.new()
	timer_label.name = "CooldownTimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(timer_label)

	_update_card_cooldown_overlay(overlay, item_data)
	return overlay

func _update_card_cooldown_overlay(overlay: ColorRect, item_data: ItemDataClass) -> void:
	if overlay == null or item_data == null:
		return

	var timer_label: Label = overlay.get_node_or_null("CooldownTimerLabel") as Label
	if item_data.current_cooldown <= 0.0 or item_data.cooldown <= 0.0:
		overlay.visible = false
		if timer_label != null:
			timer_label.text = ""
		return

	var ratio: float = clampf(item_data.current_cooldown / item_data.cooldown, 0.0, 1.0)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 1.0 - ratio
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.visible = true

	if timer_label != null:
		timer_label.text = "%.1f" % item_data.current_cooldown

func _create_monster_cooldown_overlay(monster_item: Dictionary) -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)

	var timer_label: Label = Label.new()
	timer_label.name = "CooldownTimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(timer_label)

	_update_monster_cooldown_overlay(overlay, monster_item)
	return overlay

func _update_monster_cooldown_overlay(overlay: ColorRect, monster_item: Dictionary) -> void:
	if overlay == null:
		return

	var cooldown: float = maxf(float(monster_item.get("cooldown", 0.0)), 0.0)
	var current_cooldown: float = maxf(float(monster_item.get("current_cooldown", 0.0)), 0.0)
	var timer_label: Label = overlay.get_node_or_null("CooldownTimerLabel") as Label
	if current_cooldown <= 0.0 or cooldown <= 0.0:
		overlay.visible = false
		if timer_label != null:
			timer_label.text = ""
		return

	var ratio: float = clampf(current_cooldown / cooldown, 0.0, 1.0)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 1.0 - ratio
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.visible = true

	if timer_label != null:
		timer_label.text = "%.1f" % current_cooldown

func _get_monster_item_for_card(card_panel: Panel) -> Dictionary:
	if card_panel == null or current_monster == null:
		return {}
	var item_index: int = int(card_panel.get_meta("monster_item_index", -1))
	if item_index < 0 or item_index >= current_monster.monster_items.size():
		return {}
	return current_monster.monster_items[item_index]

func _update_pvp_player_hand_labels() -> void:
	for card_panel in pvp_player_card_panels:
		if not is_instance_valid(card_panel):
			continue

		var item_data: ItemDataClass = card_panel.get_meta("item_data", null) as ItemDataClass
		if item_data == null:
			continue

		var cooldown_label: Label = card_panel.get_node_or_null("ContentVBox/CooldownLabel") as Label
		if cooldown_label != null:
			cooldown_label.text = _get_item_cooldown_text(item_data)

func _get_item_stat_text(item_data: ItemDataClass) -> String:
	if item_data == null:
		return ""

	if item_data.damage > 0:
		return "🗡️ ATK +%d" % item_data.get_rarity_adjusted_damage()
	if item_data.heal > 0:
		return "💚 Heal +%d" % item_data.get_rarity_adjusted_heal()
	if item_data.shield > 0:
		return "🛡️ Shield +%d" % item_data.get_rarity_adjusted_shield()
	return "✨ %s" % item_data.get_type_name()

func _get_item_cooldown_text(item_data: ItemDataClass) -> String:
	if item_data == null:
		return ""
	if item_data.current_cooldown > 0.0:
		return "CD: %.1fs" % item_data.current_cooldown
	if item_data.has_ammo_limit() and item_data.get_current_ammo() <= 0:
		return "Ammo 0"
	return "Ready" if item_data.cooldown > 0.0 else "Passive"

func _get_monster_cooldown_text(monster_item: Dictionary, short_text: bool = false) -> String:
	var cooldown: float = maxf(float(monster_item.get("cooldown", 0.0)), 0.0)
	var current_cooldown: float = maxf(float(monster_item.get("current_cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return ""
	if current_cooldown > 0.0:
		if short_text:
			return "%.1fs" % current_cooldown
		return "CD: %.1fs" % current_cooldown
	return ""

func _get_player_skill_names() -> Array[String]:
	var names: Array[String] = []
	var seen: Dictionary = {}

	if battle_system != null and "skill_manager" in battle_system:
		var skill_manager: Variant = battle_system.skill_manager
		if skill_manager != null and skill_manager.has_method("get_equipped_skills"):
			var equipped_skills: Array = skill_manager.get_equipped_skills()
			for skill_entry in equipped_skills:
				var skill_data: SkillDataClass = skill_entry as SkillDataClass
				if skill_data != null and not skill_data.skill_name.is_empty():
					if not seen.has(skill_data.skill_name):
						seen[skill_data.skill_name] = true
						names.append(skill_data.skill_name)

	if game_manager.selected_hero != null:
		for hero_skill in game_manager.selected_hero.skills:
			var skill_name: String = PlayerSkillCatalogClass.get_skill_display_name(hero_skill)
			if not skill_name.is_empty() and not seen.has(skill_name):
				seen[skill_name] = true
				names.append(skill_name)

	if names.is_empty() and game_manager.selected_hero != null and game_manager.selected_hero.has_passive_skill():
		names.append(game_manager.selected_hero.passive_skill_name)

	return names

func _get_monster_skill_names() -> Array[String]:
	var names: Array[String] = []
	if current_monster == null:
		return names

	for monster_item in current_monster.monster_items:
		var item_name: String = str(monster_item.get("name", ""))
		if not item_name.is_empty():
			names.append(item_name)
		if names.size() >= 3:
			break

	return names

func _update_skill_labels(skill_labels: Array[Label], skill_names: Array[String], hidden: bool) -> void:
	for index in range(skill_labels.size()):
		var skill_label: Label = skill_labels[index]
		if skill_label == null:
			continue

		if hidden:
			skill_label.text = "❓"
			skill_label.visible = true
			continue

		if index < skill_names.size():
			skill_label.text = skill_names[index]
		else:
			skill_label.text = "Empty"
