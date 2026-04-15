class_name BattleUI
extends Control

## 战斗面板 UI - 管理战斗界面和自动战斗循环
## 重构：纯物品触发战斗，移除独立攻击逻辑

const MonsterAIClass = preload("res://scripts/data/monster_ai.gd")
const SkillDataClass = preload("res://scripts/data/skill_data.gd")

const BATTLE_TICK: float = 0.5
const PVP_PANEL_TOP_BOTTOM: float = 0.18
const PVP_PLAYER_TOP: float = 0.78
const PVP_CARD_SIZE: Vector2 = Vector2(80.0, 110.0)
const PVP_HAND_SPACING: int = 12
const PVP_BASE_VIEWPORT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const PVP_MIN_SCALE: float = 0.5
const PVP_MAX_SCALE: float = 1.0
const PVP_RESIZE_CHECK_INTERVAL: float = 2.0
const PVP_RIVER_TOP: float = 0.50
const PVP_RIVER_BOTTOM: float = 0.506
const PVP_CENTER_LEFT: float = 0.08
const PVP_CENTER_RIGHT: float = 0.92
const PVP_SHOP_TOP: float = PVP_PANEL_TOP_BOTTOM + 0.04
const PVP_SHOP_BOTTOM: float = PVP_RIVER_TOP - 0.02
const PVP_HAND_TOP: float = PVP_RIVER_BOTTOM + 0.02
const PVP_HAND_BOTTOM: float = PVP_PLAYER_TOP - 0.02
const PVP_SHOP_CARD_COUNT: int = 5
const PVP_CLOCK_ICON: String = "res://assets/art/ui/pvp/pvp_clock_icon.png"
const PVP_AVATAR_FRAME: String = "res://assets/art/ui/pvp/pvp_avatar_frame.png"
const PVP_HERO_AVATAR: String = "res://assets/art/ui/pvp/pvp_hero_avatar.png"
const PVP_HAND_SLOT_COUNT: int = 10
const PVP_RIVER_COLOR: Color = Color(0.15, 0.35, 0.55, 0.8)
const PVP_SHOP_BORDER_COLOR: Color = Color8(74, 158, 255, 255)
const PVP_HAND_BORDER_COLOR: Color = Color8(42, 42, 62, 255)

## GameManager 引用
var game_manager: Node

## 战斗系统引用
var battle_system: Node

## 背包系统引用
var inventory: LinearInventory = null

## 敌人数据
var current_monster: MonsterData = null

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
var pvp_opponent_bar: PanelContainer = null
var pvp_player_bar: PanelContainer = null
var pvp_battle_center: Control = null
var pvp_river_rect: ColorRect = null
var pvp_opponent_name_label: Label = null
var pvp_opponent_hp_bar: ProgressBar = null
var pvp_opponent_hp_label: Label = null
var pvp_opponent_shield_bar: ProgressBar = null
var pvp_opponent_shield_label: Label = null
var pvp_opponent_meta_label: Label = null
var pvp_opponent_skill_labels: Array[Label] = []
var pvp_opponent_hand_container: HBoxContainer = null
var pvp_shop_container: HBoxContainer = null
var pvp_player_name_label: Label = null
var pvp_player_hp_bar: ProgressBar = null
var pvp_player_hp_label: Label = null
var pvp_player_shield_bar: ProgressBar = null
var pvp_player_shield_label: Label = null
var pvp_player_meta_label: Label = null
var pvp_player_skill_labels: Array[Label] = []
var pvp_player_hand_container: HBoxContainer = null
var pvp_auto_battle_check: CheckButton = null
var pvp_end_turn_button: Button = null
var pvp_battle_log: RichTextLabel = null
var pvp_result_label: Label = null
var pvp_continue_button: Button = null
var pvp_clock_texture: TextureRect = null
var pvp_avatar_frame_opponent: TextureRect = null
var pvp_avatar_frame_player: TextureRect = null
var pvp_player_card_panels: Array[Panel] = []
var pvp_selected_card: Panel = null
var pvp_hover_card: Panel = null
var pvp_tooltip_panel: PanelContainer = null
var pvp_tooltip_label: RichTextLabel = null
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

	_create_shield_ui()

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

func start_battle(monster: MonsterData = null, pvp: bool = false, enemy_atk_bonus: int = 0) -> void:
	is_pvp = pvp
	battle_timer = 0.0
	elapsed_since_last_tick = 0.0
	_pvp_resize_timer = 0.0

	var main: Node = get_parent()
	if main != null and main.has_node("InventoryUI"):
		inventory = main.get_node("InventoryUI").get_inventory()

	if monster != null:
		current_monster = monster
	elif not is_pvp:
		current_monster = _generate_random_monster()
	else:
		current_monster = _create_pvp_enemy(enemy_atk_bonus)

	if current_monster == null or inventory == null:
		return

	battle_system.start_battle(current_monster, inventory)

	if is_pvp:
		_create_pvp_layout()

	_show_battle_panel()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_battle_ui()

	is_battle_active = true
	_log("⚔️ 战斗开始! %s 出现!" % current_monster.monster_name)

	if current_monster.monster_items.size() > 0:
		for monster_item in current_monster.monster_items:
			_log("   → %s (伤害:%d, CD:%.1fs)" % [
				monster_item["name"],
				monster_item["damage"],
				monster_item["cooldown"]
			])

## ============ 怪物生成 ============

func _assign_monster_ai(monster: MonsterData, day: int) -> void:
	match monster.tier:
		MonsterData.MonsterTier.TIER_1:
			monster.ai = MonsterAIClass.create_swarm()
		MonsterData.MonsterTier.TIER_2:
			if randf() < 0.5:
				monster.ai = MonsterAIClass.create_technical()
			else:
				monster.ai = MonsterAIClass.create_defensive()
		MonsterData.MonsterTier.TIER_3:
			monster.ai = MonsterAIClass.create_boss()
	print("👹 [%s] AI模式: %s" % [monster.monster_name, monster.ai.get_mode_name()])

func _generate_random_monster() -> MonsterData:
	var monster: MonsterData = MonsterData.new()
	var day: int = game_manager.current_day
	var tier: MonsterData.MonsterTier = MonsterData.MonsterTier.TIER_1

	if day >= 3:
		tier = [MonsterData.MonsterTier.TIER_1, MonsterData.MonsterTier.TIER_2].pick_random()
	if day >= 5:
		tier = [
			MonsterData.MonsterTier.TIER_1,
			MonsterData.MonsterTier.TIER_2,
			MonsterData.MonsterTier.TIER_3
		].pick_random()

	match tier:
		MonsterData.MonsterTier.TIER_1:
			monster.monster_name = "史莱姆"
			monster.max_hp = 40 + day * 10
			monster.gold_reward_min = 5 + day
			monster.gold_reward_max = 10 + day * 2
			monster.monster_items = [
				{"name": "酸液喷射", "damage": 5 + day, "cooldown": 3.0, "current_cooldown": 3.0}
			]
		MonsterData.MonsterTier.TIER_2:
			monster.monster_name = "哥布林"
			monster.max_hp = 80 + day * 15
			monster.gold_reward_min = 10 + day * 2
			monster.gold_reward_max = 20 + day * 3
			monster.monster_items = [
				{"name": "石斧", "damage": 8 + day * 2, "cooldown": 3.5, "current_cooldown": 3.5}
			]
		MonsterData.MonsterTier.TIER_3:
			monster.monster_name = "食人魔"
			monster.max_hp = 130 + day * 20
			monster.gold_reward_min = 20 + day * 3
			monster.gold_reward_max = 40 + day * 5
			monster.monster_items = [
				{"name": "重锤", "damage": 12 + day * 2, "cooldown": 4.0, "current_cooldown": 4.0},
				{"name": "碎骨", "damage": 6 + day, "cooldown": 3.0, "current_cooldown": 3.0}
			]

	monster.tier = tier
	monster.current_hp = monster.max_hp
	_assign_monster_ai(monster, day)
	return monster

func _create_pvp_enemy(enemy_atk_bonus: int = 0) -> MonsterData:
	var monster: MonsterData = MonsterData.new()
	var hero_types: Array[int] = [0, 1]
	var random_hero_type: int = hero_types.pick_random()
	var day: int = game_manager.current_day

	if random_hero_type == 0:
		monster.monster_name = "PvP 战士"
		monster.max_hp = 200 + day * 15
		monster.monster_items = [
			{"name": "战士之剑", "damage": 15 + day + enemy_atk_bonus, "cooldown": 3.0, "current_cooldown": 3.0},
			{"name": "铁盾反击", "damage": 5 + day + enemy_atk_bonus, "cooldown": 2.5, "current_cooldown": 2.5}
		]
	else:
		monster.monster_name = "PvP 法师"
		monster.max_hp = 160 + day * 15
		monster.monster_items = [
			{"name": "奥术法杖", "damage": 22 + day * 2 + enemy_atk_bonus, "cooldown": 4.5, "current_cooldown": 4.5}
		]

	monster.gold_reward_min = 0
	monster.gold_reward_max = 0
	monster.current_hp = monster.max_hp
	monster.ai = MonsterAIClass.create_aggressive()

	if is_pvp:
		_log("⚔️ 对手: %s (HP: %.0f, 物品数: %d)" % [
			monster.monster_name,
			monster.max_hp,
			monster.monster_items.size()
		])

	return monster

## ============ UI 管理 ============

func _show_battle_panel() -> void:
	if is_pvp:
		battle_panel.visible = false
		if pvp_root == null:
			_create_pvp_layout()
		if pvp_root != null:
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
		return

	battle_panel.visible = true
	result_label.visible = false
	continue_button.visible = false
	battle_log_label.clear()
	_reset_shield_ui()
	_sync_auto_battle_check_state()

func _hide_battle_panel() -> void:
	if is_pvp:
		if pvp_root != null:
			pvp_root.visible = false
		_destroy_pvp_layout()
	else:
		battle_panel.visible = false

	is_battle_active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## ============ PvP 布局 ============

func _create_pvp_layout() -> void:
	if pvp_root != null:
		return

	pvp_root = Control.new()
	pvp_root.name = "PvPRoot"
	pvp_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pvp_root.set_anchor_and_offset_preset(Control.PRESET_CENTER)
	pvp_root.offset_left = -960.0
	pvp_root.offset_top = -540.0
	pvp_root.offset_right = 960.0
	pvp_root.offset_bottom = 540.0
	pvp_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pvp_root)
	_apply_pvp_content_scale()

	_create_pvp_opponent_bar()
	_create_pvp_battle_center()
	_create_pvp_player_bar()
	_create_pvp_tooltip()
	_sync_auto_battle_check_state()
	_update_pvp_player_hand()
	_update_pvp_opponent_hand()

func _destroy_pvp_layout() -> void:
	if pvp_root != null and is_instance_valid(pvp_root):
		pvp_root.queue_free()

	pvp_root = null
	pvp_opponent_bar = null
	pvp_player_bar = null
	pvp_battle_center = null
	pvp_river_rect = null
	pvp_opponent_name_label = null
	pvp_opponent_hp_bar = null
	pvp_opponent_hp_label = null
	pvp_opponent_shield_bar = null
	pvp_opponent_shield_label = null
	pvp_opponent_meta_label = null
	pvp_opponent_skill_labels.clear()
	pvp_opponent_hand_container = null
	pvp_shop_container = null
	pvp_player_name_label = null
	pvp_player_hp_bar = null
	pvp_player_hp_label = null
	pvp_player_shield_bar = null
	pvp_player_shield_label = null
	pvp_player_meta_label = null
	pvp_player_skill_labels.clear()
	pvp_player_hand_container = null
	pvp_auto_battle_check = null
	pvp_end_turn_button = null
	pvp_battle_log = null
	pvp_clock_texture = null
	pvp_avatar_frame_opponent = null
	pvp_avatar_frame_player = null
	pvp_result_label = null
	pvp_continue_button = null
	pvp_tooltip_panel = null
	pvp_tooltip_label = null
	pvp_selected_card = null
	pvp_hover_card = null
	pvp_player_card_panels.clear()
	_pvp_content_scale = 1.0
	_pvp_resize_timer = 0.0

func _create_pvp_opponent_bar() -> void:
	pvp_opponent_bar = PanelContainer.new()
	pvp_opponent_bar.name = "OpponentBar"
	pvp_opponent_bar.anchor_left = 0.02
	pvp_opponent_bar.anchor_top = 0.02
	pvp_opponent_bar.anchor_right = 0.98
	pvp_opponent_bar.anchor_bottom = PVP_PANEL_TOP_BOTTOM
	pvp_opponent_bar.offset_left = 0.0
	pvp_opponent_bar.offset_top = 0.0
	pvp_opponent_bar.offset_right = 0.0
	pvp_opponent_bar.offset_bottom = 0.0
	pvp_opponent_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.13, 0.20, 0.96), Color(0.25, 0.28, 0.40, 1.0)))
	pvp_root.add_child(pvp_opponent_bar)

	var root_hbox: HBoxContainer = HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.theme_override_constants.separation = 18
	pvp_opponent_bar.add_child(root_hbox)

	# 头像框（64x64，在info_box左边）
	pvp_avatar_frame_opponent = TextureRect.new()
	pvp_avatar_frame_opponent.name = "AvatarFrame"
	pvp_avatar_frame_opponent.texture = load(PVP_AVATAR_FRAME)
	pvp_avatar_frame_opponent.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_avatar_frame_opponent.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_avatar_frame_opponent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_avatar_frame_opponent.custom_minimum_size = Vector2(64.0, 64.0)
	root_hbox.add_child(pvp_avatar_frame_opponent)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.theme_override_constants.separation = 8
	root_hbox.add_child(info_box)

	pvp_opponent_name_label = Label.new()
	pvp_opponent_name_label.add_theme_font_size_override("font_size", 22)
	info_box.add_child(pvp_opponent_name_label)

	var hp_stack: Control = _create_pvp_hp_stack()
	info_box.add_child(hp_stack)
	pvp_opponent_hp_bar = hp_stack.get_node("HPBar") as ProgressBar
	pvp_opponent_hp_label = hp_stack.get_node("HPText") as Label
	pvp_opponent_shield_bar = hp_stack.get_node("ShieldBar") as ProgressBar
	pvp_opponent_shield_label = hp_stack.get_node("ShieldLabel") as Label

	pvp_opponent_meta_label = Label.new()
	pvp_opponent_meta_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.62, 1.0))
	info_box.add_child(pvp_opponent_meta_label)

	var skills_box: HBoxContainer = HBoxContainer.new()
	skills_box.theme_override_constants.separation = 8
	info_box.add_child(skills_box)
	pvp_opponent_skill_labels.clear()
	for skill_index in range(3):
		var skill_label: Label = _create_skill_slot_label("❓")
		skill_label.visible = true
		skills_box.add_child(skill_label)
		pvp_opponent_skill_labels.append(skill_label)

	pvp_opponent_hand_container = HBoxContainer.new()
	pvp_opponent_hand_container.alignment = BoxContainer.ALIGNMENT_END
	pvp_opponent_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp_opponent_hand_container.theme_override_constants.separation = PVP_HAND_SPACING
	root_hbox.add_child(pvp_opponent_hand_container)

func _create_pvp_battle_center() -> void:
	pvp_battle_center = Control.new()
	pvp_battle_center.name = "BattleCenter"
	pvp_battle_center.anchor_left = 0.0
	pvp_battle_center.anchor_top = 0.0
	pvp_battle_center.anchor_right = 1.0
	pvp_battle_center.anchor_bottom = 1.0
	pvp_battle_center.offset_left = 0.0
	pvp_battle_center.offset_top = 0.0
	pvp_battle_center.offset_right = 0.0
	pvp_battle_center.offset_bottom = 0.0
	pvp_root.add_child(pvp_battle_center)

	var shop_row: CenterContainer = CenterContainer.new()
	shop_row.name = "ShopRow"
	shop_row.anchor_left = PVP_CENTER_LEFT
	shop_row.anchor_top = PVP_SHOP_TOP
	shop_row.anchor_right = PVP_CENTER_RIGHT
	shop_row.anchor_bottom = PVP_SHOP_BOTTOM
	shop_row.offset_left = 0.0
	shop_row.offset_top = 0.0
	shop_row.offset_right = 0.0
	shop_row.offset_bottom = 0.0
	pvp_battle_center.add_child(shop_row)

	pvp_shop_container = HBoxContainer.new()
	pvp_shop_container.name = "ShopContainer"
	pvp_shop_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pvp_shop_container.theme_override_constants.separation = PVP_HAND_SPACING
	shop_row.add_child(pvp_shop_container)

	for shop_index in range(PVP_SHOP_CARD_COUNT):
		var shop_card: Panel = _create_pvp_shop_card_placeholder()
		pvp_shop_container.add_child(shop_card)

	# 时钟图标（河流上方居中）
	pvp_clock_texture = TextureRect.new()
	pvp_clock_texture.name = "ClockIcon"
	pvp_clock_texture.texture = load(PVP_CLOCK_ICON)
	pvp_clock_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_clock_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_clock_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_clock_texture.custom_minimum_size = Vector2(48.0, 48.0)
	pvp_clock_texture.anchor_left = 0.5
	pvp_clock_texture.anchor_right = 0.5
	pvp_clock_texture.anchor_top = PVP_SHOP_BOTTOM + 0.005
	pvp_clock_texture.anchor_bottom = PVP_RIVER_TOP - 0.005
	pvp_clock_texture.offset_left = -24.0
	pvp_clock_texture.offset_right = 24.0
	pvp_clock_texture.offset_top = 0.0
	pvp_clock_texture.offset_bottom = 0.0
	pvp_battle_center.add_child(pvp_clock_texture)

	pvp_river_rect = ColorRect.new()
	pvp_river_rect.name = "RiverDivider"
	pvp_river_rect.color = PVP_RIVER_COLOR
	pvp_river_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_river_rect.anchor_left = PVP_CENTER_LEFT
	pvp_river_rect.anchor_top = PVP_RIVER_TOP
	pvp_river_rect.anchor_right = PVP_CENTER_RIGHT
	pvp_river_rect.anchor_bottom = PVP_RIVER_BOTTOM
	pvp_river_rect.offset_left = 0.0
	pvp_river_rect.offset_top = 0.0
	pvp_river_rect.offset_right = 0.0
	pvp_river_rect.offset_bottom = 0.0
	pvp_battle_center.add_child(pvp_river_rect)

	var hand_row: CenterContainer = CenterContainer.new()
	hand_row.name = "HandRow"
	hand_row.anchor_left = PVP_CENTER_LEFT
	hand_row.anchor_top = PVP_HAND_TOP
	hand_row.anchor_right = PVP_CENTER_RIGHT
	hand_row.anchor_bottom = PVP_HAND_BOTTOM
	hand_row.offset_left = 0.0
	hand_row.offset_top = 0.0
	hand_row.offset_right = 0.0
	hand_row.offset_bottom = 0.0
	pvp_battle_center.add_child(hand_row)

	pvp_player_hand_container = HBoxContainer.new()
	pvp_player_hand_container.name = "PlayerHandContainer"
	pvp_player_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pvp_player_hand_container.theme_override_constants.separation = PVP_HAND_SPACING
	hand_row.add_child(pvp_player_hand_container)

	var log_panel: PanelContainer = PanelContainer.new()
	log_panel.name = "BattleLogPanel"
	log_panel.anchor_left = 0.73
	log_panel.anchor_top = PVP_SHOP_TOP
	log_panel.anchor_right = 0.97
	log_panel.anchor_bottom = PVP_HAND_BOTTOM
	log_panel.offset_left = 0.0
	log_panel.offset_top = 0.0
	log_panel.offset_right = 0.0
	log_panel.offset_bottom = 0.0
	log_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.09, 0.14, 0.92), Color(0.24, 0.28, 0.38, 1.0)))
	pvp_battle_center.add_child(log_panel)

	var log_vbox: VBoxContainer = VBoxContainer.new()
	log_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_vbox.offset_left = 12.0
	log_vbox.offset_top = 12.0
	log_vbox.offset_right = -12.0
	log_vbox.offset_bottom = -12.0
	log_vbox.theme_override_constants.separation = 10
	log_panel.add_child(log_vbox)

	pvp_battle_log = RichTextLabel.new()
	pvp_battle_log.bbcode_enabled = true
	pvp_battle_log.scroll_following = true
	pvp_battle_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(pvp_battle_log)

	pvp_result_label = Label.new()
	pvp_result_label.visible = false
	pvp_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvp_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_result_label.add_theme_font_size_override("font_size", 22)
	log_vbox.add_child(pvp_result_label)

	pvp_continue_button = Button.new()
	pvp_continue_button.text = "继续"
	pvp_continue_button.visible = false
	pvp_continue_button.pressed.connect(_on_continue_pressed)
	log_vbox.add_child(pvp_continue_button)

func _create_pvp_player_bar() -> void:
	pvp_player_bar = PanelContainer.new()
	pvp_player_bar.name = "PlayerBar"
	pvp_player_bar.anchor_left = 0.02
	pvp_player_bar.anchor_top = PVP_PLAYER_TOP
	pvp_player_bar.anchor_right = 0.98
	pvp_player_bar.anchor_bottom = 0.98
	pvp_player_bar.offset_left = 0.0
	pvp_player_bar.offset_top = 0.0
	pvp_player_bar.offset_right = 0.0
	pvp_player_bar.offset_bottom = 0.0
	pvp_player_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.11, 0.14, 0.10, 0.96), Color(0.25, 0.36, 0.24, 1.0)))
	pvp_root.add_child(pvp_player_bar)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.offset_left = 12.0
	root_vbox.offset_top = 10.0
	root_vbox.offset_right = -12.0
	root_vbox.offset_bottom = -10.0
	root_vbox.theme_override_constants.separation = 8
	pvp_player_bar.add_child(root_vbox)

	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.theme_override_constants.separation = 18
	root_vbox.add_child(info_row)

	# 头像框（64x64）
	pvp_avatar_frame_player = TextureRect.new()
	pvp_avatar_frame_player.name = "AvatarFrame"
	pvp_avatar_frame_player.texture = load(PVP_AVATAR_FRAME)
	pvp_avatar_frame_player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvp_avatar_frame_player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pvp_avatar_frame_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_avatar_frame_player.custom_minimum_size = Vector2(64.0, 64.0)
	info_row.add_child(pvp_avatar_frame_player)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.theme_override_constants.separation = 6
	info_row.add_child(info_box)

	var hero_avatar: TextureRect = TextureRect.new()
	hero_avatar.name = "HeroAvatar"
	hero_avatar.texture = load(PVP_HERO_AVATAR)
	hero_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_avatar.custom_minimum_size = Vector2(48.0, 48.0)
	info_box.add_child(hero_avatar)

	pvp_player_name_label = Label.new()
	pvp_player_name_label.add_theme_font_size_override("font_size", 22)
	info_box.add_child(pvp_player_name_label)

	var hp_stack: Control = _create_pvp_hp_stack()
	info_box.add_child(hp_stack)
	pvp_player_hp_bar = hp_stack.get_node("HPBar") as ProgressBar
	pvp_player_hp_label = hp_stack.get_node("HPText") as Label
	pvp_player_shield_bar = hp_stack.get_node("ShieldBar") as ProgressBar
	pvp_player_shield_label = hp_stack.get_node("ShieldLabel") as Label

	pvp_player_meta_label = Label.new()
	pvp_player_meta_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55, 1.0))
	info_box.add_child(pvp_player_meta_label)

	var skills_box: HBoxContainer = HBoxContainer.new()
	skills_box.theme_override_constants.separation = 8
	info_box.add_child(skills_box)
	pvp_player_skill_labels.clear()
	for skill_index in range(3):
		var skill_label: Label = _create_skill_slot_label("Empty")
		skills_box.add_child(skill_label)
		pvp_player_skill_labels.append(skill_label)

	var action_bar: HBoxContainer = HBoxContainer.new()
	action_bar.theme_override_constants.separation = 12
	root_vbox.add_child(action_bar)

	pvp_auto_battle_check = CheckButton.new()
	pvp_auto_battle_check.text = "自动战斗"
	pvp_auto_battle_check.toggled.connect(_on_auto_battle_toggled)
	action_bar.add_child(pvp_auto_battle_check)

	pvp_end_turn_button = Button.new()
	pvp_end_turn_button.text = "End Turn"
	pvp_end_turn_button.disabled = true
	action_bar.add_child(pvp_end_turn_button)

func _update_pvp_player_hand() -> void:
	if pvp_player_hand_container == null:
		return

	# Clear stale interaction state before rebuilding card nodes.
	pvp_hover_card = null
	pvp_selected_card = null
	_hide_pvp_tooltip()

	for child in pvp_player_hand_container.get_children():
		child.queue_free()
	pvp_player_card_panels.clear()

	if inventory == null:
		_add_empty_player_slots(PVP_HAND_SLOT_COUNT)
		return

	var card_count: int = 0
	for item in inventory.items:
		var item_data: ItemData = item as ItemData
		if item_data == null:
			continue

		var card_panel: Panel = Panel.new()
		card_panel.custom_minimum_size = PVP_CARD_SIZE
		card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_panel.add_theme_stylebox_override("panel", _create_player_card_style(item_data))
		card_panel.set_meta("item_data", item_data)
		card_panel.mouse_entered.connect(_on_pvp_card_hovered.bind(card_panel))
		card_panel.mouse_exited.connect(_on_pvp_card_unhovered.bind(card_panel))
		card_panel.gui_input.connect(_on_pvp_card_input.bind(card_panel, item_data))
		pvp_player_hand_container.add_child(card_panel)
		pvp_player_card_panels.append(card_panel)
		card_count += 1

		var illustration: ColorRect = _create_illustration_block(item_data.type)
		card_panel.add_child(illustration)

		var price_badge: Panel = _create_price_badge(item_data.buy_price)
		card_panel.add_child(price_badge)

		var content_vbox: VBoxContainer = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_vbox.offset_left = 6.0
		content_vbox.offset_top = 66.0
		content_vbox.offset_right = -6.0
		content_vbox.offset_bottom = -6.0
		content_vbox.theme_override_constants.separation = 1
		card_panel.add_child(content_vbox)

		var name_label: Label = Label.new()
		name_label.text = item_data.item_name
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_text = true
		name_label.max_lines_visible = 1
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
		stat_label.add_theme_font_size_override("font_size", 10)
		stat_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
		content_vbox.add_child(stat_label)

		var cooldown_label: Label = Label.new()
		cooldown_label.name = "CooldownLabel"
		cooldown_label.text = _get_item_cooldown_text(item_data)
		cooldown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cooldown_label.clip_text = true
		cooldown_label.max_lines_visible = 1
		cooldown_label.add_theme_font_size_override("font_size", 10)
		cooldown_label.add_theme_color_override("font_color", Color(0.86, 0.90, 1.0, 1.0))
		content_vbox.add_child(cooldown_label)

		if item_data.cooldown > 0.0:
			var cooldown_overlay: ColorRect = _create_card_cooldown_overlay(item_data)
			cooldown_overlay.name = "CooldownOverlay"
			card_panel.add_child(cooldown_overlay)

	_add_empty_player_slots(maxi(PVP_HAND_SLOT_COUNT - card_count, 0))

func _update_pvp_opponent_hand() -> void:
	if pvp_opponent_hand_container == null:
		return

	for child in pvp_opponent_hand_container.get_children():
		child.queue_free()

	if current_monster == null:
		return

	for item_index in range(current_monster.monster_items.size()):
		var card_panel: Panel = Panel.new()
		card_panel.custom_minimum_size = PVP_CARD_SIZE
		card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_theme_stylebox_override("panel", _create_card_back_style())
		pvp_opponent_hand_container.add_child(card_panel)

		var center_label: Label = Label.new()
		center_label.text = "✦"
		center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center_label.add_theme_font_size_override("font_size", 28)
		center_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.33, 1.0))
		center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_panel.add_child(center_label)

func _update_pvp_battle_ui() -> void:
	if pvp_root == null:
		return

	var hero: HeroData = game_manager.selected_hero
	var max_hp: int = game_manager.get_max_health()
	var current_shield: float = 0.0
	if hero != null:
		current_shield = hero.current_shield

	if pvp_player_name_label != null:
		pvp_player_name_label.text = hero.hero_name if hero != null else "玩家"
	if pvp_player_hp_bar != null:
		pvp_player_hp_bar.max_value = maxf(float(max_hp), 1.0)
		pvp_player_hp_bar.value = game_manager.player_health
		_update_hp_bar_color(pvp_player_hp_bar)
	if pvp_player_hp_label != null:
		pvp_player_hp_label.text = "%d" % game_manager.player_health
	_update_pvp_shield_ui(pvp_player_shield_bar, pvp_player_shield_label, max_hp, current_shield)

	if pvp_player_meta_label != null:
		var crit_text: String = "暴击 %.0f%%" % (hero.crit_chance * 100.0) if hero != null else "暴击 0%"
		var item_count: int = inventory.items.size() if inventory != null else 0
		pvp_player_meta_label.text = "%s  |  🎒 %d items" % [crit_text, item_count]

	_update_skill_labels(pvp_player_skill_labels, _get_player_skill_names(), false)

	if current_monster != null:
		if pvp_opponent_name_label != null:
			pvp_opponent_name_label.text = current_monster.monster_name
		if pvp_opponent_hp_bar != null:
			pvp_opponent_hp_bar.max_value = maxf(float(current_monster.max_hp), 1.0)
			pvp_opponent_hp_bar.value = current_monster.current_hp
			_update_hp_bar_color(pvp_opponent_hp_bar)
		if pvp_opponent_hp_label != null:
			pvp_opponent_hp_label.text = "%d" % current_monster.current_hp
		_update_pvp_shield_ui(pvp_opponent_shield_bar, pvp_opponent_shield_label, current_monster.max_hp, 0.0)
		if pvp_opponent_meta_label != null:
			var monster_damage: int = _get_monster_total_damage()
			pvp_opponent_meta_label.text = "ATK %d  |  🎒 %d items" % [
				monster_damage,
				current_monster.monster_items.size()
			]

	_update_skill_labels(pvp_opponent_skill_labels, [], true)
	_update_pvp_player_hand_labels()

func _update_pvp_cooldown_overlays() -> void:
	for card_panel in pvp_player_card_panels:
		if not is_instance_valid(card_panel):
			continue

		var item_data: ItemData = card_panel.get_meta("item_data", null) as ItemData
		if item_data == null:
			continue

		var cooldown_label: Label = card_panel.get_node_or_null("ContentVBox/CooldownLabel") as Label
		if cooldown_label != null:
			cooldown_label.text = _get_item_cooldown_text(item_data)

		var cooldown_overlay: ColorRect = card_panel.get_node_or_null("CooldownOverlay") as ColorRect
		if cooldown_overlay != null:
			_update_card_cooldown_overlay(cooldown_overlay, item_data)

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

	if is_pvp:
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
	if is_pvp:
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
	player_shield_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 1.0))
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

	if ratio > 0.6:
		fill_style.bg_color = Color(0.2, 0.75, 0.2, 1.0)
	elif ratio > 0.3:
		fill_style.bg_color = Color(0.85, 0.75, 0.2, 1.0)
	else:
		fill_style.bg_color = Color(0.8, 0.2, 0.2, 1.0)

## ============ 日志 ============

func _log(message: String) -> void:
	if is_pvp and pvp_battle_log != null:
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
	if is_pvp:
		game_manager.on_pvp_win()
	elif current_monster:
		gold_reward = current_monster.get_gold_reward()
		game_manager.add_gold(gold_reward)
		game_manager.on_battle_win()

	_last_battle_won = true
	_last_gold_reward = gold_reward

	if is_pvp:
		if pvp_result_label != null:
			pvp_result_label.text = "🎉 胜利! PvP 胜场 %d / 10" % game_manager.pvp_wins
			pvp_result_label.visible = true
		if pvp_continue_button != null:
			pvp_continue_button.visible = true
	else:
		result_label.text = "🎉 胜利! 获得 %d 金币!" % gold_reward
		result_label.visible = true
		continue_button.visible = true

	_log("🎉 战斗胜利! 获得 %d 金币!" % gold_reward)
	battle_system.end_battle()

func _on_battle_lose() -> void:
	is_battle_active = false
	pvp_selected_card = null

	if is_pvp:
		game_manager.on_pvp_lose()
	else:
		game_manager.on_battle_lose()

	_last_battle_won = false
	_last_gold_reward = 0

	if is_pvp:
		if pvp_result_label != null:
			pvp_result_label.text = "💀 失败! Prestige: %d" % game_manager.prestige
			pvp_result_label.visible = true
		if pvp_continue_button != null:
			pvp_continue_button.visible = true
	else:
		result_label.text = "💀 战斗失败!"
		result_label.visible = true
		continue_button.visible = true

	_log("💀 战斗失败!")
	battle_system.end_battle()

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
	pvp_tooltip_panel.z_index = 100

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	pvp_tooltip_panel.add_theme_stylebox_override("panel", style)
	pvp_tooltip_panel.set_anchor_and_offset_preset(Control.PRESET_TOP_LEFT)

	pvp_tooltip_label = RichTextLabel.new()
	pvp_tooltip_label.bbcode_enabled = true
	pvp_tooltip_label.fit_content = true
	pvp_tooltip_label.scroll_active = false
	pvp_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvp_tooltip_panel.add_child(pvp_tooltip_label)

	if pvp_root != null:
		pvp_root.add_child(pvp_tooltip_panel)

func _show_pvp_tooltip(card_panel: Panel, item_data: ItemData) -> void:
	if pvp_tooltip_panel == null or pvp_tooltip_label == null:
		return

	var text: String = "[b]%s[/b]\n" % item_data.item_name
	text += "Type: %s\n" % item_data.get_type_name()
	if item_data.damage > 0:
		text += "ATK: %d\n" % item_data.get_rarity_adjusted_damage()
	if item_data.heal > 0:
		text += "Heal: %d\n" % item_data.get_rarity_adjusted_heal()
	if item_data.shield > 0:
		text += "Shield: %d\n" % item_data.get_rarity_adjusted_shield()
	if item_data.crit_chance_bonus > 0:
		text += "Crit: +%.0f%%\n" % (item_data.crit_chance_bonus * 100.0)
	if item_data.cooldown > 0:
		text += "CD: %.1fs\n" % item_data.cooldown
	if item_data.poison_damage > 0:
		text += "Poison: %.1f/tick\n" % item_data.poison_damage
	if item_data.burn_damage > 0:
		text += "Burn: %.1f/tick\n" % item_data.burn_damage
	if item_data.regeneration > 0:
		text += "Regen: %.1f/tick\n" % item_data.regeneration

	pvp_tooltip_label.text = text
	pvp_tooltip_panel.visible = true
	pvp_tooltip_panel.reset_size()

	var card_rect: Rect2 = card_panel.get_global_rect()
	var tip_pos: Vector2 = card_rect.position - Vector2(0.0, pvp_tooltip_panel.size.y + 8.0)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	tip_pos.x = clampf(tip_pos.x, 8.0, vp_size.x - pvp_tooltip_panel.size.x - 8.0)
	tip_pos.y = maxf(tip_pos.y, 8.0)
	pvp_tooltip_panel.global_position = tip_pos

func _hide_pvp_tooltip() -> void:
	if pvp_tooltip_panel != null:
		pvp_tooltip_panel.visible = false

func _on_pvp_card_hovered(card_panel: Panel) -> void:
	if pvp_hover_card != null and is_instance_valid(pvp_hover_card) and pvp_hover_card != card_panel:
		_on_pvp_card_unhovered(pvp_hover_card)

	pvp_hover_card = card_panel
	var item_data: ItemData = card_panel.get_meta("item_data", null) as ItemData
	if item_data != null:
		card_panel.add_theme_stylebox_override("panel", _create_player_card_style(item_data, true))
		_show_pvp_tooltip(card_panel, item_data)

func _on_pvp_card_unhovered(card_panel: Panel = null) -> void:
	if card_panel == null or pvp_hover_card != card_panel:
		return

	if pvp_hover_card != null and is_instance_valid(pvp_hover_card):
		var item_data: ItemData = pvp_hover_card.get_meta("item_data", null) as ItemData
		var is_selected: bool = pvp_hover_card == pvp_selected_card
		if item_data != null:
			pvp_hover_card.add_theme_stylebox_override("panel", _create_player_card_style(item_data, false, is_selected))

	pvp_hover_card = null
	_hide_pvp_tooltip()

func _on_pvp_card_input(event: InputEvent, card_panel: Panel, item_data: ItemData) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if pvp_selected_card == card_panel:
			var old: Panel = pvp_selected_card
			pvp_selected_card = null
			old.add_theme_stylebox_override("panel", _create_player_card_style(item_data, false, false))
		else:
			if pvp_selected_card != null and is_instance_valid(pvp_selected_card):
				var old_data: ItemData = pvp_selected_card.get_meta("item_data", null) as ItemData
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
	style.bg_color = Color(0.09, 0.09, 0.14, 0.25)
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
		ItemData.Type.WEAPON:
			return Color(0.6, 0.2, 0.2, 0.8)
		ItemData.Type.SHIELD:
			return Color(0.2, 0.4, 0.7, 0.8)
		ItemData.Type.HEAL:
			return Color(0.2, 0.6, 0.3, 0.8)
		ItemData.Type.UTILITY:
			return Color(0.5, 0.2, 0.6, 0.8)
		_:
			return Color(0.35, 0.35, 0.4, 0.8)

func _create_price_badge(price: int) -> Panel:
	var badge: Panel = Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_top = 0.0
	badge.anchor_right = 0.0
	badge.anchor_bottom = 0.0
	badge.offset_left = 2.0
	badge.offset_top = 2.0
	badge.offset_right = 22.0
	badge.offset_bottom = 22.0

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color8(74, 158, 255, 255)
	badge_style.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", badge_style)

	var badge_label: Label = Label.new()
	badge_label.text = str(price)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_label)

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

func _create_player_card_style(item_data: ItemData, hovered: bool = false, selected: bool = false) -> StyleBoxFlat:
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
		empty_panel.custom_minimum_size = PVP_CARD_SIZE
		empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_panel.add_theme_stylebox_override("panel", _create_empty_hand_slot_style())
		pvp_player_hand_container.add_child(empty_panel)

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
	skill_label.custom_minimum_size = Vector2(92.0, 24.0)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 11)
	skill_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	skill_label.add_theme_stylebox_override("normal", _create_panel_style(Color(0.18, 0.20, 0.28, 1.0), Color(0.30, 0.34, 0.48, 1.0)))
	return skill_label

func _create_pvp_hp_stack() -> Control:
	var hp_stack: Control = Control.new()
	hp_stack.custom_minimum_size = Vector2(300.0, 50.0)

	var hp_text: Label = Label.new()
	hp_text.name = "HPText"
	hp_text.text = "0"
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hp_text.anchor_left = 0.0
	hp_text.anchor_top = 0.0
	hp_text.anchor_right = 0.0
	hp_text.anchor_bottom = 0.0
	hp_text.offset_left = 0.0
	hp_text.offset_top = 0.0
	hp_text.offset_right = 300.0
	hp_text.offset_bottom = 32.0
	hp_text.add_theme_font_size_override("font_size", 36)
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	hp_text.add_theme_constant_override("outline_size", 2)
	hp_stack.add_child(hp_text)

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(300.0, 12.0)
	hp_bar.show_percentage = false
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.anchor_left = 0.0
	hp_bar.anchor_top = 0.0
	hp_bar.anchor_right = 0.0
	hp_bar.anchor_bottom = 0.0
	hp_bar.offset_left = 0.0
	hp_bar.offset_top = 34.0
	hp_bar.offset_right = 300.0
	hp_bar.offset_bottom = 46.0
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.75, 0.2, 1.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_stack.add_child(hp_bar)

	var shield_bar: ProgressBar = ProgressBar.new()
	shield_bar.name = "ShieldBar"
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar.show_percentage = false
	shield_bar.min_value = 0.0
	shield_bar.visible = false
	shield_bar.anchor_left = 0.0
	shield_bar.anchor_top = 0.0
	shield_bar.anchor_right = 0.0
	shield_bar.anchor_bottom = 0.0
	shield_bar.offset_left = 0.0
	shield_bar.offset_top = 34.0
	shield_bar.offset_right = 300.0
	shield_bar.offset_bottom = 46.0
	shield_bar.add_theme_stylebox_override("background", _create_transparent_progress_style())
	shield_bar.add_theme_stylebox_override("fill", _create_shield_fill_style())
	hp_stack.add_child(shield_bar)

	var shield_label: Label = Label.new()
	shield_label.name = "ShieldLabel"
	shield_label.visible = false
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shield_label.anchor_left = 0.0
	shield_label.anchor_top = 0.0
	shield_label.anchor_right = 0.0
	shield_label.anchor_bottom = 0.0
	shield_label.offset_left = 0.0
	shield_label.offset_top = 34.0
	shield_label.offset_right = 300.0
	shield_label.offset_bottom = 46.0
	shield_label.add_theme_font_size_override("font_size", 9)
	shield_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 1.0))
	hp_stack.add_child(shield_label)

	return hp_stack

func _create_pvp_shop_card_placeholder() -> Panel:
	var card: Panel = Panel.new()
	card.custom_minimum_size = PVP_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25, 0.6)
	style.border_color = PVP_SHOP_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var center_label: Label = Label.new()
	center_label.text = "Shop"
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 16)
	center_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.92))
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(center_label)
	return card

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
	style.bg_color = Color(0.3, 0.6, 1.0, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _create_card_cooldown_overlay(item_data: ItemData) -> ColorRect:
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
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.add_child(timer_label)

	_update_card_cooldown_overlay(overlay, item_data)
	return overlay

func _update_card_cooldown_overlay(overlay: ColorRect, item_data: ItemData) -> void:
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

func _update_pvp_player_hand_labels() -> void:
	for card_panel in pvp_player_card_panels:
		if not is_instance_valid(card_panel):
			continue

		var item_data: ItemData = card_panel.get_meta("item_data", null) as ItemData
		if item_data == null:
			continue

		var cooldown_label: Label = card_panel.get_node_or_null("ContentVBox/CooldownLabel") as Label
		if cooldown_label != null:
			cooldown_label.text = _get_item_cooldown_text(item_data)

func _get_item_stat_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	if item_data.damage > 0:
		return "🗡️ ATK +%d" % item_data.get_rarity_adjusted_damage()
	if item_data.heal > 0:
		return "💚 Heal +%d" % item_data.get_rarity_adjusted_heal()
	if item_data.shield > 0:
		return "🛡️ Shield +%d" % item_data.get_rarity_adjusted_shield()
	return "✨ %s" % item_data.get_type_name()

func _get_item_cooldown_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	if item_data.current_cooldown > 0.0:
		return "CD: %.1fs" % item_data.current_cooldown
	return "Ready" if item_data.cooldown > 0.0 else "Passive"

func _get_monster_total_damage() -> int:
	if current_monster == null:
		return 0

	var total_damage: int = 0
	for monster_item in current_monster.monster_items:
		total_damage += int(monster_item.get("damage", 0))
	return total_damage

func _get_player_skill_names() -> Array[String]:
	var names: Array[String] = []

	if battle_system != null and "skill_manager" in battle_system:
		var skill_manager: Variant = battle_system.skill_manager
		if skill_manager != null and skill_manager.has_method("get_equipped_skills"):
			var equipped_skills: Array = skill_manager.get_equipped_skills()
			for skill_entry in equipped_skills:
				var skill_data: SkillData = skill_entry as SkillData
				if skill_data != null and not skill_data.skill_name.is_empty():
					names.append(skill_data.skill_name)

	if names.is_empty() and game_manager.selected_hero != null:
		for hero_skill in game_manager.selected_hero.skills:
			var skill_data: SkillData = hero_skill as SkillData
			if skill_data != null and not skill_data.skill_name.is_empty():
				names.append(skill_data.skill_name)

	if names.is_empty() and game_manager.selected_hero != null and game_manager.selected_hero.has_passive_skill():
		names.append(game_manager.selected_hero.passive_skill_name)

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
